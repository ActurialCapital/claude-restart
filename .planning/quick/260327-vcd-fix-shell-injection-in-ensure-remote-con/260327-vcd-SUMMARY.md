---
phase: quick
plan: 260327-vcd
subsystem: infra
tags: [bash, python, shell-injection, security]

requires: []
provides:
  - "Shell-injection-safe ensure_remote_config function in claude-wrapper"
affects: [bin/claude-wrapper]

tech-stack:
  added: []
  patterns:
    - "Pass bash variables to inline python3 via sys.argv, not string interpolation"

key-files:
  created: []
  modified:
    - bin/claude-wrapper
    - test/test-wrapper.sh

key-decisions:
  - "Use sys.argv[1]/sys.argv[2] instead of bash variable interpolation into Python strings"

patterns-established:
  - "Inline python3 -c blocks must receive bash values via sys.argv, never via $var interpolation in source"

requirements-completed: []

duration: 11min
completed: 2026-03-27
---

# Quick Task 260327-vcd: Fix Shell Injection in ensure_remote_config Summary

**Eliminated shell injection in ensure_remote_config by passing $config_file and $cwd via sys.argv instead of interpolating into Python string literals**

## Performance

- **Duration:** 11 min
- **Started:** 2026-03-28T02:55:53Z
- **Completed:** 2026-03-28T03:06:57Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2

## Accomplishments
- Eliminated code injection vulnerability where crafted directory paths could execute arbitrary Python
- Both python3 blocks (update existing config + create new config) now use sys.argv for value passing
- Added Test 23b validating single-quote path handling in ensure_remote_config
- Fixed test validation code to also use sys.argv for consistency

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add failing test** - `5a1f35d` (test)
2. **Task 1 GREEN: Fix shell injection** - `34e67d2` (fix)

## Files Created/Modified
- `bin/claude-wrapper` - Refactored both python3 blocks in ensure_remote_config to use sys.argv[1]/sys.argv[2]
- `test/test-wrapper.sh` - Added Test 23b for single-quote path validation; fixed test's own python3 validation

## Decisions Made
- Used sys.argv (command-line arguments) rather than environment variables for passing values to inline Python -- simpler and more explicit
- jq path left unchanged since it already uses --arg which handles quoting safely

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test validation also using shell interpolation**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** Test 23b's python3 validation block used `'$FAKE_HOME/.claude.json'` which is the same pattern being fixed
- **Fix:** Changed to pass the path via sys.argv[1]
- **Files modified:** test/test-wrapper.sh
- **Verification:** Test passes correctly
- **Committed in:** 34e67d2 (part of task commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Consistency fix in test code. No scope creep.

## Issues Encountered
- Full test suite hangs at Test 16 (empty restart file in mode). Confirmed pre-existing -- occurs with and without changes. Test 16 hang is unrelated to ensure_remote_config. Relevant tests (23, 23b) verified in isolation.

## Known Stubs
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Shell injection vulnerability eliminated
- Pre-existing Test 16 hang should be investigated separately

---
*Plan: quick-260327-vcd*
*Completed: 2026-03-27*
