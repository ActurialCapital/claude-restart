---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Multi-Instance Orchestration
status: planning
stopped_at: Phase 7 context gathered
last_updated: "2026-03-23T03:34:54.523Z"
last_activity: 2026-03-22 -- Roadmap created for v2.0
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-22)

**Core value:** Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.
**Current focus:** Phase 7 - Template Unit Foundation

## Current Position

Phase: 7 of 9 (Template Unit Foundation) -- 1 of 3 in v2.0
Plan: 0 of ? in current phase
Status: Ready to plan
Last activity: 2026-03-22 -- Roadmap created for v2.0

Progress (v2.0): [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0%

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Full decision history archived in milestones/v1.0-ROADMAP.md and milestones/v1.1-ROADMAP.md.

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

Last session: 2026-03-23T03:34:54.520Z
Stopped at: Phase 7 context gathered
Resume file: .planning/phases/07-template-unit-foundation/07-CONTEXT.md
