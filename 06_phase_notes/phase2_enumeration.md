# Phase 2 - Enterprise Service Enumeration

Date: 2026-09-19
Operator system: Kali Linux (attacker) -> OPFOR-02 (target)
Objective: Enumerate the FTP and HTTP services identified in Phase 1 to identify trust boundaries, authentication surfaces, and configuration weaknesses.

## Tools Used
- ftp (command-line client)
- curl

## Actions and Findings

### FTP Enumeration (Port 21)
Command:

ftp 192.168.254.128

Banner: ProFTPD 1.3.3d Server (ProFTPD Default Installation)

Attempted anonymous authentication:

Name: anonymous
Password: (blank)

Result: 530 Login incorrect. Anonymous access is not permitted on this FTP service.

### HTTP Enumeration (Port 80) - Header Inspection
Command:

curl -s -D - http://192.168.254.128/ -o /dev/null

Result:

| Header | Value |
|--------|-------|
| Status | HTTP/1.1 200 OK |
| Server | Apache/2.2.17 (PCLinuxOS 2011/PREFORK-1pclos2011) |
| Last-Modified | Sat, 06 Jan 2018 06:21:38 GMT |
| Content-Length | 5031 |
| Content-Type | text/html |

## Analysis
FTP does not permit anonymous access; valid credentials would be required and are not yet known. This service is deprioritised pending further findings unless credentials are discovered elsewhere.

HTTP service is active and serving a static-looking page (Last-Modified from 2018, unchanged since). Apache version and underlying OS (PCLinuxOS 2011) are dated, suggesting the service has not been patched or updated in some time - a relevant observation for the risk register. Content discovery is required to determine what else the web service is hosting, since the landing page alone does not reveal the full attack surface.

## Evidence References
- 01_scans/nmap_full_tcp_phase1.txt

### robots.txt Disclosure Check
Command:

curl -s http://192.168.254.128/robots.txt

Result: Default Apache/PCLinuxOS robots.txt content. Disallowed paths listed: /manual/, /manual-2.2/, /addon-modules/, /doc/, /images/, /all_our_e-mail_addresses, /admin/. This appears to be unmodified default distribution content rather than site-specific configuration, and does not by itself disclose a meaningful attack surface.

Note: /addon-modules/ and /admin/ are worth manual verification in case they resolve to something beyond default Apache manual pages.

### Manual Path Verification
Commands:

curl -s -o /dev/null -w "%{http_code}\n" http://192.168.254.128/addon-modules/
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.254.128/admin/

Result:

| Path | HTTP Status | Interpretation |
|------|-------------|----------------|
| /addon-modules/ | 403 | Path exists but access is forbidden from current context |
| /admin/ | 404 | Path does not exist on this server |

## Analysis (continued)
/addon-modules/ existing but returning 403 indicates the directory is present on disk but either lacks directory listing permissions or is restricted by IP/config (e.g. localhost-only access, per Apache configuration conventions). This is noted as a point of interest but not further pursued manually at this stage since it is access-restricted, not a confirmed vulnerability. Broader content discovery is required to identify unlisted paths not referenced in robots.txt.

### Active Content Discovery (gobuster)
Command:

gobuster dir -u http://192.168.254.128/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php,html -t 50 -o 01_scans/gobuster_root_phase2.txt

Result:

| Path | Status | Notes |
|------|--------|-------|
| /images/ | 301 | Redirect, standard static asset directory |
| /index.html, /index | 200 | Landing page |
| /css/ | 301 | Standard static asset directory |
| /js/ | 301 | Standard static asset directory |
| /vendor/ | 301 | Redirect - worth checking contents, often discloses framework/library info |
| /favicon | 200 | Standard |
| /robots | 200 | Already reviewed |
| /fonts/ | 301 | Standard static asset directory |
| /gitweb/ | 301 | Redirect - potential exposed version control interface, flagged for review |
| /server-status | 403 | Apache mod_status endpoint present but access restricted |
| /phpMyAdmin/ | 403 | Database administration interface present but access restricted |

## Analysis (continued)
Content discovery surfaced three items of particular interest beyond standard static asset directories:

