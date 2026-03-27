---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: Synchronous Dispatch Architecture
status: defining requirements
stopped_at: null
last_updated: "2026-03-27T16:30:00.000Z"
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.
**Current focus:** v3.0 Synchronous Dispatch Architecture

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-03-27 — Milestone v3.0 started

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Full decision history archived in milestones/v1.0-ROADMAP.md, milestones/v1.1-ROADMAP.md, and milestones/v2.0-ROADMAP.md.

### Key v3.0 Architecture Decisions

- `claude -p` replaces peer messaging as primary dispatch mechanism
- claude-peers (broker, watcher, MCP server) removed entirely
- Fresh context by default; `--continue` for multi-step GSD sequences
- `claude-restart` retained only for remote-control session reset
- Orchestra CLAUDE.md rewritten for synchronous dispatch pattern
- Instruments are working directories for `claude -p` AND remote-control services for phone access

### Pending Todos

None.

### Blockers/Concerns

- `claude -p` cold-start time (~10s) may affect parallel dispatch latency
- Long-running execute-phase tasks need orchestra handling strategy
- GSD skill deployment to VPS needs verification that `claude -p` inherits from `~/.claude/`

## Session Continuity

Last session: 2026-03-27
Stopped at: Milestone v3.0 started, defining requirements
Resume file: None
