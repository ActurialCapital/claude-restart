---
phase: 09-autonomous-orchestra
plan: 03
subsystem: infra
tags: [bash, remote-control, systemd, wrapper, permissions]

# Dependency graph
requires:
  - phase: 09-autonomous-orchestra
    provides: "claude-wrapper with mode selection and remote-control support"
provides:
  - "Fixed remote-control mode with correct --permission-mode bypassPermissions flag"
  - "Auto-confirm for Enable Remote Control prompt via stdin piping"
  - "Filter logic removing invalid --dangerously-skip-permissions from remote-control args"
affects: [deployment, orchestra, systemd-services]

# Tech tracking
tech-stack:
  added: []
  patterns: ["stdin piping for non-interactive prompt confirmation", "argument filtering by mode"]

key-files:
  created: []
  modified:
    - bin/claude-wrapper
    - test/test-wrapper.sh

key-decisions:
  - "Permission flag baked into mode_args rather than current_args for remote-control mode"
  - "Defensive filtering of --dangerously-skip-permissions from caller-provided args"

patterns-established:
  - "Mode-specific stdin piping: remote-control gets echo y pipe, telegram gets FIFO, interactive gets no pipe"

requirements-completed: [ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-05]

# Metrics
duration: 2min
completed: 2026-03-23
---

# Phase 9 Plan 3: Remote-Control Wrapper Fixes Summary

**Fixed two blockers preventing remote-control mode startup: replaced invalid --dangerously-skip-permissions with --permission-mode bypassPermissions and added auto-confirm for Enable Remote Control prompt**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-23T23:01:16Z
- **Completed:** 2026-03-23T23:03:29Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Remote-control mode now uses correct `--permission-mode bypassPermissions` flag instead of invalid `--dangerously-skip-permissions`
- Any `--dangerously-skip-permissions` passed by callers (e.g., systemd ExecStart) is filtered out in remote-control mode
- Enable Remote Control prompt auto-confirmed via `echo "y" |` stdin pipe for non-interactive service startup
- Four new tests verify permission flag, argument filtering, stdin auto-confirm, and interactive mode isolation

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix remote-control permission flag and auto-confirm in claude-wrapper** - `97c5ab7` (fix)
2. **Task 2: Add tests for remote-control permission flag and auto-confirm behavior** - `062c924` (test)

## Files Created/Modified
- `bin/claude-wrapper` - Added --permission-mode bypassPermissions to remote-control mode_args, added --dangerously-skip-permissions filter, added elif branch for stdin auto-confirm
- `test/test-wrapper.sh` - Updated 6 existing test expectations for new flag format, added 4 new tests (Tests 19-22)

## Decisions Made
- Permission flag added directly to mode_args array (not current_args) so it persists across restarts and cannot be overridden
- Defensive argument filtering removes --dangerously-skip-permissions even if callers pass it, preventing confusing error messages

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated existing test expectations for new permission flag**
- **Found during:** Task 1
- **Issue:** Tests 9, 13, 14, 16 had hardcoded expected strings without --permission-mode bypassPermissions
- **Fix:** Updated expected values in assert_eq calls to include the new flags
- **Files modified:** test/test-wrapper.sh
- **Verification:** All 33 original assertions pass
- **Committed in:** 97c5ab7 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Necessary update to existing tests -- the plan's test updates in Task 2 only covered new tests, not the existing ones that needed adjustment.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Orchestra service can now start in remote-control mode without hanging
- UAT Test 1 (Dynamic Instrument Discovery) and Test 3 (End-to-End VPS Deployment) unblocked
- Ready for re-verification on VPS

---
*Phase: 09-autonomous-orchestra*
*Completed: 2026-03-23*
