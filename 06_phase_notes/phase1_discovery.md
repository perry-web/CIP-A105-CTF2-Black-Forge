# Phase 1 - Network and Service Discovery

Date: 2026-09-19
Operator system: Kali Linux (attacker) -> OPFOR-02 (target)
Objective: Discover the target on the authorised isolated segment and identify exposed services.

## Tools Used
- nmap 7.99

## Actions and Findings

### Host Discovery
Command:

sudo nmap -sn 192.168.254.0/24

Result: Target identified at 192.168.254.128 (MAC vendor: VMware), alongside gateway (192.168.254.1) and DHCP service host (192.168.254.254).

### Reachability Confirmation
Command:

ping 192.168.254.128

Result: 100 percent reply rate, 0 percent packet loss, average RTT approximately 0.45ms.

### Full TCP Port and Service Scan
Command:

sudo nmap -sV -p- 192.168.254.128 -oN 01_scans/nmap_full_tcp_phase1.txt

Result:

| Port | State | Service | Version |
|------|-------|---------|---------|
| 21/tcp | open | ftp | ProFTPD 1.3.3d |
| 80/tcp | open | http | Apache httpd 2.2.17 (PCLinuxOS 2011/PREFORK-1pclos2011) |

Host OS fingerprint: Unix. Scan completed in 55.27 seconds against all 65535 TCP ports, 65533 shown closed/reset.

## Analysis
Two services exposed on the target: FTP (21) and HTTP (80). Both require enumeration in Phase 2 before an attack path is prioritised. No other TCP ports responding across the full range scanned.

## Evidence References
- 01_scans/nmap_full_tcp_phase1.txt
