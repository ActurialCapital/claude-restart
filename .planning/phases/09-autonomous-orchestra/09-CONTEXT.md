# Phase 9: Autonomous Orchestra - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

An optional autonomous Claude session that supervises all instruments -- dispatching work, resetting context, spawning research agents, and adapting to fleet changes. Orchestra drives instruments through the GSD lifecycle (discuss -> research -> plan -> execute) in parallel, using claude-peers-mcp for inter-session communication.

Requirements: ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-05

</domain>

<decisions>
## Implementation Decisions

### Orchestra Operating Mode
- **D-01:** Hybrid autonomous + responsive. Orchestra monitors and drives GSD workflows autonomously by default, but is responsive to user commands via remote-control.
- **D-02:** User can still interact with instruments directly (via `claude remote-control --name <instance>`). Orchestra and direct access coexist.

### Orchestra CLAUDE.md
- **D-03:** Hardcoded tool list + examples. CLAUDE.md lists exact commands with concrete usage examples (e.g., `claude -p "..." --cwd ~/instruments/blog/`). Examples anchor LLM behavior and reduce hallucinated flag combinations.
- **D-04:** Orchestra's CLAUDE.md defines the default GSD workflow sequence: always start with `/gsd:discuss-phase`, then `/gsd:plan-phase`, then `/gsd:execute-phase`. Workflow logic lives in orchestra's CLAUDE.md, not in instrument CLAUDE.md files.
- **D-05:** Orchestra scope for v2.0 is GSD workflow driver only:
  - **Discuss phase:** Orchestra spawns `claude -p` agents in instrument's project directory for context/information gathering, preserving orchestra's own context
  - **Research/Plan/Execute phases:** Orchestra clears instrument context (via `claude-restart --instance`) and triggers the next GSD command
  - **User interaction:** Orchestra responds to any direct user commands
  - No instrument-to-instrument communication, no autonomous health monitoring beyond GSD driving, no modifying instrument repos or configs

### Context Management
- **D-06:** Orchestra minimizes context consumption. Shallow knowledge only -- orchestra does not read full project files. Heavy reads delegated to `claude -p` one-shot agents. Orchestra only needs: instrument name, current phase, next GSD command.
- **D-07:** Orchestra tracks instrument state internally (not via STATE.md). Orchestra knows where each instrument is because it's the one giving the orders. No dependency on GSD's state management being bug-free.

