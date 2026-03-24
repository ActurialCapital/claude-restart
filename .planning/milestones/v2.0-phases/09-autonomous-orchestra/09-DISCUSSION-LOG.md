# Phase 9: Autonomous Orchestra - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-03-23
**Phase:** 09-autonomous-orchestra
**Areas discussed:** Orchestra CLAUDE.md, Dispatch model, Discovery & routing, Context reset strategy

---

## Orchestra CLAUDE.md

### Operating Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Reactive supervisor | Waits for user commands, then dispatches | |
| Proactive autonomous | Runs on its own loop, checks health, makes decisions | |
| Hybrid | Autonomous by default + responsive to user commands | |

**User's choice:** Hybrid -- but clarified the framing: orchestra monitors autonomously by default, user can interact with instruments directly, and orchestra is also responsive to user.

### Tool Documentation Style

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded tool list | CLAUDE.md lists exact commands | |
| Discovery-based | Orchestra runs --help at startup | |
| Hardcoded + examples | Lists commands AND concrete usage examples | |

**User's choice:** Hardcoded + examples. Best practice for LLM-driven systems -- examples anchor behavior, reduce hallucination, and are auditable. Maintenance cost is low for a personal VPS.

### Orchestra Scope (v2.0)

User provided detailed scope clarification:
- **Discuss phase:** Orchestra spawns `claude -p` agents for context gathering
- **Research/Plan/Execute phases:** Orchestra limited to clearing context (`/clear` -> restart) and triggering next GSD step
- **User interaction:** Orchestra responds to direct user commands
- No other instrument interaction behavior expected in v2.0

### Context Management

User raised concern about orchestra over-context (accumulating context from multiple instruments/projects). Decision: orchestra minimizes context consumption, delegates heavy reads to `claude -p` agents, maintains only shallow knowledge (instrument name, current phase, next command).

### State Tracking

User flagged STATE.md as potentially buggy/unreliable. Decision: orchestra tracks instrument state internally because it's the one giving the orders. No dependency on GSD's state management.

---

## Dispatch Model

### Dispatch Approach

User clarified: orchestra should be fully autonomous by default, otherwise its value is unclear. May ask user for genuinely difficult/ambiguous decisions, but that's the exception.

Decision: auto-advance on completion with escalation to user only when stuck. Parallel dispatch (not sequential) -- this is the core value of orchestra.

### Communication Layer

| Option | Description | Selected |
|--------|-------------|----------|
| claude-peers-mcp | Peer-to-peer messaging via broker + SQLite + channel push | |
| cj-vana/claude-swarm | MCP + tmux workers (single-repo focused) | |
| parruda/swarm | Ruby framework, single process (decoupled from Claude Code) | |
| claude-mpm | Python framework, subprocess orchestration (single-project) | |

**User's choice:** claude-peers-mcp. Only solution that fits cross-project orchestration with independent Claude Code sessions. Others designed for single-project parallelism.

**Auth investigation:** User correctly identified that sessions use `claude remote-control` (claude.ai login), not API keys. `claude setup-token` enables headless VPS auth. Channel protocol requirement is not a blocker.

### Multiplexed User Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Numbered/tagged protocol | `[1/blog]` prefix, user replies with tag | |

**User's choice:** Numbered/tagged conversations for multiplexed escalation.

---

## Discovery & Routing

### Instrument Discovery

| Option | Description | Selected |
|--------|-------------|----------|
| Peer summary via list_peers | claude-peers auto-discovery with working directory + summary | |
| Instrument manifest file | Separate config mapping instruments to metadata | |
| Hybrid | list_peers + manifest | |

**User's choice:** list_peers is sufficient. Orchestra gives the orders so it already knows what each instrument is doing. No separate manifest needed.

**Notes:** User asked about `set_summary` feature -- confirmed it's nice-to-have but not essential when orchestra drives the workflow explicitly.

### GSD Output Interpretation

User asked whether orchestra can parse GSD's human-readable "Next Up" output. Decision: trust the LLM to interpret, with `/clear` mapped to `claude-restart --instance <name>`.

---

## Context Reset Strategy

### Post-Restart Command Delivery

| Option | Description | Selected |
|--------|-------------|----------|
| Wait for peer re-registration, then send_message | Poll list_peers until instrument reappears | |
| Restart with pre-loaded command | Write command file, instrument reads on boot | |
| Both mechanisms | Primary: wait + message. Fallback: command file | |

**User's choice:** Wait for peer re-registration, then send_message.

### Reset Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Only when GSD says /clear | Trust GSD's judgment on when reset is needed | |
| Between every phase | Always restart between phases | |
| Configurable per instrument | Setting in env file | |

**User's choice:** Only when GSD says /clear.

---

## Claude's Discretion

- Orchestra CLAUDE.md wording/formatting
- Timeout for peer re-registration polling
- Status update formatting
- Internal state tracking data structure

## Deferred Ideas

- Instrument-to-instrument communication
- Autonomous health monitoring beyond GSD driving
- Structured handoff file (NEXT_ACTION.json)
- Multiplexing UX improvements
- Orchestra self-restart / crash recovery
- API rate limit budget management (ORCH-07)
