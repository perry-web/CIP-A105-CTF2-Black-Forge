# Phase 0 - Preparation and Control

Date: 2026-09-19
Operator system: Kali Linux (attacker) -> OPFOR-02 (target)
Objective: Establish an isolated, authorised lab environment before any network discovery or testing begins.

## Tools Used
- VMware Workstation
- VMware Virtual Network Editor

## Actions and Findings

### ROE Review
Rules of engagement reviewed and accepted prior to deployment. Scope confirmed as OPFOR-02 (Healthcare.ova) on an isolated host-only network, no bridged or public exposure.

### Target Deployment
Command/Action:
Imported Healthcare.ova into VMware Workstation.
Result: VM imported and powered on successfully, reaching login screen.

### Network Isolation Configuration
Command/Action:
Set both Kali and OPFOR-02 network adapters to Host-only.
Result: Adapters configured; however, VMware subsequently reported a "host-only adapter not running" error.

### Troubleshooting Host-Only Networking
Command/Action:
Checked VMware services (all running), then checked Windows Network Connections (ncpa.cpl) and found VMnet1 adapter disabled. Re-enabled VMnet1, restarted VMware Workstation.
Result: Host-only network functional; both VMs obtained addresses on 192.168.254.0/24 subnet after adapter re-enable.

### Baseline Snapshot
Command/Action:
Created VMware snapshot of OPFOR-02 named CIP-A105-CTF2-CLEAN-BASELINE once target was confirmed healthy and reachable.
Result: Baseline snapshot created for safe reversion during testing.

## Analysis
Initial network isolation encountered a host-side adapter fault unrelated to VM configuration. Resolved by re-enabling the Windows virtual adapter. Environment now meets ROE isolation requirements: target and attacker share an isolated host-only segment with no bridged or NAT path to production/public networks.

## Evidence References
- 02_screenshots/phase0_baseline_snapshot.png
