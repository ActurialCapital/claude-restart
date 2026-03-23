# Feature Research

**Domain:** Multi-instance Claude Code management and autonomous orchestration on Linux VPS
**Researched:** 2026-03-22
**Confidence:** MEDIUM (Claude Agent Teams is experimental and evolving; orchestration patterns well-established from supervisord/systemd/Kubernetes)

## Context

This is a subsequent milestone. v1.1 already ships: wrapper loop, restart trigger, shell integration, installer, systemd service with crash recovery, watchdog timer, keep-alive heartbeat, mode selection. The question is what NEW features are needed for multi-instance management and autonomous orchestration. Existing primitives (`claude-restart`, `claude-service`, `claude-wrapper`, systemd units) are the building blocks -- v2.0 parameterizes and layers on top of them.

## What Already Exists (Do Not Rebuild)

### v1.0/v1.1 Infrastructure (Already Built)
- `claude-wrapper`: loop-based restart with arg forwarding and signal handling
- `claude-restart`: kills claude process and writes new args to restart file
- `claude-service`: start/stop/restart/status/logs/watchdog/heartbeat subcommands
- `claude.service`: systemd unit with Restart=on-failure, StartLimitBurst
- `claude-watchdog.timer/service`: periodic forced restart for telegram mode
- `env.template`: ANTHROPIC_API_KEY, CLAUDE_CONNECT, CLAUDE_WATCHDOG_HOURS, PATH

### Claude Code Built-in Features (Do Not Rebuild)
- `claude remote-control`: server mode with auto-reconnect, session URLs, QR codes
- `claude -p` / `--print`: headless mode with `--output-format json` for one-shot tasks
- `claude --remote-control`: interactive session with remote access
- Agent Teams (experimental): file-based task board and inbox messaging for coordinated parallel work within a single codebase

## Feature Landscape

### Table Stakes (Users Expect These)

Features the user (phone-based VPS manager running multiple Claude projects) assumes exist. Missing these means the system is not meaningfully better than manual `systemctl` commands.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Template unit (`claude@.service`)** | systemd's native pattern for multi-instance. Without it, each instrument needs a hand-crafted unit file. | LOW | Replace `claude.service` with `claude@.service` using `%i` specifier for instance name. `WorkingDirectory` and restart file become instance-scoped. The existing single-instance unit is the template -- just parameterize it. |
| **`claude-service add <name> <dir>`** | Adding an instrument should be one command, not "copy unit, edit paths, reload daemon, enable, start". supervisord and Kubernetes both solve this. | MEDIUM | Creates instance env file at `~/.config/claude-restart/env.<name>`, enables `claude@<name>.service`, sets WorkingDirectory. Must validate dir exists and has a git repo. |
| **`claude-service remove <name>`** | Symmetric with add. Stops service, disables unit, removes instance env file. | LOW | Guard against removing a running instrument without `--force`. |
| **`claude-service list`** | Phone-based management means no desktop to see tmux panes. Must answer "what's running?" in one command. | LOW | Query `systemctl --user list-units 'claude@*.service'` and format as table with name, status, working directory, uptime. |
| **`claude-service status <name>`** | Single-instrument drill-down: running/stopped, uptime, last restart reason, log tail. | LOW | Extends existing `status` subcommand with instance awareness. Falls back to default instance if no name given (backward compat with v1.1). |
| **`claude-service logs <name>`** | Per-instrument log access. | LOW | `journalctl --user -u claude@<name> -f`. Same backward compat pattern. |
| **Instance-scoped restart files** | Current `~/.claude-restart` is a single shared file. With multiple instruments, they'd clobber each other. | LOW | Move to `~/.config/claude-restart/restart.<name>`. The wrapper reads its instance name from systemd `%i` and uses the right file. |
| **Instance-scoped env files** | Each instrument may need different settings (different CLAUDE_CONNECT, different working dirs, maybe different API keys). | LOW | `EnvironmentFile=%h/.config/claude-restart/env.%i` in the template unit. Created from template on `add`. |
| **Per-instrument watchdog** | Each instrument should have its own watchdog timer (or opt out). Instruments in remote-control mode skip watchdog (existing v1.1 behavior). | MEDIUM | Template the watchdog too: `claude-watchdog@.timer` and `claude-watchdog@.service`. Each instrument gets its own timer enabled/disabled based on its CLAUDE_CONNECT mode. |

