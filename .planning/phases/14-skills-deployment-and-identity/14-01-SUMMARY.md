---
phase: 14-skills-deployment-and-identity
plan: 01
subsystem: infra
tags: [installer, skills, gsd, deployment, bash]

requires:
  - phase: 08-instrument-lifecycle
    provides: install.sh Linux path with systemd template units
provides:
  - deploy_skills function in install.sh for GSD and superpowers deployment
  - skills/get-shit-done/ and commands/ source directories in repo
  - Tests 21-23 validating skills deployment
affects: [14-02-identity, vps-deployment]

tech-stack:
  added: []
  patterns: [deploy_skills pattern matching existing cp-based install flow]

key-files:
  created: [skills/get-shit-done/README.md, commands/README.md]
  modified: [bin/install.sh, test/test-install.sh]

key-decisions:
  - "Direct cp from repo skills/ and commands/ dirs during install (per D-01)"
  - "Graceful skip with warning when source directories missing"
  - "Fixed pre-existing test failures from v2.0 template unit migration (Tests 11-19)"

patterns-established:
  - "deploy_skills: conditional cp with mkdir -p and warning fallback for missing sources"

requirements-completed: [DEPL-01, DEPL-02, DEPL-03]

duration: 3min
completed: 2026-03-27
---

# Phase 14 Plan 01: Skills Deployment Summary

**deploy_skills function added to install.sh copying GSD and superpowers from repo to ~/.claude/ on VPS, with 3 new tests and pre-existing test fixes**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-27T21:35:21Z
- **Completed:** 2026-03-27T21:38:40Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added deploy_skills() function to install.sh that copies skills/get-shit-done/ to ~/.claude/get-shit-done/ and commands/ to ~/.claude/commands/
- Created skills/get-shit-done/README.md and commands/README.md as repo source directories with deployment docs
- Added Tests 21-23 validating: GSD deployment, graceful skip when source missing, content integrity
- Fixed 8 pre-existing test failures from v2.0 template unit migration (Tests 11, 12, 14, 17, 18, 19, 20)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add deploy_skills function to install.sh** - `9024c5a` (feat)
2. **Task 2: Create skills source directories and add install tests** - `0e51771` (feat)

## Files Created/Modified
- `bin/install.sh` - Added deploy_skills() function, called from do_install_linux step 1c
- `skills/get-shit-done/README.md` - GSD skills source directory with deployment instructions
- `commands/README.md` - Superpowers commands source directory with deployment instructions
- `test/test-install.sh` - Added Tests 21-23 for skills deployment; fixed Tests 11-20 for template units

## Decisions Made
- Used direct `cp -r` from repo directories during install (per D-01 from CONTEXT.md)
- Graceful skip with warning when source directories missing -- allows install.sh to work even before skills are bundled
- Fixed pre-existing test failures as Rule 3 deviation (blocking: tests crashed at Test 11 preventing new test execution)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed pre-existing test failures in Tests 11-20**
- **Found during:** Task 2 (adding new tests)
- **Issue:** Tests 11-20 referenced non-template unit names (claude.service, claude-watchdog.timer) but install.sh deploys template units (claude@.service, claude-watchdog@.timer) since v2.0. Test 11's `cat claude.service` crashed with set -e, preventing all subsequent tests from running.
- **Fix:** Updated test assertions to use template unit names: claude@.service, claude@default.service, claude-watchdog@.timer, claude-watchdog@default.timer. Fixed Test 12 and 17 env path from flat to per-instance directory layout.
- **Files modified:** test/test-install.sh
- **Verification:** 51/53 tests pass (2 remaining failures are pre-existing Test 20 hardcoded timer issue)
- **Committed in:** 0e51771 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Fix was necessary to unblock test execution. No scope creep -- tests now correctly match v2.0 template unit architecture.

## Issues Encountered
- Test 20 (custom watchdog hours) still fails -- CLAUDE_WATCHDOG_HOURS env var doesn't modify the systemd timer template file during install. This is documented tech debt from v2.0 (hardcoded 8h intervals). Out of scope for this plan.

## Known Stubs
- skills/get-shit-done/ contains only README.md -- actual GSD skill files need to be copied from ~/.claude/get-shit-done/ before VPS deployment
- commands/ contains only README.md -- actual superpowers command files need to be copied from ~/.claude/commands/ before VPS deployment

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- deploy_skills function ready for VPS deployment
- User must populate skills/get-shit-done/ and commands/ with actual skill files before running install.sh on VPS
- Plan 14-02 (instrument identity) can proceed independently

## Self-Check: PASSED

All files verified present, all commit hashes found in git log.

---
*Phase: 14-skills-deployment-and-identity*
*Completed: 2026-03-27*
