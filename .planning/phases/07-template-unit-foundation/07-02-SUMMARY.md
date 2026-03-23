---
phase: 07-template-unit-foundation
plan: 02
subsystem: infra
tags: [bash, systemd, multi-instance, remote-control]

# Dependency graph
requires:
  - phase: 05-systemd-service
    provides: "claude.service, claude-service helper, systemd env file"
  - phase: 04-wrapper-hardening
    provides: "claude-wrapper with mode selection, claude-restart with PPID walk"
provides:
  - "Instance-aware claude-wrapper with --name passthrough"
  - "Instance-targeted claude-restart with --instance flag and systemctl path"
  - "Instance-aware claude-service routing to claude@<name>.service"
affects: [07-03-installer, 08-watchdog, 09-lifecycle-tooling]

# Tech tracking
tech-stack:
  added: []
  patterns: [instance-aware-scripts, systemctl-template-routing, backward-compatible-defaults]

key-files:
  created: []
  modified:
    - bin/claude-wrapper
    - bin/claude-restart
    - bin/claude-service

key-decisions:
  - "CLAUDE_INSTANCE_NAME check only in remote-control mode (telegram uses bot identity)"
  - "mkdir -p for restart file directory to ensure path exists for new instances"
  - "Service echo messages include instance name for clarity"

patterns-established:
  - "Instance default pattern: unset or 'default' triggers backward-compatible behavior"
  - "systemctl template routing: claude@${INSTANCE}.service for all service operations"

requirements-completed: [INST-05, WRAP-05, WRAP-06]

# Metrics
duration: 1min
completed: 2026-03-23
---

# Phase 7 Plan 2: Instance-Aware Scripts Summary

**Three shell scripts made instance-aware: wrapper passes --name to remote-control, restart targets instruments via systemctl, service routes to template units**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-23T03:49:25Z
- **Completed:** 2026-03-23T03:50:47Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- claude-wrapper passes `--name $CLAUDE_INSTANCE_NAME` to `claude remote-control` for non-default instances
- claude-restart accepts `--instance <name>` flag, writes to instance-specific restart file, uses `systemctl --user restart claude@<name>.service`
- claude-service routes all commands to `claude@${INSTANCE}.service`, defaulting to "default" instance

## Task Commits

Each task was committed atomically:

1. **Task 1: Make claude-wrapper instance-aware with --name passthrough** - `d88d985` (feat)
2. **Task 2: Add --instance flag to claude-restart with systemctl path** - `26292bf` (feat)
3. **Task 3: Make claude-service route to template units** - `ef077eb` (feat)

## Files Created/Modified
- `bin/claude-wrapper` - Added CLAUDE_INSTANCE_NAME check and --name passthrough in remote-control mode
- `bin/claude-restart` - Added --instance flag parsing, instance-aware restart file path, systemctl restart path with PPID walk fallback
- `bin/claude-service` - Replaced static SERVICE with template unit routing (claude@${INSTANCE}.service), updated logs/heartbeat journalctl filters

## Decisions Made
- Only pass `--name` in remote-control mode since telegram mode uses bot identity, not session names
- Added `mkdir -p` for restart file directory creation (Rule 2 - missing critical: without it, writing to `~/.config/claude-restart/<name>/restart` fails if directory doesn't exist)
- Updated service echo messages to include instance name for operator clarity

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added mkdir -p for restart file directory**
- **Found during:** Task 2 (claude-restart --instance flag)
- **Issue:** Writing restart file to `$HOME/.config/claude-restart/$INSTANCE/restart` would fail if the directory doesn't exist for new instances
- **Fix:** Added `mkdir -p "$(dirname "$RESTART_FILE")"` before writing restart file
- **Files modified:** bin/claude-restart
- **Verification:** Script logic ensures directory exists before touch/write
- **Committed in:** 26292bf (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Essential for correctness when targeting instances that haven't been fully provisioned yet. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three scripts are instance-aware with clean backward compatibility
- Ready for Plan 3 (installer migration and template unit deployment)
- Watchdog timer remains non-templated (Phase 8 scope)

## Self-Check: PASSED

All 3 files verified present. All 3 commit hashes verified in git log.

---
*Phase: 07-template-unit-foundation*
*Completed: 2026-03-23*
