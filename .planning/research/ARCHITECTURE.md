# Architecture Research

**Domain:** Multi-instance Claude Code orchestration on Linux VPS
**Researched:** 2026-03-22
**Confidence:** HIGH (systemd template patterns well-documented; Claude Code remote-control/SDK docs verified against official sources)

## System Overview

```
                          Phone / Browser
                               |
                    claude.ai/code (remote-control)
                               |
                    +==========|============+
                    |      VPS (systemd)    |
                    |                       |
                    |  [orchestra session]  |  <-- claude@orchestra.service
                    |    |    |    |        |      WorkingDirectory=~/.orchestra
                    |    |    |    |        |
                    |    v    v    v        |
                    |  inst  inst  inst     |  <-- claude@<name>.service
                    |  (A)   (B)   (C)      |      per-project WorkingDirectory
                    |                       |
                    |  [ad-hoc agents]      |  <-- claude -p (spawned, not services)
                    |  (short-lived)        |
                    +=======================+
```

### Layers

```
+-----------------------------------------------------------------+
|                     User Access Layer                             |
|  claude.ai/code, Claude mobile app, direct SSH/tmux              |
+-----------------------------------------------------------------+
|                     Orchestration Layer                           |
|  Orchestra session (optional autonomous supervisor)              |
|  - Dispatches work via claude -p in instrument directories       |
|  - Resets instrument context via claude-restart                  |
|  - Reads manifest to discover instruments                        |
+-----------------------------------------------------------------+
|                     Instrument Layer                              |
|  claude@<name>.service instances (template units)                |
|  Each: own WorkingDirectory, own env file, own restart file      |
+-----------------------------------------------------------------+
|                     Service Layer                                 |
|  systemd user services, template units, watchdog timers          |
|  claude-instrument CLI (lifecycle management)                    |
+-----------------------------------------------------------------+
|                     Foundation Layer                              |
|  claude-wrapper (restart loop), claude-restart (kill + signal)   |
|  Per-instance FIFO heartbeat, per-instance restart files         |
+-----------------------------------------------------------------+
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `claude@.service` | Template unit for all instrument instances | systemd template, `%i` specifier for instance name |
| `claude@orchestra.service` | Orchestra is just another instance of the template | Same template, special env file and working directory |
| `claude-wrapper` | Restart loop, signal forwarding, heartbeat | Existing bash script, modified for per-instance paths |
| `claude-restart` | Kill claude process, write restart file | Existing bash script, modified for per-instance paths |
| `claude-instrument` | CLI for add/remove/list/status lifecycle | New bash script replacing single-instance `claude-service` |
| Manifest | Registry of all instruments and their config | `~/.config/claude-restart/instruments.json` |
| Per-instance env | API keys, CLAUDE_CONNECT, instance-specific vars | `~/.config/claude-restart/<name>/env` |
| Per-instance restart file | Restart signal coordination per instrument | `~/.claude-restart-<name>` |

## Recommended Project Structure

```
bin/
  claude-wrapper           # Modified: reads CLAUDE_INSTANCE_NAME for per-instance paths
  claude-restart           # Modified: reads CLAUDE_INSTANCE_NAME for per-instance paths
  claude-instrument        # NEW: lifecycle CLI (add/remove/list/status/logs)
  install.sh               # Modified: deploys template units + claude-instrument

systemd/
  claude@.service          # NEW: template unit replacing claude.service
  claude-watchdog@.timer   # NEW: per-instance watchdog timer (replaces claude-watchdog.timer)
  claude-watchdog@.service # NEW: per-instance watchdog oneshot (replaces claude-watchdog.service)
  env.template             # Modified: includes CLAUDE_INSTANCE_NAME

tests/
  test-wrapper.bats        # Modified: per-instance path tests
  test-restart.bats        # Modified: per-instance path tests
  test-instrument.bats     # NEW: lifecycle CLI tests
  test-manifest.bats       # NEW: manifest CRUD tests
```

### Structure Rationale

- **`bin/`**: Single flat directory. No subdirectories needed -- the project has 4-5 scripts total.
- **`systemd/`**: Template units replace single-instance units. The `@` in filenames is the systemd convention for templates.
- **`tests/`**: One test file per script, plus integration tests for manifest operations.

## Architectural Patterns

### Pattern 1: systemd Template Units with Per-Instance Environment Files

**What:** A single `claude@.service` template file serves all instances. The instance name after `@` (`%i`) drives per-instance paths for env files, working directories, and restart files.

**When to use:** Always -- this is the foundation of multi-instance support.

**Trade-offs:** Elegant and native to systemd. One limitation: `WorkingDirectory` cannot read values from `EnvironmentFile` because systemd resolves `WorkingDirectory=` at unit parse time, before `EnvironmentFile=` is loaded.

**Implementation:**

```ini
# systemd/claude@.service
[Unit]
Description=Claude Code - %i
After=network-online.target
Wants=network-online.target
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Type=simple
ExecStart=%h/.local/bin/claude-wrapper --dangerously-skip-permissions
EnvironmentFile=%h/.config/claude-restart/%i/env
Restart=on-failure
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=10

