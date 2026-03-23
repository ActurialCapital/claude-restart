---
phase: 06-watchdog-and-keep-alive
plan: 02
subsystem: infra
tags: [systemd, installer, bash, watchdog, heartbeat]

# Dependency graph
requires:
  - phase: 06-watchdog-and-keep-alive
    provides: watchdog timer and oneshot systemd units, env template with CLAUDE_WATCHDOG_HOURS
provides:
  - installer deploys watchdog timer and oneshot alongside main service
  - installer replaces CLAUDE_WATCHDOG_HOURS placeholder in timer unit
  - claude-service watchdog and heartbeat subcommands
  - uninstaller cleans up watchdog files
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [watchdog timer deployment via installer, claude-service subcommand extension]

key-files:
  created: []
  modified:
    - bin/install.sh
    - bin/claude-service
    - test/test-install.sh

key-decisions:
  - "Watchdog timer cleanup runs before main service cleanup in uninstaller to avoid dependency issues"
  - "heartbeat subcommand greps journald for 'heartbeat sent' string matching wrapper output"

patterns-established:
  - "Installer watchdog deployment: copy timer+oneshot, sed placeholder, enable+start timer"
  - "claude-service subcommand pattern: systemctl for status, journalctl for log grep"

requirements-completed: [WDOG-01, KALV-01]

# Metrics
duration: 2min
completed: 2026-03-22
---

# Phase 06 Plan 02: Installer and Service Updates Summary

**Installer deploys watchdog timer/oneshot with configurable hours, claude-service gains watchdog and heartbeat subcommands, 49 tests passing**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-22T05:08:59Z
- **Completed:** 2026-03-22T05:10:22Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Updated installer to deploy watchdog timer and oneshot service files with placeholder replacement for configurable hours
- Added watchdog (timer status) and heartbeat (log grep) subcommands to claude-service
- Added 3 new test cases (tests 18-20) covering timer deployment, uninstall cleanup, and custom hours
- All 49 installer tests pass including 12 new assertions

## Task Commits

Each task was committed atomically:

1. **Task 1: Update installer to deploy watchdog timer and oneshot, update uninstaller** - `43e9823` (feat)
2. **Task 2: Add watchdog/heartbeat subcommands and installer tests** - `354c934` (feat)

## Files Created/Modified
- `bin/install.sh` - Deploy watchdog timer/oneshot in do_install_linux(), cleanup in do_uninstall()
- `bin/claude-service` - Added watchdog and heartbeat subcommands, updated usage
- `test/test-install.sh` - Added tests 18-20 for watchdog deployment, uninstall, custom hours

## Decisions Made
- Watchdog timer cleanup ordered before main service cleanup in uninstaller to avoid dependency issues
- heartbeat subcommand uses `journalctl --user -u claude --grep="heartbeat sent"` matching wrapper's stderr output

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 06 complete: all watchdog and keep-alive artifacts created, deployed by installer, manageable via claude-service
- Ready for real-world testing on VPS

---
*Phase: 06-watchdog-and-keep-alive*
*Completed: 2026-03-22*
