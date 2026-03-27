---
phase: 12-peers-teardown
plan: 02
subsystem: infra
tags: [bash, systemd, teardown, installer, tests]

# Dependency graph
requires:
  - phase: 12-peers-teardown plan 01
    provides: cleaned wrapper, env.template, and deleted message-watcher
provides:
  - Clean installer without peers infrastructure
  - Clean claude-service without peers provisioning
  - Updated test suite without peers-specific assertions
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - bin/claude-service
    - test/test-orchestra.sh

key-decisions:
  - "install.sh already had no message-watcher references in this worktree - no changes needed"
  - "Removed 4 peers tests from test-orchestra.sh, renumbered remaining 9 sequentially"

patterns-established: []

requirements-completed: [CLNP-01, CLNP-02, CLNP-04, CLNP-05]

# Metrics
duration: 2min
completed: 2026-03-27
---

# Phase 12 Plan 02: Strip Peers from Installer, Service Manager, and Tests Summary

**Removed CLAUDE_CHANNELS injection, .mcp.json provisioning, and peers-specific tests from claude-service and test suite**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-27T17:32:29Z
- **Completed:** 2026-03-27T17:34:20Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Stripped CLAUDE_CHANNELS sed and .mcp.json provisioning block from do_add_orchestra in claude-service (36 lines removed)
- Deleted test/test-wrapper-channels.sh (7 obsolete channel tests)
- Removed 4 peers-specific tests from test-orchestra.sh, renumbered remaining 9 tests -- all passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Strip peers infrastructure from install.sh and claude-service** - `214097f` (fix)
2. **Task 2: Clean up peers-specific tests** - `3baf25d` (fix)

## Files Created/Modified
- `bin/claude-service` - Removed CLAUDE_CHANNELS sed injection and entire .mcp.json provisioning block from do_add_orchestra
- `test/test-wrapper-channels.sh` - Deleted (all 7 tests verified removed peers infrastructure)
- `test/test-orchestra.sh` - Removed 4 peers-specific tests, renumbered remaining 9

## Decisions Made
- install.sh had no message-watcher references in this worktree state, so no changes were needed to it
- Per D-02 from context: only stopped writing claude-peers to .mcp.json on new adds; existing VPS files cleaned manually

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] install.sh already clean**
- **Found during:** Task 1
- **Issue:** Plan specified removing message-watcher lines from install.sh, but the file had no such references (likely cleaned by Plan 01 or worktree state)
- **Fix:** No action needed -- skipped install.sh edits, proceeded with claude-service cleanup only
- **Files modified:** None (install.sh unchanged)
- **Verification:** `grep -c 'message-watcher' bin/install.sh` returns 0

---

**Total deviations:** 1 (install.sh already clean, not a problem)
**Impact on plan:** Minimal -- one file was already in target state. All acceptance criteria still met.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All peers references removed from installer, service manager, and test suite
- Remaining tests pass (9/9 orchestra tests green)
- Both scripts pass bash syntax validation

---
*Phase: 12-peers-teardown*
*Completed: 2026-03-27*
