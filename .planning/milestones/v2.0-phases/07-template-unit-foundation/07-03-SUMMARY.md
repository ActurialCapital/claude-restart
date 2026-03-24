---
phase: 07-template-unit-foundation
plan: 03
subsystem: infra
tags: [systemd, template-unit, installer, migration, bash]

requires:
  - phase: 07-01
    provides: "systemd template unit (claude@.service) and updated env template"
  - phase: 07-02
    provides: "instance-aware wrapper, restart, and service scripts"
provides:
  - "Instance-aware installer with template unit deployment"
  - "v1.1 to v2.0 migration function (migrate_v1_env)"
  - "Per-instance env directory creation at ~/.config/claude-restart/<name>/env"
  - "Template instance cleanup in uninstaller"
affects: [08-lifecycle-tooling, 09-orchestra]

tech-stack:
  added: []
  patterns: ["migrate_v1_env for non-destructive env migration with backup", "template unit deployment replacing single-instance unit"]

key-files:
  created: []
  modified: ["bin/install.sh"]

key-decisions:
  - "Migration creates backup at env.v1-backup before removing flat env file"
  - "Working directory extracted from old claude.service during migration when possible"
  - "do_install_macos left unchanged (no systemd on macOS)"

patterns-established:
  - "Migration pattern: detect old layout, copy to new, augment missing vars, backup old"
  - "Template unit deployment: copy claude@.service, remove old claude.service"

requirements-completed: [INST-01, INST-02, INST-03, INST-05]

duration: 2min
completed: 2026-03-23
---

# Phase 7 Plan 3: Installer with Template Unit Deployment Summary

**Instance-aware installer deploying claude@.service template unit with v1.1 migration function that preserves existing config in per-instance default/ directory**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-23T03:53:31Z
- **Completed:** 2026-03-23T03:55:00Z
- **Tasks:** 1 automated (1 checkpoint pending)
- **Files modified:** 1

## Accomplishments
- Installer deploys claude@.service template unit instead of claude.service
- Added migrate_v1_env() function that moves flat env to default/ subdirectory with backup
- Per-instance env file created at ~/.config/claude-restart/default/env with all new variables
- Uninstaller iterates all instance directories for cleanup
- Old claude.service stopped, disabled, and removed during migration
- do_install_macos preserved unchanged (no systemd on macOS)

## Task Commits

Each task was committed atomically:

1. **Task 1: Update installer for template unit deployment and migration** - `5a5c8c8` (feat)

**Plan metadata:** pending (awaiting checkpoint approval)

## Files Created/Modified
- `bin/install.sh` - Updated with migrate_v1_env(), template unit deployment, per-instance env dirs, template-aware uninstall

## Decisions Made
- Migration extracts WorkingDirectory from old claude.service unit when available, falls back to $HOME
- Backup created at env.v1-backup for safety before removing flat env file
- New variables (CLAUDE_INSTANCE_NAME, CLAUDE_RESTART_FILE, CLAUDE_MEMORY_MAX, WORKING_DIRECTORY) added conditionally during migration (grep guard)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Complete Phase 7 infrastructure is installable via install.sh
- v1.1 users can upgrade without losing configuration
- Fresh installs create a "default" instance that works identically to v1.1
- Phase 8 (lifecycle tooling) can build on this foundation

---
*Phase: 07-template-unit-foundation*
*Completed: 2026-03-23*
