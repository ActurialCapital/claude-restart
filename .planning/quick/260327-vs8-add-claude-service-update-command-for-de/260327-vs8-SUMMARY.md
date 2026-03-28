---
phase: quick-260327-vs8
plan: 01
subsystem: claude-service
tags: [lifecycle, update, deploy-skills]
dependency_graph:
  requires: []
  provides: [claude-service-update]
  affects: [bin/claude-service, test/test-service-lifecycle.sh]
tech_stack:
  added: []
  patterns: [deploy_skills reuse from install.sh, sed_inplace template substitution]
key_files:
  created: []
  modified:
    - bin/claude-service
    - test/test-service-lifecycle.sh
decisions:
  - Removed --force flag from test cleanup (remove command has no interactive confirmation in this codebase)
  - Fixed default env heredoc to use expanded HOME for test isolation with update --all
metrics:
  duration: 3m
  completed: "2026-03-28T03:58:40Z"
  tasks_completed: 2
  tasks_total: 2
---

# Quick Task 260327-vs8: Add claude-service update command Summary

Add `claude-service update [<name>|--all]` command that re-deploys CLAUDE.md templates and skills without touching env files or restarting services.

## What Was Done

### Task 1: Implement do_update and deploy_skills in claude-service
**Commit:** 597b6cd

Added three new functions to `bin/claude-service`:

- **deploy_skills()** - Copied from install.sh: runs `npx get-shit-done-cc@latest --global --claude` and `claude plugins install superpowers@superpowers-marketplace` with graceful fallback on missing tools or failure.
- **do_update(name)** - Resolves working directory from env file, then either re-deploys orchestra behavioral spec + identity hint, or re-deploys instrument identity from INSTRUMENT.md.template with sed placeholder substitution. Never touches env files or systemctl.
- **do_update_all()** - Iterates all registered instruments, calls do_update for each, then calls deploy_skills once at the end.

Added `update` case to command dispatch: `--all` calls do_update_all, named argument calls do_update + deploy_skills, no argument shows usage.

Updated usage() with the new command and an example.

### Task 2: Add tests for the update command
**Commit:** 5f72edf

Added 6 new tests (15-20) to `test/test-service-lifecycle.sh`:

- Test 15: update requires argument (shows usage)
- Test 16: update rejects nonexistent instrument
- Test 17: update re-deploys instrument identity (corrupts then restores, verifies deploy_skills called)
- Test 18: update orchestra re-deploys behavioral spec and identity (corrupts both, verifies restoration)
- Test 19: update --all iterates all instruments (verifies both restored, deploy_skills called exactly once)
- Test 20: update does not modify env files

Added mock binaries for `npx` and `claude` CLI to support deploy_skills testing.

All 47 tests pass (41 existing + 6 new).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed --force flag from test cleanup commands**
- **Found during:** Task 2
- **Issue:** Plan specified `remove --force` in test cleanup, but the current codebase has no `--force` flag on the remove command (no interactive confirmation exists). Passing `--force` as an argument would be interpreted as the instrument name.
- **Fix:** Changed all test cleanup calls from `remove --force "name"` to `remove "name"`.
- **Files modified:** test/test-service-lifecycle.sh

**2. [Rule 3 - Blocking] Fixed default env heredoc for test isolation**
- **Found during:** Task 2
- **Issue:** Default env template used literal `/home/testuser` as WORKING_DIRECTORY. When `update --all` iterated the default instance, it tried to mkdir under `/home/testuser` which fails on macOS. The heredoc used single-quoted delimiter preventing variable expansion.
- **Fix:** Changed heredoc to unquoted delimiter so `$HOME` expands to the test's fake home path.
- **Files modified:** test/test-service-lifecycle.sh

## Known Stubs

None.

## Verification

- `bash bin/claude-service --help` shows update command in usage output
- `bash test/test-service-lifecycle.sh` passes 47/47 tests

## Self-Check: PASSED
