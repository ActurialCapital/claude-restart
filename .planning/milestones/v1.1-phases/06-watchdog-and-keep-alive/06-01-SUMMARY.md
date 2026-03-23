---
phase: 06-watchdog-and-keep-alive
plan: 01
subsystem: infra
tags: [systemd, watchdog, heartbeat, fifo, bash]

# Dependency graph
requires:
  - phase: 05-systemd-service
    provides: systemd service unit, env template, wrapper with CLAUDE_CONNECT mode selection
provides:
  - systemd watchdog timer and mode-aware oneshot for periodic forced restart
  - keep-alive heartbeat via FIFO stdin in telegram mode
  - CLAUDE_WATCHDOG_HOURS env variable with 8-hour default
affects: [06-02 installer-and-service-updates]

# Tech tracking
tech-stack:
  added: [systemd-timer, mkfifo]
  patterns: [FIFO-based stdin delivery for heartbeat, backgrounded sleep with trap for clean shutdown]

key-files:
  created:
    - systemd/claude-watchdog.timer
    - systemd/claude-watchdog.service
  modified:
    - systemd/env.template
    - bin/claude-wrapper
    - test/test-wrapper.sh

key-decisions:
  - "FIFO-based stdin delivery for heartbeat — cross-platform (macOS + Linux), avoids /proc/pid/fd/0 Linux-only approach"
  - "Backgrounded sleep with explicit kill in TERM trap prevents orphaned sleep processes"
  - "CLAUDE_WRAPPER_HEARTBEAT_INTERVAL env override for testability (same pattern as CLAUDE_WRAPPER_DELAY)"

patterns-established:
  - "FIFO heartbeat pattern: mkfifo, redirect claude stdin from FIFO, write to FIFO fd in background loop"
  - "Subshell cleanup: trap TERM, background sleep with tracked PID, kill sleep in trap handler"

requirements-completed: [WDOG-01, KALV-01]

# Metrics
duration: 12min
completed: 2026-03-22
---

# Phase 06 Plan 01: Watchdog Timer and Keep-Alive Heartbeat Summary

**Systemd watchdog timer with mode-aware oneshot restart and FIFO-based stdin heartbeat for telegram mode**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-22T04:54:44Z
- **Completed:** 2026-03-22T05:07:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Created systemd watchdog timer (claude-watchdog.timer) with configurable interval placeholder for periodic forced restart
- Created mode-aware oneshot service (claude-watchdog.service) that skips restart in remote-control mode
- Added FIFO-based keep-alive heartbeat to claude-wrapper that sends stdin newlines every 5 minutes in telegram mode
- All 33 wrapper tests pass including 2 new heartbeat tests

## Task Commits

Each task was committed atomically:

1. **Task 1: Create watchdog timer and oneshot systemd units, update env template** - `26b4e3b` (feat)
2. **Task 2: Add keep-alive heartbeat to wrapper and tests** - `1368f9a` (feat)

## Files Created/Modified
- `systemd/claude-watchdog.timer` - Periodic timer that triggers watchdog oneshot (uses CLAUDE_WATCHDOG_HOURS_PLACEHOLDER)
- `systemd/claude-watchdog.service` - Mode-aware oneshot: skips restart for remote-control, restarts for telegram
- `systemd/env.template` - Added CLAUDE_WATCHDOG_HOURS=8 default
- `bin/claude-wrapper` - Added heartbeat loop with FIFO stdin delivery for telegram mode
- `test/test-wrapper.sh` - Added tests 17-18 for heartbeat behavior, updated create_mock for FIFO compatibility

## Decisions Made
- Used FIFO-based stdin delivery instead of /proc/pid/fd/0 for cross-platform compatibility (macOS dev + Linux production)
- Backgrounded sleep inside heartbeat subshell with tracked PID and TERM trap to prevent orphaned sleep processes
- Added CLAUDE_WRAPPER_HEARTBEAT_INTERVAL env override (default 300) for testability, following established CLAUDE_WRAPPER_DELAY pattern
- Updated existing create_mock test helper to drain stdin in background, ensuring FIFO compatibility across all telegram-mode tests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed orphaned sleep processes in heartbeat subshell**
- **Found during:** Task 2 (heartbeat implementation)
- **Issue:** When heartbeat subshell was killed, backgrounded `sleep` became orphaned because subshell's TERM handler didn't track the sleep PID
- **Fix:** Track sleep PID in `_hb_sleep_pid`, kill it explicitly in TERM trap handler
- **Files modified:** bin/claude-wrapper
- **Verification:** No orphaned sleep processes after test suite run
- **Committed in:** 1368f9a (Task 2 commit)

**2. [Rule 3 - Blocking] Updated existing test mocks for FIFO stdin compatibility**
- **Found during:** Task 2 (test creation)
- **Issue:** Existing telegram-mode tests (10, 15) hung because mock claude didn't consume stdin from FIFO
- **Fix:** Updated create_mock to drain stdin via `cat > /dev/null &`, updated Test 15 inline mock similarly, added global CLAUDE_WRAPPER_HEARTBEAT_INTERVAL=9999 to prevent heartbeat from firing during short-lived tests
- **Files modified:** test/test-wrapper.sh
- **Verification:** All 33 tests pass including existing telegram-mode tests
- **Committed in:** 1368f9a (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for correctness. FIFO stdin changes required corresponding test updates. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Watchdog timer and heartbeat are ready for Plan 02 (installer and claude-service updates)
- Installer needs to deploy claude-watchdog.timer and claude-watchdog.service, enable timer
- claude-service needs watchdog and heartbeat subcommands

---
*Phase: 06-watchdog-and-keep-alive*
*Completed: 2026-03-22*
