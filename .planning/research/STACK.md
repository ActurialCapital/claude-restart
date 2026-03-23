# Stack Research

**Domain:** Multi-instance Claude Code orchestration on Linux VPS
**Researched:** 2026-03-22
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| systemd template units (`claude@.service`) | systemd 249+ (any modern distro) | Multi-instance service management | Native to Linux, zero dependencies. `%i` specifier gives per-instance config for free. Already using systemd for single-instance -- template units are the natural extension, not a new technology. |
| Claude CLI `remote-control` server mode | Claude Code v2.1.51+ | Per-instrument session hosting | `claude remote-control --name "<project>"` runs a headless server accepting connections via claude.ai/code and mobile app. Each instrument is one `claude@<name>.service`. No local ports, no tunnel config. |
| Claude CLI `-p` (print/headless) mode | Claude Code v2.1.51+ | Orchestra ad-hoc dispatch | `claude -p "prompt" --output-format json` spawns one-shot tasks in any project directory. Session continuation via `--resume <session_id>` enables multi-turn orchestration. Orchestra uses this to query instruments' codebases. |
| Plain text manifest (one name per line) | N/A | Instrument registry | Simplest format parsable by bash with zero dependencies. File at `~/.config/claude-restart/instruments` lists instrument names, one per line. Bash reads with `while read`. Comments with `#`. |
| bash 4+ (existing) | 4.0+ | All scripting | Entire v1.1 codebase is 260 LOC of bash + 918 LOC tests. No reason to introduce Python/Node.js for orchestration glue. |
| jq | 1.6+ | Parse JSON from `claude -p` output | Only new external dependency. Orchestra extracts `session_id`, `result`, and structured output from headless claude calls. Available in every Linux package manager. |

### Supporting Technologies

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| systemd drop-in overrides | systemd 249+ | Per-instance WorkingDirectory | `claude@myproject.service.d/workdir.conf` sets WorkingDirectory without modifying the template unit. Created by `claude-service add`. |
| `systemctl --user list-units` | bundled | Enumerate running instruments | `systemctl --user list-units 'claude@*.service' --no-legend` gives all active instances with state. No custom registry needed for status. |
| `journalctl --user -u claude@<name>` | bundled | Per-instrument log access | Filtered logs per instrument, already working for single instance. Template unit inherits this automatically. |
| Per-instance EnvironmentFile | systemd | Instance-specific config | `EnvironmentFile=%h/.config/claude-restart/env.%i` loads instance overrides (restart file path, instance name) on top of shared base config. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| shellcheck | Bash linting | Already in use for v1.1 |
| bats-core | Bash testing | Already in use -- 82 assertions across 3 test suites in v1.1 |

## What Is NOT Being Added

This project stays pure bash + systemd + jq. No Node.js runtime, no Python, no Docker, no additional process managers.

## Installation

```bash
# Only new external dependency
sudo apt install jq    # Debian/Ubuntu
# or: dnf install jq   # Fedora
# or: brew install jq   # macOS dev

# Everything else is already installed or bundled with systemd
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Plain text manifest (one name per line) | JSON manifest parsed with `jq` | If instruments need metadata beyond name+directory (e.g., priority, resource limits, tags). Not needed now -- systemd EnvironmentFile handles per-instance config. |
| Plain text manifest | TOML manifest | Never for this project. TOML requires `stoml` or similar parser -- unnecessary dependency for a list of names. |
| `claude -p` for orchestra dispatch | Claude Agent SDK (TypeScript/Python) | If building a standalone orchestration app with hooks, approval callbacks, or structured multi-turn. Overkill here -- the orchestra IS a Claude session using bash tools, not a Node.js application. |
| `claude remote-control` (server mode) | `claude --remote-control` (interactive + RC) | `--remote-control` flag is for development/debugging when you want local terminal access alongside remote. Production instruments use pure `remote-control` server mode. |
| Per-instance EnvironmentFile | Single shared EnvironmentFile | Never. Each instrument needs its own restart file path and instance name. Per-instance `env.%i` files are the systemd-native solution. |
| systemd template units | Docker containers per instance | Never. Adds massive complexity for zero benefit -- these are single-user VPS instances running the same binary with different working directories. |
| `systemctl --user list-units claude@*` | Custom PID tracking / process registry | Never. systemd already tracks instance state, restart counts, and failure status. Don't reinvent process management. |
| systemd drop-in overrides for WorkingDirectory | `cd` in wrapper before exec | Drop-ins are the systemd-native pattern. The wrapper `cd` approach works but is invisible to `systemctl show` and harder to debug. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Claude Agent SDK (npm package) | Introduces Node.js runtime dependency for orchestration. The orchestra IS a Claude session -- it does not need an SDK to call itself. | `claude -p --output-format json` via Bash tool |
| WebSocket/HTTP direct protocol to running sessions | Remote Control uses HTTPS polling + SSE through Anthropic relay. There is NO documented local API to send messages to a running session from another process. | `claude -p --resume <session_id>` for multi-turn. `claude-restart` for context reset. |
| supervisor / pm2 / monit | Adding a process manager on top of systemd is redundant. systemd user services with template units provide restart, logging, dependency management. | systemd template units (`claude@.service`) |
| YAML for manifest | Requires `yq` dependency, complex syntax for a flat list. | Plain text, one name per line, `#` for comments |
| tmux for process lifecycle | tmux is for human terminal access, not process management. systemd owns the lifecycle. | systemd for lifecycle; tmux optionally for interactive debugging |
| Shared restart file (`~/.claude-restart`) | Single file creates race conditions with multiple instances writing simultaneously. | Per-instance: `~/.claude-restart.<instance>` via `CLAUDE_RESTART_FILE` env var (already supported in claude-wrapper!) |
| `Type=notify` or `WatchdogSec` | Claude process does not call `sd_notify()`. Watchdog for telegram mode is handled by timer, not WatchdogSec. | `Type=simple` (current) with separate watchdog timer per v1.1 pattern |

