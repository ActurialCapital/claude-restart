---
phase: 04-wrapper-hardening
plan: 01
subsystem: infra
tags: [bash, signals, systemd, process-management, env-var]

# Dependency graph
requires:
  - phase: v1.0
    provides: wrapper loop pattern with args forwarding
provides:
  - SIGTERM forwarding to child process (systemd stop works cleanly)
  - SIGHUP ignore (SSH disconnect survival)
  - CLAUDE_CONNECT mode selection (remote-control, telegram, interactive)
  - Mode + extra args composition pattern
affects: [05-systemd-service, 04-02]

# Tech tracking
tech-stack:
  added: []
  patterns: [background-child-with-wait, trap-forward-signal, env-var-mode-selection]

key-files:
  created: []
  modified:
    - bin/claude-wrapper
    - test/test-wrapper.sh

key-decisions:
  - "Claude runs in background with wait to enable signal trapping"
  - "Mode args prepended to current_args, never replaced by restart file"
  - "Invalid CLAUDE_CONNECT exits 1 before launching claude"

patterns-established:
  - "Signal forwarding: trap TERM, kill child, wait, exit 0"
  - "Mode selection: case on CLAUDE_CONNECT env var, map to CLI args array"
  - "Background child pattern: cmd & / child_pid=$! / wait $child_pid"

requirements-completed: [WRAP-01, WRAP-02]

# Metrics
duration: 2min
completed: 2026-03-22
---

# Phase 4 Plan 1: Signal Handling and Mode Selection Summary

**SIGTERM forwarding to child process, SIGHUP ignore, and CLAUDE_CONNECT env var mode selection (remote-control/telegram/interactive)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-22T02:18:27Z
- **Completed:** 2026-03-22T02:20:30Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments
- SIGTERM sent to wrapper now forwards to claude child process and wrapper exits 0 (systemd-friendly)
- SIGHUP ignored so wrapper survives SSH disconnects
- CLAUDE_CONNECT env var selects launch mode: remote-control, telegram, or unset (interactive/backwards-compatible)
- Invalid CLAUDE_CONNECT values rejected with error message and exit 1
- All 24 tests pass (13 test cases, 24 assertions) -- 7 new tests added

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing tests for signal handling and mode selection** - `88da1f9` (test)
2. **Task 1 GREEN: Implement signal handling and mode selection** - `b019232` (feat)

_TDD task: test commit followed by implementation commit._

## Files Created/Modified
- `bin/claude-wrapper` - Added signal traps (TERM forwarding, HUP ignore), background child with wait, CLAUDE_CONNECT mode-to-args mapping
- `test/test-wrapper.sh` - Added 7 new tests: SIGTERM forwarding, SIGHUP survival, 4 mode selection tests, mode+args combination

## Decisions Made
- Claude process launched in background (`&`) with `wait` to enable signal trapping -- foreground processes cannot have signals intercepted by the parent shell
- Mode args stored in `mode_args` array, prepended to `current_args` at launch -- restart file only replaces extra args, never mode args (per D-09)
- Signal interrupt of `wait` (exit > 128) triggers loop continue rather than exit -- allows wrapper to handle signals without losing the loop

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Signal handling ready for systemd integration (Phase 5) -- `systemctl stop` will cleanly terminate claude
- Mode selection ready for systemd ExecStart -- `Environment=CLAUDE_CONNECT=telegram` in unit file
- Plan 04-02 (restart-file mode awareness) can build on the mode_args pattern established here

---
*Phase: 04-wrapper-hardening*
*Completed: 2026-03-22*