1. /gitweb/ - suggests a Git web interface may be exposed, which can disclose source code, commit history, or configuration data if accessible.
2. /phpMyAdmin/ - a database administration panel is present on the server. Currently returns 403, but its presence confirms a MySQL/MariaDB backend exists and is a relevant finding for the risk register regardless of current access level.
3. /server-status - Apache's mod_status module is enabled; also 403 at present, but its presence is worth noting as a configuration observation.

/vendor/ also warrants inspection, as this path commonly discloses third-party library names and versions in PHP-based applications, which can inform vulnerability research in Phase 3.

Full raw output saved to 01_scans/gobuster_root_phase2.txt for evidence.

## Evidence References
- 01_scans/gobuster_root_phase2.txt

### Manual Inspection of /vendor/ and /gitweb/
Commands:

curl -s http://192.168.254.128/vendor/
curl -s http://192.168.254.128/gitweb/

Result: Both return HTTP 403 Forbidden (standard Apache "Access forbidden" error page). No directory listing enabled, no index document present, no content disclosed via direct browsing.

## Analysis (continued)
Direct browsing of /vendor/ and /gitweb/ does not yield further information; both are access-restricted at the directory level with no listing enabled. These remain noted as present-but-inaccessible findings for the risk register (a Git interface and a vendor/library directory both being deployed, even if not directly browsable, is still a relevant configuration observation).

Given the initial gobuster wordlist targeted only the site root, the next step is to broaden content discovery: (1) run a lowercase-specific wordlist in case case-sensitivity affects results, and (2) consider that a functional application may be hosted under an undiscovered subdirectory not covered by a generic wordlist, warranting either a larger wordlist or a more targeted enumeration approach.

### Broadened Content Discovery (lowercase wordlist)
Command:

gobuster dir -u http://192.168.254.128/ -w /usr/share/wordlists/dirbuster/directory-list-lowercase-2.3-medium.txt -x php,html -t 50 -o 01_scans/gobuster_root_lowercase_phase2.txt

Result: No new paths identified beyond the initial medium wordlist scan. Same core set of directories returned (css, images, js, vendor, fonts, gitweb, server-status).

## Analysis (continued)
The medium-sized wordlists (standard and lowercase) have been exhausted against the site root without surfacing an application beyond the static landing page and known scaffolding directories. This suggests either: (a) the functional application is hosted under a path not present in medium-sized generic wordlists, or (b) it is not linked from anywhere discoverable via standard brute-force at this word-list size. Next step is to escalate to the larger wordlist and/or a wordlist tailored to common CMS/application naming conventions, per standard methodology for boxes that do not yield results from initial-tier wordlists.

### Environment Adjustment - Internet Access for Tooling
Kali's second network adapter (eth0) was found to have no assigned IP, preventing package installation (DNS resolution failure). Adapter was configured to NAT in VMware and DHCP renewed. This restored internet access on eth0 while the host-only adapter (eth1, 192.168.254.129) remained dedicated to the isolated lab segment reaching OPFOR-02. Isolation of the target segment was verified unaffected. SecLists wordlist collection installed via apt as a result.

### Escalated Content Discovery (large wordlist)
Command:

gobuster dir -u http://192.168.254.128/ -w /usr/share/seclists/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-big.txt -x php,html -t 50 -o 01_scans/gobuster_root_big_phase2.txt

Result: Same scaffolding directories as prior scans, plus one new and significant finding:

| Path | Status | Notes |
|------|--------|-------|
| /openemr/ | 301 | New - redirects to /openemr/, previously undiscovered application directory |
| /server-info | 403 | Apache mod_info endpoint, access restricted |

An anomalous long filename matching an eBay search-query string was also returned (artifact of the wordlist itself, status 403, not considered relevant to the target).

## Analysis (continued)
The larger wordlist surfaced /openemr/, a substantial finding not present in either medium-sized wordlist scan. OpenEMR is an open-source electronic health records / medical practice management application, which is consistent with the "Healthcare" theming of this target. This represents the primary web application attack surface and is the clear priority for further enumeration going into the exploit-chain development phase.

Next steps: enumerate the /openemr/ application directly (version identification, login interface, exposed configuration files) before moving to Phase 3 vulnerability research.

## Evidence References
- 01_scans/gobuster_root_big_phase2.txt

### OpenEMR Landing Page Inspection
Command:

curl -s http://192.168.254.128/openemr/

Result: Page redirects via JavaScript to interface/login/login_frame.php?site=default. Confirms a functional OpenEMR installation is present and reachable at /openemr/.

