# Technical Report
## CIP-A105 | CTF2 | Operation Black Forge

---

| Field | Detail |
|-------|--------|
| Course | CIP-A105 |
| CTF Number | 2 |
| Operation Codename | Black Forge |
| Student Name | Perry Koko |
| Registration Number | C1126EHIT17343 |
| Submission Date | 2026-09-19 |
| Classification | Confidential — For Instructor Use Only |

---

## 1. Scope and Rules of Engagement

| Item | Detail |
|------|--------|
| Authorised target | OPFOR-02 — Healthcare:1 (VulnHub, v1n1v131r4) |
| Attacker system | Kali Linux (192.168.254.129) |
| Network | Isolated Host-Only VMware segment (VMnet1, 192.168.254.0/24) |
| Prohibited | Bridged networking, public internet exposure, use of public walkthroughs or spoiler content |
| Required | Derive all attack paths from evidence; maintain operator log; document all phases |

---

## 2. Laboratory Architecture and Methodology

### Network Diagram

[Host PC - Windows]
|
[VMware VMnet1 - Host-Only - 192.168.254.0/24]
| |
[Kali Linux] [Healthcare VM]
192.168.254.129 192.168.254.128
(eth1 - host-only) (eth1 - host-only)
(eth0 - NAT, internet)


### Methodology
The assessment followed the seven-phase methodology defined in the Operation Black Forge brief:
- Phase 0: Preparation and environment control
- Phase 1: Network and service discovery
- Phase 2: Enterprise service enumeration
- Phase 3: Exploit chain development
- Phase 4: Initial access
- Phase 5: Linux post-exploitation
- Phase 6: Privilege escalation and objectives
- Phase 7: Remediation validation and withdrawal

All findings were derived independently from enumeration evidence. No public walkthroughs or target-specific spoilers were used for attack path derivation.

---

## 3. Network and Service Enumeration

### Host Discovery

Command: sudo nmap -sn 192.168.254.0/24
Target identified: 192.168.254.128 (MAC vendor: VMware)


### Full TCP Port Scan

Command: sudo nmap -sV -p- 192.168.254.128
Output saved to: 01_scans/nmap_full_tcp_phase1.txt


| Port | State | Service | Version |
|------|-------|---------|---------|
| 21/tcp | open | ftp | ProFTPD 1.3.3d |
| 80/tcp | open | http | Apache httpd 2.2.17 (PCLinuxOS 2011/PREFORK-1pclos2011) |

65,533 ports closed or filtered. No UDP services scanned (not required by scope).

---

## 4. Web Service Enumeration

### HTTP Header Analysis
Server header confirmed: Apache/2.2.17 (PCLinuxOS 2011)
PHP version disclosed in subsequent requests: PHP/5.3.3 (X-Powered-By header)

### robots.txt
Default Apache/PCLinuxOS content. Disallowed paths listed but none target-specific. /admin/ returns 404. /addon-modules/ returns 403 (exists but restricted).

### Content Discovery
Three sequential wordlist scans were required to surface the primary application:

| Wordlist | Size | Result |
|----------|------|--------|
| directory-list-2.3-medium.txt | ~220k | Standard scaffolding only (css, js, images, fonts, gitweb, phpMyAdmin) |
| directory-list-lowercase-2.3-medium.txt | ~208k | No new results |
| DirBuster-2007_directory-list-2.3-big.txt (SecLists) | ~3.8M | /openemr/ discovered |

Key paths identified:

| Path | Status | Significance |
|------|--------|--------------|
| /openemr/ | 301 | OpenEMR electronic health records application |
| /phpMyAdmin/ | 403 | Database admin panel present, access restricted |
| /gitweb/ | 301/403 | Git web interface present, directory listing disabled |
| /server-status | 403 | Apache mod_status enabled |

### OpenEMR Application Fingerprinting
Login page source analysis (login.php) revealed:
- jQuery 1.4.3 (consistent with 2010-2011 era OpenEMR)
- Client-side SHA1 and MD5 password hashing via embedded JavaScript
- AJAX call to validateUser.php?u= during login to select hash algorithm
- Commented-out demo credential block (admin/pass) left in page source
- PHP/5.3.3 disclosed in response headers