### Communication Layer
- **D-08:** claude-peers-mcp (https://github.com/louislva/claude-peers-mcp) is the inter-session communication layer. Provides peer discovery via broker daemon + SQLite, instant message delivery via Claude channel protocol, and async messaging for parallel dispatch.
- **D-09:** Parallel dispatch -- orchestra drives all instruments simultaneously, not sequentially. This is the core value of orchestra.
- **D-10:** Numbered/tagged conversation protocol for user escalation. When orchestra needs user input for multiple instruments simultaneously, it tags each request (e.g., `[1/blog]`, `[2/api]`) and user replies with the tag prefix to route answers.

### Discovery & Routing
- **D-11:** `list_peers` from claude-peers for live instrument discovery. Each instrument registers automatically with the broker. Orchestra sees peer ID, working directory, and summary. Working directory (`~/instruments/<name>/`) is the primary identifier.
- **D-12:** No separate manifest needed. Orchestra discovers instruments via `list_peers` and tracks them internally.

### Context Reset Strategy
- **D-13:** When GSD output includes `/clear`, orchestra translates that to `claude-restart --instance <name>` (kills and relaunches the instrument with fresh context). Orchestra only restarts when GSD explicitly says `/clear` -- trusts GSD's judgment on when context reset is needed.
- **D-14:** After restart, orchestra polls `list_peers` until the instrument re-registers with the claude-peers broker, then sends the next GSD command via `send_message`.

### Dispatch Model
- **D-15:** Orchestra interprets GSD's human-readable output (including "Next Up" instructions) to determine the next action. Trust the LLM to read and act on GSD's natural language output -- no structured handoff file needed for v2.0.
- **D-16:** Auto-advance on completion. When orchestra detects a phase completed (via instrument's message back), it automatically kicks off the next GSD step. Orchestra only escalates to user when genuinely stuck or ambiguous.

### Claude's Discretion
- Orchestra's CLAUDE.md wording and formatting (as long as it includes tool list + examples + GSD workflow sequence + behavioral scope)
- Timeout duration for waiting on peer re-registration after restart
- How orchestra formats status updates when user asks "what's happening"
- Internal data structure for tracking instrument state

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Communication Layer
- claude-peers-mcp repo: https://github.com/louislva/claude-peers-mcp -- broker daemon architecture, MCP tools (list_peers, send_message, set_summary, check_messages), channel protocol for instant message delivery

### Existing Infrastructure
- `bin/claude-service` -- add/remove/list subcommands, instance-aware start/stop/restart/status
- `bin/claude-restart` -- `--instance <name>` for targeted instrument restart (context reset primitive)
- `bin/claude-wrapper` -- instance-aware wrapper with CLAUDE_INSTANCE_NAME passthrough
- `systemd/claude@.service` -- template unit for running instruments
- `systemd/env.template` -- per-instance environment configuration

### Prior Phase Context
- `.planning/phases/07-template-unit-foundation/07-CONTEXT.md` -- instance naming (D-01), directory layout (D-02, D-03), backward compatibility (D-05 through D-08)
- `.planning/phases/08-instrument-lifecycle/08-CONTEXT.md` -- filesystem as manifest (D-02), add/remove workflow (D-03 through D-08), non-interactive design (specifics)

### Requirements
- `.planning/REQUIREMENTS.md` -- ORCH-01 through ORCH-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `claude-service add/remove/list` -- lifecycle management already built, orchestra can call these
- `claude-restart --instance <name>` -- context reset primitive, ready to use
- `claude-service list` -- instrument discovery via filesystem scan (fallback if claude-peers broker is down)

### Established Patterns
- Environment variable-driven config (CLAUDE_CONNECT, CLAUDE_INSTANCE_NAME, CLAUDE_MEMORY_MAX)
- systemd template units with `%i` for instance name
- Non-interactive command design (all commands work via `claude -p` from orchestra)
- API key and PATH copied from default instance for new instruments

### Integration Points
- Orchestra registers as `claude@orchestra.service` -- itself an instrument managed by systemd
- Orchestra's working directory needs claude-peers MCP server configured
- Each instrument needs claude-peers MCP server + `--dangerously-load-development-channels server:claude-peers`
- `claude auth login` or `claude setup-token` required on VPS for channel protocol support

</code_context>

<specifics>
## Specific Ideas

- Orchestra's primary value is parallel GSD workflow driving -- sequential defeats the purpose
- User manages VPS from phone -- numbered/tagged escalation protocol must be readable on a small screen
- Instruments are disposable clones from GitHub -- orchestra should not be precious about restarting them
- claude-peers broker auto-launches and auto-cleans dead peers -- minimal ops overhead
- Bun is a new dependency for claude-peers (not in current pure-bash stack)
- `--dangerously-skip-permissions` required for channel mode -- acceptable on personal VPS

</specifics>

<deferred>
## Deferred Ideas

- Instrument-to-instrument communication (instruments talking to each other without orchestra)
- Autonomous health monitoring beyond GSD driving (checking if instruments are stuck, OOM, etc.)
- Structured handoff file (NEXT_ACTION.json) if LLM interpretation of GSD output proves unreliable
- Multiplexing UX improvements (richer tagging, conversation threading)
- Orchestra self-restart / crash recovery strategy
- Orchestra managing API rate limit budget across concurrent instruments (ORCH-07)

</deferred>

---

*Phase: 09-autonomous-orchestra*
*Context gathered: 2026-03-23*
