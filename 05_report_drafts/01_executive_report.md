# Executive Report
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

## Enterprise Risk Summary

Operation Black Forge identified eight confirmed security findings against OPFOR-02, a Linux-based healthcare records server running OpenEMR 4.1.0. Two findings are rated Critical severity, three High, two Medium, and one Low. The confirmed attack chain required no prior credentials, no physical access, and no privileged network position — only network reachability to the target's web service on port 80.

The most significant risk is a combination of an unauthenticated SQL injection vulnerability in the OpenEMR login subsystem and a custom SUID binary susceptible to privilege escalation via PATH manipulation. Together these two weaknesses form a complete, unauthenticated path from zero access to full root compromise of the server, with no defensive control successfully interrupting the chain at any stage.

The server runs on a software stack that has been entirely end-of-life since at least 2014 (PHP 5.3.3, Apache 2.2.17, PCLinuxOS 2011, Linux kernel 2.6.38.8), meaning no security patches are available for the underlying platform, and the risk of exploitation applies to the server as a whole, not only to the identified OpenEMR vulnerabilities.

---

## Attack Chain Summary

The operator established full root access to OPFOR-02 via the following chain, derived entirely from evidence gathered during enumeration:

1. Port scan identified two services: ProFTPD 1.3.3d on port 21 and Apache 2.2.17 on port 80.
2. Web content discovery surfaced a hidden OpenEMR 4.1.0 installation at /openemr/, not linked from the landing page.
3. Analysis of the OpenEMR login page source revealed a pre-authentication AJAX endpoint (validateUser.php) used for credential hashing. This endpoint was found vulnerable to time-based blind SQL injection (Exploit-DB 49742).
4. The SQL injection extracted two username and SHA1 password hash pairs from the OpenEMR user database without any authentication.
5. Both hashes were cracked against the rockyou.txt wordlist in under one second, yielding admin:ackbar and medical:medical.
6. An authenticated session was established as admin by submitting the pre-hashed credential directly to the login endpoint, bypassing client-side JavaScript hashing.
7. An authenticated arbitrary file upload vulnerability in manage_site_files.php allowed a PHP bind shell to be uploaded to a web-accessible directory.
8. An interactive shell was obtained as the apache web process user (uid=479) via netcat connecting to the bind shell on port 5555. Outbound connections from the target were blocked by Shorewall firewall, making a bind shell necessary.
9. Post-exploitation enumeration identified a custom SUID binary (/usr/bin/healthcheck) owned by root that invokes system commands via system() without absolute paths.
10. PATH environment variable manipulation caused the binary to execute a malicious payload as root, creating a SUID copy of bash (/tmp/rootbash).
11. Root access was confirmed (euid=0) and mission flags retrieved from /root/root.txt and /home/almirant/user.txt.

Total time from first network scan to root: approximately 8 hours including documentation and troubleshooting.

---

## Business Impact

The target hosts an OpenEMR electronic health records system. A complete compromise of this system has the following business and regulatory implications:

- All patient health records stored in the OpenEMR database are accessible to an attacker with root access.
- Database credentials are stored in plaintext in a web-accessible configuration file, making lateral movement to connected database systems trivial.
- Root access provides full control of the host, including the ability to install persistent backdoors, modify or destroy records, and pivot to any network segment reachable from this host.
- A healthcare records breach carries significant regulatory consequences under applicable data protection legislation, including mandatory patient notification and potential financial penalty.
- The server's age (2011 OS, 2011 kernel) means there is no vendor patch available for the underlying platform, making remediation dependent on migration rather than patching.

---

## Top Remediation Priorities

| Priority | Action | Timeframe |
|----------|--------|-----------|
| 1 | Remove SUID/SGID bits from /usr/bin/healthcheck or delete the binary | Immediate |
| 2 | Upgrade OpenEMR to a supported version to patch validateUser.php SQL injection | Immediate |
| 3 | Reset all OpenEMR account passwords and enforce a minimum password policy | Immediate |
| 4 | Restrict file upload in manage_site_files.php to whitelisted extensions and disable PHP execution in the upload directory | Short-term |
| 5 | Migrate the entire server to a supported OS and software stack | Strategic |

---

*This report covers findings within the authorised scope of CIP-A105 CTF2. All testing was conducted on an isolated host-only lab network against a designated target VM.*
