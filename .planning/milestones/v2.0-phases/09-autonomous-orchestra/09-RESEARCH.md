# Phase 9: Autonomous Orchestra - Research

**Researched:** 2026-03-23
**Domain:** Claude Code inter-session orchestration via claude-peers-mcp
**Confidence:** MEDIUM

## Summary

Phase 9 delivers an optional autonomous Claude session ("orchestra") that supervises all instruments, driving them through the GSD workflow lifecycle in parallel. The core communication layer is claude-peers-mcp, a third-party MCP server that provides peer discovery and instant message delivery via a localhost broker daemon with SQLite storage. Orchestra itself runs as a standard instrument (`claude@orchestra.service`) with a CLAUDE.md that encodes its supervisor role, available tools, and the GSD workflow sequence.

The primary technical challenge is not infrastructure (existing scripts handle lifecycle) but **LLM behavioral reliability**: orchestra must correctly interpret GSD output, determine next actions, and drive multiple instruments simultaneously without losing track of state. The communication layer (claude-peers) is straightforward -- four MCP tools with simple schemas. The novel part is the CLAUDE.md prompt engineering that makes orchestra behave as a reliable supervisor.

**Primary recommendation:** Implement in two waves -- (1) orchestra as instrument + claude-peers integration + CLAUDE.md authoring, (2) parallel dispatch + user escalation protocol. Keep CLAUDE.md concrete with exact command examples; avoid abstract descriptions.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Hybrid autonomous + responsive. Orchestra monitors and drives GSD workflows autonomously by default, but is responsive to user commands via remote-control.
- **D-02:** User can still interact with instruments directly (via `claude remote-control --name <instance>`). Orchestra and direct access coexist.
- **D-03:** Hardcoded tool list + examples. CLAUDE.md lists exact commands with concrete usage examples (e.g., `claude -p "..." --cwd ~/instruments/blog/`). Examples anchor LLM behavior and reduce hallucinated flag combinations.
- **D-04:** Orchestra's CLAUDE.md defines the default GSD workflow sequence: always start with `/gsd:discuss-phase`, then `/gsd:plan-phase`, then `/gsd:execute-phase`. Workflow logic lives in orchestra's CLAUDE.md, not in instrument CLAUDE.md files.
- **D-05:** Orchestra scope for v2.0 is GSD workflow driver only (discuss, research/plan/execute, user interaction). No instrument-to-instrument communication, no autonomous health monitoring beyond GSD driving.
- **D-06:** Orchestra minimizes context consumption. Shallow knowledge only -- heavy reads delegated to `claude -p` one-shot agents.
- **D-07:** Orchestra tracks instrument state internally (not via STATE.md).
- **D-08:** claude-peers-mcp is the inter-session communication layer.
- **D-09:** Parallel dispatch -- orchestra drives all instruments simultaneously.
- **D-10:** Numbered/tagged conversation protocol for user escalation (e.g., `[1/blog]`, `[2/api]`).
- **D-11:** `list_peers` from claude-peers for live instrument discovery. Working directory is the primary identifier.
- **D-12:** No separate manifest needed. Orchestra discovers instruments via `list_peers`.
- **D-13:** When GSD output includes `/clear`, orchestra translates to `claude-restart --instance <name>`. Only restarts when GSD explicitly says `/clear`.
- **D-14:** After restart, orchestra polls `list_peers` until instrument re-registers, then sends next GSD command via `send_message`.
- **D-15:** Orchestra interprets GSD's human-readable output to determine next action. No structured handoff file.
- **D-16:** Auto-advance on completion. Orchestra only escalates to user when genuinely stuck or ambiguous.

### Claude's Discretion
- Orchestra's CLAUDE.md wording and formatting (as long as it includes tool list + examples + GSD workflow sequence + behavioral scope)
- Timeout duration for waiting on peer re-registration after restart
- How orchestra formats status updates when user asks "what's happening"
- Internal data structure for tracking instrument state

