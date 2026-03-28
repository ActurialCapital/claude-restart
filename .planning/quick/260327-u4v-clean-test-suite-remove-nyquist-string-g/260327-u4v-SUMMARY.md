---
phase: quick
plan: 260327-u4v
subsystem: test
tags: [cleanup, tests, maintenance]
dependency_graph:
  requires: []
  provides: [clean-test-suite]
  affects: [test/]
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified: []
  deleted:
    - test/test-peers-teardown.sh
    - test/test-phase13-validation.sh
    - test/test-phase14-validation.sh
decisions:
  - No assertions needed migration; behavioral tests are strictly stronger
metrics:
  duration: 200s
  completed: "2026-03-28T02:47:42Z"
---

# Quick Task 260327-u4v: Clean Test Suite - Remove Nyquist String-Grep Tests

Deleted 3 redundant Nyquist string-grep validation test files (547 lines) that duplicated behavioral test coverage.

## Tasks Completed

### Task 1: Delete Nyquist string-grep test files
- **Commit:** a90e8cc
- **Action:** Deleted test-peers-teardown.sh (20 tests), test-phase13-validation.sh (21 tests), test-phase14-validation.sh (~25 assertions)
- **Result:** 5 behavioral test files remain in test/

### Task 2: Verify behavioral test suite passes
- **Action:** Ran all 5 behavioral test suites
- **Results:**
  - test-wrapper.sh: 44/44 passed
  - test-restart.sh: 13/13 passed
  - test-install.sh: 51/53 passed (2 pre-existing failures in Test 20: custom watchdog hours)
  - test-service-lifecycle.sh: 34/34 passed
  - test-orchestra.sh: 21/21 passed
- **References check:** Deleted file names appear in planning docs only (phase 12/13/14 VALIDATION.md files, prior quick task plans/summaries). No code references remain.

## Deviations from Plan

None - plan executed exactly as written.

## Pre-existing Issues Noted

test-install.sh Test 20 (custom watchdog hours) has 2 failures: the `WATCHDOG_HOURS` environment variable is not being applied during install. This is unrelated to the deleted files and pre-dates this task.

## Known Stubs

None.

## Self-Check: PASSED
