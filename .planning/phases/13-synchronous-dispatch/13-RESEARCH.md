# Phase 13: Synchronous Dispatch - Research

**Researched:** 2026-03-27
**Domain:** Claude CLI dispatch patterns, shell parallelism, orchestra behavioral spec authoring
**Confidence:** HIGH

## Summary

Phase 13 replaces the peer-messaging orchestra CLAUDE.md with a fresh rewrite built on `claude -p` synchronous dispatch. The deliverable is a single file -- `orchestra/CLAUDE.md` -- that serves as the complete behavioral specification for the orchestra supervisor. No code changes to bin scripts are needed; the orchestra is pure prompt engineering.

The `claude -p` CLI is well-documented and stable. It supports `--continue` for multi-turn chaining, `--output-format json` for structured output with session IDs, and `--dangerously-skip-permissions` for autonomous operation. Shell backgrounding (`&`, `wait`) provides parallel dispatch. The main design challenge is crafting the CLAUDE.md to teach the orchestra how to dispatch, collect results, handle failures, and manage long-running tasks -- all through natural language instructions.

**Primary recommendation:** Full rewrite of `orchestra/CLAUDE.md` replacing all `list_peers`/`send_message`/`check_messages` patterns with `cd ~/instruments/<name> && claude -p "..." --dangerously-skip-permissions` dispatch patterns, using shell backgrounding for parallelism and `--continue` for multi-step GSD sequences.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Always use `--dangerously-skip-permissions` on all `claude -p` dispatches. Orchestra dispatches are autonomous by design, no human in the loop.
- **D-05:** No concurrency limit -- dispatch to all instruments freely. No artificial cap.
- **D-09:** Full rewrite from scratch -- do not incrementally edit the current peer-messaging CLAUDE.md. Start fresh with `claude -p` as the foundation.

### Claude's Discretion
- Error handling / retry strategy (D-02)
- Output format for `claude -p` results (D-03)
- Parallelism mechanism (D-04)
- Blocked instrument handling (D-06)
- Continuation strategy -- `--continue` vs fresh (D-07)
- Instrument state tracking approach (D-08)
- Fleet discovery method (D-10)
- Escalation format for phone reading (D-11)
- Example verbosity in CLAUDE.md (D-12)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DISP-01 | Orchestra dispatches GSD commands to instruments via `claude -p` with stdout captured synchronously | `claude -p` returns stdout synchronously; exit code indicates success/failure; `--output-format json` available for structured results |
| DISP-02 | Orchestra runs parallel `claude -p` across multiple instruments simultaneously (backgrounded) | Shell `&` backgrounding + `wait` collects PIDs; stdout captured via temp files or process substitution |
| DISP-03 | Orchestra uses `--continue` for multi-step GSD sequences within same instrument | `claude -c -p "next prompt"` continues most recent conversation in working directory; `--resume <session_id>` for explicit session targeting |
| DISP-04 | Orchestra handles long-running `claude -p` tasks without blocking other dispatch | Backgrounded processes run independently; orchestra checks completion via `wait -n` or polling; no blocking |
| ORCH-01 | Orchestra CLAUDE.md rewritten for `claude -p` dispatch (no send_message/check_messages) | Full rewrite from scratch (D-09); all peer-messaging patterns replaced with CLI dispatch |
| ORCH-02 | Orchestra parallel dispatch pattern documented with backgrounding and output collection | Shell backgrounding pattern with temp files for stdout capture; documented in CLAUDE.md |
| ORCH-03 | Orchestra escalation protocol preserved (user questions routed via remote-control) | Escalation format from current CLAUDE.md preserved; `[N/name]` tagged format for phone reading |
</phase_requirements>

## Standard Stack

This phase has no library dependencies. The deliverable is a single markdown file (`orchestra/CLAUDE.md`) that uses only:

### Core
| Tool | Purpose | Why Standard |
|------|---------|--------------|
| `claude -p` | Synchronous dispatch to instruments | Official CLI, replaces peer messaging entirely |
| `claude -c -p` | Continue conversation in same instrument context | Official CLI flag for multi-step sequences |
| `--dangerously-skip-permissions` | Autonomous operation without permission prompts | Required by D-01; standard for autonomous dispatch |
| `--output-format json` | Structured output with session_id for resume | Official CLI flag; enables `jq` parsing and session tracking |
| Shell backgrounding (`&` / `wait`) | Parallel dispatch across instruments | POSIX standard; no external dependencies |
| `claude-service list` | Fleet discovery | Already deployed in bin/claude-service |
| `claude-restart --instance <name>` | Context reset for instruments | Already deployed; proven in v2.0 |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `--resume <session_id>` | Resume specific session by ID | When multiple conversations active per instrument; more precise than `--continue` |
| `--max-turns` | Limit agent loop iterations | Safety net for runaway tasks |
| `--bare` | Skip hooks/plugins/MCP for faster cold start | Assessment one-shots that don't need full instrument context |
| `jq` | Parse JSON output from `claude -p` | Extract session_id, result text, error info from structured output |

