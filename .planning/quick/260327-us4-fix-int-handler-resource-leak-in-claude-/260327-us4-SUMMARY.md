---
phase: quick
plan: 260327-us4
subsystem: infra
tags: [bash, signal-handling, process-management, fifo]

requires: []
provides:
  - "Fixed INT trap in claude-wrapper with proper heartbeat cleanup"
affects: [claude-wrapper, deployment]

tech-stack:
  added: []
  patterns:
    - "python3 start_new_session for process-group INT testing"

key-files:
  created: []
  modified:
    - bin/claude-wrapper
    - test/test-wrapper.sh

key-decisions:
  - "Used python3 subprocess with start_new_session=True for INT testing since bash cannot reliably deliver INT to background processes"
  - "INT trap mirrors TERM trap pattern: stop_heartbeat, forward signal to child, wait, exit"

patterns-established:
  - "Process group signal delivery via python3 for testing bash INT traps"

requirements-completed: []

duration: 20min
completed: 2026-03-28
---

# Quick Task 260327-us4: Fix INT Handler Resource Leak Summary

**Fixed SIGINT trap in claude-wrapper to call stop_heartbeat and forward INT to child, preventing orphaned heartbeat subshells and leftover FIFOs on Ctrl+C**

## Performance

- **Duration:** 20 min
- **Started:** 2026-03-28T03:11:37Z
- **Completed:** 2026-03-28T03:32:08Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments
- INT trap now calls stop_heartbeat before exiting, matching TERM trap cleanup pattern
- Forwards INT signal to child process and waits for it to exit before returning 130
- New Test 26 verifies heartbeat cleanup and FIFO removal on SIGINT using process-group signal delivery
- All 46 tests pass with no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing SIGINT cleanup test** - `9c12175` (test)
2. **Task 1 GREEN: Fix INT trap + update test** - `69837cf` (fix)

## Files Created/Modified
- `bin/claude-wrapper` - Fixed INT trap on line 118 to call stop_heartbeat, forward INT to child, and exit 130
- `test/test-wrapper.sh` - Added Test 26: SIGINT in telegram mode cleans up heartbeat subshell and FIFO

## Decisions Made
- Used python3 `subprocess.Popen(start_new_session=True)` + `os.killpg()` for Test 26 because bash's `kill -INT $pid` does not reliably trigger INT traps in background processes during `wait` -- only process-group delivery (as Ctrl+C does) works
- INT trap mirrors TERM trap structure but exits 130 (standard INT exit code) and forwards INT (not TERM) to the child

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test approach changed from shell-only to python3 process group delivery**
- **Found during:** Task 1 RED phase
- **Issue:** `kill -INT $wrapper_pid` from bash does not reliably trigger INT traps in background bash scripts during `wait` builtin -- this is a known bash behavior where INT is special-cased for job control
- **Fix:** Used python3 `subprocess.Popen(start_new_session=True)` to give the wrapper its own process group, then `os.killpg(pid, SIGINT)` to simulate real Ctrl+C behavior
- **Files modified:** test/test-wrapper.sh
- **Verification:** Test passes with fix applied, fails without (confirmed RED/GREEN cycle)
- **Committed in:** 69837cf

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Test approach adapted to work around bash INT signal delivery limitation. The fix itself matches the plan exactly.

## Issues Encountered
- Bash INT trap behavior differs from TERM: sending INT to a single PID via `kill -INT` does not reliably trigger traps during `wait`, while process-group delivery (Ctrl+C) does. This required using python3 for test signal delivery.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None.

## Next Phase Readiness
- claude-wrapper INT handling is now robust; no further work needed
- All signal paths (TERM, INT, HUP) properly tested

---
*Plan: quick-260327-us4*
*Completed: 2026-03-28*
