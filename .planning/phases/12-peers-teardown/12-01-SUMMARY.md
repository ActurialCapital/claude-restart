---
phase: 12-peers-teardown
plan: 01
subsystem: infra
tags: [claude-peers, teardown, shell, systemd]

# Dependency graph
requires:
  - phase: 11-orchestra-claude-md
    provides: "Orchestra and instrument infrastructure with peers"
provides:
  - "Clean claude-wrapper without channel_args or message-watcher references"
  - "Clean env.template without CLAUDE_CHANNELS variable"
affects: [12-02, 13-synchronous-dispatch]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Removal-only change: no new code, only deletions"

key-files:
  created: []
  modified:
    - bin/claude-wrapper
    - systemd/env.template

key-decisions:
  - "bin/message-watcher already absent from branch -- no deletion needed"
  - "stop_watcher and watcher_pid already absent from wrapper -- only channel_args block needed removal"

patterns-established:
  - "claude invocations use only mode_args and current_args (no channel injection)"

requirements-completed: [CLNP-02, CLNP-03, CLNP-04, CLNP-05]

# Metrics
duration: 3min
completed: 2026-03-27
---

# Phase 12 Plan 01: Strip Peers from Wrapper Summary

**Removed channel_args block and CLAUDE_CHANNELS env var -- instruments launch claude with only mode_args and current_args, no peers infrastructure**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-27T17:32:44Z
- **Completed:** 2026-03-27T17:35:52Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Removed channel_args block (CLAUDE_CHANNELS conditional, --dangerously-load-development-channels flag) from claude-wrapper
- Removed "${channel_args[@]}" from all three claude invocations (telegram, remote-control, interactive modes)
- Removed CLAUDE_CHANNELS variable and comment from systemd env.template
- Verified bash syntax validity of modified wrapper

## Task Commits

Each task was committed atomically:

1. **Task 1: Strip channel_args and message-watcher from claude-wrapper** - `918d07b` (feat)
2. **Task 2: Remove CLAUDE_CHANNELS from env.template** - `e3d3d2d` (feat)

## Files Created/Modified
- `bin/claude-wrapper` - Removed channel_args block (lines 53-60) and channel_args from 3 claude invocations
- `systemd/env.template` - Removed CLAUDE_CHANNELS variable and comment (last 2 lines)

## Decisions Made
- bin/message-watcher was already absent from this branch (removed in earlier work), so no file deletion was needed
- stop_watcher function, watcher_pid variable, and message-watcher spawn block were also already absent -- the plan's instructions for those were a no-op
- Only the channel_args block and its usage in claude invocations needed removal

## Deviations from Plan

None - plan executed as written. Some removal targets (message-watcher, stop_watcher, watcher_pid) were already absent, reducing the actual diff to channel_args removal only.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- claude-wrapper is clean of all peers references
- env.template is clean of CLAUDE_CHANNELS
- Ready for 12-02 to strip peers from install.sh, claude-service, and tests

---
*Phase: 12-peers-teardown*
*Completed: 2026-03-27*
