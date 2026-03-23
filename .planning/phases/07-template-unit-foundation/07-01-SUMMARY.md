---
phase: 07-template-unit-foundation
plan: 01
subsystem: infra
tags: [systemd, template-unit, multi-instance, cgroups]

requires:
  - phase: v1.1
    provides: Single-instance claude.service and env.template baseline
provides:
  - systemd template unit claude@.service with %i-based per-instance config
  - Updated env.template with instance-aware variables (CLAUDE_INSTANCE_NAME, WORKING_DIRECTORY, CLAUDE_RESTART_FILE, CLAUDE_MEMORY_MAX)
affects: [07-02-wrapper-instance-awareness, 07-03-installer-migration]

tech-stack:
  added: []
  patterns:
    - "systemd %i specifier for per-instance EnvironmentFile routing"
    - "ExecStartPre with systemctl set-property for dynamic MemoryMax from env var"
    - "Environment variable-driven WorkingDirectory instead of hardcoded placeholder"

key-files:
  created:
    - systemd/claude@.service
  modified:
    - systemd/env.template

key-decisions:
  - "MemoryMax applied dynamically via ExecStartPre + systemctl set-property (systemd cannot expand env vars in resource control directives)"
  - "WorkingDirectory uses ${WORKING_DIRECTORY} env var from per-instance env file"
  - "Default CLAUDE_MEMORY_MAX=1G allows 3-4 concurrent instances on 8GB VPS"

patterns-established:
  - "Per-instance config at ~/.config/claude-restart/<name>/env loaded via EnvironmentFile=%h/.config/claude-restart/%i/env"
  - "INSTANCE_PLACEHOLDER and WORKING_DIR_PLACEHOLDER in env.template for installer substitution"

requirements-completed: [INST-01, INST-02, INST-03, INST-04]

duration: 1min
completed: 2026-03-23
---

# Phase 07 Plan 01: Template Unit Foundation Summary

**systemd template unit claude@.service with %i-based per-instance config, dynamic MemoryMax via ExecStartPre, and env template with 4 new instance-aware variables**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-23T03:49:07Z
- **Completed:** 2026-03-23T03:50:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created systemd template unit that enables any instrument to run as `claude@<name>.service` with isolated config
- Dynamic MemoryMax enforcement via ExecStartPre reading CLAUDE_MEMORY_MAX env var (no drop-ins needed)
- Updated env template with CLAUDE_INSTANCE_NAME, WORKING_DIRECTORY, CLAUDE_RESTART_FILE, and CLAUDE_MEMORY_MAX variables

## Task Commits

Each task was committed atomically:

1. **Task 1: Create systemd template unit claude@.service** - `5b77737` (feat)
2. **Task 2: Update env.template with instance-aware variables** - `db788f9` (feat)

## Files Created/Modified
- `systemd/claude@.service` - Template unit using %i for per-instance env file, dynamic MemoryMax, env-var WorkingDirectory
- `systemd/env.template` - Added CLAUDE_INSTANCE_NAME, WORKING_DIRECTORY, CLAUDE_RESTART_FILE, CLAUDE_MEMORY_MAX with installer placeholders

## Decisions Made
- MemoryMax cannot use env var substitution in systemd resource control directives; solved with ExecStartPre calling `systemctl --user set-property` to apply it dynamically at service start
- WorkingDirectory uses `${WORKING_DIRECTORY}` from env file instead of WORKING_DIR_PLACEHOLDER in the unit file (env var expansion works in Exec and WorkingDirectory directives)
- Default memory limit of 1G balances concurrent instance count with 8GB VPS capacity

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Template unit ready for installer (Plan 03) to deploy via `systemctl --user link`
- Env template ready for installer to copy and substitute placeholders per instance
- Original claude.service preserved as migration reference

---
*Phase: 07-template-unit-foundation*
*Completed: 2026-03-23*