These indicators are consistent with OpenEMR version 4.1.0.

### FTP Enumeration
Anonymous authentication attempted and rejected (530 Login incorrect). ProFTPD 1.3.3d banner confirmed. No further FTP enumeration possible without credentials.

---

## 5. Attack Surface Summary

| Asset | Service | Version | Finding | Severity |
|-------|---------|---------|---------|---------|
| validateUser.php | HTTP/OpenEMR | 4.1.0 | Unauthenticated SQL injection | Critical |
| OpenEMR user accounts | HTTP/OpenEMR | 4.1.0 | Weak credentials cracked from rockyou.txt | High |
| manage_site_files.php | HTTP/OpenEMR | 4.1.0 | Authenticated arbitrary file upload | High |
| /usr/bin/healthcheck | OS binary | N/A | SUID binary PATH hijack | Critical |
| Entire host | OS/Stack | PCLinuxOS 2011 | End-of-life software stack | High |
| sqlconf.php | Config file | N/A | Plaintext database credentials | Medium |
| /phpMyAdmin/ | HTTP | Unknown | Database admin panel exposed | Medium |
| ProFTPD | FTP | 1.3.3d | EOL service, unnecessary exposure | Low |

---

## 6. Confirmed Findings and Risk Ratings

### F1 — Unauthenticated SQL Injection (validateUser.php)

- CVSS Vector: AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N
- Severity: Critical
- Exploit-DB Reference: 49742
- Description: The u parameter in /openemr/interface/login/validateUser.php is vulnerable to time-based blind SQL injection. The endpoint is called pre-authentication via AJAX and performs no input sanitisation on the u parameter before passing it to a database query. An attacker can enumerate the entire users table including username and password hash pairs without any prior access.
- Evidence: python3 49742.py extracted admin and medical credentials in a single unauthenticated request chain.

### F2 — Weak Credentials

- Severity: High
- Description: Both OpenEMR user accounts use passwords present in the rockyou.txt wordlist. admin uses ackbar (a dictionary word) and medical uses medical (identical to the username). Both hashes were cracked in under one second from the first 7.24 percent of the rockyou.txt wordlist.
- Evidence: john and hashcat output confirming plaintext recovery.

### F3 — Authenticated Arbitrary File Upload

- Severity: High
- Exploit-DB Reference: 28329
- Description: The manage_site_files.php endpoint in the OpenEMR admin panel accepts file uploads of any type and stores them in /var/www/html/openemr/sites/default/images/, which is web-accessible and PHP-executable. An authenticated admin user can upload a PHP webshell and execute arbitrary OS commands as the apache web process.
- Evidence: bindshell2.php uploaded and executed; interactive shell obtained as uid=479(apache).

### F4 — SUID Binary PATH Hijack

- Severity: Critical
- Description: /usr/bin/healthcheck is a custom SUID/SGID binary owned by root that executes system commands (ifconfig, fdisk, du) via system() without specifying absolute paths. The system() function inherits the caller's PATH environment variable. An attacker with any shell on the system can prepend a malicious directory to PATH and cause healthcheck to execute an arbitrary payload as root.
- Evidence: strings analysis, rootbash creation, euid=0 confirmation.

### F5 — End-of-Life Server Stack

- Severity: High
- Description: The entire server platform is end-of-life: OS (PCLinuxOS 2011), kernel (2.6.38.8, July 2011), Apache (2.2.17, EOL), PHP (5.3.3, EOL since December 2014). No security patches are available from any vendor for any component of this stack.
- Evidence: nmap service scan, uname -a, /etc/issue, X-Powered-By header.

### F6 — Plaintext Database Credentials

- Severity: Medium
- Description: MySQL credentials for the openemr database account are stored in plaintext in /var/www/html/openemr/sites/default/sqlconf.php, readable by any process or user with file read access (including via RCE as apache).
- Evidence: cat sqlconf.php output showing host, login, pass, dbase fields in cleartext.

### F7 — phpMyAdmin Exposed