### Deferred Ideas (OUT OF SCOPE)
- Instrument-to-instrument communication
- Autonomous health monitoring beyond GSD driving
- Structured handoff file (NEXT_ACTION.json)
- Multiplexing UX improvements (richer tagging, conversation threading)
- Orchestra self-restart / crash recovery strategy
- Orchestra managing API rate limit budget across concurrent instruments (ORCH-07)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORCH-01 | Orchestra is itself an instrument -- a Claude session with CLAUDE.md that runs as its own systemd service | Existing `claude-service add` workflow + `claude@.service` template unit. Orchestra registered as `claude@orchestra.service`. CLAUDE.md is the novel deliverable. |
| ORCH-02 | Orchestra can dispatch one-shot agents via `claude -p` in any instrument's project directory | `claude -p` supports non-interactive mode with CLAUDE.md discovery. Must use `cd /path && claude -p "..."` since `--cwd` does not exist. |
| ORCH-03 | Orchestra can restart any instrument via `claude-restart --instance <name>` for context reset between phases | Existing `claude-restart --instance` script handles this via `systemctl --user restart`. No new code needed -- just CLAUDE.md documentation. |
| ORCH-04 | Orchestra detects instruments added or removed while it is running (dynamic discovery) | claude-peers `list_peers` with `scope: "machine"` returns all registered peers. Broker auto-cleans dead peers. Fallback: `claude-service list` reads filesystem. |
| ORCH-05 | Orchestra always routes messages to the correct instrument based on project context | claude-peers `send_message` takes `to_id` (peer ID from `list_peers`). Orchestra matches working directory to instrument name for routing. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| claude-peers-mcp | latest (main branch) | Inter-session peer discovery + messaging | Only MCP-based Claude-to-Claude communication tool. Provides `list_peers`, `send_message`, `set_summary`, `check_messages` |
| Bun | latest | Runtime for claude-peers broker + MCP server | Required by claude-peers (uses `bun:sqlite`, `Bun.serve()`) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| claude-service (existing) | N/A | Instrument lifecycle (add/remove/list/start/stop) | Registering orchestra as instrument |
| claude-restart (existing) | N/A | Context reset primitive (`--instance <name>`) | Orchestra resetting instruments between GSD phases |
| claude-wrapper (existing) | N/A | Wrapper loop with mode-aware restart | Running orchestra via systemd |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| claude-peers-mcp | Direct `claude -p` dispatch only (no messaging) | Loses instant message delivery, peer discovery, parallel feedback. claude-peers adds real-time bidirectional communication. |
| Bun | Node.js | claude-peers hard-requires Bun (`bun:sqlite`, `Bun.serve()`). No choice here. |

**Installation (on VPS):**
```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Clone and install claude-peers-mcp
git clone https://github.com/louislva/claude-peers-mcp.git ~/claude-peers-mcp
cd ~/claude-peers-mcp && bun install

# Register MCP server globally for all Claude sessions
claude mcp add --scope user --transport stdio claude-peers -- bun ~/claude-peers-mcp/server.ts
```

## Architecture Patterns

### Orchestra as Instrument

Orchestra is registered exactly like any other instrument:
```
~/instruments/orchestra/     # Working directory (can be a dedicated repo or this repo)
~/.config/claude-restart/orchestra/env   # Environment config
claude@orchestra.service     # systemd unit
```

The key difference is its CLAUDE.md, which defines supervisor behavior instead of project development behavior.

### Orchestra CLAUDE.md Structure (Recommended)

The CLAUDE.md must be concrete and example-heavy. Recommended sections:

