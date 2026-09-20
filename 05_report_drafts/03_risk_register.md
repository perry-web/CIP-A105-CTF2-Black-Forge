# Risk Register
## CIP-A105 | CTF2 | Operation Black Forge

---

| ID | Finding | Asset/Service | Likelihood | Impact | Severity | Evidence File | Remediation Summary |
|----|---------|---------------|------------|--------|----------|---------------|---------------------|
| R1 | Unauthenticated SQL Injection in validateUser.php | OpenEMR /openemr/interface/login/validateUser.php | High | Critical | Critical | 01_scans/searchsploit_openemr_phase3.txt, 04_evidence_hashes/openemr_hashes.txt | Upgrade OpenEMR to supported version; implement prepared statements |
| R2 | Weak and default credentials on OpenEMR accounts | OpenEMR user accounts (admin, medical) | High | High | High | 04_evidence_hashes/openemr_cracked_creds.txt | Enforce password policy minimum 16 chars; rotate all credentials immediately |
| R3 | Authenticated arbitrary file upload via manage_site_files.php | OpenEMR /openemr/interface/super/manage_site_files.php | High | High | High | 06_phase_notes/phase4_initial_access.md | Whitelist upload extensions; disable PHP execution in upload directory |
| R4 | SUID binary PATH hijack via /usr/bin/healthcheck | /usr/bin/healthcheck (custom binary, root:root rwsr-sr-x) | High | Critical | Critical | 06_phase_notes/phase6_privesc.md | Remove SUID bit immediately; rewrite with absolute command paths or delete binary |
| R5 | End-of-life server software stack | Entire OPFOR-02 host (OS, kernel, Apache, PHP) | High | High | High | 01_scans/nmap_full_tcp_phase1.txt, 06_phase_notes/phase1_discovery.md | Migrate to supported Ubuntu LTS, PHP 8.x, Apache 2.4.x |
| R6 | Plaintext database credentials in web-accessible config | /var/www/html/openemr/sites/default/sqlconf.php | Medium | Medium | Medium | 06_phase_notes/phase5_post_exploitation.md | Rotate MySQL credentials; chmod 640 on sqlconf.php; restrict DB account privileges |
| R7 | phpMyAdmin database admin panel exposed on public web interface | http://192.168.254.128/phpMyAdmin/ | Medium | Medium | Medium | 01_scans/gobuster_root_big_phase2.txt | Remove phpMyAdmin or restrict to localhost via Apache access controls |
| R8 | ProFTPD EOL service with no identified business justification | ProFTPD 1.3.3d on port 21 | Low | Low | Low | 01_scans/nmap_full_tcp_phase1.txt | Disable ProFTPD; use SFTP via existing sshd if file transfer required |

---

## Severity Definitions

| Severity | Definition |
|----------|------------|
| Critical | Direct path to full system compromise or data exfiltration requiring no authentication |
| High | Significant exposure enabling privilege escalation, authenticated RCE, or mass credential theft |
| Medium | Information disclosure or configuration weakness enabling lateral movement if chained |
| Low | Minimal exploitability, low impact, or mitigated by other controls |

---

## Likelihood Definitions

| Likelihood | Definition |
|------------|------------|
| High | Exploit is publicly available, requires low skill, and the condition is confirmed present |
| Medium | Exploit exists but requires specific conditions or moderate skill to execute |
| Low | Limited public exploit availability or significant preconditions required |
