---
phase: 09-autonomous-orchestra
plan: 06
subsystem: infra
tags: [bash, systemd, remote-control, claude-config, workspace-trust]

requires:
  - phase: 09-autonomous-orchestra/05
    provides: FIFO-based stdin with heartbeat writer for remote-control mode
provides:
  - ensure_remote_config() pre-sets remoteDialogSeen and workspace trust in ~/.claude.json
  - Silent FIFO for remote-control (open but no writes, no EOF)
  - --no-create-session-in-dir prevents eager session that reads stdin
  - --dangerously-load-development-channels skipped for remote-control (not supported)
  - install.sh and claude-service also pre-set remoteDialogSeen
affects: [orchestra, remote-control, deployment, instruments]

tech-stack:
  added: []
  patterns: [python3-preferred JSON config editing with jq fallback]

key-files:
  created: []
  modified: [bin/claude-wrapper, bin/claude-service, bin/install.sh, test/test-wrapper.sh, test/test-wrapper-channels.sh]

key-decisions:
  - "Pre-set remoteDialogSeen + hasTrustDialogAccepted rather than piping 'y' through FIFO"
  - "Silent FIFO (write-end held open, no writes) instead of /dev/null — prevents EOF and stale data"
  - "--no-create-session-in-dir prevents pre-created session from reading inherited stdin"
  - "Skip --dangerously-load-development-channels for remote-control — not supported by subcommand, use .mcp.json instead"
  - "ensure_remote_config uses python3 preferred, jq fallback for atomic JSON updates"

patterns-established:
  - "Config pre-set pattern: edit ~/.claude.json projects section before launching claude to bypass interactive prompts and workspace trust"
  - "MCP servers for remote-control loaded via .mcp.json in working directory, not CLI flags"

requirements-completed: [ORCH-01]

duration: 90min
completed: 2026-03-24
---

# Phase 09 Plan 06: Gap Closure Summary

**Fixed remote-control session spawning: pre-set remoteDialogSeen + workspace trust, silent FIFO, skip eager session, skip unsupported channel flag**

## Performance

- **Duration:** ~90 min (iterative VPS debugging)
- **Started:** 2026-03-24T00:50:00Z
- **Completed:** 2026-03-24T02:40:00Z
- **Tasks:** 1 automated + 1 checkpoint (VPS verification)
- **Files modified:** 5

## Accomplishments
- Added `ensure_remote_config()` to claude-wrapper that writes both `remoteDialogSeen` and `hasTrustDialogAccepted` to `~/.claude.json`
- Replaced FIFO heartbeat writer with silent FIFO (write-end held open, no data written) — prevents EOF and stale stdin
- Added `--no-create-session-in-dir` to remote-control mode — prevents eager session from reading inherited stdin
- Skipped `--dangerously-load-development-channels` for remote-control mode — flag not supported by subcommand
- VPS verified: orchestra + 2 instruments running as systemd services, peer discovery and messaging working via claude-peers MCP

## Task Commits

1. **Pre-set remoteDialogSeen and remove FIFO echo y** - `26bc37f` (fix)
2. **Replace FIFO with /dev/null** - `664122a` (fix, later revised)
3. **Silent FIFO instead of /dev/null** - `7c8cfe7` (fix)
4. **Add --no-create-session-in-dir** - `4bdea31` (fix)
5. **Skip channel flag for remote-control** - `6ac7cf7` (fix)
6. **Auto-trust workspace in ensure_remote_config** - `47ed0ca` (fix)

## Files Created/Modified
- `bin/claude-wrapper` - ensure_remote_config() with workspace trust, silent FIFO, --no-create-session-in-dir, channel flag skip
- `bin/claude-service` - add-orchestra pre-sets remoteDialogSeen
- `bin/install.sh` - Linux install pre-sets remoteDialogSeen for remote-control mode
- `test/test-wrapper.sh` - Tests 18, 21 rewritten, Test 23 expanded (42 total assertions)
- `test/test-wrapper-channels.sh` - Updated guard test for remote-control exclusion

## Decisions Made
- /dev/null causes immediate EOF → switched to silent FIFO (write-end held open blocks stdin indefinitely)
- remote-control pre-creates a session that inherits stdin → --no-create-session-in-dir disables this
- --dangerously-load-development-channels not supported by remote-control subcommand → use .mcp.json instead
- Workspace trust requires hasTrustDialogAccepted in ~/.claude.json projects section → auto-set by wrapper

## Deviations from Plan

### Auto-fixed Issues

**1. /dev/null causes immediate EOF**
- **Found during:** VPS testing
- **Fix:** Silent FIFO (write-end held open, no writes)

**2. Pre-created session reads inherited stdin**
- **Found during:** VPS testing
- **Fix:** --no-create-session-in-dir flag

**3. Channel flag breaks remote-control arg parsing**
- **Found during:** VPS testing
- **Fix:** Skip channel_args when CLAUDE_CONNECT=remote-control

**4. Workspace not trusted for new directories**
- **Found during:** VPS testing (adding instruments)
- **Fix:** ensure_remote_config writes hasTrustDialogAccepted to ~/.claude.json

**Total deviations:** 4 auto-fixed (all discovered during VPS testing)
**Impact on plan:** All fixes necessary for remote-control to function. No scope creep.

## Issues Encountered
- Remote-control stdin inheritance required 3 iterations to solve correctly (FIFO→/dev/null→silent FIFO)
- Workspace trust is stored in ~/.claude.json projects section, not discoverable without VPS testing

## User Setup Required
None - all config pre-set automatically by wrapper.

## Next Phase Readiness
- Orchestra + instruments verified running as systemd services
- Peer discovery and messaging working via claude-peers MCP
- v2.0 milestone ready for completion

---
*Phase: 09-autonomous-orchestra*
*Completed: 2026-03-24*