```markdown
# Orchestra - Autonomous Supervisor

## Your Role
You are the orchestra supervisor. You drive instruments through the GSD workflow.
You do NOT write code. You dispatch work and track progress.

## Available Tools

### Peer Discovery
- `list_peers` (scope: "machine") -- discover all running instruments
- `set_summary` -- update your status for other peers

### Messaging
- `send_message` (to_id, message) -- send instruction to an instrument
- `check_messages` -- check for responses

### One-Shot Agents (for information gathering)
- `cd ~/instruments/<name> && claude -p "<question>"` -- spawn research agent

### Context Reset
- `claude-restart --instance <name>` -- kill and relaunch instrument with fresh context

## GSD Workflow Sequence
For each instrument with pending work:
1. Send: `/gsd:discuss-phase`
2. Wait for response. If user input needed, escalate with tag.
3. Send: `/gsd:plan-phase`
4. Send: `/gsd:execute-phase`
5. If response contains `/clear`, run `claude-restart --instance <name>`
6. Poll `list_peers` until instrument re-registers
7. Send next GSD command

## Parallel Dispatch
Drive ALL instruments simultaneously. Do not wait for one to finish before starting another.

## User Escalation Format
When you need user input for multiple instruments:
[1/blog] Question about blog instrument
[2/api] Question about api instrument
User replies with tag prefix to route answer.
```

### Pattern: Dispatch via send_message

```
Orchestra                         Instrument (blog)
    |                                    |
    |-- list_peers (scope: "machine") -->|
    |<-- [{id: "abc", dir: "~/instruments/blog", ...}]
    |                                    |
    |-- send_message(to: "abc",          |
    |     msg: "/gsd:discuss-phase") --->|
    |                                    |
    |<-- (channel notification)          |
    |     "Phase discussed. Ready for    |
    |      planning."                    |
    |                                    |
    |-- send_message(to: "abc",          |
    |     msg: "/gsd:plan-phase") ------>|
```

### Pattern: Context Reset + Re-registration

```
Orchestra                         Instrument (blog)
    |                                    |
    |-- claude-restart --instance blog   |
    |   (systemd restarts the service)   X (killed)
    |                                    |
    |-- list_peers (poll) ------------->  (not yet registered)
    |-- list_peers (poll, +5s) -------->  (not yet registered)
    |-- list_peers (poll, +10s) ------->  [{id: "def", dir: "~/instruments/blog"}]
    |                                    |
    |-- send_message(to: "def", ...)     |
```

### Anti-Patterns to Avoid
- **Orchestra reading project files directly:** Orchestra should never `cat` or `Read` files in instrument repos. Delegate to `claude -p` one-shot agents for heavy reads. Orchestra only needs: instrument name, current phase, next command.
- **Sequential dispatch:** Driving instruments one at a time defeats the core value proposition. Always dispatch in parallel.
- **Trusting peer IDs across restarts:** Peer IDs change when an instrument restarts (new session = new registration). Always re-discover via `list_peers` after a `claude-restart`.
- **Orchestra modifying instrument repos:** Orchestra is a supervisor, not a developer. It sends GSD commands; instruments do the work.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Peer discovery | Custom socket/file-based IPC | claude-peers `list_peers` | Broker handles registration, cleanup, scoping |
| Message delivery | File-based message passing | claude-peers `send_message` + channel protocol | Instant delivery via Claude channel push, no polling needed on receiving end |
| Instrument lifecycle | Custom start/stop scripts | Existing `claude-service` + `claude-restart` | Already built and tested in phases 7-8 |
| GSD workflow engine | Structured state machine | LLM interpreting GSD output (per D-15) | GSD output is human-readable; LLM interpretation is sufficient for v2.0 |

**Key insight:** Almost all infrastructure already exists. Phase 9 is primarily about (1) installing/configuring claude-peers, (2) writing orchestra's CLAUDE.md, and (3) integration testing the end-to-end flow.

## Common Pitfalls

### Pitfall 1: Authentication Mismatch for Channel Protocol
**What goes wrong:** claude-peers channel notifications require `claude.ai` authentication (OAuth login), not just an `ANTHROPIC_API_KEY`. If instruments only have API key auth, `send_message` falls back to polling via `check_messages` instead of instant push.
**Why it happens:** Channel protocol is a Claude.ai feature, not an API feature. The env template currently only sets `ANTHROPIC_API_KEY`.
**How to avoid:** Run `claude auth login` on the VPS before deploying. Verify with `claude auth status`. All instances share the auth token stored in `~/.claude/`.
**Warning signs:** `send_message` works but messages are delayed; `check_messages` shows messages that should have been pushed.

