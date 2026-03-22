---
phase: 05-systemd-service
plan: 02
subsystem: infra
tags: [systemd, installer, bash, linux, cross-platform]

requires:
  - phase: 05-systemd-service
    plan: 01
    provides: "systemd unit file, env template, and claude-service helper"
provides:
  - "Platform-aware installer with Linux systemd deployment path"
  - "Test coverage for Linux install path with mocked systemd commands"
affects: []

tech-stack:
  added: []
  patterns: [platform-detection, env-override-for-testing, mock-commands-via-PATH]

key-files:
  created: []
  modified:
    - bin/install.sh
    - test/test-install.sh

key-decisions:
  - "sed_inplace uses actual uname -s (not overridden PLATFORM) so sed syntax matches real OS even when testing cross-platform"
  - "CLAUDE_RESTART_PLATFORM env override enables testing Linux path on macOS without modifying uname"
  - "CLAUDE_RESTART_SYSTEMD_DIR and CLAUDE_RESTART_ENV_DIR env overrides for test isolation"

patterns-established:
  - "Platform override pattern: CLAUDE_RESTART_PLATFORM env var for testability, actual uname for OS-specific commands"
  - "Mock command pattern: create temp scripts in PATH-prepended dir that log calls to file for assertion"

requirements-completed: [SYSD-02, SYSD-03]

duration: 2min
completed: 2026-03-22
---

# Phase 05 Plan 02: Installer Linux Path Summary

**Platform-aware installer that deploys systemd unit file, env file with prompted API key/mode, enables linger, and starts service -- with 7 new test cases using mocked systemctl/loginctl**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-22T03:45:42Z
- **Completed:** 2026-03-22T03:48:06Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Extended install.sh with platform detection and Linux-specific do_install_linux() function
- Linux path deploys systemd unit file, creates env file (chmod 600), copies claude-service, enables linger, starts service
- macOS path preserved unchanged as do_install_macos() with all existing behavior intact
- Added 7 new test cases (37 total assertions) covering Linux install with mocked systemctl/loginctl

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Linux/systemd branch to installer** - `fb065f9` (feat)
2. **Task 2: Add tests for Linux install path** - `cb8451d` (test)

## Files Created/Modified
- `bin/install.sh` - Platform-aware installer with Linux systemd branch, sed_inplace helper, env override variables
- `test/test-install.sh` - 7 new test cases for Linux install path with mock systemctl/loginctl

## Decisions Made
- sed_inplace uses `uname -s` directly instead of `$PLATFORM` variable, so sed syntax always matches the real OS even when PLATFORM is overridden for testing
- Added CLAUDE_RESTART_PLATFORM, CLAUDE_RESTART_SYSTEMD_DIR, CLAUDE_RESTART_ENV_DIR env overrides for full test isolation
- Mock commands via PATH-prepended temp scripts that log calls to a file for assertion

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed sed_inplace using wrong platform variable**
- **Found during:** Task 2 (test execution)
- **Issue:** sed_inplace checked `$PLATFORM` (which tests override to "Linux") but needs the actual OS to choose correct sed syntax
- **Fix:** Changed sed_inplace to use `$(uname -s)` instead of `$PLATFORM`
- **Files modified:** bin/install.sh
- **Verification:** All 37 tests pass on macOS with PLATFORM overridden to Linux
- **Committed in:** cb8451d (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for cross-platform testing. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 05 complete: all systemd artifacts created and installer deploys them
- Ready for real VPS deployment: run install.sh on Linux, answer prompts, service starts immediately
- Phase 06 (watchdog/keep-alive) can build on the running systemd service

---
*Phase: 05-systemd-service*
*Completed: 2026-03-22*

## Self-Check: PASSED