[Install]
WantedBy=default.target
```

**Critical detail -- WorkingDirectory resolution:** systemd resolves `WorkingDirectory=` at unit parse time, before `EnvironmentFile=` is read. This means `WorkingDirectory=$CLAUDE_WORKING_DIR` does not work. Two solutions exist:

1. **Wrapper `cd` approach (recommended):** `claude-wrapper` reads `CLAUDE_WORKING_DIR` from the environment and does `cd "$CLAUDE_WORKING_DIR"` before launching claude. Simple, no extra systemd files.
2. **Drop-in override approach:** `claude-instrument add` creates `~/.config/systemd/user/claude@<name>.service.d/workdir.conf` with a hardcoded `[Service] WorkingDirectory=/path/to/project`. More systemd-native but adds file management complexity.

Use approach 1. It keeps everything in the env file and avoids systemd drop-in proliferation.

### Pattern 2: Per-Instance Path Namespacing via Environment Variable

**What:** A single `CLAUDE_INSTANCE_NAME` env var drives all per-instance file paths: restart file, heartbeat FIFO, env file directory, log identification.

**When to use:** Everywhere. This is how the existing single-instance scripts become multi-instance without forking code.

**Trade-offs:** Minimal code changes to existing scripts. When unset, defaults to legacy single-instance behavior (backward compatible).

**Implementation in claude-wrapper:**

```bash
# Per-instance paths (backward compatible: unset = legacy behavior)
INSTANCE="${CLAUDE_INSTANCE_NAME:-}"
if [[ -n "$INSTANCE" ]]; then
    RESTART_FILE="${CLAUDE_RESTART_FILE:-$HOME/.claude-restart-$INSTANCE}"
    HEARTBEAT_FIFO_PREFIX="/tmp/claude-heartbeat-$INSTANCE"
    # cd to working directory from env file
    if [[ -n "${CLAUDE_WORKING_DIR:-}" ]]; then
        cd "$CLAUDE_WORKING_DIR"
    fi
else
    RESTART_FILE="${CLAUDE_RESTART_FILE:-$HOME/.claude-restart}"
    HEARTBEAT_FIFO_PREFIX="/tmp/claude-heartbeat"
fi
```

**Implementation in claude-restart:**

```bash
INSTANCE="${CLAUDE_INSTANCE_NAME:-}"
if [[ -n "$INSTANCE" ]]; then
    RESTART_FILE="${CLAUDE_RESTART_FILE:-$HOME/.claude-restart-$INSTANCE}"
else
    RESTART_FILE="${CLAUDE_RESTART_FILE:-$HOME/.claude-restart}"
