---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Multi-Instance Orchestration
status: Milestone complete
stopped_at: Completed 09-05-PLAN.md
last_updated: "2026-03-24T02:44:48.168Z"
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 11
  completed_plans: 11
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-22)

**Core value:** Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.
**Current focus:** Phase 09 — autonomous-orchestra

## Current Position

Phase: 09
Plan: Not started

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Full decision history archived in milestones/v1.0-ROADMAP.md and milestones/v1.1-ROADMAP.md.

- [Phase 07]: MemoryMax applied via ExecStartPre + systemctl set-property (env vars not supported in systemd resource control directives)
- [Phase 07]: Scripts use CLAUDE_INSTANCE_NAME and --instance flag for instance targeting, defaulting to backward-compatible behavior
- [Phase 07]: Migration creates env.v1-backup before removing flat env file; WorkingDirectory extracted from old claude.service when possible
- [Phase 08]: Hardcoded 8h timer intervals in watchdog template (systemd timer directives cannot read env vars)
- [Phase 08]: API key and PATH copied from default instance env for non-interactive orchestra automation
- [Phase 08]: Instrument working directories under ~/instruments/<name> by convention
- [Phase 09]: Test extraction uses sed function body isolation instead of grep -A for reliability
- [Phase 09]: Orchestra CLAUDE.md is pure prompt engineering -- the CLAUDE.md IS the orchestra supervisor
- [Phase 09]: Permission flag baked into mode_args for remote-control; defensive filtering of --dangerously-skip-permissions
- [Phase 09]: Remote-control uses identical FIFO pattern as telegram, with y written before heartbeat loop

### Key v2.0 Architecture Decisions

- All sessions use `remote-control` mode (no Telegram in this milestone)
- Instruments are isolated: one folder, one repo, one Claude session
- Orchestra is optional, autonomous-only (no relay mode)
- Orchestra is a supervisor/dispatcher, not a developer -- instruments hold project intelligence
- Orchestra spawns ad-hoc agents in project directories for research questions
- `claude-restart` is the orchestration primitive for instrument context reset
- Two interaction models coexist: direct instrument access (A) + orchestra access (B)
- Dynamic instrument awareness: hot add/remove while system is running

### Pending Todos

None.

### Blockers/Concerns

- Orchestra dispatch patterns are novel -- no established best practices (research MEDIUM confidence)
- `claude remote-control` exit codes undocumented -- may need Restart=always for remote-control instances
- Rate limit behavior under 3+ concurrent instances needs real-world validation

## Session Continuity

Last session: 2026-03-24T00:02:23.543Z
Stopped at: Completed 09-05-PLAN.md
Resume file: None
