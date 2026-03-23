# Pitfalls Research

**Domain:** Multi-instance orchestration -- systemd template units, remote-control session management, orchestra coordination for bash-based Claude Code management
**Researched:** 2026-03-22
**Confidence:** HIGH (systemd template unit pitfalls verified via official docs; Claude Code remote-control verified via official docs; memory/rate limit issues verified via multiple GitHub issues and official documentation)

**Scope:** This document covers pitfalls specific to adding multi-instance management and autonomous orchestration on top of the existing v1.1 single-instance infrastructure. For v1.1-era pitfalls (double-restart loop, SIGTERM forwarding, tmux/systemd conflicts, etc.), see git history of this file.

---

## Critical Pitfalls

### Pitfall 1: Shared Restart File -- All Instruments Write to the Same `~/.claude-restart`

**What goes wrong:**
The existing `claude-restart` script writes to a single hardcoded path (`$HOME/.claude-restart`), and `claude-wrapper` reads from that same path. When multiple instruments run simultaneously, any instrument's restart signal clobbers or is consumed by the wrong instrument. Instrument A writes its restart file, but Instrument B's wrapper loop checks and consumes it first. Instrument B restarts with Instrument A's args. Instrument A never restarts at all.

**Why it happens:**
The v1.0 design assumed a single instance. The `CLAUDE_RESTART_FILE` env var exists for testing override but is not wired into any per-instance dispatch. When moving to multi-instance, the natural first step is "just run N copies of the same service" without addressing shared mutable state.

**How to avoid:**
Each instrument must use an instance-specific restart file. The path should be derived from the instance name:
```bash
CLAUDE_RESTART_FILE="$HOME/.claude-restart-${INSTANCE_NAME}"
```
Set `CLAUDE_RESTART_FILE` in the per-instance environment file (see Pitfall 3). The `claude-restart` script must also accept an instance identifier to target the correct file. Both `claude-wrapper` and `claude-restart` already respect `$CLAUDE_RESTART_FILE` -- the fix is ensuring it is always set per-instance in the systemd environment.

**Warning signs:**
- Instruments restarting with wrong CLI args (args from a different project)
- One instrument restarting while another ignores its restart signal
- Restart file appearing/disappearing without the expected instrument responding

**Phase to address:**
Phase: Template unit setup -- must be the first thing addressed because every subsequent feature (orchestrated restart, watchdog per-instance) depends on isolated restart files.

---

### Pitfall 2: systemd Template Unit Specifier Escaping -- `%i` Breaks with Paths and Special Characters

**What goes wrong:**
systemd template units (`claude@.service`) use `%i` to inject the instance name. If the instance name contains slashes (common if using project paths as identifiers like `home-user-projects-myapp`), dashes, or other special characters, the specifier expands incorrectly. Specifically:
- `%i` gives the raw (escaped) instance string where `/` is encoded as `-`
- `%I` gives the unescaped instance string
- Using the wrong one in `WorkingDirectory=%I` vs `EnvironmentFile=.../%i/env` produces mismatched paths
- Instance names with literal dashes are ambiguous: is `my-project` an escaped path `/my/project` or a literal name `my-project`?

**Why it happens:**
systemd's escaping rules are non-obvious. Developers use `%i` everywhere without understanding that `-` in instance names is ambiguous with escaped `/`. The `systemd-escape` tool exists but is rarely used in practice.

**How to avoid:**
Use simple, flat instance names with no dashes or slashes -- e.g., `projectA`, `webapp`, `telebot`. Map instance name to working directory and config via the per-instance environment file, not via specifier path construction:
```ini
# claude@.service -- template
[Service]
EnvironmentFile=%h/.config/claude-restart/%i.env
ExecStart=%h/.local/bin/claude-wrapper --dangerously-skip-permissions
# WorkingDirectory comes from the env file via a wrapper, NOT from %I
```
The per-instance env file (`projectA.env`) contains `WORKING_DIR=/home/user/projects/myapp`. The wrapper `cd`s to `$WORKING_DIR` before launching claude. This avoids all specifier escaping entirely.

**Warning signs:**
- `systemctl start claude@my-project` starts but working directory is wrong
- `journalctl` shows "Failed to determine working directory" or path-not-found
- Instance names with dashes behave differently from names without dashes

