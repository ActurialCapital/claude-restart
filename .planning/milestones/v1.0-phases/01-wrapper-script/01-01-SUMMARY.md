---
phase: 01-wrapper-script
plan: 01
subsystem: cli
tags: [bash, wrapper, restart-loop, signal-handling]

# Dependency graph
requires: []
provides:
  - "bin/claude-wrapper: restart loop script that runs claude and relaunches on signal"
  - "test/test-wrapper.sh: automated test suite with 13 assertions"
affects: [02-restart-script, 03-shell-integration]

# Tech tracking
tech-stack:
  added: []
  patterns: [bash-wrapper-loop, signal-trapping, restart-file-protocol]

key-files:
  created:
    - bin/claude-wrapper
    - test/test-wrapper.sh
  modified: []

key-decisions:
  - "Environment variable overrides (CLAUDE_WRAPPER_DELAY, CLAUDE_WRAPPER_MAX_RESTARTS, CLAUDE_RESTART_FILE) for testability"
  - "Max restart check uses > (not >=) so exactly MAX_RESTARTS restarts complete before exit"

patterns-established:
  - "Restart file protocol: ~/.claude-restart presence triggers restart, content provides new CLI args, empty means use original args"
  - "Mock-based testing: prepend temp dir to PATH with mock claude script for isolation"
  - "Environment variable configuration for test-time overrides of delays and limits"

requirements-completed: [WRAP-01, WRAP-02, WRAP-03, WRAP-04, WRAP-05]

# Metrics
duration: 3min
completed: 2026-03-20
---

# Phase 1 Plan 1: Wrapper Script Summary

**Bash wrapper loop with signal trapping, restart file protocol, and configurable delay/limits**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-20T20:19:41Z
- **Completed:** 2026-03-20T20:22:31Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Wrapper script runs claude in a loop, relaunching when ~/.claude-restart exists with new or original CLI args
- SIGINT trap kills entire wrapper (exit 130), preventing accidental restart on Ctrl+C
- Safety valve exits after 10 consecutive restarts with warning message
- Full test suite with 6 test cases (13 assertions) all passing, using mock claude for isolation

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Failing test suite** - `1cfbd3c` (test)
2. **Task 1 (GREEN): Wrapper script + test fixes** - `8b399dd` (feat)

_Note: Task 2 (test suite) was completed as part of Task 1's TDD cycle._

## Files Created/Modified
- `bin/claude-wrapper` - Main wrapper loop script (55 lines, executable)
- `test/test-wrapper.sh` - Automated test suite with mock claude (163 lines, executable)

## Decisions Made
- Added environment variable overrides (CLAUDE_WRAPPER_DELAY, CLAUDE_WRAPPER_MAX_RESTARTS, CLAUDE_RESTART_FILE) so tests can run without 2s sleeps and with custom paths
- Used `> MAX_RESTARTS` instead of `>= MAX_RESTARTS` so exactly 10 restarts complete (11 total claude invocations) before the safety valve triggers

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed max restart boundary condition**
- **Found during:** Task 1 GREEN phase (test 5)
- **Issue:** Using `-ge` caused wrapper to exit after 9 restarts instead of 10
- **Fix:** Changed to `-gt` so exactly MAX_RESTARTS restarts complete
- **Files modified:** bin/claude-wrapper
- **Verification:** Test 5 passes with 11 invocations (1 initial + 10 restarts)
- **Committed in:** 8b399dd

**2. [Rule 1 - Bug] Fixed test set -e compatibility**
- **Found during:** Task 1 GREEN phase (tests 4 and 5)
- **Issue:** `set -euo pipefail` caused test script to exit on non-zero wrapper exit codes before assertions could run
- **Fix:** Used `cmd || exit_code=$?` pattern to capture exit codes without triggering errexit
- **Files modified:** test/test-wrapper.sh
- **Verification:** All 13 assertions pass
- **Committed in:** 8b399dd

**3. [Rule 2 - Missing Critical] Added environment variable configuration**
- **Found during:** Task 1 GREEN phase
- **Issue:** Tests would take 20+ seconds due to 2s sleep on each restart; no way to override restart file path for isolation
- **Fix:** Added CLAUDE_WRAPPER_DELAY, CLAUDE_WRAPPER_MAX_RESTARTS, CLAUDE_RESTART_FILE env vars with sensible defaults
- **Files modified:** bin/claude-wrapper, test/test-wrapper.sh
- **Verification:** Tests complete in under 1 second
- **Committed in:** 8b399dd

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing critical)
**Impact on plan:** All fixes necessary for correctness and testability. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Wrapper script ready for Phase 2 (restart script) integration
- Restart file protocol established: Phase 2 script writes to ~/.claude-restart, wrapper reads it
- Test pattern established for mock-based testing of the restart script

## Self-Check: PASSED

- [x] bin/claude-wrapper exists
- [x] test/test-wrapper.sh exists
- [x] 01-01-SUMMARY.md exists
- [x] Commit 1cfbd3c found (RED phase)
- [x] Commit 8b399dd found (GREEN phase)

---
*Phase: 01-wrapper-script*
*Completed: 2026-03-20*
