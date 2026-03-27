# Phase 13: Synchronous Dispatch - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite orchestra CLAUDE.md and establish `claude -p` synchronous dispatch patterns. After this phase, the orchestra drives instruments via `claude -p` commands with parallel execution, long-running task handling, and continuation support. All claude-peers references (`send_message`, `check_messages`, `list_peers`) are replaced.

Requirements: DISP-01, DISP-02, DISP-03, DISP-04, ORCH-01, ORCH-02, ORCH-03

</domain>

<decisions>
## Implementation Decisions

### Dispatch Pattern
- **D-01:** Always use `--dangerously-skip-permissions` on all `claude -p` dispatches. Orchestra dispatches are autonomous by design, no human in the loop.
- **D-02:** Claude's discretion on error/retry strategy when `claude -p` fails (non-zero exit, timeout, garbled output).
- **D-03:** Claude's discretion on output format — whether to parse raw text, use structured markers, or a hybrid approach.

### Parallel Execution
- **D-04:** Claude's discretion on parallelism mechanism (shell backgrounding, sequential non-blocking, etc.).
- **D-05:** No concurrency limit — dispatch to all instruments freely. No artificial cap.
- **D-06:** Claude's discretion on handling blocked instruments while others continue.

### Continuation Model
- **D-07:** Claude's discretion on when to use `--continue` vs fresh `claude -p`. GSD state lives in `.planning/` files.
- **D-08:** Claude's discretion on how orchestra tracks instrument state (internal memory, state files, or reading `.planning/STATE.md`).

### Orchestra CLAUDE.md Rewrite
- **D-09:** Full rewrite from scratch — do not incrementally edit the current peer-messaging CLAUDE.md. Start fresh with `claude -p` as the foundation.
- **D-10:** Claude's discretion on fleet discovery mechanism (`claude-service list`, hardcoded, or both).
- **D-11:** Claude's discretion on escalation protocol format.
- **D-12:** Claude's discretion on whether to include concrete `claude -p` examples or just describe patterns.

### Claude's Discretion
- Error handling / retry strategy (D-02)
- Output format for `claude -p` results (D-03)
- Parallelism mechanism (D-04)
- Blocked instrument handling (D-06)
- Continuation strategy — `--continue` vs fresh (D-07)
- Instrument state tracking approach (D-08)
- Fleet discovery method (D-10)
- Escalation format for phone reading (D-11)
- Example verbosity in CLAUDE.md (D-12)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — DISP-01 through DISP-04, ORCH-01 through ORCH-03 define the dispatch and orchestra requirements

### Current Orchestra Spec (being replaced)
- `orchestra/CLAUDE.md` — Current behavioral spec built around claude-peers. Full rewrite target. Read to understand current structure (escalation protocol, anti-patterns, startup sequence, state tracking, parallel dispatch) but do NOT preserve the peer-messaging mechanics.

### Prior Phase Context
- `.planning/phases/12-peers-teardown/12-CONTEXT.md` — Phase 12 decisions on peers removal (now complete)

### Project Architecture
- `.planning/PROJECT.md` — Key decisions table, especially: "`claude -p` replaces peer messaging", "Fresh context by default, `--continue` for continuity", "Orchestra CLAUDE.md as pure prompt engineering"

### Existing Tooling
- `bin/claude-service` — Fleet management (list, start, stop, add, remove). Orchestra may use for discovery.
- `bin/claude-restart` — Context reset for instruments. Orchestra uses for inter-phase resets.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/claude-service list` — Already provides fleet discovery (registered instruments + systemd state)
- `bin/claude-restart --instance <name>` — Context reset mechanism, already proven
- `cd ~/instruments/<name> && claude -p "..."` pattern — Already used for one-shot assessment agents in current CLAUDE.md

### Established Patterns
- Orchestra CLAUDE.md is pure prompt engineering — the CLAUDE.md IS the orchestra, no code needed
- `--dangerously-skip-permissions` used on all autonomous dispatches
- Instruments are isolated folders with own repos, own CLAUDE.md, own `.planning/`
- GSD state lives in `.planning/` files — conversation context is disposable

### Integration Points
- `orchestra/CLAUDE.md` — The single file being rewritten. This IS the deliverable.
- `bin/claude-service` — Orchestra calls this for fleet management
- `bin/claude-restart` — Orchestra calls this for instrument context reset
- Instrument `.planning/STATE.md` — Orchestra may read to assess instrument progress

</code_context>

<specifics>
## Specific Ideas

No specific requirements — user deferred most implementation details to Claude's discretion. The key locked decisions are:
1. Always `--dangerously-skip-permissions` on dispatches
2. No concurrency limit on parallel dispatches
3. Full CLAUDE.md rewrite from scratch (not incremental edit)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 13-synchronous-dispatch*
*Context gathered: 2026-03-27*