### Differentiators (Competitive Advantage)

Features that make this system more than "systemd wrapper scripts" -- the orchestration layer.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Orchestra session as a Claude instrument** | The orchestra is itself a Claude Code session running in remote-control mode. It can receive instructions from the phone, reason about what to do, and act on instruments. No custom daemon code needed -- Claude IS the orchestrator. | MEDIUM | Registered as a special instrument (`claude@orchestra.service`) with its own working directory (this repo). Its CLAUDE.md contains orchestration instructions and available tools. |
| **Orchestra dispatches via `claude -p`** | Orchestra can run `claude -p "do X" --output-format json` in any instrument's working directory for one-shot tasks (research, status checks). No need to build a custom IPC protocol. | LOW | `claude -p` (print/headless mode) is stable, supports JSON output, and exits cleanly. Orchestra shells out to it. Perfect for ad-hoc research agents that do not disturb running instruments. |
| **Orchestra context-resets via `claude-restart`** | When an instrument finishes a phase, the orchestra uses the existing `claude-restart` mechanism to reboot it with fresh context and new instructions. This is already built in v1.0. | LOW | The restart file accepts new CLI args. Orchestra writes phase-specific args and triggers restart. Existing infrastructure, zero new code for the primitive itself. |
| **Dynamic instrument discovery** | Orchestra detects when instruments are added/removed without restarting itself. | MEDIUM | Two viable approaches: (1) Poll `systemctl --user list-units` on a timer (simple, 30s interval). (2) `systemd.path` unit watching `~/.config/claude-restart/` for file creates/deletes (event-driven, zero latency). Recommend approach 1 for simplicity -- polling is fine at this scale (fewer than 10 instruments). |
| **Orchestra status dashboard** | Orchestra maintains awareness of all instruments: what phase they're in, when they last restarted, whether they're healthy. Reports via remote-control when asked. | MEDIUM | Orchestra reads `systemctl status` + journalctl for each instrument. Stores state in a simple JSON file. Answers "what's everyone doing?" from phone. |
| **Orchestra spawns ad-hoc research agents** | Orchestra can spin up temporary Claude sessions in any project directory for research questions without disturbing the running instrument. | LOW | Uses `claude -p` in the target project dir. Not a persistent service -- just a one-shot process. Existing `claude -p --output-format json` covers this completely. |
| **Instrument health monitoring** | Orchestra periodically checks if instruments are responsive (systemd active, not crash-looping). Can alert or auto-restart. | MEDIUM | systemd already handles crash recovery (Restart=on-failure, StartLimitBurst). Orchestra adds awareness layer: reads systemd state, detects instruments hitting their restart limit, reports to user. |
| **Orchestra CLAUDE.md as configuration** | Orchestra behavior is configured via CLAUDE.md in its working directory, not a custom config format. Change orchestration rules by editing markdown. | LOW | This is how Claude Code already works. The orchestra's CLAUDE.md defines: which instruments exist, what phases they're in, when to context-reset, escalation rules. Pure convention, zero code. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Orchestra relay mode (proxy all instrument interactions)** | Seems convenient to talk to all instruments through one interface. | Adds latency, loses instrument-specific context, creates bottleneck. Claude Agent Teams tried inter-agent messaging and it's fragile (messages queue, lag, get lost). | Direct access to instruments via remote-control + orchestra for coordination only. Already in PROJECT.md Out of Scope. |
| **Shared memory/context between instruments** | "The API instrument should know what the frontend instrument discovered." | Context windows are isolated by design. Sharing context means either (a) massive token costs duplicating context, or (b) lossy summaries. Claude Agent Teams uses file-based inbox/task systems and it works but is complex and token-expensive. | Instruments share via git commits. Orchestra can read git logs to know what changed. Files on disk ARE the shared state. |
| **Orchestra making implementation decisions** | "The orchestra should decide how to implement feature X across projects." | Orchestra lacks project-specific context. Each instrument has deep context about its project. Centralizing decisions means worse decisions. Already in Out of Scope. | Orchestra dispatches work and monitors progress. Instruments hold project intelligence and make implementation decisions. |
| **Custom IPC protocol between instruments** | "Build a message queue / socket / REST API for inter-instrument communication." | Massive complexity for marginal gain. Claude Agent Teams built file-based messaging and it works but has known issues (status lag, lost messages, double-claims needing file locks). | Use existing primitives: `claude -p` for one-shot queries, `claude-restart` for lifecycle, `systemctl` for status, git for data sharing. No custom protocol needed. |
| **Real-time activity streaming** | "Show me a live feed of what every instrument is doing." | Requires tapping into Claude Code's internal state which has no public API for this. journalctl provides logs but not conversation-level activity. | Periodic status checks via `systemctl status` + journalctl tail. Ask instruments directly via remote-control when detailed status needed. |
| **Automatic scaling (add/remove instruments based on load)** | "Orchestra should spin up new instruments when there's more work." | This is a personal VPS, not a cloud. Resources are fixed. Auto-scaling on fixed hardware means instruments compete for CPU/memory. | Fixed instrument count per project. User explicitly adds/removes via CLI. Orchestra can recommend but not auto-create. |
| **Nested orchestration (orchestra of orchestras)** | "What if I need orchestras for different domains?" | Complexity explosion. Claude Agent Teams explicitly prohibits nested teams (teammates cannot spawn teams). One level of coordination is the sweet spot. | One orchestra, multiple instruments. If instrument count grows past manageable, the answer is better organization, not more layers. |

