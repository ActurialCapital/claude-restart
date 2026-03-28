---
phase: quick
plan: 260327-vop
subsystem: cli
tags: [bash, safety, confirmation-prompt, claude-service]

provides:
  - "Safe remove command with confirmation prompt and --force bypass"
affects: [claude-service, instrument-management]

tech-stack:
  added: []
  patterns: ["interactive confirmation before destructive operations"]

key-files:
  created: []
  modified: [bin/claude-service]

key-decisions:
  - "Used git -C instead of cd subshell for uncommitted change detection"
  - "Only show WARNING line when uncommitted count > 0"

patterns-established:
  - "Destructive CLI commands require explicit 'yes' confirmation with --force bypass"

requirements-completed: [QUICK-260327-vop]

duration: 1min
completed: 2026-03-28
---

# Quick Task 260327-vop: Add Confirmation Prompt to do_remove Summary

**Interactive confirmation prompt before rm -rf in claude-service remove, with --force flag for automation**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-28T03:50:39Z
- **Completed:** 2026-03-28T03:51:25Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added confirmation prompt to `do_remove` showing config dir, working dir, and uncommitted change count
- Any answer other than "yes" aborts removal with exit 1
- `--force` flag works in either position (`remove --force name` or `remove name --force`)
- Updated usage text and examples to document the new flag

## Task Commits

Each task was committed atomically:

1. **Task 1: Add confirmation prompt and --force flag to do_remove** - `caa6db6` (feat)

## Files Created/Modified
- `bin/claude-service` - Added force parameter to do_remove, confirmation prompt with uncommitted change detection, --force argument parsing in case statement, updated usage text

## Decisions Made
- Used `git -C "$work_dir" status --porcelain` instead of cd subshell for cleaner uncommitted change detection
- Only display WARNING line when uncommitted count is actually > 0 (avoids confusing "0 uncommitted change(s)" message)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None

## Next Phase Readiness
- Remove command is now safe by default; automation can use --force

---
*Plan: quick/260327-vop*
*Completed: 2026-03-28*
