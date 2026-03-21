---
phase: 03-shell-integration
plan: 01
subsystem: infra
tags: [bash, shell, zsh, installer]

# Dependency graph
requires:
  - phase: 01-wrapper-script
    provides: claude-wrapper loop script
  - phase: 02-restart-trigger
    provides: claude-restart trigger script
provides:
  - install.sh that copies scripts to ~/.local/bin and configures .zshrc
  - Automated test suite for install/uninstall/idempotency
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [sentinel-based idempotent shell config, env var overrides for test isolation]

key-files:
  created: [bin/install.sh, test/test-install.sh]
  modified: []

key-decisions:
  - "Sentinel markers (# >>> claude-restart >>>) for idempotent zshrc modification"
  - "INSTALL_DIR expanded at install time, CLAUDE_RESTART_DEFAULT_OPTS kept as runtime variable"

patterns-established:
  - "Sentinel-guarded config blocks: use # >>> name >>> / # <<< name <<< for reversible shell config"
  - "Env var overrides for all paths: CLAUDE_RESTART_INSTALL_DIR, CLAUDE_RESTART_ZSHRC for test isolation"

requirements-completed: [SHEL-01, SHEL-02]

# Metrics
duration: 2min
completed: 2026-03-21
---

# Phase 03 Plan 01: Shell Integration Summary

**Install script with sentinel-based idempotent zshrc config, uninstall support, and 9-test automated suite**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-21T02:42:30Z
- **Completed:** 2026-03-21T02:44:11Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Install script copies claude-wrapper and claude-restart to ~/.local/bin/ with proper permissions
- Shell function in .zshrc routes no-arg calls through default opts and arg calls through passthrough
- Sentinel-based idempotency prevents duplicate zshrc entries on re-install
- Clean uninstall via --uninstall removes scripts and zshrc block
- 9 test cases (15 assertions) verify install, uninstall, idempotency, and correctness

## Task Commits

Each task was committed atomically:

1. **Task 1: Create install script** - `13776f8` (feat)
2. **Task 2: Create test suite** - `60b5823` (test)

## Files Created/Modified
- `bin/install.sh` - Install/uninstall script with sentinel-based zshrc integration
- `test/test-install.sh` - 9-test automated suite covering install, uninstall, idempotency

## Decisions Made
- Sentinel markers (`# >>> claude-restart >>>` / `# <<< claude-restart <<<`) for reversible, idempotent zshrc modifications
- `$INSTALL_DIR` expanded at install time so absolute paths are written to zshrc; `$CLAUDE_RESTART_DEFAULT_OPTS` kept as runtime variable for flexibility
- macOS `sed -i ''` syntax used (project targets zsh/macOS)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three scripts (claude-wrapper, claude-restart, install.sh) are complete
- All three test suites pass (41/41 assertions across test-wrapper.sh, test-restart.sh, test-install.sh)
- v1.0 feature set is complete: user can run `bin/install.sh` then `claude-restart` in a new terminal

## Self-Check: PASSED

All files and commits verified.

---
*Phase: 03-shell-integration*
*Completed: 2026-03-21*
