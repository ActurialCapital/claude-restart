---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: VPS Reliability
status: unknown
stopped_at: Completed 04-02-PLAN.md
last_updated: "2026-03-22T02:26:56.319Z"
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-20)

**Core value:** Claude can be restarted with new CLI options from within a session without manual exit-and-retype.
**Current focus:** Phase 04 — wrapper-hardening

## Current Position

Phase: 5
Plan: Not started

## Performance Metrics

**Velocity:**

- Total plans completed: 0 (v1.1)
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*
| Phase 04 P01 | 2min | 1 tasks | 2 files |
| Phase 04 P02 | 2min | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Full v1.0 decision history archived in milestones/v1.0-ROADMAP.md.

Recent decisions affecting current work:

- SIGTERM forwarding (WRAP-01) must land in Phase 4 before systemd wraps the wrapper — `systemctl stop` hangs 90s without it
- Mode selection (WRAP-02) is Phase 4 prerequisite — `ExecStart` in the systemd unit must know which mode to invoke
- Use `Restart=on-failure` not `Restart=always` to avoid double-restart loop (wrapper + systemd both reacting to same exit)
- `StartLimitBurst` must be in `[Unit]` section, not `[Service]` (silently ignored otherwise)
- Keep-alive (KALV-01) is Telegram-only — remote-control has built-in reconnection, do not duplicate
- [Phase 04]: Claude runs in background with wait to enable signal trapping
- [Phase 04]: CLAUDE_CONNECT env var maps to CLI args array; mode_args prepended to current_args
- [Phase 04]: Restart file content only replaces extra args (current_args), never mode_args -- mode fixed at launch per D-09
- [Phase 04]: Installer exports CLAUDE_CONNECT=telegram instead of embedding channel string in DEFAULT_OPTS

### Pending Todos

None.

### Blockers/Concerns

- Phase 6 watchdog threshold is heuristic (CPU=0 + no network > 10 min) — needs real-world calibration during Phase 6 planning
- `claude remote-control` exit code on 10-min network timeout not confirmed — resolve during Phase 5 (affects `RestartPreventExitStatus` config)

## Session Continuity

Last session: 2026-03-22T02:24:19.388Z
Stopped at: Completed 04-02-PLAN.md
Resume file: None