## Architecture Patterns

### Deliverable Structure

The phase produces exactly one file:
```
orchestra/CLAUDE.md    # Complete behavioral spec (rewritten from scratch)
```

The `claude-service add-orchestra` command (in `bin/claude-service`) copies this file to `~/instruments/orchestra/CLAUDE.md` on deploy. No changes to `bin/claude-service` are needed -- the copy mechanism already works.

### Pattern 1: Synchronous Dispatch (replaces send_message)
**What:** Orchestra sends a GSD command to an instrument and captures the result synchronously.
**When to use:** Single-instrument dispatch, sequential operations.
**Example:**
```bash
# Source: https://code.claude.com/docs/en/headless
cd ~/instruments/blog && claude -p "/gsd:discuss-phase" --dangerously-skip-permissions
```
The output goes to stdout. Exit code 0 = success, non-zero = failure. The orchestra reads the output directly -- no polling, no message queues.

### Pattern 2: Parallel Dispatch (replaces send_message + check_messages polling)
**What:** Orchestra dispatches to multiple instruments simultaneously using shell backgrounding.
**When to use:** Driving multiple instruments through GSD steps at the same time.
**Example:**
```bash
# Dispatch to all instruments in parallel, capture output per-instrument
cd ~/instruments/blog && claude -p "/gsd:discuss-phase" --dangerously-skip-permissions > /tmp/orchestra-blog.out 2>&1 &
BLOG_PID=$!

cd ~/instruments/api && claude -p "/gsd:execute-phase" --dangerously-skip-permissions > /tmp/orchestra-api.out 2>&1 &
API_PID=$!

# Wait for all and collect results
wait $BLOG_PID; BLOG_EXIT=$?
wait $API_PID; API_EXIT=$?

# Read results
cat /tmp/orchestra-blog.out
cat /tmp/orchestra-api.out
```

### Pattern 3: Multi-Step Continuation (replaces sequential send_message)
**What:** Chain multiple GSD commands in the same instrument conversation context.
**When to use:** discuss -> plan -> execute sequence where conversation context helps.
**Example:**
```bash
# Source: https://code.claude.com/docs/en/headless
# Step 1: discuss
cd ~/instruments/blog && claude -p "/gsd:discuss-phase" --dangerously-skip-permissions

# Step 2: plan (continues the discuss conversation)
cd ~/instruments/blog && claude -c -p "/gsd:plan-phase" --dangerously-skip-permissions

# Step 3: execute (continues the plan conversation)
cd ~/instruments/blog && claude -c -p "/gsd:execute-phase" --dangerously-skip-permissions
```

**Key insight:** `--continue` resumes the most recent conversation in the working directory. Since each instrument has its own directory, `--continue` naturally targets the right conversation. No session ID tracking needed for simple sequential flows.

### Pattern 4: Session ID Tracking (precise continuation)
**What:** Capture session ID from JSON output for explicit resume targeting.
**When to use:** When running multiple concurrent conversations per instrument, or when you need guaranteed session targeting.
**Example:**
```bash
# Source: https://code.claude.com/docs/en/headless
SESSION=$(cd ~/instruments/blog && claude -p "/gsd:discuss-phase" --dangerously-skip-permissions --output-format json | jq -r '.session_id')

# Resume that exact session
cd ~/instruments/blog && claude -p "/gsd:plan-phase" --dangerously-skip-permissions --resume "$SESSION"
```

### Pattern 5: Assessment One-Shot (preserved from current CLAUDE.md)
**What:** Spawn a temporary Claude session to read instrument state without consuming orchestra context.
**When to use:** Before dispatching GSD commands, to check instrument phase/status.
**Example:**
```bash
cd ~/instruments/blog && claude -p "Read .planning/STATE.md. What is the current phase and next step?" --dangerously-skip-permissions
```
This pattern already exists in the current CLAUDE.md and carries forward unchanged.

