---
phase: 09-autonomous-orchestra
plan: 04
subsystem: infra
tags: [bash, claude-cli, argument-parsing]

requires:
  - phase: 09-autonomous-orchestra
    provides: "claude-wrapper with channel_args support (plan 01, 03)"
provides:
  - "Correct argument ordering: channel flags before subcommand in all claude invocations"
  - "Regression test preventing future reordering"
affects: [orchestra-startup, remote-control]

tech-stack:
  added: []
  patterns: ["top-level CLI flags must precede subcommands"]

key-files:
  created: []
  modified: [bin/claude-wrapper, test/test-wrapper-channels.sh]

key-decisions:
  - "Used grep -c with || true to handle zero-match case under set -euo pipefail"

patterns-established:
  - "Argument order convention: channel_args before mode_args before current_args in all claude invocations"

requirements-completed: [ORCH-01]

duration: 3min
completed: 2026-03-23
gap_closure: true
---

# Plan 09-04: Channel Flag Argument Ordering Fix Summary

**Swapped channel_args before mode_args at all three claude invocation sites, unblocking orchestra startup**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-23T23:15:00Z
- **Completed:** 2026-03-23T23:18:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed argument ordering so --dangerously-load-development-channels is parsed as a top-level claude flag, not a remote-control subcommand argument
- Added regression test (Test 7) to prevent future reordering
- All 7 channel flag tests pass

## Task Commits

1. **Task 1: Swap channel_args before mode_args at all three call sites** - `c3dfa5a` (fix)
2. **Task 2: Add argument-order regression test** - `501a769` (test)

## Files Created/Modified
- `bin/claude-wrapper` - Swapped argument order at lines 85, 106, 109
- `test/test-wrapper-channels.sh` - Added Test 7: argument-order regression check

## Decisions Made
- Used `grep -c` with `|| true` instead of `grep | wc -l` to avoid pipefail exit on zero matches

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed pipefail-incompatible grep pipeline in test**
- **Found during:** Task 2 (regression test)
- **Issue:** Plan's suggested `grep ... | wc -l` pipeline fails under `set -euo pipefail` when grep returns no matches (exit code 1)
- **Fix:** Used `grep -c ... || true` instead
- **Files modified:** test/test-wrapper-channels.sh
- **Verification:** All 7 tests pass
- **Committed in:** `501a769` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary fix for test correctness under strict shell options. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Orchestra startup should no longer fail with "Unknown argument: --dangerously-load-development-channels"
- Verified on next VPS deploy

---
*Phase: 09-autonomous-orchestra*
*Completed: 2026-03-23*
