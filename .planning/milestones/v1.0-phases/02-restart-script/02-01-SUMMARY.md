---
phase: 02-restart-script
plan: 01
subsystem: cli
tags: [bash, restart, ppid-walk, sigterm, process-management]

# Dependency graph
requires:
  - phase: 01-wrapper-script
    provides: "Restart file protocol (wrapper reads ~/.claude-restart and relaunches)"
provides:
  - "bin/claude-restart: restart trigger script that writes options and kills claude process"
  - "test/test-restart.sh: automated test suite with 13 assertions"
affects: [03-shell-integration]

# Tech tracking
tech-stack:
  added: []
  patterns: [ppid-chain-walk, env-var-test-overrides, graceful-degradation]

key-files:
  created:
    - bin/claude-restart
    - test/test-restart.sh
  modified: []

key-decisions:
  - "CLAUDE_RESTART_TARGET_PID env var for test-time kill override (avoids needing real process tree in tests)"
  - "PPID walk up to 5 levels with node+claude command match for reliable PID targeting"
  - "Graceful degradation: file always written even when PID not found, with stderr warning"

patterns-established:
  - "PPID chain walk: iterate ps -o ppid= up to N levels, match command pattern"
  - "Test-time PID override: CLAUDE_RESTART_TARGET_PID skips PPID walk for isolated kill testing"

requirements-completed: [REST-01, REST-02, REST-03]

# Metrics
duration: 2min
completed: 2026-03-20
---

# Phase 2 Plan 1: Restart Script Summary

**Restart trigger script with PPID chain walk, SIGTERM kill, and configurable default options via env vars**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-20T23:05:17Z
- **Completed:** 2026-03-20T23:06:55Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Restart script writes CLI args (or env var defaults) to ~/.claude-restart for wrapper consumption
- PPID chain walk finds claude (node) process up to 5 levels deep and sends SIGTERM
- Graceful degradation when PID not found: file still written, warning printed, exits 0
- Full TDD cycle: 8 test cases (13 assertions) all passing

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Failing test suite** - `c8b2052` (test)
2. **Task 2 (GREEN): Restart script implementation** - `544e3cf` (feat)

## Files Created/Modified
- `bin/claude-restart` - Restart trigger script (60 lines, executable)
- `test/test-restart.sh` - Automated test suite with 8 test cases and 13 assertions (135 lines, executable)

## Decisions Made
- Used `CLAUDE_RESTART_TARGET_PID` env var to allow tests to specify exact PID to kill, avoiding need for complex process tree mocking
- PPID walk checks both "node" and "claude" in command string to avoid killing unrelated node processes
- Used `$*` (not `$@`) when writing args to file since wrapper reads it as a single line

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Restart script ready for Phase 3 (shell integration)
- Full restart cycle works: restart script writes file + kills claude, wrapper detects file + relaunches
- Both test suites pass independently (13+13 = 26 assertions total)

## Self-Check: PASSED

- [x] bin/claude-restart exists
- [x] test/test-restart.sh exists
- [x] 02-01-SUMMARY.md exists
- [x] Commit c8b2052 found (RED phase)
- [x] Commit 544e3cf found (GREEN phase)

---
*Phase: 02-restart-script*
*Completed: 2026-03-20*
