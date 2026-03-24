---
phase: 09-autonomous-orchestra
plan: 06
subsystem: infra
tags: [bash, systemd, remote-control, claude-config]

requires:
  - phase: 09-autonomous-orchestra/05
    provides: FIFO-based stdin with heartbeat writer for remote-control mode
provides:
  - remoteDialogSeen pre-set in ~/.claude.json bypassing Enable Remote Control prompt
  - Removed stale echo y from FIFO stdin writer
  - install.sh and claude-service also pre-set remoteDialogSeen
affects: [orchestra, remote-control, deployment]

tech-stack:
  added: []
  patterns: [jq-based JSON config editing with python3 fallback]

key-files:
  created: []
  modified: [bin/claude-wrapper, bin/claude-service, bin/install.sh, test/test-wrapper.sh]

key-decisions:
  - "Pre-set remoteDialogSeen rather than trying to pipe 'y' through FIFO — more reliable in non-TTY contexts"
  - "Helper function ensure_remote_dialog_seen uses jq with python3 fallback, creates minimal config if missing"

patterns-established:
  - "Config pre-set pattern: edit ~/.claude.json before launching claude to bypass interactive prompts"

requirements-completed: [ORCH-01]

duration: 8min
completed: 2026-03-24
---

# Phase 09 Plan 06: Gap Closure Summary

**Pre-set remoteDialogSeen=true in ~/.claude.json to bypass "Enable Remote Control?" prompt, fixing orchestra session spawn blocker**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-24T00:50:00Z
- **Completed:** 2026-03-24T00:58:00Z
- **Tasks:** 1 automated + 1 checkpoint
- **Files modified:** 4

## Accomplishments
- Added `ensure_remote_dialog_seen()` function to claude-wrapper that writes `remoteDialogSeen: true` to `~/.claude.json` before remote-control launch
- Removed unreliable `echo "y" >&3` from FIFO subshell — no more stale stdin data
- Pre-set remoteDialogSeen in install.sh (reads CLAUDE_CONNECT from env file, not interactive variable) and claude-service add-orchestra
- Updated Test 21 to verify no "y" on stdin, added Test 23 for config file creation

## Task Commits

Each task was committed atomically:

1. **Task 1: Pre-set remoteDialogSeen and remove FIFO echo y** - `26bc37f` (fix)

## Files Created/Modified
- `bin/claude-wrapper` - Added ensure_remote_dialog_seen() helper, called before FIFO setup, removed echo y
- `bin/claude-service` - add-orchestra pre-sets remoteDialogSeen after env file creation
- `bin/install.sh` - Linux install pre-sets remoteDialogSeen for remote-control mode
- `test/test-wrapper.sh` - Test 21 rewritten (no y on stdin), Test 23 added (config creation)

## Decisions Made
- Used jq with python3 fallback for JSON editing — covers most Linux server environments
- Helper runs on every remote-control loop iteration but short-circuits when already true (cheap idempotent check)
- install.sh reads CLAUDE_CONNECT from env file (not CONN_MODE variable) to work for both fresh installs and re-runs

## Deviations from Plan
None - plan executed exactly as written

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Orchestra remote-control mode should now spawn sessions without the "Enable Remote Control?" prompt blocking
- VPS verification pending (checkpoint approved)

---
*Phase: 09-autonomous-orchestra*
*Completed: 2026-03-24*