### Anti-Patterns to Avoid
- **Using `--cwd`:** This flag does not exist. Always use `cd ~/instruments/<name> && claude -p "..."`.
- **Forgetting `--dangerously-skip-permissions`:** Without it, `claude -p` will hang waiting for permission prompts in headless mode.
- **Using `--continue` across instruments:** `--continue` resumes the most recent conversation in the current directory. It is directory-scoped. Running `cd ~/instruments/api && claude -c -p "..."` will NOT continue a blog conversation.
- **Polling for results:** With synchronous dispatch there is nothing to poll. The command blocks until complete and returns output. This is the entire point of replacing peer messaging.
- **Using `--bare` for GSD commands:** GSD skills live in `~/.claude/` and require hooks/skills loading. `--bare` skips all of that. Only use `--bare` for simple assessment one-shots that don't need GSD.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fleet discovery | Custom instrument scanning | `claude-service list` | Already built, returns instrument names + systemd status |
| Context reset | Custom kill/restart logic | `claude-restart --instance <name>` | Already built, handles PPID chain walk and restart file |
| Structured output parsing | Regex on raw text | `--output-format json` + `jq` | Official format includes session_id, result, cost, error metadata |
| Session continuation | Custom state files tracking conversation IDs | `--continue` / `--resume` | Built into CLI, directory-scoped, zero configuration |
| Permission handling | Interactive prompts | `--dangerously-skip-permissions` | Required for autonomous dispatch (D-01) |

**Key insight:** The entire dispatch mechanism is built into the `claude` CLI. The orchestra CLAUDE.md is purely behavioral instructions teaching the orchestra LLM which patterns to use and when. No new code or scripts are needed.

## Common Pitfalls

### Pitfall 1: Cold Start Latency
**What goes wrong:** `claude -p` takes ~10 seconds to cold-start (noted in STATE.md blockers). Multiple parallel dispatches all hit this at once.
**Why it happens:** Each `claude -p` invocation loads the model, parses CLAUDE.md, initializes tools. There's no persistent process.
**How to avoid:** Accept the latency. It's inherent to fresh-context dispatch. The 10s startup is amortized across the minutes a GSD step actually takes. Do NOT try to keep sessions alive to avoid cold start -- this contradicts the fresh-context-by-default architecture.
**Warning signs:** Orchestra documentation suggesting "keep sessions warm" or "reuse connections" -- these are anti-patterns.

### Pitfall 2: --continue in Parallel Dispatch
**What goes wrong:** If orchestra dispatches to the same instrument directory from two parallel processes, `--continue` in the second process might continue the wrong conversation.
**Why it happens:** `--continue` resumes the "most recent" conversation in the directory. If two conversations are active, "most recent" is ambiguous.
**How to avoid:** For parallel dispatch to the SAME instrument (rare), use `--resume <session_id>` with explicit session tracking. For parallel dispatch to DIFFERENT instruments (the normal case), `--continue` is fine because each has its own directory.
**Warning signs:** Multiple backgrounded `claude -p` calls targeting the same instrument directory.

### Pitfall 3: Stdout Capture in Background Processes
**What goes wrong:** Backgrounded `claude -p &` output gets interleaved or lost.
**Why it happens:** Multiple background processes writing to the same stdout.
**How to avoid:** Redirect each background process to a temp file: `> /tmp/orchestra-<name>.out 2>&1 &`. Read files after `wait`.
**Warning signs:** Garbled output, missing results, or output from one instrument appearing in another's capture.

### Pitfall 4: Exit Code Handling
**What goes wrong:** Orchestra treats any `claude -p` exit as success, or doesn't differentiate failure modes.
**Why it happens:** `claude -p` returns non-zero on various failures (API errors, permission denials, model refusals, tool errors).
**How to avoid:** Check exit code after `wait $PID; EXIT=$?`. Decide retry vs escalation based on exit code and output content.
**Warning signs:** Orchestra blindly proceeding after failed dispatches.

### Pitfall 5: GSD Skills Not Available in --bare Mode
**What goes wrong:** `claude --bare -p "/gsd:discuss-phase"` fails because `--bare` skips skill loading.
**Why it happens:** `--bare` skips hooks, skills, plugins, MCP servers, auto memory, and CLAUDE.md. GSD commands are skills in `~/.claude/get-shit-done/`.
**How to avoid:** Do NOT use `--bare` for GSD command dispatch. Only use it for simple assessment queries that need raw file reading. Standard `claude -p` (without `--bare`) loads skills from `~/.claude/`.
**Warning signs:** "Unknown command" or "skill not found" errors from instruments.

