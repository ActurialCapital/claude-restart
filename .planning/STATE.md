---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Multi-Instance Orchestration
status: defining requirements
stopped_at: null
last_updated: "2026-03-22T12:00:00.000Z"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-22)

**Core value:** Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.
**Current focus:** Defining requirements

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-03-22 — Milestone v2.0 started

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Full decision history archived in milestones/v1.0-ROADMAP.md and milestones/v1.1-ROADMAP.md.

### Key v2.0 Architecture Decisions

- All sessions use `remote-control` mode (no Telegram in this milestone)
- Instruments are isolated: one folder, one repo, one Claude session
- Orchestra is optional, autonomous-only (no relay mode)
- Orchestra is a supervisor/dispatcher, not a developer — instruments hold project intelligence
- Orchestra spawns ad-hoc agents in project directories for research questions
- `claude-restart` is the orchestration primitive for instrument context reset
- Two interaction models coexist: direct instrument access (A) + orchestra access (B)
- Dynamic instrument awareness: hot add/remove while system is running

### Pending Todos

None.

### Blockers/Concerns

- Need to research exact mechanics of connecting to `claude remote-control` sessions programmatically
- Agent Teams (built-in experimental) is single-repo only — doesn't solve cross-project orchestration

## Session Continuity

Last session: 2026-03-22
Stopped at: Defining requirements for v2.0
Resume file: None