## Remote Control Protocol Details

Remote Control is NOT a local API. These facts drive architecture decisions:

- **Protocol**: HTTPS polling outbound (CLI polls Anthropic relay every ~2-5 seconds) + SSE for streaming responses back
- **No local port opened**: All traffic is outbound to Anthropic relay servers over TLS
- **No programmatic local API**: Cannot send messages to a running `claude remote-control` session from another local process via any documented mechanism
- **Per-process sessions**: Each `claude remote-control` process hosts one logical session. Server mode supports `--capacity N` (default 32) for concurrent web sessions.
- **Session URL**: Each session gets a unique URL under `claude.ai/code` that serves as authentication
- **Reconnection**: Exponential backoff, ~30s ceiling, ~10 minute network timeout before exit
- **Requires subscription auth**: API keys are NOT supported for remote-control. Requires claude.ai Pro/Max/Team/Enterprise login.

**Implication for orchestra design**: The orchestra CANNOT programmatically inject prompts into a running instrument's remote-control session. Instead:
1. Orchestra uses `claude-restart --instance <name>` to restart instruments (context reset between phases)
2. Orchestra spawns `claude -p` one-shot tasks in instrument project directories for ad-hoc research
3. Human-to-instrument interaction happens via claude.ai/code (independent of orchestra)
4. Orchestra monitors instrument health via `systemctl --user status claude@<name>.service`

## Key Integration Points with Existing v1.1

### claude-wrapper modifications

1. **Per-instance restart file**: `CLAUDE_RESTART_FILE` env var already supported -- just set it per-instance in EnvironmentFile to `~/.claude-restart.<instance-name>`
2. **Remote-control server mode**: Add `CLAUDE_CONNECT=remote-control` handling that runs `claude remote-control --name "$CLAUDE_INSTANCE_NAME"` (currently `remote-control` is passed as args to `claude`, but server mode is a subcommand not a flag)
3. **Instance name awareness**: New env var `CLAUDE_INSTANCE_NAME` set per-instance, used for `--name` flag and log prefix

### claude-restart modifications

1. **Instance targeting**: Accept `--instance <name>` flag to target specific instrument's restart file and systemd unit
2. **Backwards compatible**: Without `--instance`, behaves exactly as v1.1 (single instance)

### claude-service modifications

1. **Instance-aware commands**: `claude-service start myproject` maps to `systemctl --user start claude@myproject.service`
2. **List command**: `claude-service list` via `systemctl --user list-units 'claude@*.service'`
3. **Add/remove**: `claude-service add myproject /path/to/project` creates env file + drop-in + enables service
4. **Backwards compatible**: `claude-service start` (no name) targets `claude.service` for migration path

### systemd template unit design

