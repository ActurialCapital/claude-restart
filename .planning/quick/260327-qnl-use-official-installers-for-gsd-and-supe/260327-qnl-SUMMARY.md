---
phase: quick
plan: 260327-qnl
subsystem: installer
tags: [skills, deployment, npx, claude-plugins]
key-files:
  modified:
    - bin/install.sh
    - test/test-install.sh
    - test/test-phase14-validation.sh
  removed:
    - skills/README.md
    - commands/README.md
decisions:
  - "Use npx get-shit-done-cc@latest --global --claude for GSD (official npm installer)"
  - "Use claude plugins install superpowers@superpowers-marketplace for superpowers"
  - "Remove skills/ and commands/ directories entirely (no vendoring, no cloning)"
metrics:
  duration: ~5 min
  completed: 2026-03-28
  tasks: 3/3
---

# Quick Task 260327-qnl: Use Official Installers for GSD and Superpowers

Replaced git clone-based skill deployment with official package installers: npx for GSD and claude plugins for superpowers.

## Changes Made

### Task 1: Update deploy_skills() in bin/install.sh
- Replaced git clone/pull logic with `npx get-shit-done-cc@latest --global --claude`
- Replaced superpowers git clone with `claude plugins install superpowers@superpowers-marketplace`
- Added `command -v` checks for npx and claude CLI availability before attempting install
- Removed `GSD_REPO` and `SUPERPOWERS_REPO` env var configuration lines
- Removed `skills/` and `commands/` directories from the repository
- **Commit:** d3af984

### Task 2: Update test/test-install.sh
- Replaced `setup_linux_mocks_with_git()` helper with npx/claude mocks in `setup_linux_mocks()`
- Test 21: Verifies `npx get-shit-done-cc@latest --global --claude` is called
- Test 22: Verifies graceful handling when npx/claude return errors (NPX_MOCK_FAIL, CLAUDE_MOCK_FAIL)
- Test 23: Verifies graceful handling when npx/claude executables fail
- All 51/53 tests pass (2 pre-existing failures in Test 20: custom watchdog hours)
- **Commit:** 0cbe9a6

### Task 3: Update test/test-phase14-validation.sh
- DEPL-01 now validates `npx get-shit-done-cc@latest` and `--global --claude` flags
- DEPL-02 now validates `claude plugins install superpowers@superpowers-marketplace`
- Edge case tests verify warning messages for installer failures
- All 23/23 phase 14 validation tests pass
- **Commit:** 2baec65

## Deviations from Plan

None - task executed exactly as specified in constraints.

## Known Stubs

None.

## Self-Check: PASSED