**Phase to address:**
Phase: Template unit setup -- naming convention and env file structure must be locked down before any instruments are added.

---

### Pitfall 3: Per-Instance Environment Files -- Overriding vs Layering Confusion

**What goes wrong:**
The v1.1 system uses a single `~/.config/claude-restart/env` file shared by the service, watchdog, and wrapper. With template units, each instance needs its own env file (different `WORKING_DIR`, potentially different `CLAUDE_CONNECT` mode, different `CLAUDE_RESTART_FILE`). Two failure modes:
1. **All instances share the same env file** -- every instrument runs in the same directory with the same restart file (see Pitfall 1).
2. **Per-instance env files miss shared variables** -- e.g., `ANTHROPIC_API_KEY` or `PATH` is only in the global file, not the instance file, and the template only loads the instance file.

systemd's `EnvironmentFile=` does not "merge" files intuitively. The last `EnvironmentFile=` wins for duplicate variables, but if a variable is only in one file it appears regardless. However, if you want to override a global setting per-instance, the ordering of `EnvironmentFile=` directives matters and is easy to get wrong.

**Why it happens:**
Developers either copy the entire env file per instance (maintenance nightmare -- change the API key in one place, forget the others) or try to layer a global + instance file without understanding systemd's variable precedence (later `EnvironmentFile=` overrides earlier ones for the same variable).

**How to avoid:**
Use two `EnvironmentFile=` directives in the template unit -- global first, instance second:
```ini
[Service]
EnvironmentFile=%h/.config/claude-restart/env
EnvironmentFile=%h/.config/claude-restart/%i.env
```
Global `env` contains: `ANTHROPIC_API_KEY`, `PATH`, `CLAUDE_CONNECT` (default mode).
Instance `%i.env` contains: `WORKING_DIR`, `CLAUDE_RESTART_FILE`, and optionally overrides like `CLAUDE_CONNECT` if this instance uses a different mode.

The instance file overrides the global file for any variable present in both. Shared settings remain in one place.

**Warning signs:**
- API key change requires editing N files
- New instance starts but fails because `PATH` is missing (not in instance env file)
- Instance meant to be in telegram mode starts in remote-control mode (or vice versa)

**Phase to address:**
Phase: Template unit setup -- env file layering strategy must be defined alongside the template unit.

---

### Pitfall 4: Orchestra Context Bleed -- Sending Wrong Instructions to Wrong Instrument

**What goes wrong:**
The orchestra session manages multiple instruments. When dispatching work, it must send the right message to the right instrument. If the orchestra tracks instruments by index, name, or session ID, any confusion in this mapping results in: research instructions sent to the webapp instrument, deployment commands sent to the research instrument, or the same instruction sent twice. In the worst case, an instrument receives a prompt meant for another project and executes destructive operations (file deletion, git operations) in the wrong repository.

**Why it happens:**
The orchestra is itself a Claude Code session with a context window. As the conversation grows, earlier instrument assignments may scroll out of context. If instruments are referenced by position ("instrument 1", "instrument 2") rather than by stable identifiers, a restarted orchestra that lost context can misroute. Additionally, Claude's tool-use can hallucinate parameters -- if the routing mechanism uses string-based identifiers, a typo in the instrument name silently routes to nowhere (or the wrong place).

**How to avoid:**
1. **Stable, human-readable instrument names** tied to project directories (e.g., `webapp`, `api`, `docs`), not indices or UUIDs.
2. **Validation at the routing layer**: the dispatch mechanism must reject unknown instrument names rather than silently failing.
3. **Orchestra system prompt includes current instrument roster** -- the instrument list must be in the system prompt or CLAUDE.md, not just in conversation history that can scroll out.
4. **Instrument isolation by design**: each instrument runs in its own directory with its own systemd unit. Even if the orchestra misroutes, the instrument can only affect files in its own `WorkingDirectory`.
5. **Stateless dispatch**: each orchestra instruction to an instrument should be self-contained (include project name, task, expected behavior) rather than relying on prior conversation context in the instrument.

