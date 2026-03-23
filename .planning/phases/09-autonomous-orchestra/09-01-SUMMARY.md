---
phase: 09-autonomous-orchestra
plan: 01
subsystem: infra
tags: [systemd, bash, claude-peers, channels, orchestra]

requires:
  - phase: 08-instrument-lifecycle
    provides: claude-service add/remove/list, template units
provides:
  - CLAUDE_CHANNELS env var in env.template for channel flag injection
  - --dangerously-load-development-channels support in claude-wrapper
  - add-orchestra subcommand in claude-service (no git clone registration)
  - Bun in PATH via env.template
  - Test suites for orchestra and wrapper channels
affects: [09-02, orchestra-claude-md, claude-peers-integration]

tech-stack:
  added: []
  patterns: [env-var-driven-feature-flags, function-extraction-for-variants]

key-files:
  created:
    - test/test-orchestra.sh
    - test/test-wrapper-channels.sh
  modified:
    - bin/claude-wrapper
    - bin/claude-service
    - systemd/env.template

key-decisions:
  - "Test extraction uses sed function body isolation instead of grep -A for reliability"

patterns-established:
  - "Channel flag injection: CLAUDE_CHANNELS env var drives --dangerously-load-development-channels flag"
  - "Orchestra variant: add-orchestra subcommand follows add pattern but skips git clone"

requirements-completed: [ORCH-01, ORCH-04]

duration: 4min
completed: 2026-03-23
---

# Phase 09 Plan 01: Orchestra Infrastructure Summary

**Channel flag injection in wrapper, Bun in PATH, and add-orchestra subcommand for git-free orchestra registration with claude-peers enabled**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-23T17:29:14Z
- **Completed:** 2026-03-23T17:33:00Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- env.template extended with CLAUDE_CHANNELS variable and .bun/bin in PATH
- claude-wrapper injects --dangerously-load-development-channels when CLAUDE_CHANNELS is set, backward compatible when unset
- claude-service add-orchestra creates orchestra instrument without git clone, sets CLAUDE_CHANNELS=server:claude-peers
- 14 new tests across 2 test scripts, all 33 existing wrapper tests still pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Add channel flag support to wrapper and update env template** - `87bf46d` (feat)
2. **Task 2: Add add-orchestra subcommand to claude-service** - `c417b09` (feat)
3. **Task 3: Create test scripts for orchestra and wrapper channels** - `e67fa46` (test)

## Files Created/Modified
- `systemd/env.template` - Added CLAUDE_CHANNELS variable and .bun/bin to PATH
- `bin/claude-wrapper` - Channel args injection when CLAUDE_CHANNELS is set
- `bin/claude-service` - New do_add_orchestra() function and add-orchestra case
- `test/test-wrapper-channels.sh` - 6 tests for channel flag injection
- `test/test-orchestra.sh` - 8 tests for orchestra registration

## Decisions Made
- Test scripts use sed-based function body extraction instead of grep -A for reliable full-function matching on long functions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test-orchestra.sh grep patterns for long function body**
- **Found during:** Task 3 (test creation)
- **Issue:** Plan's grep -A 30/50 patterns too short for 68-line do_add_orchestra function; grep -q 'git clone' false-positived on comment text
- **Fix:** Used `sed -n '/^do_add_orchestra()/,/^}/p'` to extract full function body, filtered comments for git clone check
- **Files modified:** test/test-orchestra.sh
- **Verification:** All 8 tests pass
- **Committed in:** e67fa46 (Task 3 commit)

**2. [Rule 1 - Bug] Fixed test-orchestra.sh usage test subprocess failure**
- **Found during:** Task 3 (test creation)
- **Issue:** Running claude-service --help as subprocess with pipefail caused grep to miss output
- **Fix:** Changed to grep usage() function body directly instead of running subprocess
- **Files modified:** test/test-orchestra.sh
- **Verification:** All 8 tests pass
- **Committed in:** e67fa46 (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs in plan-provided test code)
**Impact on plan:** Necessary fixes for test correctness. No scope creep.

## Issues Encountered
None beyond the test script fixes documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Orchestra infrastructure complete, ready for 09-02 (CLAUDE.md and integration verification)
- add-orchestra subcommand ready for VPS deployment
- Channel flag support ready for claude-peers integration

---
*Phase: 09-autonomous-orchestra*
*Completed: 2026-03-23*