- Severity: Medium
- Description: A phpMyAdmin database administration interface is present at /phpMyAdmin/ on the public web service. Currently returning 403, but its presence confirms a database management interface is deployed and fingerprintable.
- Evidence: gobuster output, curl status check.

### F8 — ProFTPD Unnecessary Exposure

- Severity: Low
- Description: ProFTPD 1.3.3d is running on port 21 with no identified business justification. The version is end-of-life. No anonymous access was possible but the service represents unnecessary attack surface.
- Evidence: nmap service scan result.

---

## 7. Initial Access Narrative

Following enumeration, the OpenEMR application at /openemr/ was identified as the primary attack surface. Analysis of the login page JavaScript source revealed that the authentication flow includes a pre-authentication AJAX call to validateUser.php?u= to determine the password hashing algorithm. Cross-referencing this endpoint against Exploit-DB identified a time-based blind SQL injection vulnerability (49742) targeting precisely this parameter.

The exploit was copied from the local Exploit-DB mirror, modified to target the correct host IP, and executed. The exploit performed character-by-character extraction of the OpenEMR users table via sleep-based timing inference, returning two username:hash pairs after several minutes of execution.

Both SHA1 hashes were submitted to john and hashcat with the rockyou.txt wordlist. Both cracked within one second. The admin account credential ackbar and the medical account credential medical were confirmed.

Attempts to authenticate using cleartext passwords via curl initially failed. Analysis of the login.php JavaScript revealed that the browser never sends the cleartext password; it computes a SHA1 hash client-side and submits only the hash in the authPass field, clearing clearPass before form submission. Re-attempting authentication by submitting the extracted SHA1 hash directly in the authPass field succeeded, returning HTTP 200 OK for both accounts.

With an authenticated admin session established, the manage_site_files.php endpoint was identified as an arbitrary file upload surface. A PHP bind shell (bindshell2.php) was uploaded to /var/www/html/openemr/sites/default/images/. Triggering the uploaded file via HTTP caused PHP to open a listening TCP socket on port 5555. Connecting via netcat from Kali yielded an interactive shell as apache (uid=479).

Note on failed reverse shell attempts: Multiple reverse shell payloads (bash TCP redirect, mkfifo pipe, python socket, php fsockopen) were attempted before the bind shell approach was adopted. All reverse shells failed silently. Post-compromise enumeration confirmed that the Shorewall firewall service was active on the target, blocking outbound TCP connections. ICMP (ping) was permitted outbound, confirming network reachability, but TCP connections from target to attacker were dropped. The bind shell approach (attacker connects to target) bypassed this restriction since only outbound connections were blocked.

---

## 8. Post-Exploitation and Privilege Escalation Narrative

From the apache shell, systematic post-exploitation enumeration was conducted across host identity, users, sudo rights, SUID/SGID files, running services, network state, scheduled jobs, and configuration files.

Key findings from enumeration:

- Three interactive user accounts: root, medical, and almirant. The user almirant had the most recent and frequent login history, suggesting this is the primary workstation account.
- apache has no sudo rights.
- MySQL credentials openemr:openemr found in plaintext in sqlconf.php.
- Shorewall firewall confirmed active in /etc/init.d/.
- SUID/SGID binary: /usr/bin/healthcheck (root:root, rwsr-sr-x, 5813 bytes, created 2020-07-29).

The healthcheck binary immediately stood out as non-standard. Running strings against the binary revealed the complete command string executed via system():

clear ; echo 'System Health Check' ; echo '' ; echo 'Scanning System' ; sleep 2 ; ifconfig ; fdisk -l ; du -h


Every command in this string is invoked without an absolute path. The system() C library function passes the command string to /bin/sh -c, which resolves command names against the current PATH environment variable. Since the binary is SUID root, all commands it invokes via system() execute with root effective UID.

The privilege escalation was executed in three steps:

Step 1 — A malicious ifconfig script was placed in /tmp:

echo 'cp /bin/bash /tmp/rootbash && chmod 4777 /tmp/rootbash' > /tmp/ifconfig
chmod +x /tmp/ifconfig


