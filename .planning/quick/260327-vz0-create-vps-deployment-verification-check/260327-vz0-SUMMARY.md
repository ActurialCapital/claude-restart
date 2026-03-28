---
phase: quick
plan: 260327-vz0
subsystem: documentation
tags: [vps, deployment, verification, checklist]
dependency_graph:
  requires: []
  provides: [vps-deployment-verification-checklist]
  affects: []
tech_stack:
  added: []
  patterns: [structured-verification-checklist]
key_files:
  created:
    - VPS-VERIFICATION.md
  modified: []
decisions:
  - Marked Section 8 (update command) as planned feature since claude-service does not yet implement update or --force flags
metrics:
  duration: 98s
  completed: 2026-03-28T04:05:25Z
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Quick Task 260327-vz0: Create VPS Deployment Verification Checklist Summary

Structured 10-section verification checklist covering every stage from pre-deploy prerequisites through watchdog firing and final cleanup, with runnable commands and expected outputs for each check.

## Task Completion

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Write VPS-VERIFICATION.md checklist | 4099c96 | VPS-VERIFICATION.md |

## What Was Done

Created `VPS-VERIFICATION.md` in the repo root with 10 ordered sections matching the real deployment sequence:

1. **Pre-Deploy Checks** - Node.js, npm, Claude CLI, git, systemd, linger, API key, jq, python3
2. **install.sh Execution** - Clone, run installer, verify all artifacts deployed
3. **Default Instance Smoke Test** - Service enabled/running, journal entries, remote control URL
4. **Instrument Add/Remove Lifecycle** - Full add/verify/list/remove cycle with cleanup checks
5. **Orchestra Add and Dispatch** - Orchestra-specific registration and dispatch test
6. **Heartbeat and FIFO Verification** - Mode-aware heartbeat and FIFO lifecycle
7. **Watchdog Timer Firing** - Timer schedule, mode-aware skip/restart behavior
8. **Update Command** - Marked as planned feature (not yet implemented in claude-service)
9. **Restart Mechanism** - Restart file flow, systemctl restart, max restart protection
10. **Cleanup and Final State** - Orphaned resources, memory limits, final service state

Each check includes a markdown checkbox, description, fenced bash command block, and "Expected:" output line. A results summary table is included at the bottom for tracking pass/fail during verification.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Feature] Documented update command as planned**
- **Found during:** Task 1 (writing Section 8)
- **Issue:** Plan references `claude-service update` and `--force` flag, but neither is implemented in the current codebase
- **Fix:** Added a note in Section 8 indicating the update command is a planned feature, advising to skip the section until implemented
- **Files modified:** VPS-VERIFICATION.md

## Known Stubs

None -- file is complete documentation with no placeholder data.

## Self-Check: PASSED

- [x] VPS-VERIFICATION.md exists (596 lines, 10 sections, 62 command blocks)
- [x] Commit 4099c96 exists in git log