### Pitfall 2: --cwd Flag Does Not Exist
**What goes wrong:** CLAUDE.md examples might reference `claude -p "..." --cwd ~/instruments/blog/` but this flag does not exist (feature request closed as not-planned).
**Why it happens:** D-03 in CONTEXT.md mentions `--cwd` in the example. This was aspirational.
**How to avoid:** Use `cd ~/instruments/<name> && claude -p "..."` pattern in all CLAUDE.md examples and dispatch logic.
**Warning signs:** `claude -p` runs in wrong directory, fails to find CLAUDE.md, produces irrelevant output.

### Pitfall 3: Peer IDs Are Ephemeral
**What goes wrong:** Orchestra caches a peer ID, instrument gets restarted, old peer ID is now invalid. Messages sent to stale ID are lost.
**Why it happens:** Each Claude session gets a new peer registration. The broker cleans up dead peers, but there's a window where the old ID is gone and the new one isn't registered yet.
**How to avoid:** Always call `list_peers` before `send_message`. After `claude-restart`, poll `list_peers` until the instrument re-appears (match by working directory path, not peer ID).
**Warning signs:** `send_message` returns error or silently fails.

### Pitfall 4: Bun Not in systemd PATH
**What goes wrong:** claude-peers MCP server fails to start because `bun` isn't in the PATH available to the systemd user service.
**Why it happens:** Bun installs to `~/.bun/bin/` which may not be in the PATH set in `env.template`.
**How to avoid:** After installing Bun, add `~/.bun/bin` to the PATH line in every instrument's env file (including orchestra's). Or use absolute path in MCP registration: `claude mcp add ... -- ~/.bun/bin/bun ~/claude-peers-mcp/server.ts`.
**Warning signs:** MCP server connection errors in Claude logs; `list_peers` tool not available.

### Pitfall 5: Orchestra Context Exhaustion
**What goes wrong:** Orchestra accumulates too much context from instrument responses, hitting token limits and degrading performance.
**Why it happens:** Each instrument response from GSD phases can be verbose. With N instruments running in parallel, context grows rapidly.
**How to avoid:** Orchestra should (1) only retain summary of each instrument's status, (2) delegate detailed reads to `claude -p` agents, (3) use `/clear` context resets for itself periodically.
**Warning signs:** Orchestra responses become slow, incoherent, or start confusing instruments.

### Pitfall 6: Race Condition in Parallel Dispatch
**What goes wrong:** Orchestra sends commands to all instruments simultaneously, but some instruments respond while orchestra is still processing other responses.
**Why it happens:** Channel notifications arrive asynchronously. If orchestra is mid-thought when a message arrives, it may lose track.
**How to avoid:** The tagged protocol (D-10) helps. Orchestra should process one batch of responses at a time, not try to interleave dispatch and response handling.
**Warning signs:** Orchestra "forgets" about instruments or sends duplicate commands.

## Code Examples

### Registering Orchestra as an Instrument

```bash
# Create orchestra working directory (can be this repo itself or a dedicated one)
mkdir -p ~/instruments/orchestra

# Use claude-service to register (adapts existing pattern)
# Note: orchestra doesn't need a git clone -- it can use a local directory
# Manual setup (since add expects a git URL):
mkdir -p ~/.config/claude-restart/orchestra
cp ~/.config/claude-restart/env.template ~/.config/claude-restart/orchestra/env
# Edit env: set CLAUDE_INSTANCE_NAME=orchestra, WORKING_DIRECTORY=~/instruments/orchestra
# Copy API key and PATH from default instance

# Enable systemd
systemctl --user daemon-reload
systemctl --user enable --now claude@orchestra.service
systemctl --user enable --now claude-watchdog@orchestra.timer
```

### claude-peers MCP Tool Schemas (from source)