## Feature Dependencies

```
[systemd template unit claude@.service]
    |-- requires --> [instance-scoped env files]
    |-- requires --> [instance-scoped restart files]
    |-- enables  --> [claude-service add/remove/list]
    |-- enables  --> [per-instrument watchdog timer]

[claude-service add <name> <dir>]
    |-- requires --> [systemd template unit]
    |-- requires --> [instance-scoped env files]
    |-- enables  --> [orchestra session]

[claude-service list]
    |-- requires --> [systemd template unit]
    |-- enables  --> [orchestra status dashboard]

[orchestra session (claude@orchestra.service)]
    |-- requires --> [claude-service add/remove/list]  (manages own lifecycle)
    |-- requires --> [claude -p headless mode]          (spawns research agents)
    |-- requires --> [claude-restart mechanism]          (context-resets instruments)
    |-- enhances --> [dynamic instrument discovery]
    |-- enhances --> [instrument health monitoring]

[dynamic instrument discovery]
    |-- requires --> [claude-service list]
    |-- enhances --> [orchestra session]

[ad-hoc research agents]
    |-- requires --> [claude -p --output-format json]   (already available)
    |-- requires --> [orchestra session]                 (to dispatch them)
```

### Dependency Notes

- **Template unit is the foundation**: Everything else depends on the shift from `claude.service` to `claude@.service`. This must come first.
- **Instance scoping is structural**: Env files and restart files must be per-instance before `add/remove` makes sense. These are low complexity but foundational.
- **Orchestra depends on lifecycle CLI**: The orchestra needs `claude-service list` to discover instruments and `claude-service add` to register itself. Build lifecycle tooling before orchestra.
- **`claude -p` is already available**: The headless/print mode that the orchestra uses for ad-hoc agents requires zero new code. It is a stable Claude Code CLI feature.
- **`claude-restart` is already available**: The context-reset mechanism the orchestra uses to reboot instruments between phases exists since v1.0. Zero new code for the primitive.
- **Dynamic discovery enhances but does not block orchestra**: Orchestra can start with a static instrument list (from `claude-service list`) and add dynamic discovery later.

## MVP Definition

### Phase 1: Multi-Instance Foundation

Minimum infrastructure to run multiple instruments. No orchestra yet.

- [ ] **systemd template unit `claude@.service`** -- parameterize existing unit with `%i`
- [ ] **Instance-scoped env files** -- `~/.config/claude-restart/env.<name>`
- [ ] **Instance-scoped restart files** -- `~/.config/claude-restart/restart.<name>`
- [ ] **`claude-service add <name> <dir>`** -- register a new instrument
- [ ] **`claude-service remove <name>`** -- deregister an instrument
- [ ] **`claude-service list`** -- show all instruments with status
- [ ] **Per-instrument watchdog templates** -- `claude-watchdog@.timer` and `claude-watchdog@.service`
- [ ] **Backward compatibility** -- bare `claude-service start/stop/status` works for single-instance (default instance name)

### Phase 2: Orchestra Bootstrap

Minimal autonomous coordinator.

