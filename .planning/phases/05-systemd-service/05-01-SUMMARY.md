---
phase: 05-systemd-service
plan: 01
subsystem: infra
tags: [systemd, service, bash, linux]

requires:
  - phase: 04-wrapper-hardening
    provides: "SIGTERM forwarding and CLAUDE_CONNECT mode selection in claude-wrapper"
provides:
  - "systemd user service unit file (claude.service)"
  - "Environment file template for installer to populate (env.template)"
  - "claude-service management helper with 5 subcommands"
affects: [05-02-installer-linux]

tech-stack:
  added: [systemd]
  patterns: [systemd-user-service, environment-file-separation, placeholder-based-install]

key-files:
  created:
    - systemd/claude.service
    - systemd/env.template
    - bin/claude-service
  modified: []

key-decisions:
  - "RestartSec=5 for reasonable delay between crash and restart"
  - "TimeoutStopSec=10 to give wrapper time to forward SIGTERM to claude child"
  - "KillSignal=SIGTERM to trigger wrapper's TERM trap on systemctl stop"

patterns-established:
  - "Placeholder pattern: WORKING_DIR_PLACEHOLDER, HOME_PLACEHOLDER, NODEVERSION_PLACEHOLDER for installer replacement"
  - "EnvironmentFile separation: secrets and config in env file, not unit file"

requirements-completed: [SYSD-01, SYSD-02]

duration: 1min
completed: 2026-03-22
---

# Phase 05 Plan 01: systemd Service Artifacts Summary

**systemd user service unit file, env template with API key/PATH/mode placeholders, and claude-service helper with start/stop/restart/status/logs subcommands**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-22T03:42:50Z
- **Completed:** 2026-03-22T03:43:44Z
- **Tasks:** 2
- **Files created:** 3

## Accomplishments
- Created systemd unit file with Restart=on-failure, StartLimitBurst=5 in [Unit], EnvironmentFile directive
- Created env template with ANTHROPIC_API_KEY, CLAUDE_CONNECT, and PATH placeholders for installer
- Created claude-service management helper with 5 subcommands wrapping systemctl/journalctl

## Task Commits

Each task was committed atomically:

1. **Task 1: Create systemd unit file and env template** - `e9a6a5c` (feat)
2. **Task 2: Create claude-service management helper script** - `9b76915` (feat)

## Files Created/Modified
- `systemd/claude.service` - systemd user service unit file for claude-wrapper
- `systemd/env.template` - Environment file template with API key, mode, and PATH placeholders
- `bin/claude-service` - Service management helper (start/stop/restart/status/logs)

## Decisions Made
- RestartSec=5 chosen as reasonable crash-to-restart delay (Claude's discretion per CONTEXT.md)
- KillSignal=SIGTERM ensures wrapper's trap fires cleanly on systemctl stop
- TimeoutStopSec=10 gives wrapper time to forward SIGTERM to claude child process

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three artifacts ready for Plan 02 (installer Linux path) to deploy
- Unit file has WORKING_DIR_PLACEHOLDER for installer to replace
- Env template has HOME_PLACEHOLDER and NODEVERSION_PLACEHOLDER for installer to replace
- claude-service ready for installer to copy to ~/.local/bin/

---
*Phase: 05-systemd-service*
*Completed: 2026-03-22*

## Self-Check: PASSED