```typescript
// list_peers
{
  name: "list_peers",
  inputSchema: {
    type: "object",
    properties: {
      scope: {
        type: "string",
        enum: ["machine", "directory", "repo"],
        description: "machine = all instances. directory = same working dir. repo = same git repo."
      }
    },
    required: ["scope"]
  }
}

// send_message
{
  name: "send_message",
  inputSchema: {
    type: "object",
    properties: {
      to_id: { type: "string", description: "Peer ID from list_peers" },
      message: { type: "string", description: "The message to send" }
    },
    required: ["to_id", "message"]
  }
}

// set_summary
{
  name: "set_summary",
  inputSchema: {
    type: "object",
    properties: {
      summary: { type: "string", description: "1-2 sentence summary of current work" }
    },
    required: ["summary"]
  }
}

// check_messages
{
  name: "check_messages",
  inputSchema: { type: "object", properties: {} }
}
```

### Claude -p Dispatch Pattern (Orchestra's Bash Usage)

```bash
# Orchestra dispatches a one-shot research agent in blog instrument's directory
cd ~/instruments/blog && claude -p "What phase is this project currently on? Check .planning/STATE.md"

# Orchestra dispatches with --dangerously-skip-permissions for non-interactive
cd ~/instruments/blog && claude -p --dangerously-skip-permissions "What phase is this project currently on?"
```

### Env File Additions for Channel Support

```bash
# In each instrument's env file, ensure channel support:
# 1. Bun must be in PATH
PATH=/usr/local/bin:/usr/bin:/bin:~/.local/bin:~/.npm-global/bin:~/.nvm/versions/node/.../bin:~/.bun/bin

# 2. claude-wrapper must launch with channel flag
# This requires modifying claude-wrapper or claude@.service ExecStart
```

### Channel Flag Integration

The `--dangerously-load-development-channels server:claude-peers` flag must be passed to every `claude` invocation that needs instant message delivery. Options:

1. **Modify claude-wrapper** to always include the flag when claude-peers MCP is registered
2. **Modify env.template** to add a `CLAUDE_CHANNELS` variable and have wrapper read it
3. **Modify claude@.service** ExecStart to pass the flag

