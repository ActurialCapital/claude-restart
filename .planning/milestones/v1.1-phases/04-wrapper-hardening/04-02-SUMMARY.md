---
phase: 04-wrapper-hardening
plan: 02
subsystem: infra
tags: [bash, restart, mode-selection, env-var, installer]

# Dependency graph
requires:
  - phase: 04-01
    provides: CLAUDE_CONNECT mode selection, mode_args + current_args composition pattern
provides:
  - Mode-aware restart logic (mode preserved across restarts)
  - Installer using CLAUDE_CONNECT instead of hardcoded channel string
affects: [05-systemd-service]

# Tech tracking
tech-stack:
  added: []
  patterns: [mode-args-fixed-at-launch, restart-replaces-extra-args-only]

key-files:
  created: []
  modified:
    - bin/claude-wrapper
    - bin/install.sh
    - test/test-wrapper.sh
    - test/test-install.sh

key-decisions:
  - "Restart file content only replaces extra args (current_args), never mode_args -- mode is fixed at launch per D-09"
  - "Installer exports CLAUDE_CONNECT=telegram instead of embedding channel string in DEFAULT_OPTS"

patterns-established:
  - "Mode invariant: mode_args set once from CLAUDE_CONNECT at wrapper startup, never modified by restart logic"
  - "Installer mode configuration: CLAUDE_CONNECT env var selects mode, DEFAULT_OPTS holds non-mode flags only"

requirements-completed: [WRAP-03, WRAP-04]

# Metrics
duration: 2min
completed: 2026-03-22
---

# Phase 4 Plan 2: Mode-Aware Restart and Installer Update Summary

**Mode-aware restart preserving CLAUDE_CONNECT mode args across restarts, installer migrated from hardcoded channel string to CLAUDE_CONNECT env var**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-22T02:21:40Z
- **Completed:** 2026-03-22T02:23:29Z
- **Tasks:** 2 (Task 1: TDD RED + GREEN, Task 2: auto)
- **Files modified:** 4

## Accomplishments
- Restart in remote-control mode preserves "remote-control" base arg while replacing extra args from restart file
- Restart in telegram mode preserves "--channels plugin:telegram@..." base args while replacing extra args
- Empty restart file restores original extra args while keeping mode base args
- Installer now exports CLAUDE_CONNECT="telegram" and CLAUDE_RESTART_DEFAULT_OPTS="--dangerously-skip-permissions" (no hardcoded channel string)
- All 61 assertions across 3 test suites pass (31 wrapper, 17 install, 13 restart)

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing tests for mode-aware restart** - `054f68b` (test)
2. **Task 1 GREEN: Mode-aware restart invariant comment** - `43a2d67` (feat)
3. **Task 2: Installer CLAUDE_CONNECT migration** - `89cece2` (feat)

_TDD task 1: test commit followed by implementation commit._

## Files Created/Modified
- `bin/claude-wrapper` - Added D-09 mode-aware restart invariant comment block above restart branch
- `bin/install.sh` - Replaced hardcoded telegram channel string with CLAUDE_CONNECT="telegram" export
- `test/test-wrapper.sh` - Added 3 new tests (14-16): mode-aware restart for remote-control, telegram, and empty file scenarios
- `test/test-install.sh` - Updated test 9 for CLAUDE_CONNECT assertion, added test 10 to verify no channel string in DEFAULT_OPTS

## Decisions Made
- Plan 01's mode_args/current_args separation already provided correct mode-aware restart behavior -- no logic changes needed, only documentation and tests
- Installer CLAUDE_CONNECT export placed on separate line before DEFAULT_OPTS for clarity

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 4 complete: wrapper has signal handling, mode selection, and mode-aware restart
- Ready for Phase 5 (systemd service): `Environment=CLAUDE_CONNECT=telegram` in unit file will configure mode
- Installer pattern established: CLAUDE_CONNECT for mode, DEFAULT_OPTS for extra flags

---
*Phase: 04-wrapper-hardening*
*Completed: 2026-03-22*