- [ ] **Register orchestra as `claude@orchestra.service`** -- runs in this repo's directory
- [ ] **Orchestra CLAUDE.md** -- defines orchestration behavior, instrument roster, dispatch rules
- [ ] **Orchestra reads instrument list** -- calls `claude-service list` or reads systemd state
- [ ] **Orchestra dispatches ad-hoc research** -- uses `claude -p` in instrument project dirs
- [ ] **Orchestra triggers context-reset** -- uses `claude-restart` to reboot instruments with new args

### Phase 3: Autonomous Features

After basic orchestra works, add intelligence.

- [ ] **Dynamic instrument discovery** -- detect new/removed instruments without orchestra restart
- [ ] **Health monitoring** -- detect crash-looping instruments, report to user
- [ ] **Status dashboard** -- orchestra answers "what's everyone doing?" with structured response

### Future Consideration

- [ ] **Cross-instrument git awareness** -- orchestra reads git logs to understand project progress
- [ ] **Phase-aware scheduling** -- orchestra knows instrument phases and auto-advances when milestones complete
- [ ] **Priority queue** -- orchestra maintains a work queue and assigns tasks by priority

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Depends On v1.1 |
|---------|------------|---------------------|----------|-----------------|
| systemd template unit | HIGH | LOW | P1 | Evolves claude.service |
| Instance-scoped env files | HIGH | LOW | P1 | Evolves env.template |
| Instance-scoped restart files | HIGH | LOW | P1 | Evolves claude-restart |
| `claude-service add` | HIGH | MEDIUM | P1 | Evolves claude-service |
| `claude-service remove` | HIGH | LOW | P1 | Evolves claude-service |
| `claude-service list` | HIGH | LOW | P1 | Evolves claude-service |
| Per-instrument watchdog | MEDIUM | MEDIUM | P1 | Evolves watchdog timer/service |
| Backward compat (default instance) | MEDIUM | LOW | P1 | Wraps existing behavior |
| Orchestra as instrument | HIGH | MEDIUM | P2 | Template unit |
| Orchestra CLAUDE.md | HIGH | LOW | P2 | Convention only |
| Ad-hoc research agents | MEDIUM | LOW | P2 | `claude -p` (exists) |
| Context-reset dispatch | HIGH | LOW | P2 | `claude-restart` (exists) |
| Dynamic discovery | MEDIUM | MEDIUM | P3 | `claude-service list` |
| Health monitoring | MEDIUM | MEDIUM | P3 | Template unit |
| Status dashboard | MEDIUM | LOW | P3 | Orchestra + list |

**Priority key:**
- P1: Foundation -- must exist before anything else works
- P2: Orchestra bootstrap -- the differentiating value of v2.0
- P3: Autonomous intelligence -- polish and reliability

## Competitor Feature Analysis

| Feature | Claude Agent Teams | supervisord | Kubernetes | Our Approach |
|---------|-------------------|-------------|------------|--------------|
| **Instance lifecycle** | Lead spawns/shuts down teammates programmatically | Config file defines programs; `supervisorctl add/remove` at runtime | Deployments with replica sets, `kubectl apply` | `claude-service add/remove/list` wrapping systemd template units |
| **Instance isolation** | Each teammate gets own context window, shares filesystem | Each program has own stdout/stderr, can have own env | Pods with resource limits, network namespaces | Each instrument has own env file, working directory, restart file; systemd provides process isolation |
| **Status monitoring** | Lead sees teammate states via shared task list; messages auto-delivered | `supervisorctl status` shows running/stopped/exited per program | `kubectl get pods`, health checks, liveness probes | `claude-service list/status` + journalctl; orchestra reads systemd state |
| **Health recovery** | Teammates can stop on errors; lead spawns replacements manually | `autorestart=unexpected` restarts on unexpected exits | Restart policies, liveness/readiness probes auto-restart | systemd Restart=on-failure + StartLimitBurst (already built); orchestra detects crash-looping |
| **Task dispatch** | Shared task list with file locking; self-claim or lead-assigned | No built-in task dispatch; process-level only | Jobs/CronJobs for batch; no built-in task routing | Orchestra uses `claude -p` for one-shot tasks, `claude-restart` for phase transitions |
| **Inter-instance comms** | File-based inbox system (JSON files per agent); message types: direct, broadcast, shutdown | No built-in IPC; programs are independent | Services, DNS, shared volumes | Git commits as shared state; `claude -p` for queries; no custom IPC |
| **Dynamic discovery** | Team config in `~/.claude/teams/{name}/config.json`; fixed at team creation | Config reload via `supervisorctl reread && update` | Watch API, controller pattern | Poll systemd unit list or `systemd.path` watching config directory |
| **Coordination model** | Lead + teammates with shared task board and messaging | Flat process group with priorities | Controllers reconcile desired vs actual state | Orchestra session with CLAUDE.md-defined behavior; instruments are autonomous within their project |

