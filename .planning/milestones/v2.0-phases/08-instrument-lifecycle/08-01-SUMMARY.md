---
phase: 08-instrument-lifecycle
plan: 01
subsystem: infra
tags: [systemd, watchdog, template-units]

# Dependency graph
requires:
  - phase: 07-template-unit-foundation
    provides: "systemd template unit pattern (claude@.service) and per-instance env layout"
provides:
  - "Per-instance watchdog template units (claude-watchdog@.service, claude-watchdog@.timer)"
  - "Installer deploys template watchdog units with old unit migration"
affects: [08-02, claude-service]

# Tech tracking
tech-stack:
  added: []
  patterns: ["systemd template watchdog units with hardcoded timer intervals"]

key-files:
  created:
    - systemd/claude-watchdog@.service
    - systemd/claude-watchdog@.timer
  modified:
    - bin/install.sh

key-decisions:
  - "Hardcoded 8h timer intervals instead of env var placeholders (systemd timer directives cannot read env vars)"

patterns-established:
  - "Watchdog template pattern: claude-watchdog@%i mirrors claude@%i for per-instance lifecycle"

requirements-completed: [WDOG-04]

# Metrics
duration: 1min
completed: 2026-03-23
---

# Phase 8 Plan 1: Watchdog Template Units Summary

**Per-instance watchdog template units (claude-watchdog@.service/timer) with hardcoded 8h intervals and installer migration from old non-template units**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-23T14:13:32Z
- **Completed:** 2026-03-23T14:14:40Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created watchdog template units with %i parameterization for per-instance targeting
- Updated install.sh to deploy template watchdog units and migrate old non-template units
- Uninstall path loops through all env dirs to stop/disable per-instance watchdog timers

## Task Commits

Each task was committed atomically:

1. **Task 1: Create watchdog template units** - `bbb7143` (feat)
2. **Task 2: Update install.sh for watchdog template deployment and migration** - `647799a` (feat)

## Files Created/Modified
- `systemd/claude-watchdog@.service` - Per-instance watchdog oneshot with mode-aware restart logic
- `systemd/claude-watchdog@.timer` - Per-instance 8h periodic timer targeting watchdog@%i.service
- `bin/install.sh` - Template unit deployment, old unit migration, per-instance enable/disable

## Decisions Made
- Hardcoded 8h timer intervals: systemd timer directives cannot read environment variables, so OnBootSec and OnUnitActiveSec are set to 8h directly (per Phase 8 research Pitfall 2)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Watchdog template units ready for Plan 02 (claude-service add/remove/list subcommands)
- claude-service watchdog commands need updating to use template pattern (planned in 08-02)

---
*Phase: 08-instrument-lifecycle*
*Completed: 2026-03-23*