fi
```

### Pattern 3: Manifest-Driven Instrument Registry

**What:** A JSON manifest at `~/.config/claude-restart/instruments.json` records all registered instruments. The CLI and orchestra read this to discover instruments.

**When to use:** For lifecycle tooling (list/status) and orchestra awareness.

**Trade-offs:** Simple file-based approach. No daemon needed. Slightly out-of-sync risk if someone manually edits systemd units, but `claude-instrument list` can reconcile by checking both manifest and `systemctl --user list-units 'claude@*'`.

**Manifest structure:**

```json
{
  "version": 1,
  "instruments": {
    "myproject": {
      "working_dir": "/home/user/repos/myproject",
      "added": "2026-03-22T10:00:00Z",
      "connect_mode": "remote-control",
      "description": "My main project"
    },
    "orchestra": {
      "working_dir": "/home/user/.orchestra",
      "added": "2026-03-22T10:00:00Z",
      "connect_mode": "remote-control",
      "description": "Autonomous orchestra supervisor",
      "role": "orchestra"
    }
  }
}
```

**Why JSON and not plain text:** The manifest needs structured data (working directories, timestamps, optional metadata). `jq` is a reasonable dependency for a tool that already requires `node` (for claude itself). Alternatively, the bash scripts can use simple field extraction without `jq` if the format is kept flat.

### Pattern 4: Orchestra-to-Instrument Communication

**What:** The orchestra session controls instruments through two mechanisms: (1) `claude-restart` for context reset of running instruments, and (2) `claude -p` for spawning ad-hoc research agents in instrument directories.

**When to use:** When the orchestra needs to dispatch work or reset instrument state.

**Critical constraint verified against official docs:** Claude Code's `remote-control` mode does not expose a programmatic message-sending API. It routes through claude.ai/code's web interface only. There is no `claude inject <session_id>` command -- this is an open feature request ([GitHub issue #24947](https://github.com/anthropics/claude-code/issues/24947)). The orchestra cannot "talk to" a running instrument's conversation.

**What the orchestra CAN do:**

1. **Restart instruments** with new instructions via `claude-restart` (causes context loss)
2. **Spawn ad-hoc agents** via `claude -p` in instrument directories (independent sessions, no shared context with running instrument)
3. **Read instrument status** via `claude-instrument status` and `systemctl --user status`
4. **Read/write files** in instrument working directories (the orchestra has filesystem access)

**What the orchestra CANNOT do:**

1. Send a message to a running instrument's conversation
2. Read a running instrument's conversation context
3. Observe instrument output in real time

**Orchestra dispatch via `claude -p`:**

```bash
# Orchestra spawns a research agent in an instrument's project directory
cd /home/user/repos/myproject
claude -p "Analyze the test coverage and report gaps" \
    --allowedTools "Read,Grep,Glob,Bash" \
    --output-format json \
    --bare
```

**Orchestra restart via `claude-restart`:**

```bash
# Orchestra triggers context reset of an instrument
CLAUDE_INSTANCE_NAME=myproject claude-restart "new task instructions here"
```

**How the orchestra discovers instruments:** Reads the manifest file. The orchestra's CLAUDE.md includes instructions to check `~/.config/claude-restart/instruments.json` and use `claude-instrument status` for live state.

### Pattern 5: Agent Teams as Alternative Orchestra Pattern

**What:** Claude Code v2.1.32+ includes experimental "Agent Teams" for cross-session coordination. One session acts as team lead, spawning teammates with shared task lists and inter-agent messaging.

**When to use:** Evaluated but NOT recommended for this project.

**Why not:** Agent teams are experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag), have known limitations around session resumption, require interactive mode (not compatible with headless systemd services), and are designed for short-lived coordinated work sessions rather than persistent long-running services. The systemd-based approach is more reliable for always-on VPS operation.

**When to reconsider:** If agent teams become stable and gain persistent/headless support, they could replace the custom orchestra pattern entirely.

## Data Flow

### Instrument Lifecycle Flow

```
claude-instrument add myproject /path/to/project
    |
    v
Create env file:     ~/.config/claude-restart/myproject/env
Write manifest:      ~/.config/claude-restart/instruments.json
    |
    v
systemctl --user enable claude@myproject.service
systemctl --user start claude@myproject.service
    |
    v
claude-wrapper starts (reads CLAUDE_INSTANCE_NAME=myproject from env)
    |
    v
cd $CLAUDE_WORKING_DIR
claude remote-control --name "myproject" --dangerously-skip-permissions
    |
    v
Session available at claude.ai/code as "myproject"
```

### Per-Instance Restart Flow

```
[orchestra or user]
    |
    v
CLAUDE_INSTANCE_NAME=myproject claude-restart "new args"
    |
    v
Writes ~/.claude-restart-myproject
Kills claude process via PPID chain walk
    |
    v
claude-wrapper detects restart file
Reads new args, re-launches claude in same working directory
```

### Orchestra Dispatch Flow

```
Orchestra session (running in ~/.orchestra)
    |
    +-- Reads instruments.json for discovery
    |
    +-- Option A: Reset instrument context
    |     CLAUDE_INSTANCE_NAME=myproject claude-restart "phase 2 instructions"
    |
    +-- Option B: Spawn ad-hoc research agent
    |     cd /home/user/repos/myproject
    |     claude -p "research question" --bare --output-format json
    |     (reads stdout JSON, processes result)
    |
    +-- Option C: Check instrument status
          claude-instrument status myproject
          (parses systemctl output)