### Pitfall 6: CLAUDE.md Not Loaded in Fresh Dispatch
**What goes wrong:** Assessment one-shots dispatched to an instrument directory don't pick up the instrument's CLAUDE.md project context.
**Why it happens:** `claude -p` (without `--bare`) DOES load CLAUDE.md from the working directory. This is actually fine. The pitfall is using `--bare` and losing it, or running from the wrong directory.
**How to avoid:** Always `cd ~/instruments/<name>` before `claude -p`. Never use `--bare` for dispatches that need project context.
**Warning signs:** Instrument responses that seem unaware of their project.

## Code Examples

### Complete Dispatch Pattern (recommended for CLAUDE.md)
```bash
# Source: https://code.claude.com/docs/en/headless + project patterns
# Single instrument dispatch with error handling
RESULT=$(cd ~/instruments/blog && claude -p "/gsd:discuss-phase" --dangerously-skip-permissions 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Dispatch to blog failed (exit $EXIT_CODE): $RESULT"
    # Decide: retry, escalate, or skip
fi
```

### Parallel Dispatch with Collection
```bash
# Dispatch to all instruments in parallel
for name in blog api docs; do
    cd ~/instruments/$name && claude -p "/gsd:execute-phase" --dangerously-skip-permissions > /tmp/orchestra-${name}.out 2>&1 &
    eval "${name}_PID=$!"
done

# Wait for all to complete
for name in blog api docs; do
    eval "wait \$${name}_PID"
    echo "=== $name (exit $?) ==="
    cat /tmp/orchestra-${name}.out
done
```

### Multi-Step GSD Sequence with Continuation
```bash
# Source: https://code.claude.com/docs/en/headless
# discuss -> plan -> execute in same conversation
cd ~/instruments/blog

claude -p "/gsd:discuss-phase" --dangerously-skip-permissions
claude -c -p "/gsd:plan-phase" --dangerously-skip-permissions
claude -c -p "/gsd:execute-phase" --dangerously-skip-permissions
```

### JSON Output with Session Tracking
```bash
# Source: https://code.claude.com/docs/en/headless
OUTPUT=$(cd ~/instruments/blog && claude -p "/gsd:discuss-phase" --dangerously-skip-permissions --output-format json)
SESSION_ID=$(echo "$OUTPUT" | jq -r '.session_id')
RESULT=$(echo "$OUTPUT" | jq -r '.result')

# Later: resume this exact session
cd ~/instruments/blog && claude -p "/gsd:plan-phase" --dangerously-skip-permissions --resume "$SESSION_ID"
```

## State of the Art

| Old Approach (v2.0) | New Approach (v3.0) | Impact |
|---------------------|---------------------|--------|
| `list_peers(scope: "machine")` for discovery | `claude-service list` for fleet status | No peer registration needed; works even when instruments are stopped |
| `send_message(to_id, "/gsd:...")` for dispatch | `cd ~/instruments/<name> && claude -p "/gsd:..." --dangerously-skip-permissions` | Synchronous, stdout captured, no polling needed |
| `check_messages()` polling for responses | Direct stdout capture from `claude -p` | Immediate result, no lost messages, no timing issues |
| Peer ID discovery + matching by working_directory | Instrument name = directory name = service name | Stable identity, no ephemeral IDs |
| `claude-restart` + poll `list_peers` for re-registration | `claude-restart` still works; no poll needed since dispatch is one-shot | Simpler lifecycle |
| Internal working memory for state tracking | Can read `.planning/STATE.md` via assessment agents OR track internally | Both options available; STATE.md is source of truth |

**Deprecated/removed:**
- `list_peers()` MCP tool: removed in Phase 12
- `send_message()` MCP tool: removed in Phase 12
- `check_messages()` MCP tool: removed in Phase 12
- `set_summary()` MCP tool: removed in Phase 12
- `CLAUDE_CHANNELS` env var: removed in Phase 12
- `bin/message-watcher`: deleted in Phase 12

## CLAUDE.md Rewrite Structure (Recommended)

The new `orchestra/CLAUDE.md` should follow this structure, preserving the organizational patterns from the current version while replacing all mechanics:

```
# Orchestra - Autonomous Supervisor
  [Role description -- preserved from current]

## Dispatch Mechanics
  [NEW: claude -p patterns, cd-then-dispatch, --dangerously-skip-permissions]

## Parallel Dispatch
  [NEW: shell backgrounding, temp file capture, wait collection]

## Multi-Step Sequences
  [NEW: --continue for chained GSD steps, when to use fresh vs continue]

## Fleet Discovery
  [NEW: claude-service list, or direct directory listing]

## Assessment Agents
  [PRESERVED: one-shot claude -p for reading instrument state]

## GSD Workflow Sequence
  [REWRITTEN: same logical flow, new dispatch mechanics]

## Context Reset
  [PRESERVED: claude-restart --instance <name>, no polling needed]

## User Escalation Protocol
  [PRESERVED: [N/name] tagged format, phone-friendly]

## Internal State Tracking
  [PRESERVED or EVOLVED: track instrument name, phase, GSD step, status]

## Anti-Patterns
  [REWRITTEN: no --cwd, no --bare for GSD, no polling, etc.]

## Startup Sequence
  [REWRITTEN: assess instruments via one-shot agents, begin parallel dispatch]
```

