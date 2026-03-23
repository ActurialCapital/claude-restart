---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Multi-Instance Orchestration
status: Ready to execute
stopped_at: Completed 07-01-PLAN.md
last_updated: "2026-03-23T03:50:54.199Z"
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 3
  completed_plans: 1
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-22)

**Core value:** Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.
**Current focus:** Phase 07 — template-unit-foundation

## Current Position

Phase: 07 (template-unit-foundation) — EXECUTING
Plan: 2 of 3

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Full decision history archived in milestones/v1.0-ROADMAP.md and milestones/v1.1-ROADMAP.md.

- [Phase 07]: MemoryMax applied via ExecStartPre + systemctl set-property (env vars not supported in systemd resource control directives)

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

Last session: 2026-03-23T03:50:54.197Z
Stopped at: Completed 07-01-PLAN.md
Resume file: None
