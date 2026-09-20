# Lessons-Learned Statement
## CIP-A105 | CTF2 | Operation Black Forge

---

## 1. Attack Chain Selection

The attack chain selected (SQLi credential extraction → authenticated file upload → SUID PATH hijack) proved sound and produced a complete root compromise. The chain was derived entirely from enumeration evidence without reliance on external walkthroughs, which is the correct methodology for operational and exam contexts alike.

The primary rationale for selecting 49742.py over other available OpenEMR exploits was the direct correlation between the AJAX endpoint (validateUser.php?u=) observed in the login.php source during Phase 2 and the specific parameter name in the exploit title. This kind of cross-referencing between live enumeration findings and exploit descriptions is more reliable than version-matching alone, since version numbers are often unavailable or ambiguous.

The decision to pursue manage_site_files.php as the file upload vector (rather than the openflashchart path) was made after confirming that the openflashchart tmp-upload-images directory returned 404, meaning the pre-requisite directory for that vector did not exist. Checking pre-requisites before investing time in an exploit is an important operational discipline that saved time here once applied.

---

## 2. Failed Paths and Why They Were Abandoned

### Openflashchart File Upload (24529.rb)
The ofc_upload_image.php endpoint was confirmed present and responsive (HTTP 200, "Saving your image to" in body). The upload was attempted and the server acknowledged the write attempt but returned a "can't open file" error. Checking the upload destination (tmp-upload-images/) confirmed a 404 — the directory did not exist on this installation. The vector was abandoned because the necessary write target was not present, not because the endpoint was absent.

Lesson: Verify the complete pre-requisite chain for an exploit (endpoint present, AND writable destination present, AND execution path accessible) before investing significant time.

### Reverse Shell Attempts
Multiple reverse shell payload types were attempted (bash TCP redirect, mkfifo pipe, Python socket, PHP fsockopen) before adopting the bind shell approach. All failed silently (curl returned immediately with no output) or hung with no connection in the listener. This consumed significant time.

The root cause was identified post-compromise: Shorewall firewall was running and blocking outbound TCP from the target. ICMP was unblocked (confirmed by ping response), which created a misleading signal — network reachability appeared fine but TCP was restricted directionally.

Lesson: After obtaining command execution via a webshell, check iptables -L -n as an early enumeration step before attempting reverse shells. A quick check of the firewall ruleset would have immediately explained the failure and led directly to the bind shell approach.

### ProFTPD as Initial Attack Vector
ProFTPD 1.3.3d was noted in the nmap scan. The 1.3.3c backdoor is a well-known finding, and this version number is close enough to warrant checking. Searchsploit confirmed that all publicly known CVEs for ProFTPD in this range (backdoor, IAC overflow) target 1.3.3c and below, with 1.3.3d released explicitly as the fix. ProFTPD was correctly ruled out as a primary attack vector.

Lesson: Version numbers matter. 1.3.3c and 1.3.3d look similar but have fundamentally different security posture. Reading the scope of CVEs carefully prevents wasted effort.

---

## 3. Linux Operational Gaps Identified

### TTY Limitations in Non-Interactive Shells
The bind shell obtained via PHP stream_socket_server did not allocate a TTY. This caused interactive commands (bash -p without -c) to exit immediately. Familiarity with techniques for upgrading non-TTY shells (python pty spawn, script /dev/null, socat) or structuring exploitation to avoid needing them (using -p -c flags as done here) is an important gap to address.

### Session Timeout Awareness
The OpenEMR admin session expired between the first file upload (shell.php) and the subsequent bind shell upload. The expired session caused a 302 redirect to the login page rather than a successful upload. Monitoring for session expiry and having a re-authentication command ready would have avoided the need to diagnose the 302 mid-operation.

### PHP Extension Availability
The initial bind shell used socket_create(), which requires the PHP sockets extension. The extension was not loaded on this target (confirmed via php -r 'echo function_exists("socket_create")?"yes":"no"'). Falling back to stream_socket_server() (core PHP, no extension required) resolved the issue but required an additional upload cycle. Knowing which PHP networking functions require extensions vs which are available in core PHP is a practical gap to close.

---

## 4. Improvement Priorities

| Priority | Area | Action |
|----------|------|--------|
| 1 | Firewall enumeration | Make iptables -L -n an early post-RCE step before any reverse shell attempt |
| 2 | Shell stability | Practice TTY upgrade techniques (python pty, socat, script) to handle non-TTY bind shells cleanly |
| 3 | Session management | Build a session-refresh function or wrapper to re-authenticate automatically when sessions expire mid-operation |
| 4 | PHP knowledge | Build reference list of PHP networking functions and their extension dependencies |
| 5 | Pre-requisite checking | Always verify the full pre-requisite chain of an exploit vector before executing |
| 6 | Documentation discipline | Phase notes kept pace with operations throughout this exercise — this should be maintained as a standard practice for all future assessments |

---

## 5. Summary

Operation Black Forge was completed successfully with full root access achieved and both mission flags
retrieved. The attack chain was derived from evidence, executed methodically, and documented in real time across all seven phases. The principal learning outcome is the value of systematic enumeration before exploitation: the key findings (validateUser.php endpoint, manage_site_files.php upload surface, healthcheck SUID binary) were all surfaced through enumeration before any exploit was run, making the exploitation phase a structured execution rather than trial and error.