## Open Questions

1. **Output format preference: text vs JSON**
   - What we know: `--output-format json` gives structured data with session_id. Plain text is simpler to read but harder to parse.
   - What's unclear: Whether orchestra (an LLM) benefits more from structured JSON or human-readable text output.
   - Recommendation: Use plain text (`--output-format text`, the default) for GSD dispatches since the orchestra LLM reads the output naturally. Use `--output-format json` only when session_id tracking is explicitly needed for `--resume`.

2. **State tracking: internal memory vs STATE.md reads**
   - What we know: Current CLAUDE.md says "track in working memory." But orchestra context resets lose this.
   - What's unclear: How often orchestra context resets actually happen. If rare, working memory is fine.
   - Recommendation: Hybrid -- track in working memory during a session, but always re-assess via one-shot agents on startup. STATE.md is the source of truth for recovery.

3. **When to use --continue vs fresh dispatch**
   - What we know: `--continue` preserves conversation context. Fresh dispatch gives clean slate. GSD state lives in `.planning/` files, not conversation context.
   - What's unclear: Whether discussion context actually helps planning, or whether fresh context is always better.
   - Recommendation: Use `--continue` only within a single GSD step when the step requires multi-turn interaction (e.g., a large execute-phase). Use fresh dispatch between GSD steps (discuss, plan, execute) since each step reads its own `.planning/` context files.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash test scripts (custom assertion pattern) |
| Config file | none -- tests are standalone bash scripts |
| Quick run command | `bash test/test-orchestra.sh` |
| Full suite command | `for t in test/test-*.sh; do bash "$t"; done` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DISP-01 | claude -p dispatch pattern in CLAUDE.md | content verification | `grep -q 'claude -p' orchestra/CLAUDE.md` | Wave 0 |
| DISP-02 | Parallel dispatch documented | content verification | `grep -q 'background\|parallel\|&' orchestra/CLAUDE.md` | Wave 0 |
| DISP-03 | --continue usage documented | content verification | `grep -q '\-\-continue\|-c' orchestra/CLAUDE.md` | Wave 0 |
| DISP-04 | Long-running task handling documented | content verification | `grep -qi 'long.running\|background\|wait' orchestra/CLAUDE.md` | Wave 0 |
| ORCH-01 | No peer messaging references | negative verification | `! grep -q 'send_message\|check_messages\|list_peers' orchestra/CLAUDE.md` | Wave 0 |
| ORCH-02 | Parallel dispatch pattern present | content verification | `grep -q 'parallel' orchestra/CLAUDE.md` | Wave 0 |
| ORCH-03 | Escalation protocol present | content verification | `grep -q 'escalat' orchestra/CLAUDE.md` | Wave 0 |

### Sampling Rate
- **Per task commit:** `bash test/test-orchestra.sh`
- **Per wave merge:** Full test suite
- **Phase gate:** All tests green + manual CLAUDE.md content review

### Wave 0 Gaps
- [ ] Update `test/test-orchestra.sh` to verify new CLAUDE.md content (replace peer-messaging assertions with dispatch pattern assertions)
- No new test framework needed -- existing bash assertion pattern works

## Sources

### Primary (HIGH confidence)
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) -- Full flag documentation for -p, --continue, --resume, --output-format, --dangerously-skip-permissions, --bare
- [Claude Code Headless/SDK Docs](https://code.claude.com/docs/en/headless) -- Patterns for continuation, parallel execution, structured output, session ID tracking
- `orchestra/CLAUDE.md` (current) -- Existing behavioral spec being replaced; structural reference
- `bin/claude-service` -- Fleet discovery implementation (list subcommand)

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` -- Blockers noting cold-start latency and long-running task concerns
- `.planning/PROJECT.md` -- Architecture decisions table confirming `claude -p` replaces peer messaging

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- `claude -p` CLI is well-documented with official examples
- Architecture: HIGH -- Patterns verified against official docs; deliverable is a single CLAUDE.md file
- Pitfalls: HIGH -- Known issues (cold start, --bare skipping skills, --continue scoping) verified against docs

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable -- CLI flags are well-established)
