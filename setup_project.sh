#!/bin/bash
# CIP-A105 CTF2 Black Forge - Project Scaffolding Script

BASE_DIR=~/CIP-A105_RegNo_CTF2_Black-Forge

# Create directory structure
mkdir -p "$BASE_DIR"/{01_scans,02_screenshots,03_operator_log,04_evidence_hashes,05_report_drafts,06_phase_notes}

cd "$BASE_DIR/06_phase_notes" || exit

# Function to create a phase file with a standard template
create_phase_doc() {
    local filename="$1"
    local phase_title="$2"
    cat > "$filename" << EOF
# ${phase_title}

Date:
Operator system: Kali Linux (attacker) -> OPFOR-02 (target)
Objective:

## Tools Used

## Actions and Findings

### Action 1
Command:
\`\`\`
\`\`\`
Result:

## Analysis

## Evidence References
- 

EOF
    echo "Created $filename"
}

create_phase_doc "phase0_preparation.md" "Phase 0 - Preparation and Control"
create_phase_doc "phase1_discovery.md" "Phase 1 - Network and Service Discovery"
create_phase_doc "phase2_enumeration.md" "Phase 2 - Enterprise Service Enumeration"
create_phase_doc "phase3_exploit_dev.md" "Phase 3 - Exploit Chain Development"
create_phase_doc "phase4_initial_access.md" "Phase 4 - Initial Access"
create_phase_doc "phase5_post_exploitation.md" "Phase 5 - Linux Post-Exploitation"
create_phase_doc "phase6_privesc.md" "Phase 6 - Privilege Escalation and Objectives"
create_phase_doc "phase7_remediation.md" "Phase 7 - Remediation Validation and Withdrawal"

# Create phase index
cat > README.md << 'EOF'
# Phase Notes Index

| Phase | Status | File |
|-------|--------|------|
| 0 - Preparation | Not started | phase0_preparation.md |
| 1 - Discovery | Not started | phase1_discovery.md |
| 2 - Enumeration | Not started | phase2_enumeration.md |
| 3 - Exploit Dev | Not started | phase3_exploit_dev.md |
| 4 - Initial Access | Not started | phase4_initial_access.md |
| 5 - Post-Exploitation | Not started | phase5_post_exploitation.md |
| 6 - Privilege Escalation | Not started | phase6_privesc.md |
| 7 - Remediation | Not started | phase7_remediation.md |
EOF
echo "Created README.md index"

# Create operator log
cd "$BASE_DIR/03_operator_log" || exit
LOGFILE="operator_log.md"
cat > "$LOGFILE" << 'EOF'
# Operator Activity Log - CIP-A105 CTF2 Black Forge

| Timestamp | System | Action/Command | Purpose | Outcome |
|-----------|--------|------------------|---------|---------|
EOF
echo "Created $LOGFILE"

echo ""
echo "Project scaffolding complete at $BASE_DIR"