### OpenEMR Login Page Analysis
Commands:

curl -s "http://192.168.254.128/openemr/interface/login/login_frame.php?site=default"
curl -s http://192.168.254.128/openemr/library/version.php
curl -s http://192.168.254.128/openemr/interface/login/login.php

Result:
- login_frame.php confirms a frameset structure loading login.php within it (standard OpenEMR layout).
- library/version.php returned no visible output (either empty response or not directly renderable via curl - worth re-checking with verbose headers if version fingerprinting is needed later).
- login.php returned the full login form. Notable observations:
  - jQuery 1.4.3 is loaded (jquery-1.4.3.min.js), suggesting an OpenEMR release from approximately the 2010-2011 era.
  - Client-side password hashing logic (MD5 and SHA1 JavaScript implementations) is present and used to hash the password before submission, with the algorithm selected dynamically via an AJAX call to validateUser.php.
  - A commented-out HTML block references demo installation credentials (login: admin / password: pass), left in the page source rather than removed.

## Analysis (continued)
The jQuery version and client-side hashing implementation are consistent with an older OpenEMR release, which will need confirmation via targeted version research in Phase 3 (e.g. searchsploit, changelog comparison, or checking other known version-disclosing files/paths).

The commented-out demo credential reference is a configuration hygiene finding - default/demo credentials left in source code comments, even if inactive, indicate incomplete hardening of the installation. This is flagged for both the risk register and potential credential testing, pending confirmation of whether default credentials remain functional on this instance.

## Evidence References
- 01_scans/gobuster_root_big_phase2.txt

### Version Disclosure Path Checks
Commands:

curl -s http://192.168.254.128/openemr/Documentation/VERSION
curl -s http://192.168.254.128/openemr/version.txt
curl -s http://192.168.254.128/openemr/dbupgrade.php

Result: All three returned HTTP 404 (Apache "Object not found" page). Version is not directly disclosed via these common paths. Version identification will need to rely on other indicators (jQuery version, UI/theme fingerprints, or behavior consistent with known CVEs) in Phase 3.

### Demo Credential Test (admin/pass)
Command:

curl -s -c cookies.txt -X POST "http://192.168.254.128/openemr/interface/main/main_screen.php?auth=login&site=default" -d "authProvider=Default&authUser=admin&clearPass=pass&authPass=&languageChoice=1"

Result: Empty response body returned. Inconclusive from body alone - OpenEMR's login flow typically responds via redirect rather than inline content, so status code and Location header must be reviewed to determine success or failure. Follow-up requested with verbose headers.

### Demo Credential Test - Result Confirmed
Command:

curl -s -i -c cookies.txt -X POST "http://192.168.254.128/openemr/interface/main/main_screen.php?auth=login&site=default" -d "authProvider=Default&authUser=admin&clearPass=pass&authPass=&languageChoice=1"

Result: HTTP 302 redirect to /openemr/interface/login_screen.php?error=1&site= - this is OpenEMR's failed-authentication redirect pattern. Confirms admin/pass (the commented demo credential) is not valid on this instance.

Additional disclosure from response headers:
- X-Powered-By: PHP/5.3.3
- Server: Apache/2.2.17 (PCLinuxOS 2011/PREFORK-1pclos2011)

## Analysis (continued)
Demo credentials are not functional on this installation - authentication mechanism is active and correctly rejecting invalid attempts. However, the PHP 5.3.3 and Apache 2.2.17 versions, combined with the jQuery 1.4.3 fingerprint observed earlier, place this OpenEMR installation firmly in the 2010-2012 release window. This version range is known to have had significant security vulnerabilities, which will be the focus of Phase 3 vulnerability research.

This concludes initial Phase 2 enumeration. Summary of confirmed attack surface:
- FTP (21) - ProFTPD 1.3.3d, anonymous access disabled
- HTTP (80) - Apache 2.2.17 / PHP 5.3.3, hosting OpenEMR application at /openemr/
- OpenEMR authentication is active; default/demo credentials not functional
- Supporting evidence: gitweb and phpMyAdmin interfaces present but access-restricted (403)

Phase 3 (Exploit Chain Development) will focus on identifying known vulnerabilities matching this specific OpenEMR/PHP/Apache version combination.
