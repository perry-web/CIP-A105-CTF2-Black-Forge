# Phase 7 - Remediation Validation and Withdrawal

Date: 2026-09-19
Operator system: Kali Linux (attacker) -> OPFOR-02 (target)
Objective: Translate each confirmed weakness into a prioritised remediation action. Terminate sessions, restore clean baseline, and prepare for report submission.

## Confirmed Findings and Remediation Roadmap

### Finding 1 - Unauthenticated SQL Injection in OpenEMR validateUser.php
Severity: Critical
Asset: http://192.168.254.128/openemr/interface/login/validateUser.php
Evidence: 49742.py extracted full user credential table with no authentication required.

Remediation:
- Upgrade OpenEMR immediately to a supported version (4.1.3 or later patched the u parameter injection).
- Apply parameterised queries / prepared statements to all database-facing input handling.
- Implement a web application firewall rule to block SQL metacharacters in the u parameter as an interim control.

Validation without changing the issued image:
- Run the exploit script against the patched version and confirm it no longer extracts data.
- Verify the validateUser.php endpoint sanitises input via code review.

### Finding 2 - Weak and Default Credentials
Severity: High
Asset: OpenEMR application user accounts
Evidence: admin:ackbar and medical:medical cracked from rockyou.txt in under 1 second.

Remediation:
- Enforce a minimum password policy: length at least 12 characters, complexity required.
- Remove or rename the admin account; assign a unique strong passphrase.
- Change medical account password immediately.
- Consider implementing account lockout after a defined number of failed login attempts.
- Remove the commented-out demo credential hint from login.php source.

Validation:
- Attempt to crack newly set passwords against rockyou.txt and confirm failure.
- Review login.php source to confirm comment removed.

### Finding 3 - Authenticated Arbitrary File Upload via manage_site_files.php
Severity: High
Asset: http://192.168.254.128/openemr/interface/super/manage_site_files.php
Evidence: Uploaded shell.php and bindshell2.php to /var/www/html/openemr/sites/default/images/ using authenticated admin session.

Remediation:
- Restrict file uploads to a whitelist of permitted extensions (gif, jpg, png only for an image upload function).
- Store uploaded files outside the web root or in a directory with PHP execution disabled via Apache configuration (php_flag engine off).
- Implement server-side MIME type validation, not just extension checking.
- Restrict access to manage_site_files.php by IP address or require a secondary authentication factor for admin functions.

Validation:
- Attempt to upload a .php file and confirm it is rejected or not executable.
- Confirm uploaded files land in a non-executable directory.

### Finding 4 - SUID Binary PATH Hijack (/usr/bin/healthcheck)
Severity: Critical
Asset: /usr/bin/healthcheck
Evidence: Binary calls system commands without absolute paths via system(). PATH manipulation caused ifconfig to be replaced with a malicious payload, creating a root SUID shell.

Remediation:
- Remove the SUID and SGID bits from healthcheck immediately: chmod 0755 /usr/bin/healthcheck
- Rewrite the binary (or its source) to use absolute paths for all system calls (/sbin/ifconfig, /sbin/fdisk, /usr/bin/du).
- If the binary is not required, remove it entirely.
- Audit all SUID/SGID binaries on the system and remove unnecessary elevated permissions.

Validation:
- Confirm chmod removed the SUID bit: ls -la /usr/bin/healthcheck should show -rwxr-xr-x.
- Repeat the PATH hijack attempt and confirm it no longer produces an elevated shell.

### Finding 5 - End-of-Life Server Stack
Severity: High
Asset: Entire OPFOR-02 host
Evidence: Apache 2.2.17 (EOL), PHP 5.3.3 (EOL since 2014), PCLinuxOS 2011, Kernel 2.6.38.8 (2011).

Remediation:
- Migrate the OpenEMR installation to a supported OS and server stack (current Ubuntu LTS, PHP 8.x, Apache 2.4.x).
- Apply all available OS and package updates as an immediate interim measure.
- Establish a patch management process to ensure timely updates going forward.

Validation:
- Confirm updated versions via apache2 -v, php -v, uname -r after migration.