```

### Key Data Flows

1. **Instance startup:** systemd starts template unit -> wrapper reads instance env -> wrapper `cd`s to working dir -> wrapper launches claude with mode args -> claude connects via remote-control
2. **Instance restart:** restart script writes per-instance restart file -> kills claude process -> wrapper detects file -> re-launches claude with new args in same directory
3. **Orchestra dispatch:** orchestra reads manifest -> executes `claude -p` in target directory -> captures JSON output -> processes result
4. **Instrument discovery:** `claude-instrument list` reads manifest + cross-references `systemctl --user list-units 'claude@*'` for live reconciliation

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-3 instruments | Manifest is optional; can rely on systemd unit listing alone. Orchestra is overkill. |
| 4-8 instruments | Manifest becomes valuable for metadata (descriptions, roles). Orchestra adds value for cross-project coordination. |
| 8+ instruments | Memory/CPU become constraints. Consider per-instrument resource limits via systemd `MemoryMax=` / `CPUQuota=`. Watchdog becomes essential for preventing runaway instances. |

### Scaling Priorities

1. **First bottleneck: Memory.** Each Claude Code session consumes ~200-500MB. At 8 instances, that is 1.6-4GB just for Claude processes plus node overhead. Monitor with `systemd-cgtop` or per-unit `MemoryMax=`.
2. **Second bottleneck: API rate limits.** Multiple instances hitting the Anthropic API concurrently may trigger rate limits, especially if orchestra is also spawning `claude -p` agents. Orchestra should pace dispatches.

## Anti-Patterns

### Anti-Pattern 1: Shared Restart File Across Instances

**What people do:** Reuse `~/.claude-restart` for all instances (the v1.x default).
**Why it's wrong:** Race condition. Instance A's restart signal gets consumed by instance B's wrapper.
**Do this instead:** Per-instance restart files: `~/.claude-restart-<name>`. Driven by `CLAUDE_INSTANCE_NAME` in each instance's env file.

### Anti-Pattern 2: Orchestra Sending Messages to Running Instruments

**What people do:** Try to use some IPC to send messages to a running instrument session's conversation.
**Why it's wrong:** No such API exists. The `claude inject` feature request ([GitHub issue #24947](https://github.com/anthropics/claude-code/issues/24947)) is still open as of March 2026. Remote-control routes through claude.ai/code only, not a local API.
**Do this instead:** Orchestra has two levers: (1) restart the instrument with new instructions via `claude-restart`, or (2) spawn a separate `claude -p` agent in the same directory. Accept that the orchestra cannot interact with a running instrument's conversation context.

### Anti-Pattern 3: WorkingDirectory from EnvironmentFile

**What people do:** Set `WorkingDirectory=$CLAUDE_WORKING_DIR` in the systemd template, expecting it to be resolved from EnvironmentFile.
**Why it's wrong:** systemd resolves `WorkingDirectory=` at unit parse time, before `EnvironmentFile=` is read. The variable is treated as a literal string, causing the service to fail.
**Do this instead:** Have `claude-wrapper` read `CLAUDE_WORKING_DIR` from the environment and `cd` to it before launching claude.

### Anti-Pattern 4: Per-Instance Service Files Instead of Templates

**What people do:** Copy `claude.service` to `claude-myproject.service`, `claude-other.service`, etc.
**Why it's wrong:** Duplicated unit files. Every change requires updating N files. No consistency guarantee.
**Do this instead:** Single `claude@.service` template. All instances share the same unit definition. Instance-specific config lives in per-instance env files at `~/.config/claude-restart/<name>/env`.

### Anti-Pattern 5: Using Agent Teams for Persistent Orchestration

**What people do:** Try to use Claude Code's experimental Agent Teams feature for always-on cross-project orchestration.
**Why it's wrong:** Agent Teams are experimental, not designed for persistent/headless operation, have session resumption limitations, and require interactive mode. They are designed for short-lived coordinated work sessions.
**Do this instead:** Use systemd template units for persistent instrument management, with the orchestra as a regular instrument that uses `claude-restart` and `claude -p` for inter-instrument coordination.

## Integration Points

### Existing Components Modified

| Component | Change | Rationale |
|-----------|--------|-----------|
| `claude-wrapper` | Add `CLAUDE_INSTANCE_NAME` path namespacing, add `cd $CLAUDE_WORKING_DIR` | Multi-instance restart file isolation, per-instance working directory |
| `claude-restart` | Add `CLAUDE_INSTANCE_NAME` path namespacing | Per-instance restart file targeting |
| `install.sh` | Deploy template units, offer multi-instance setup flow, deploy `claude-instrument` | Replace single-instance `claude.service` with `claude@.service` |

### New Components

| Component | Purpose | Depends On |
|-----------|---------|------------|
| `claude@.service` | systemd template unit for all instances | `claude-wrapper` (modified), per-instance env files |
| `claude-watchdog@.timer` | Per-instance watchdog timer | Template unit pattern |
| `claude-watchdog@.service` | Per-instance watchdog oneshot | Template unit pattern |
| `claude-instrument` | Lifecycle CLI (add/remove/list/status/logs) | Manifest, systemd template units |
| `instruments.json` | Instrument registry/manifest | `claude-instrument` (manages it) |
| Orchestra CLAUDE.md | System prompt for orchestra behavior | Manifest, `claude-instrument`, `claude-restart` |

### Backward Compatibility

The v1.x single-instance `claude.service` coexists with template units during migration. When `CLAUDE_INSTANCE_NAME` is unset, `claude-wrapper` and `claude-restart` behave identically to v1.1. Migration path:

1. Install template units alongside existing single-instance service
2. Create first instrument via `claude-instrument add` (registers in manifest, starts `claude@<name>.service`)
3. Stop and disable legacy `claude.service` when ready
4. Remove legacy unit file via `claude-instrument migrate` or manual cleanup

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Wrapper <-> Restart | Restart file (`~/.claude-restart-<name>`) | File-based signaling, same as v1.x but per-instance |
| CLI <-> systemd | `systemctl --user` commands | Template instances: `claude@<name>.service` |
| CLI <-> Manifest | Read/write `instruments.json` | CLI is sole writer; orchestra and status commands are readers |
| Orchestra <-> Instruments | `claude-restart` (restart) or `claude -p` (dispatch) | No direct messaging to running sessions |
| Orchestra <-> Manifest | Read-only discovery | Orchestra discovers instruments by reading manifest |

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Anthropic API | Each instance authenticates independently | API key in per-instance env file. Same key can be shared across instances. |
| claude.ai/code | Each `remote-control` instance appears as separate named session | Named via `--name` flag; instance name maps to session name |
| systemd | User-level services with linger | Template units, `loginctl enable-linger` for boot persistence |

## Build Order

Based on dependency analysis, the recommended implementation order:

| Phase | Component | Depends On | Produces |
|-------|-----------|------------|----------|
| 1 | Per-instance path namespacing (modify `claude-wrapper` + `claude-restart`) | Nothing | Foundation: backward-compatible per-instance restart files, heartbeat FIFOs, working directory |
| 2 | Template unit files (`claude@.service`, watchdog templates) | Phase 1 | systemd-managed multi-instance capability |
| 3 | Per-instance env files and manifest structure | Phase 2 | Instrument configuration storage and registry |
| 4 | `claude-instrument` CLI | Phases 1-3 | User-facing lifecycle management (add/remove/list/status/logs) |
| 5 | Installer updates | Phase 4 | One-command deployment of multi-instance infrastructure |
| 6 | Orchestra session (CLAUDE.md + working directory) | Phase 4 | Autonomous supervisor using `claude-restart` + `claude -p` |

**Phase ordering rationale:**
- Phase 1 must come first because all other phases depend on per-instance path isolation
- Phases 2-3 are the systemd + config foundation that the CLI wraps
- Phase 4 (CLI) is the user-facing tool that ties 1-3 together
- Phase 5 (installer) packages everything for deployment
- Phase 6 (orchestra) is the capstone -- it is a Claude session with a CLAUDE.md that uses the tools built in phases 1-5; it requires no new code, only prompt engineering and a working multi-instance infrastructure

## Sources

- [systemd.unit man page](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html) -- template unit specifiers (%i, %I), EnvironmentFile resolution order
- [Fedora Magazine: systemd template unit files](https://fedoramagazine.org/systemd-template-unit-files/) -- practical template unit examples
- [Claude Code: Run programmatically (headless)](https://code.claude.com/docs/en/headless) -- `-p` flag, `--bare`, `--output-format json`, `--continue`, `--resume`
- [Claude Code: Remote Control](https://code.claude.com/docs/en/remote-control) -- server mode, `--name` flag, no programmatic message API
- [Claude Code: Sub-agents](https://code.claude.com/docs/en/sub-agents) -- subagent spawning, cannot nest, isolated context
- [Claude Code: Agent Teams](https://code.claude.com/docs/en/agent-teams) -- experimental cross-session coordination, limitations, not suitable for persistent services
- [GitHub Issue #24947: `claude inject`](https://github.com/anthropics/claude-code/issues/24947) -- no programmatic message injection to running sessions (open, unresolved as of March 2026)
- [GitHub Issue #2929: programmatically drive instances](https://github.com/anthropics/claude-code/issues/2929) -- confirms no inter-session messaging API

---
*Architecture research for: Claude Restart v2.0 Multi-Instance Orchestration*
*Researched: 2026-03-22*