```ini
[Unit]
Description=Claude Code Instrument - %i
After=network-online.target
Wants=network-online.target
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Type=simple
ExecStart=%h/.local/bin/claude-wrapper --dangerously-skip-permissions
EnvironmentFile=%h/.config/claude-restart/env
EnvironmentFile=%h/.config/claude-restart/env.%i
Restart=on-failure
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=10

[Install]
WantedBy=default.target
```

Key design decisions:
- **Two EnvironmentFiles**: Base `env` has shared config (API key, PATH). Per-instance `env.%i` has CLAUDE_INSTANCE_NAME, CLAUDE_RESTART_FILE.
- **No WorkingDirectory in template**: Set via drop-in override per instance because systemd directives cannot be set from EnvironmentFile.
- **Type=simple**: Same as v1.1. claude-wrapper is the foreground process.

### Per-instance env file (`env.<instance>`)

```bash
# ~/.config/claude-restart/env.myproject
CLAUDE_INSTANCE_NAME=myproject
CLAUDE_RESTART_FILE=/home/user/.claude-restart.myproject
```

### Per-instance drop-in (`claude@myproject.service.d/workdir.conf`)

```ini
[Service]
WorkingDirectory=/home/user/projects/myproject
```

### Instrument manifest (`~/.config/claude-restart/instruments`)

```
# One instrument name per line
# Name must match systemd instance identifier (no spaces, no special chars)
myproject
another-project
research-bot
```

## Stack Patterns by Use Case

**Instrument in `remote-control` mode (default, production):**
- ExecStart runs `claude remote-control --name "<instance>"` via wrapper
- Watchdog timer NOT needed (remote-control has built-in reconnection per v1.1 D-16)
- Heartbeat NOT needed (no stdin to keep alive)
- Access via claude.ai/code or Claude mobile app

**Orchestra session:**
- Same `remote-control` mode as instruments
- WorkingDirectory is a dedicated orchestration project folder
- System prompt (via CLAUDE.md) includes awareness of instrument manifest
- Has Bash tool access to `claude-service`, `claude-restart`, and `claude -p`
- Is itself an instrument in the manifest (self-referential but manageable)

**Ad-hoc research agent (spawned by orchestra):**
- Uses `claude -p --bare` for fast startup
- Runs in instrument's project directory
- One-shot: executes task and returns JSON result
- No systemd unit needed -- spawned and awaited by orchestra via Bash tool

## Version Compatibility

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| Claude Code CLI | v2.1.51+ | Required for `remote-control` mode. `--capacity` flag for server mode. |
| systemd | 249+ | Template units with `%i`, drop-in overrides, user services. Any distro from 2021+. |
| bash | 4.0+ | Arrays in claude-wrapper. macOS ships 3.2 but Homebrew bash is 5.x. |
| jq | 1.6+ | JSON parsing of `claude -p` output. Standard in all package managers. |

## Sources

- [Claude Code Remote Control docs](https://code.claude.com/docs/en/remote-control) -- Official. Server mode flags, `--capacity`, `--spawn`, session lifecycle. HIGH confidence.
- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference) -- Official. Full flag list including `-p`, `--resume`, `--output-format`, `--bare`. HIGH confidence.
- [Claude Code headless mode](https://code.claude.com/docs/en/headless) -- Official. Print mode patterns, session continuation, `--bare` for fast scripted calls. HIGH confidence.
- [Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) -- Official. SDK capabilities, session management, `query()` API. HIGH confidence.
- [Deep dive: Remote Control internals](https://dev.to/chwu1946/deep-dive-how-claude-code-remote-control-actually-works-50p6) -- HTTPS polling (not WebSocket), SSE streaming, no local API. MEDIUM confidence (third-party analysis, consistent with official docs).
- [systemd template unit files (Fedora Magazine)](https://fedoramagazine.org/systemd-template-unit-files/) -- `%i` specifier, per-instance patterns. HIGH confidence.
- [systemd.unit man page](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html) -- Specifiers, EnvironmentFile, drop-in directories. HIGH confidence.
- [Run multiple instances with systemd (Steven Rombauts)](https://www.stevenrombauts.be/2019/01/run-multiple-instances-of-the-same-systemd-unit/) -- Multi-instance EnvironmentFile pattern. HIGH confidence.
- [systemd for Administrators Part X (Lennart Poettering)](http://0pointer.de/blog/projects/instances.html) -- Authoritative template unit guide from systemd creator. HIGH confidence.

---
*Stack research for: claude-restart v2.0 multi-instance orchestration*
*Researched: 2026-03-22*