**Warning signs:**
- Instrument working on a task that belongs to a different project
- Orchestra logs showing "sent to instrumentX" but instrumentX's logs show a different task
- After orchestra restart, instruments receive duplicate or contradictory instructions

**Phase to address:**
Phase: Orchestra implementation -- routing validation and instrument roster management must be core to the orchestra design.

---

### Pitfall 5: Claude Code Memory Leak Multiplied by N Instances

**What goes wrong:**
Claude Code has a well-documented memory leak (GitHub issues #4953, #18011, #22188, #21403) where Node.js processes grow to 15-120GB over extended sessions. With a single instance, this eventually triggers OOM kill and systemd restarts it. With N instances, memory pressure arrives N times faster. On a typical VPS with 4-16GB RAM, running 3+ Claude Code instances means the OOM killer fires frequently, potentially killing the wrong instance (the one doing important work, not the idle one). systemd-oomd may kill entire cgroups, taking down multiple instruments at once.

**Why it happens:**
The memory leak is in Claude Code's Node.js runtime and is not fixed as of March 2026. Each instance is an independent Node.js process. VPS RAM is finite and often modest (4-8GB for personal VPS). Developers add instances without accounting for the multiplicative memory impact.

**How to avoid:**
1. **MemoryMax= in systemd unit**: set a per-instance memory ceiling so one runaway instance cannot starve others:
   ```ini
   [Service]
   MemoryMax=4G
   MemoryHigh=3G
   ```
   `MemoryHigh` triggers kernel memory reclaim pressure before the hard `MemoryMax` kill. Tune based on VPS total RAM / max instances.
2. **Periodic restart via watchdog timer per instance**: the existing watchdog concept (forced restart every N hours) is the best mitigation for the memory leak. Each instance needs its own timer (see Pitfall 6).
3. **Limit concurrent active instances**: not all instruments need to run 24/7. The orchestra can start/stop instruments on demand. Idle instruments should be stopped, not just sitting there leaking memory.
4. **Monitor memory per-instance**: `systemctl status claude@instrumentA` shows memory via cgroup accounting. Build this into the `claude-service` helper.

**Warning signs:**
- VPS swap usage climbing rapidly (check `free -h`)
- OOM kill messages in `dmesg` or `journalctl -k`
- Instruments restarting more frequently than the watchdog interval suggests
- VPS becoming unresponsive to SSH

**Phase to address:**
Phase: Template unit setup -- `MemoryMax`/`MemoryHigh` must be in the template unit from day one. Watchdog timer association addressed in a separate phase.

---

### Pitfall 6: Watchdog Timer Not Associated Per-Instance

**What goes wrong:**
The v1.1 watchdog uses `claude-watchdog.timer` and `claude-watchdog.service` as singleton units. They restart `claude.service`. With template units, there is no `claude.service` -- there is `claude@projectA.service`, `claude@projectB.service`, etc. The singleton watchdog either:
1. Tries to restart `claude.service` which no longer exists -- silently fails
2. Is duplicated manually per instance without using template units for the watchdog itself
3. Restarts only one hardcoded instance

**Why it happens:**
The watchdog was designed for single-instance. Converting the main service to a template but forgetting the watchdog timer creates a mismatch. systemd timers and their associated service units must be templated together.

**How to avoid:**
Create template watchdog units that mirror the main service:
```
claude-watchdog@.timer   -> triggers claude-watchdog@%i.service
claude-watchdog@%i.service -> restarts claude@%i.service
```
The lifecycle tooling (`claude-service add <name>`) must enable both `claude@name.service` and `claude-watchdog@name.timer` together. The remove command must disable both.

**Warning signs:**
- `systemctl --user list-timers` shows no watchdog timers, or only one for a nonexistent unit
- Watchdog logs reference `claude.service` instead of `claude@<instance>.service`
- Some instances get watchdog restarts, others do not

**Phase to address:**
Phase: Watchdog migration -- immediately after template units are working, the watchdog must be templated to match.

---

### Pitfall 7: Race Condition -- Instrument Added While Orchestra Is Mid-Operation

**What goes wrong:**
The orchestra discovers instruments dynamically (e.g., by listing `systemctl --user list-units 'claude@*'`). If a new instrument is added (`claude-service add newproject`) while the orchestra is mid-dispatch or mid-status-check, the orchestra's instrument list becomes stale. Three failure modes:
1. New instrument exists but orchestra doesn't know about it -- work is never dispatched to it
2. Orchestra caches a stale list and later references a removed instrument -- dispatch fails
3. Orchestra is iterating over instruments and the list changes mid-iteration -- inconsistent state

**Why it happens:**
Dynamic discovery and mutable state are inherently racy. The orchestra has a context window, not a live database. Its knowledge of instruments comes from tool calls (listing units, checking status) that return point-in-time snapshots.

**How to avoid:**
1. **Refresh-before-act pattern**: the orchestra should re-discover instruments at the start of each dispatch cycle, not cache from a previous cycle.
2. **Idempotent dispatch**: if the orchestra sends work to a stopped/removed instrument, the mechanism should return a clear error ("instrument not found") rather than silently queuing.
3. **Roster file or directory**: maintain a simple text file or directory (`~/.config/claude-restart/instruments/`) that lists active instruments. The lifecycle tooling updates this atomically. The orchestra reads it fresh each cycle.
4. **Accept eventual consistency**: the orchestra does not need real-time awareness. A few seconds of staleness is acceptable. Design for "instrument might not exist when I try to reach it" rather than "instrument list is always perfect."

**Warning signs:**
- Orchestra reports "dispatched to instrumentX" but instrumentX was just removed
- New instrument sits idle for an entire orchestra cycle before being discovered
- Orchestra error logs showing "failed to connect to instrument" after a removal

**Phase to address:**
Phase: Dynamic discovery -- separate phase from template unit setup. The orchestra's instrument awareness mechanism must be designed with staleness tolerance.

---

### Pitfall 8: API Rate Limits Shared Across All Instances

**What goes wrong:**
All Claude Code instances sharing the same `ANTHROPIC_API_KEY` share the same rate limit pool. Anthropic enforces RPM (requests per minute), TPM (tokens per minute), and daily token quotas. Three active instruments each consuming 50K-150K tokens per interaction can easily exceed TPM limits. The rate limit error is returned to whichever instance happens to make the next request -- which may be the most important task, not the least important one.

**Why it happens:**
Rate limits are per-API-key, not per-process. Developers think of each instance as independent, but Anthropic sees them as one customer. A single heavy interaction (large codebase context) from one instrument can consume the entire minute's token budget.

**How to avoid:**
1. **Limit concurrent active instruments**: if using a Pro/Max subscription plan, the rate limit is generous for 1-2 active instances but tight for 3+. The orchestra should serialize heavy operations rather than parallelizing across all instruments.
2. **Stagger instrument activity**: the orchestra should not dispatch work to all instruments simultaneously. Introduce a brief delay (30-60s) between dispatches to avoid burst rate limit hits.
3. **Handle rate limit errors gracefully**: instruments must not crash on 429 responses. Claude Code should retry automatically, but if it doesn't, the wrapper should treat a rate-limit exit as a "retry after delay" scenario, not a crash.
4. **Monitor token usage**: track which instruments consume the most tokens. Consider `CLAUDE_CODE_MAX_TOKENS` or similar constraints if available.

**Warning signs:**
- "Rate limit reached" errors appearing in one instrument's logs when another instrument is doing heavy work
- Instruments taking much longer than expected (waiting on rate limit retry)
- All instruments simultaneously pausing for 60 seconds (minute-window rate limit reset)

**Phase to address:**
Phase: Orchestra implementation -- the orchestra's dispatch strategy must account for shared rate limits.

---

### Pitfall 9: remote-control Session Identity Confusion -- Connecting to Wrong Instance from Phone

**What goes wrong:**
Each instrument runs `claude remote-control` and registers a session. On claude.ai/code or the mobile app, the user sees N sessions listed. If sessions have default names (working directory basename), multiple instruments in similarly-named directories produce indistinguishable session entries. The user connects to the wrong instrument and sends instructions meant for a different project.

**Why it happens:**
remote-control session names default to the working directory or first prompt. Without explicit `--name` flags, sessions are hard to distinguish. The mobile interface is small and does not show full paths.

**How to avoid:**
1. **Mandatory `--name` flag per instance**: the lifecycle tooling must set `--name` when starting remote-control mode. Use the instrument name as the session name:
   ```bash
   claude remote-control --name "instrument: webapp"
   ```
2. **Naming convention**: prefix all session names with `instrument:` so they are visually distinct from ad-hoc sessions.
3. **Document in the orchestra's context**: the orchestra should know each instrument's session name and communicate it when directing the user to interact directly with an instrument.

**Warning signs:**
- User reports "I was talking to the wrong Claude"
- Session list on mobile shows multiple entries with the same name
- Instrument receives instructions clearly meant for a different project

**Phase to address:**
Phase: Template unit setup -- the `--name` flag must be wired into the service unit or wrapper from the start.

---

### Pitfall 10: `daemon-reload` Race During Dynamic Instrument Add/Remove

**What goes wrong:**
When the lifecycle tooling adds a new instrument, it must run `systemctl --user daemon-reload` for systemd to recognize the new instance's env file changes or drop-in overrides. If another operation (starting, stopping, or restarting an existing instrument) is in progress during the reload, systemd can lose track of the in-flight operation. The documented race condition between `systemctl start` and `systemctl daemon-reload` (systemd issue #5328) can leave a service in an inconsistent state.

**Why it happens:**
`daemon-reload` is a global operation that re-reads all unit files. It is not scoped to a single unit. Running it while other operations are in flight is inherently racy. The lifecycle tooling (`claude-service add`) naturally wants to reload immediately after writing the env file.

**How to avoid:**
1. **Serialize lifecycle operations**: the `claude-service` helper should use a lockfile (`flock`) to ensure only one add/remove/reload operation runs at a time.
2. **Reload once, not per-operation**: if adding multiple instruments in sequence, batch the `daemon-reload` at the end rather than after each add.
3. **Check service state after reload**: after `daemon-reload`, verify the target service is in the expected state before proceeding.
4. **Template units don't need reload for new instances**: a key systemd behavior -- if the template unit file itself hasn't changed, you do NOT need `daemon-reload` to start a new instance. `systemctl start claude@newproject` works immediately if `claude@.service` is already loaded. You only need `daemon-reload` if you changed the template file or added drop-in overrides.

**Warning signs:**
- `systemctl start claude@newproject` hangs or times out immediately after `daemon-reload`
- Service shows "activating" state indefinitely after a reload
- Concurrent add operations produce "Unit not found" errors intermittently

**Phase to address:**
Phase: Lifecycle tooling -- the add/remove commands must handle serialization and avoid unnecessary reloads.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Shared env file for all instances | One file to maintain | All instances use same working dir and restart file; completely broken multi-instance | Never |
| Using project paths as instance names | No name mapping needed | Escaped path names (`home-user-projects-myapp`) are fragile and ambiguous | Never -- use simple names |
| Hardcoded instance list in orchestra prompt | Works for initial 2-3 instruments | Must edit system prompt for every add/remove; easily stale | Only for initial MVP with static instrument count |
| Single global watchdog for all instances | Simpler setup | Some instances get watchdog, others don't; restart targets wrong unit | Never -- template the watchdog from the start |
| No MemoryMax in service units | Avoid premature optimization | One leaky instance OOM-kills the entire VPS, taking down all instruments | Never -- VPS has finite RAM; set limits from day one |
| Orchestra polls `systemctl list-units` every message | Always fresh data | Slow (100-500ms per call), wastes context tokens on tool-use overhead | Acceptable for MVP; cache with refresh-on-dispatch later |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Template unit + restart file | All instances share `~/.claude-restart` | Set `CLAUDE_RESTART_FILE` per-instance in env file |
| Template unit + EnvironmentFile | Single env file or duplicated env files | Two `EnvironmentFile=` directives: global + per-instance |
| Template unit + watchdog timer | Singleton watchdog targets nonexistent `claude.service` | Template the watchdog: `claude-watchdog@.timer` + `claude-watchdog@.service` |
| Template unit + WorkingDirectory | Using `%I` specifier with escaped paths | Store `WORKING_DIR` in per-instance env file; wrapper `cd`s to it |
| remote-control + multi-instance | All sessions have default names, indistinguishable on mobile | Use `--name "instrument: <name>"` per instance |
| Orchestra + instrument dispatch | String-based routing with no validation | Reject unknown instrument names; refresh roster before each dispatch |
| Lifecycle tooling + daemon-reload | Reload after every add/remove | Template units don't need reload for new instances; only reload on template file changes |
| Orchestra + rate limits | Parallel dispatch to all instruments | Stagger dispatches; serialize heavy operations |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| N instances x memory leak = N x 4-15GB | VPS swap thrashing, SSH unresponsive, OOM kills | `MemoryMax=` per instance, periodic watchdog restart | At 2-3 instances on an 8GB VPS |
| Concurrent API requests from all instances | Rate limit errors (429), all instances paused | Orchestra staggers dispatch; limit concurrent active instances | At 3+ active instances on same API key |
| Orchestra refreshing instrument list on every message | Each refresh is a tool call consuming tokens + latency | Cache roster, refresh on dispatch cycle start only | When orchestra conversation grows long and each message adds tool overhead |
| All watchdog timers fire at the same time | All instances restart simultaneously, brief total outage | Stagger timer start times with `RandomizedDelaySec=` in timer units | When instance count > 2 and watchdog interval is the same for all |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Per-instance env files with different API keys but world-readable | Credential exposure; each env file may have different keys for different projects | All env files `chmod 600`; lifecycle tooling must set permissions on creation |
| Orchestra has write access to all instrument working directories | Orchestra misroute could modify wrong project's files | Orchestra should dispatch via `claude-restart` (signaling), not by directly editing files in instrument directories |
| Restart file writable by any local user | Attacker injects CLI args to any instrument via predictable restart file path | `chmod 600` on all restart files; use `/run/user/$UID/` (tmpfs, per-user) instead of `$HOME` for restart files |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Indistinguishable sessions on mobile | User connects to wrong instrument, wastes time | Mandatory `--name` with instrument prefix |
| No instrument status overview | User must check each instrument individually via SSH | `claude-service list` showing all instruments with status, uptime, memory |
| Orchestra restart loses all dispatch context | After orchestra restart, it doesn't know what work was in progress | Orchestra reads a simple task log file on startup; instruments are self-contained and don't depend on orchestra memory |
| Adding an instrument requires multiple manual steps | User forgets to create env file, or enable watchdog timer | Single `claude-service add <name> --dir /path/to/project` command handles everything atomically |

---

## "Looks Done But Isn't" Checklist

- [ ] **Restart file isolation:** Each instrument has its own `CLAUDE_RESTART_FILE` -- trigger restart on instrument A, verify instrument B is unaffected
- [ ] **Env file layering:** Change `ANTHROPIC_API_KEY` in global env, verify all instances pick it up after restart -- then set instance-specific override, verify only that instance uses the override
- [ ] **Watchdog per-instance:** `systemctl --user list-timers 'claude-watchdog@*'` shows one timer per active instrument, each targeting the correct service
- [ ] **MemoryMax enforcement:** Start an instance, verify `systemctl show claude@test -p MemoryMax` returns the configured limit
- [ ] **Session naming:** Connect from phone, verify each instrument session has a distinct, recognizable name
- [ ] **daemon-reload not needed for new instances:** Start `claude@newname` without `daemon-reload` -- it should work if the template hasn't changed
- [ ] **Orchestra routing validation:** Tell orchestra to dispatch to nonexistent instrument name -- verify clear error, not silent failure
- [ ] **Rate limit resilience:** Run 3 instruments doing heavy work simultaneously -- verify graceful degradation, not crashes
- [ ] **Lifecycle atomicity:** Run `claude-service add test --dir /tmp/test` -- verify env file, service, and watchdog timer are all created in one command
- [ ] **Instrument removal cleanup:** Run `claude-service remove test` -- verify service stopped, timer stopped, env file removed, restart file removed

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong restart file consumed by wrong instrument | LOW | Restart both affected instruments; fix env file `CLAUDE_RESTART_FILE` paths |
| Specifier escaping produces wrong working directory | LOW | Fix instance naming convention; restart affected instance |
| All instances OOM-killed simultaneously | MEDIUM | SSH in (may be slow), `systemctl --user restart claude@<name>` for most critical instance first; add `MemoryMax` to prevent recurrence |
| Orchestra dispatches to wrong instrument | LOW-MEDIUM | Stop the wrongly-instructed instrument, restart it to clear context; have orchestra re-dispatch correctly |
| Rate limit blocks all instances | LOW | Wait 60 seconds for rate limit reset; reduce concurrent active instances |
| Watchdog restarts all instances simultaneously | LOW | Add `RandomizedDelaySec=300` to timer template; stagger manually if urgent |
| daemon-reload race leaves service in bad state | LOW | `systemctl --user reset-failed claude@<name> && systemctl --user restart claude@<name>` |
| Orchestra loses context after restart | MEDIUM | Re-read instrument roster, re-check status of all instruments, resume from task log |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Shared restart file (Pitfall 1) | Template unit setup | Restart instrument A; verify B is unaffected |
| Specifier escaping (Pitfall 2) | Template unit setup | Start instance with multi-word name; verify correct working directory |
| Env file layering (Pitfall 3) | Template unit setup | Change global key; verify all instances see it; override one instance; verify isolation |
| Orchestra context bleed (Pitfall 4) | Orchestra implementation | Dispatch to each instrument; verify correct project receives work |
| Memory leak x N (Pitfall 5) | Template unit setup | `systemctl show` confirms MemoryMax; run 2+ instances and monitor memory |
| Watchdog not per-instance (Pitfall 6) | Watchdog migration | `list-timers` shows one watchdog per instrument |
| Dynamic discovery race (Pitfall 7) | Dynamic discovery | Add instrument while orchestra is dispatching; verify discovery on next cycle |
| Rate limit contention (Pitfall 8) | Orchestra implementation | Run 3 instruments; verify no rate limit crashes |
| Session identity confusion (Pitfall 9) | Template unit setup | Check mobile app for distinct session names |
| daemon-reload race (Pitfall 10) | Lifecycle tooling | Add instrument without reload; start succeeds; add with reload during active operation; verify no hang |

---

## Sources

- [systemd.unit -- specifier documentation (%i, %I, escaping)](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
- [systemd-escape -- string escaping for unit names](https://www.freedesktop.org/software/systemd/man/latest/systemd-escape.html)
- [systemd template unit files -- Fedora Magazine](https://fedoramagazine.org/systemd-template-unit-files/)
- [systemd for Administrators, Part X -- Lennart Poettering (instances)](http://0pointer.de/blog/projects/instances.html)
- [Claude Code Remote Control official docs](https://code.claude.com/docs/en/remote-control) -- session naming, capacity, one-session-per-process limitation, 10-minute timeout
- [Claude Code Memory Leak -- GitHub issue #4953](https://github.com/anthropics/claude-code/issues/4953) -- process grows to 120GB+
- [Claude Code Memory Leak -- GitHub issue #21403](https://github.com/anthropics/claude-code/issues/21403) -- 15-17GB on Linux
- [Claude Code Memory Leak -- GitHub issue #22188](https://github.com/anthropics/claude-code/issues/22188) -- 93GB heap
- [Anthropic Rate Limits documentation](https://platform.claude.com/docs/en/api/rate-limits) -- RPM, TPM, daily quotas
- [Rate limit with concurrent instances -- GitHub issue #27603](https://github.com/anthropics/claude-code/issues/27603)
- [Multi-Agent Orchestration: Running 10+ Claude instances -- DEV Community](https://dev.to/bredmond1019/multi-agent-orchestration-running-10-claude-instances-in-parallel-part-3-29da)
- [systemd daemon-reload race condition -- GitHub issue #5328](https://github.com/systemd/systemd/issues/5328)
- [EnvironmentFile override behavior -- GitHub issue #9788](https://github.com/systemd/systemd/issues/9788)
- Personal inspection of existing v1.1 codebase: `bin/claude-wrapper`, `bin/claude-restart`, `bin/claude-service`, `bin/install.sh`, `systemd/claude.service`, `systemd/env.template`

---
*Pitfalls research for: Multi-instance orchestration -- systemd template units, remote-control session management, orchestra coordination*
*Researched: 2026-03-22*
