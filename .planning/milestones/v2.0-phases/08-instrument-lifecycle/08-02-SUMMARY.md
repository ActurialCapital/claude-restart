---
phase: 08-instrument-lifecycle
plan: 02
subsystem: infra
tags: [systemd, lifecycle, claude-service, instruments]

# Dependency graph
requires:
  - phase: 08-instrument-lifecycle
    plan: 01
    provides: "Per-instance watchdog template units (claude-watchdog@.service/timer)"
  - phase: 07-template-unit-foundation
    provides: "systemd template unit pattern (claude@.service) and per-instance env layout"
provides:
  - "claude-service add/remove/list subcommands for single-command instrument lifecycle"
  - "Automatic watchdog timer pairing on add, cleanup on remove"
  - "env.template deployment via install.sh for runtime access"
affects: [08-03, orchestra, dynamic-awareness]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Lifecycle subcommands with mock-friendly systemctl/git for cross-platform testing"]

key-files:
  created:
    - test/test-service-lifecycle.sh
  modified:
    - bin/claude-service
    - bin/install.sh

key-decisions:
  - "API key and PATH copied from default instance env (avoids interactive prompts, enables orchestra automation)"
  - "Instrument working directories under ~/instruments/<name> by convention"
  - "Name validation regex ^[a-zA-Z0-9][a-zA-Z0-9-]*$ prevents systemd unit name issues"

patterns-established:
  - "Mock systemctl/git in test tmpdir for macOS-compatible systemd testing"
  - "Lifecycle commands (add/remove/list) routed before instance-aware commands in case statement"

requirements-completed: [LIFE-01, LIFE-02, LIFE-03, WDOG-05]

# Metrics
duration: 3min
completed: 2026-03-23
---

# Phase 8 Plan 2: Instrument Lifecycle Commands Summary

**Single-command instrument add/remove/list via claude-service with automatic watchdog pairing, env template provisioning, and git clone**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-23T14:17:50Z
- **Completed:** 2026-03-23T14:21:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added do_add() to claude-service: clones repo, creates env from template, copies API key + PATH from default instance, enables service + watchdog
- Added do_remove() with full cleanup: stops/disables systemd units, deletes config and working directory
- Added do_list() with columnar output showing instrument name and systemd status
- Created 26-assertion test suite with mocked systemctl/git for macOS compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Add lifecycle subcommands to claude-service** - `8524c48` (feat)
2. **Task 2: Deploy env.template to config dir in installer** - `97fc836` (feat)
3. **Task 3: Create lifecycle test suite** - `752ddc5` (test)

## Files Created/Modified
- `bin/claude-service` - Added add/remove/list subcommands, sed_inplace, updated watchdog to template pattern
- `bin/install.sh` - Added env.template deployment to config dir during Linux install
- `test/test-service-lifecycle.sh` - 26-assertion test suite with mock systemctl/git

## Decisions Made
- API key and PATH copied from default instance env rather than prompting (non-interactive for orchestra automation)
- Instruments cloned to ~/instruments/<name> as convention
- Name validation prevents systemd unit name issues (alphanumeric + hyphens)
- WATCHDOG_TIMER moved inside case branch to use per-instance INSTANCE variable

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all functionality is fully wired.

## Next Phase Readiness
- Lifecycle commands ready for dynamic instrument awareness (hot add/remove detection)
- Orchestra can use `claude-service add/remove/list` non-interactively for instrument management

## Self-Check: PASSED

All files exist, all commits verified.

---
*Phase: 08-instrument-lifecycle*
*Completed: 2026-03-23*
