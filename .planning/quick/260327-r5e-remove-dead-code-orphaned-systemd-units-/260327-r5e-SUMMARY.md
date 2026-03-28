---
phase: quick
plan: 260327-r5e
subsystem: infra
tags: [systemd, install, cleanup, dead-code]

requires: []
provides:
  - "Cleaner install.sh without v1.1 migration artifacts"
  - "No orphaned systemd unit files in repo"
  - "macOS CLAUDE_CONNECT defaults to remote-control"
affects: []

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - bin/install.sh
    - test/test-install.sh
  deleted:
    - systemd/claude.service
    - systemd/claude-watchdog.service
    - systemd/claude-watchdog.timer

key-decisions:
  - "Removed v1.1 migration references from do_uninstall as well (not just do_install_linux) for complete cleanup"

requirements-completed: []

duration: 3min
completed: 2026-03-28
---

# Quick Task 260327-r5e: Remove Dead Code and Orphaned Systemd Units Summary

**Deleted 3 orphaned v1.1 systemd units, removed 68 lines of migration code from install.sh, fixed macOS CLAUDE_CONNECT default from telegram to remote-control**

## What Changed

### Task 1: Remove orphaned systemd units and v1.1 migration code (04c0265)

Deleted three orphaned v1.1 systemd unit files that were superseded by template units in v2.0:
- `systemd/claude.service` (replaced by `systemd/claude@.service`)
- `systemd/claude-watchdog.service` (replaced by `systemd/claude-watchdog@.service`)
- `systemd/claude-watchdog.timer` (replaced by `systemd/claude-watchdog@.timer`)

Removed from `bin/install.sh`:
- The entire `migrate_v1_env` function (50 lines) -- migrated v1.1 flat env to per-instance layout
- The call to `migrate_v1_env` in `do_install_linux`
- The v1.1 `claude.service` migration block in `do_install_linux`
- The v1.1 `claude-watchdog` migration block in `do_install_linux`
- The v1.1 non-template unit cleanup lines in `do_uninstall`

### Task 2: Fix macOS telegram hardcode and update tests (b694488)

- Changed `do_install_macos` to export `CLAUDE_CONNECT="remote-control"` instead of `"telegram"`
- Updated Test 9 assertion to expect `remote-control`
- Updated Test 10 description strings for clarity
- Updated Tests 18, 19, 20 stdin inputs from `telegram` to `remote-control`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing cleanup] Removed v1.1 references from do_uninstall**
- **Found during:** Task 1
- **Issue:** The plan only specified removing v1.1 migration code from `do_install_linux`, but `do_uninstall` also had references to non-template unit cleanup (`claude-watchdog.timer`, `claude-watchdog.service`, `claude.service`)
- **Fix:** Removed the 3 cleanup lines from `do_uninstall` as well
- **Files modified:** bin/install.sh
- **Commit:** 04c0265

## Pre-existing Issues

Test 20 (Custom watchdog hours) fails 2 assertions before and after this change. The `CLAUDE_WATCHDOG_HOURS` env var is not substituted into the timer template file during install. This is an existing bug unrelated to this task.

## Known Stubs

None.

## Verification

- `ls systemd/` shows only template units: `claude@.service`, `claude-watchdog@.service`, `claude-watchdog@.timer`, `env.template`
- `grep -c "migrate_v1_env\|claude\.service\|claude-watchdog\.service\|claude-watchdog\.timer" bin/install.sh` returns 0
- Test suite: 51/53 pass (2 pre-existing failures in Test 20)

## Self-Check: PASSED