Recommended: Option 2 -- add `CLAUDE_CHANNELS=server:claude-peers` to env, have wrapper append `--dangerously-load-development-channels $CLAUDE_CHANNELS` when set.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| File-based IPC between Claude sessions | claude-peers-mcp with channel protocol | 2025-2026 | Instant message delivery, peer discovery, no custom IPC needed |
| `claude inject` for sending prompts to running sessions | Not yet available (issue #24947) | Blocked | Orchestra uses `send_message` via claude-peers instead |
| `--cwd` flag for setting working directory | Does not exist (closed as not-planned) | March 2026 | Must use `cd /path && claude -p` pattern |
| Channels via official plugins only | `--dangerously-load-development-channels` for dev servers | March 2026 (research preview) | claude-peers uses this for channel push notifications |

## Open Questions

1. **Channel authentication on headless VPS**
   - What we know: Channels require `claude.ai` login (OAuth), not just API key. `claude auth login` opens a browser.
   - What's unclear: Whether `claude auth login --console` or `claude setup-token` works for headless VPS (no browser). The user manages VPS from phone.
   - Recommendation: Test `claude auth login` flow on VPS. May need to copy auth token from a machine with browser, or use `--console` flag.

2. **claude-peers broker lifecycle**
   - What we know: Broker auto-launches on first session start, runs on localhost:7899, auto-cleans dead peers.
   - What's unclear: What happens if broker crashes? Does each MCP server re-launch it? Is there a systemd unit for the broker?
   - Recommendation: Accept auto-launch behavior for v2.0. If broker proves unreliable, add a simple systemd unit later.

3. **Wrapper modification for channel flag**
   - What we know: `--dangerously-load-development-channels server:claude-peers` must be passed to `claude` for instant message delivery.
   - What's unclear: Whether this flag works with `remote-control` mode simultaneously. The wrapper currently constructs mode_args separately.
   - Recommendation: Test flag combination. If incompatible, fall back to `check_messages` polling.

4. **Orchestra's own CLAUDE.md discovery**
   - What we know: `claude -p` discovers CLAUDE.md from working directory. Orchestra runs from `~/instruments/orchestra/`.
   - What's unclear: Whether orchestra's interactive `remote-control` session also picks up CLAUDE.md from WORKING_DIRECTORY.
   - Recommendation: Place orchestra's CLAUDE.md at `~/instruments/orchestra/CLAUDE.md`. The wrapper already `cd`s to WORKING_DIRECTORY before launching claude.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash test scripts (project convention from phases 7-8) |
| Config file | None -- tests are standalone bash scripts in `test/` |
| Quick run command | `bash test/test-orchestra.sh` |
| Full suite command | `for f in test/test-*.sh; do bash "$f"; done` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORCH-01 | Orchestra registered as instrument with CLAUDE.md | smoke | `bash test/test-orchestra.sh` (verify env file, CLAUDE.md, systemd unit) | No -- Wave 0 |
| ORCH-02 | One-shot dispatch via `claude -p` in instrument directory | integration (manual) | Manual -- requires live Claude session | N/A manual-only |
| ORCH-03 | Context reset via `claude-restart --instance` | unit | `bash test/test-restart.sh` (existing, covers --instance) | Yes (partial) |
| ORCH-04 | Dynamic instrument discovery | integration (manual) | Manual -- requires live claude-peers broker | N/A manual-only |
| ORCH-05 | Message routing to correct instrument | integration (manual) | Manual -- requires live claude-peers + multiple instruments | N/A manual-only |

**Note:** ORCH-02 through ORCH-05 are inherently integration tests requiring live Claude sessions and the claude-peers broker. They cannot be meaningfully unit tested because they depend on LLM behavior and network services. The testable units are: (1) orchestra env file generation, (2) CLAUDE.md file existence and content validation, (3) claude-peers MCP registration, (4) wrapper channel flag injection.

### Sampling Rate
- **Per task commit:** `bash test/test-orchestra.sh` (fast structural checks)
- **Per wave merge:** All `test/test-*.sh` scripts
- **Phase gate:** Manual integration test with live orchestra + 1 instrument

### Wave 0 Gaps
- [ ] `test/test-orchestra.sh` -- verify orchestra env file, CLAUDE.md placement, systemd unit registration
- [ ] `test/test-wrapper-channels.sh` -- verify wrapper correctly injects channel flags when CLAUDE_CHANNELS is set

## Sources

### Primary (HIGH confidence)
- [claude-peers-mcp GitHub](https://github.com/louislva/claude-peers-mcp) - Tool schemas, architecture, installation, broker behavior
- [claude-peers-mcp server.ts](https://raw.githubusercontent.com/louislva/claude-peers-mcp/main/server.ts) - Exact MCP tool definitions and input schemas
- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference) - All CLI flags including `-p`, `--dangerously-skip-permissions`, `--dangerously-load-development-channels`
- Existing codebase: `bin/claude-service`, `bin/claude-restart`, `bin/claude-wrapper`, `systemd/claude@.service`, `systemd/env.template`

### Secondary (MEDIUM confidence)
- [Claude Code headless docs](https://code.claude.com/docs/en/headless) - `claude -p` behavior, CLAUDE.md discovery, bare mode
- [Channels reference](https://code.claude.com/docs/en/channels-reference) - Channel protocol, development channels flag
- [--cwd feature request (closed)](https://github.com/anthropics/claude-code/issues/26287) - Confirmed `--cwd` does not exist

### Tertiary (LOW confidence)
- claude-peers broker reliability under sustained use (no production reports found)
- Channel protocol behavior with `remote-control` mode simultaneously (untested combination)
- `claude auth login` flow on headless VPS (unclear if browser-free path exists)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - claude-peers is the only option; tool schemas verified from source code
- Architecture: MEDIUM - Orchestra-as-instrument pattern is straightforward, but CLAUDE.md prompt engineering for reliable LLM supervision is novel territory
- Pitfalls: MEDIUM - Authentication and PATH issues are well-understood; LLM behavioral reliability pitfalls are based on reasoning, not empirical evidence

**Research date:** 2026-03-23
**Valid until:** 2026-04-15 (claude-peers is actively developed; channel protocol is research preview)