### Finding 6 - Plaintext Database Credentials in Web-Accessible Config File
Severity: Medium
Asset: /var/www/html/openemr/sites/default/sqlconf.php
Evidence: openemr:openemr MySQL credentials readable by the apache web process and any user with file read access via RCE.

Remediation:
- Change the MySQL openemr account password to a strong unique value.
- Restrict file permissions on sqlconf.php: chmod 640, owned root:apache.
- Consider storing credentials in environment variables rather than flat config files.
- Ensure the MySQL openemr account has only the minimum required database privileges (SELECT, INSERT, UPDATE on openemr database only, no FILE or SUPER privilege).

Validation:
- Confirm file permissions updated.
- Attempt to read the file as an unprivileged web process and confirm access is denied.

### Finding 7 - phpMyAdmin Exposed on Public Web Interface
Severity: Medium
Asset: http://192.168.254.128/phpMyAdmin/
Evidence: phpMyAdmin interface present on port 80, currently returning 403 but present and fingerprintable.

Remediation:
- Remove phpMyAdmin from the production web server entirely if not required.
- If required, restrict access to localhost or a management network segment via Apache access controls.
- Keep phpMyAdmin updated to a patched version if retained.

Validation:
- Confirm phpMyAdmin is no longer accessible or returns 403 with no version information disclosed.

### Finding 8 - ProFTPD 1.3.3d Exposed with No Business Justification Identified
Severity: Low
Asset: ProFTPD on port 21
Evidence: FTP service running, anonymous access denied, version 1.3.3d is EOL.

Remediation:
- Disable and remove ProFTPD if FTP is not required for a business function.
- If FTP is required, migrate to SFTP (already available via sshd) and disable plain FTP.
- Ensure ProFTPD is not configured to allow anonymous access under any configuration change.

Validation:
- Confirm port 21 is no longer open via nmap scan after removal.

## Prioritised Remediation Summary

| Priority | Finding | Action |
|----------|---------|--------|
| Immediate | SUID healthcheck PATH hijack | Remove SUID bit, rewrite with absolute paths |
| Immediate | OpenEMR SQLi in validateUser.php | Upgrade OpenEMR to supported version |
| Immediate | Weak credentials admin and medical | Reset all passwords, enforce policy |
| Short-term | Arbitrary file upload via manage_site_files | Whitelist extensions, disable PHP in upload dir |
| Short-term | Plaintext DB credentials in sqlconf.php | Rotate credentials, restrict file permissions |
| Short-term | EOL server stack | Plan migration to supported OS and stack |
| Strategic | phpMyAdmin exposure | Remove or restrict to management network |
| Strategic | ProFTPD unnecessary exposure | Disable FTP, use SFTP only |

## Session Termination and Withdrawal

Actions taken:
- Bind shell connection closed (exit in Terminal 2)
- Webshell files (shell.php, revshell.php, bindshell.php, bindshell2.php) should be removed from target
- rootbash SUID copy should be removed from /tmp
- Evidence folder preserved at ~/CIP-A105_RegNo_CTF2_Black-Forge/
- Clean baseline snapshot (CIP-A105-CTF2-CLEAN-BASELINE) available for restoration

## Cleanup Commands (run from webshell before closing)

```
/tmp/rootbash -p -c 'rm /tmp/rootbash /tmp/ifconfig /tmp/f /tmp/exploit.sh'
```

```bash
curl -s "http://192.168.254.128/openemr/sites/default/images/shell.php?cmd=rm+/var/www/html/openemr/sites/default/images/shell.php"
curl -s "http://192.168.254.128/openemr/sites/default/images/bindshell2.php?cmd=rm+/var/www/html/openemr/sites/default/images/bindshell2.php"
```

## Evidence References
- 03_operator_log/operator_log.md
- 06_phase_notes/ (all phase files)
- 01_scans/ (all scan output files)
- 02_screenshots/ (all screenshots)
- 04_evidence_hashes/openemr_hashes.txt
- 04_evidence_hashes/openemr_cracked_creds.txt