### Key Insight from Competitor Analysis

Claude Agent Teams is the closest analog but solves a different problem: short-lived collaboration on a single codebase. Our system manages long-running, persistent instruments across separate projects. The patterns that transfer well:

1. **Lead/worker topology** (Agent Teams has lead + teammates -- we have orchestra + instruments)
2. **File-based coordination** (Agent Teams uses JSON files for tasks/messages -- we use systemd state + env files)
3. **Self-claim pattern** (Agent Teams teammates self-claim tasks -- our instruments work autonomously, orchestra dispatches when needed)

The patterns to avoid:

1. **Complex messaging protocol** (Agent Teams' inbox system has known issues with lag and lost messages)
2. **Tight coupling** (Agent Teams requires all members in same filesystem -- our instruments are project-isolated)
3. **Token-heavy coordination** (Agent Teams broadcasts are expensive -- our orchestra queries instruments only when needed via `claude -p`)

### What the Orchestra Should Know About Each Instrument

Based on patterns from supervisord (process groups with metadata), Kubernetes (pod spec + status), and Agent Teams (member registry with prompts):

| Data Point | Where It Lives | How Orchestra Reads It |
|------------|---------------|----------------------|
| Instance name | systemd unit name (`claude@<name>`) | `claude-service list` |
| Working directory | Instance env file | Read `~/.config/claude-restart/env.<name>` |
| Running status | systemd state | `systemctl --user is-active claude@<name>` |
| Connection mode | Instance env file (`CLAUDE_CONNECT`) | Read env file |
| Last restart time | systemd/journalctl | `systemctl --user show claude@<name> -p ActiveEnterTimestamp` |
| Current phase/task | CLAUDE.md or status file in project dir | Read `<project>/.planning/PROJECT.md` or similar |
| Health | systemd + restart count | `systemctl --user show claude@<name> -p NRestarts` |

### What Autonomous Decisions the Orchestra Should/Should Not Make

**Should make (low-risk, reversible):**
- Context-reset an instrument that completed its phase (restart with new args)
- Spawn ad-hoc research agents in any project directory
- Report status when asked
- Detect and report unhealthy instruments
- Suggest next work items based on project state

**Should NOT make (high-risk, irreversible):**
- Remove an instrument (user decision)
- Add new instruments (user decision -- resource allocation)
- Change an instrument's working directory or project
- Make implementation decisions for instruments
- Force-stop an instrument that is mid-work
- Modify project code or configuration directly

## Sources

- [Claude Code Agent Teams official docs](https://code.claude.com/docs/en/agent-teams) -- HIGH confidence, official documentation
- [Claude Code Remote Control official docs](https://code.claude.com/docs/en/remote-control) -- HIGH confidence, official documentation
- [Claude Code headless/programmatic mode](https://code.claude.com/docs/en/headless) -- HIGH confidence, official documentation
- [systemd template units](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html) -- HIGH confidence, official systemd docs
- [systemd.path units](https://www.freedesktop.org/software/systemd/man/latest/systemd.path.html) -- HIGH confidence, official systemd docs
- [Supervisor process management](https://supervisord.org/) -- HIGH confidence, official docs
- [Multi-instance systemd patterns](https://opensource.com/article/20/12/multiple-service-instances-systemctl) -- MEDIUM confidence, well-regarded tutorial
- [Run multiple instances of same systemd unit](https://www.stevenrombauts.be/2019/01/run-multiple-instances-of-the-same-systemd-unit/) -- MEDIUM confidence, practical tutorial
- [From Tasks to Swarms: Agent Teams internals](https://alexop.dev/posts/from-tasks-to-swarms-agent-teams-in-claude-code/) -- MEDIUM confidence, third-party analysis of Agent Teams architecture
- [CrewAI multi-agent orchestration](https://crewai.com/open-source) -- LOW confidence, used for pattern comparison only

---
*Feature research for: Multi-instance Claude Code management and autonomous orchestration*
*Researched: 2026-03-22*