Step 2 — PATH was modified to prepend /tmp and healthcheck was executed in the same shell environment:

export PATH=/tmp:$PATH ; /usr/bin/healthcheck


When healthcheck called ifconfig, the shell resolved it to /tmp/ifconfig (first match in PATH), executing the payload as root. This created a world-executable SUID copy of bash at /tmp/rootbash.

Step 3 — Root access was confirmed and flags retrieved:

/tmp/rootbash -p -c 'id'
Result: uid=479(apache) gid=416(apache) euid=0(root) groups=0(root),416(apache)

/tmp/rootbash -p -c 'cat /root/root.txt'
/tmp/rootbash -p -c 'cat /home/almirant/user.txt'


The -p flag instructs bash not to drop the elevated effective UID inherited from the SUID bit, preserving root access.

---

## 9. Mission Objectives and Proof of Completion

| Objective | Status | Evidence |
|-----------|--------|----------|
| Gain initial access to OPFOR-02 | Complete | Shell as apache uid=479 via bindshell2.php |
| Achieve root access | Complete | euid=0 via /tmp/rootbash -p |
| Retrieve user flag | Complete | /home/almirant/user.txt |
| Retrieve root flag | Complete | /root/root.txt |

### Mission Proofs

| Flag | Value |
|------|-------|
| user.txt | d41d8cd98f00b204e9800998ecf8427e |
| root.txt | eaff25eaa9ffc8b62e3dfebf70e83a7b |

---

## 10. Remediation Roadmap

### Immediate Actions (within 24 hours)

1. Remove SUID and SGID bits from /usr/bin/healthcheck:
   chmod 0755 /usr/bin/healthcheck
   If the binary is not operationally required, remove it entirely.

2. Upgrade OpenEMR to a supported version that patches the validateUser.php SQL injection.

3. Reset all OpenEMR account passwords immediately. Enforce minimum 16-character passphrases.

### Short-Term Actions (within 30 days)

4. Implement file extension whitelisting and disable PHP execution in the OpenEMR images upload directory.

5. Rotate MySQL credentials and restrict sqlconf.php file permissions (chmod 640, root:apache).

6. Begin planning migration of the server to a supported OS and software stack.

### Strategic Actions (within 90 days)

7. Complete server migration to supported Ubuntu LTS with PHP 8.x, Apache 2.4.x, and a current OpenEMR release.

8. Restrict phpMyAdmin to localhost access only, or remove it entirely.

9. Disable ProFTPD and migrate any FTP-dependent processes to SFTP.

10. Implement a patch management policy with defined timelines for OS and application updates.

---

## 11. Conclusion and Lessons Learned

OPFOR-02 was fully compromised via a chain of three primary weaknesses: a pre-authentication SQL injection in OpenEMR, an authenticated arbitrary file upload in the OpenEMR admin panel, and a custom SUID binary susceptible to PATH hijack. No single defensive control successfully interrupted the attack chain at any stage.

The server's end-of-life software stack is the systemic root cause underlying most findings. A platform last patched in 2011-2014 cannot be secured through configuration alone; migration is the only complete remediation.

### Failed Paths and Lessons

The openflashchart upload path (24529.rb) was initially identified as a viable vector. Testing confirmed the ofc_upload_image.php endpoint was present and responsive, but the tmp-upload-images upload directory did not exist, making the vector non-viable on this specific installation. This reinforced the importance of verifying each step of an exploit chain against the actual target rather than assuming a match between the vulnerability description and the target's configuration.

Reverse shell attempts consumed significant time before the Shorewall firewall restriction was identified. Earlier enumeration of firewall rules via the command execution webshell would have identified this constraint sooner and avoided repeated failed attempts across multiple payload types.

### Operational Improvements

- Run iptables -L -n as an early post-RCE enumeration step rather than waiting until reverse shells fail.
- Use a session-refresh mechanism (re-authentication wrapper) when conducting multi-step operations against web applications with session timeouts, to avoid the 302 redirect issue encountered during file uploads.
- Always verify SUID binary behaviour with strings before attempting exploitation to confirm the specific PATH manipulation opportunity rather than assuming.
