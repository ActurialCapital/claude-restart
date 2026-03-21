# Architecture Research

**Domain:** VPS reliability layer for Claude Code wrapper/restart mechanism
**Researched:** 2026-03-20
**Confidence:** HIGH (systemd mechanics), MEDIUM (claude process behavior), LOW (watchdog for channels-mode specifics)

## Standard Architecture

### System Overview

The existing v1.0 architecture is a foreground loop. The new VPS reliability layer adds three orthogonal concerns: process management (systemd), health detection (watchdog), and idle prevention (keep-alive). These must integrate without fighting each other.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PROCESS MANAGEMENT LAYER                      │
│                                                                      │
│  systemd user service                                                │
│  (restart on crash + boot persistence)                               │
│  Restart=on-failure, WatchdogSec=120s                                │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                      claude-wrapper                          │    │
│  │   (existing restart-on-exit loop — v1.0)                    │    │
│  │                                                              │    │
│  │   loop:                                                      │    │
│  │     launch claude [mode args]     ←── RESTART_FILE          │    │
│  │     check restart file on exit                              │    │
│  │     sleep 2s → relaunch                                     │    │
│  │                                                              │    │
│  │   ┌───────────────────────────────────────────────────┐     │    │
│  │   │         claude process (node)                      │     │    │
│  │   │                                                    │     │    │
│  │   │  Mode A: claude --channels plugin:telegram@...    │     │    │
│  │   │  Mode B: claude remote-control                    │     │    │
│  │   └───────────────────────────────────────────────────┘     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    watchdog sidecar (new)                    │    │
│  │   periodic health check → sd_notify WATCHDOG=1              │    │
│  │   OR kill claude-wrapper on hung detection                   │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                  keep-alive (new, inline)                    │    │
│  │   prevents idle timeout while waiting for Telegram messages  │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `claude-wrapper` | Foreground restart loop, reads RESTART_FILE, passes mode args | Existing — modified |
| `claude-restart` | Writes RESTART_FILE, kills claude via PPID walk | Existing — unchanged |
| `install.sh` | Copies scripts, patches zshrc | Existing — extended |
| `claude.service` | systemd user unit: boot persistence, crash restart, watchdog integration | New |
| `claude-watchdog` | Detects hung claude process, pings systemd watchdog or kills wrapper | New |
| `claude-mode-select` | Writes correct mode args to RESTART_FILE before launch | New or inline in wrapper |
| Keep-alive logic | Prevents idle timeout; inline in wrapper or separate loop | New — inline in wrapper |

---

## Key Architecture Question: How Do systemd and the Wrapper Loop Layer?

### The Layering Answer

They operate at different levels and serve different purposes — they do not conflict when configured correctly.

**Wrapper loop** handles: "Claude exited — should I relaunch it?" It exists because the restart signal (`claude-restart`) kills the claude process and expects the wrapper to relaunch it. The wrapper is the foreground process that users interact with in a terminal.

**systemd** handles: "The wrapper itself crashed, or the VPS rebooted — start everything again." systemd watches the wrapper, not claude. The wrapper is the `ExecStart` target.

**The correct mental model:**

```
systemd → watches → claude-wrapper → watches → claude process
```

systemd restarts the wrapper only when the wrapper exits with a failure code or is killed by the watchdog. The wrapper's own restart loop is transparent to systemd — from systemd's perspective, the wrapper is always "running" as long as the loop continues.

**Critical configuration:** Use `Type=simple` (not `Type=forking`). The wrapper runs in the foreground and never forks — it is the main process. systemd tracks the wrapper's PID directly.

**Avoid the restart loop collision:** The wrapper must NOT exit with success (exit 0) on every restart cycle — it only exits when the user intentionally quits claude (no RESTART_FILE present) or hits the max-restarts limit. This is already the existing behavior and is correct.

**Restart storm prevention:** systemd's `StartLimitBurst` and `StartLimitIntervalSec` act as circuit breakers. If the wrapper itself crashes rapidly (not normal restarts), systemd stops attempting after N failures in the interval window.

---

## Key Architecture Question: Watchdog for "Process Alive But Unresponsive"

### The Problem

The Telegram channels mode has a documented failure pattern: the `claude` process stays alive (node process running, no crash) but stops responding to Telegram messages. systemd's normal process monitoring only detects exit — it cannot detect this "zombie" state.

### Why External Watchdog Is Needed

The `claude` process is a Node.js binary. It does not call `sd_notify(WATCHDOG=1)` natively. A watchdog must be implemented externally.

### Watchdog Implementation Options

**Option A: Wrapper-inline watchdog (recommended for simplicity)**

The wrapper spawns a background subshell that periodically sends `systemd-notify WATCHDOG=1`. This runs in the same process group as the wrapper, satisfying `NotifyAccess=main` (the subshell inherits the wrapper's group).

```bash
# Inside claude-wrapper, after launching claude in background:
watchdog_loop() {
    while kill -0 "$claude_pid" 2>/dev/null; do
        systemd-notify WATCHDOG=1 2>/dev/null || true
        sleep "$((WATCHDOG_USEC / 1000000 / 2))"
    done
}
watchdog_loop &
```

The health check for "is claude actually responding?" is the hard part (see below). If health check fails, the watchdog stops pinging systemd, which times out and kills+restarts the wrapper.

**Option B: Separate watchdog sidecar**

A separate process runs alongside the wrapper, polls a health endpoint, and either pings systemd or kills the wrapper directly. More complex, requires coordination.

For this project's scale (personal VPS, single user, ~200 LOC philosophy), Option A is correct.

### Health Check Strategy: How to Detect "Unresponsive"

This is the hardest part. There is no standard health endpoint for claude.

**For channels/Telegram mode:**

The Telegram plugin polls Telegram's API. The most reliable proxy for "is claude responding?" is: "has the Telegram plugin sent a heartbeat or processed a message recently?"

Options in order of reliability:
1. **Process tree check** — verify the Bun subprocess (Telegram plugin) is alive and has file descriptors open. If Bun is dead, claude is in a bad state. LOW confidence this catches all hung states.
2. **Timestamp file** — patch or configure claude to touch a health file periodically. Not feasible without modifying claude itself.
3. **Message-based probe** — send a test message to the Telegram bot and check for a response within N seconds. HIGH confidence but requires Telegram API access in the watchdog. HIGH complexity.
4. **Process CPU/IO check** — if the claude process shows zero CPU and zero IO for an extended period (e.g., 30+ minutes on a channels session), declare it hung. LOW confidence, many false positives during idle periods.
5. **Restart on inactivity timer** — do not try to detect hung state; instead, restart claude every N hours proactively. This matches the existing `claude-restart` mechanism and is zero-complexity.

**For remote-control mode:**

`claude remote-control` exits on its own after a ~10-minute network outage (documented behavior). systemd's crash-restart already handles this case. No additional health check is needed — the process self-terminates when unresponsive.

**Recommended approach for v1.1:**

Use option 5 (periodic restart) as a pragmatic substitute for true health detection. The watchdog only needs to confirm the process is alive (standard PID check) to ping systemd. A separate keep-alive/restart timer handles the "alive but unresponsive" case by scheduling periodic restarts via `claude-restart`. This avoids the complexity of a real health probe.

---

## Key Architecture Question: tmux vs systemd

### Answer: systemd replaces tmux for reliability; tmux becomes optional for interactive use

**Current state:** User SSH in → start tmux → run claude manually. tmux serves two purposes: (1) session persistence across SSH drops, and (2) a way to detach and reattach.

**With systemd:** The claude-wrapper runs as a systemd user service. SSH drops do not kill it. No tmux needed for persistence.

**What tmux still provides:** An interactive terminal window to view claude's output and type commands. This is a separate concern from reliability. If the user wants to see claude's terminal output, they can attach to a tmux session inside which they run `journalctl -fu claude.service` or a socat pipe. But the service runs whether or not tmux is open.

**Conclusion:**

| Concern | systemd handles | tmux handles |
|---------|----------------|--------------|
| Survive SSH drop | YES | YES (but process stays in tmux) |
| Auto-start on boot | YES | No |
| Crash recovery | YES | No |
| Interactive terminal output | No | YES |
| Detach/reattach | No | YES |

For a VPS running channels/remote-control mode, there is no interactive terminal output to view. The user interacts via Telegram or the mobile app. tmux is no longer needed at all.

If the user wants to occasionally attach and interact via terminal (e.g., to run `claude-restart`), they can `systemctl --user stop claude`, then start claude manually in a tmux session for that interaction, then restart the service. This is an acceptable workflow for a personal VPS.

**Systemd user service with lingering** is the correct replacement for tmux-as-persistence.

---

## Recommended Project Structure

```
bin/
├── claude-wrapper          # Existing — modified to support mode selection + keep-alive
├── claude-restart          # Existing — unchanged
├── install.sh              # Existing — extended to install systemd unit + mode config
└── claude-watchdog         # New — optional, may be inline in wrapper instead
systemd/
└── claude.service          # New — user unit file template
```

### Structure Rationale

- **bin/**: All executable scripts, consistent with v1.0
- **systemd/**: Unit file lives in repo, `install.sh` copies to `~/.config/systemd/user/`
- **No new config files beyond systemd unit**: Mode selection stored in RESTART_FILE or env var

---

## Architectural Patterns

### Pattern 1: Layered Restart Hierarchy

**What:** Two independent restart mechanisms at different levels — wrapper loop for graceful restart-with-new-args, systemd for crash/boot recovery. They do not interfere because the wrapper is always the primary process.

**When to use:** Any foreground-loop process managed by systemd.

**Trade-offs:** Simple to reason about; two different failure modes are handled separately. Risk: wrapper max-restarts limit causes wrapper to exit 1, triggering systemd restart, triggering wrapper again — potential restart storm. Mitigate with `StartLimitBurst`.

```
systemd Restart=on-failure
    └── triggers when wrapper exits with non-zero
        └── wrapper exits non-zero when MAX_RESTARTS exceeded
            └── systemd waits RestartSec, relaunches wrapper
                └── wrapper resets restart_count to 0
```

### Pattern 2: Cooperative Watchdog via Wrapper Subshell

**What:** The wrapper owns the watchdog pinging responsibility. A background subshell within the wrapper reads `$WATCHDOG_USEC` from environment (set by systemd when `WatchdogSec` is configured) and calls `systemd-notify WATCHDOG=1` at half the interval.

**When to use:** When the main application (claude/node) cannot be modified to call sd_notify itself.

**Trade-offs:** Works within existing bash script constraints; no external dependencies. The health check is process-alive-only (not semantic). For this project that is acceptable given the periodic-restart fallback.

**Key systemd requirement:** `NotifyAccess=main` is sufficient because the subshell inherits the wrapper process group. Do NOT use `NotifyAccess=all` unnecessarily.

### Pattern 3: Mode Selection via RESTART_FILE

**What:** Mode selection (channels vs remote-control) is expressed as CLI arguments written to RESTART_FILE at startup or via `claude-restart <mode-args>`. The wrapper reads them on each restart cycle.

**When to use:** Consistent with existing restart mechanism — no new coordination primitives needed.

**Trade-offs:** Mode is determined at wrapper launch and can be changed mid-session via `claude-restart`. Simple. Limitation: cannot switch modes without restarting the claude process (acceptable — mode switch requires restart anyway).

```bash
# Launch in channels mode:
claude-wrapper --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions

# Switch to remote-control mode:
claude-restart remote-control
# wrapper picks up the new args on next restart cycle
```

---

## Data Flow

### Normal Operation (Telegram channels mode)

```
[systemd starts claude-wrapper on boot]
    ↓
[claude-wrapper launches: claude --channels plugin:telegram@... --dangerously-skip-permissions]
    ↓
[watchdog subshell pings systemd every 60s: systemd-notify WATCHDOG=1]
    ↓
[Telegram message arrives → Bun plugin → claude process handles it → replies]
    ↓
[idle period: keep-alive loop touches activity file or does minimal work]
    ↓
[claude exits for any reason]
    ↓
[wrapper checks RESTART_FILE]
    ├── File present → read new args → sleep 2s → relaunch claude
    └── File absent → wrapper exits → systemd sees non-zero or Restart=always → restarts wrapper
```

### Restart-with-Mode-Change Flow

```
[user sends "restart in remote-control mode" to Telegram bot]
    ↓
[claude runs: claude-restart remote-control]
    ↓
[RESTART_FILE written: "remote-control"]
[claude process killed via PPID walk]
    ↓
[wrapper detects exit + RESTART_FILE present]
[reads: "remote-control"]
[relaunches: claude remote-control]
```

### Hung Process Recovery Flow (watchdog path)

```
[claude process alive but unresponsive to Telegram]
    ↓
[watchdog subshell stops detecting healthy state]
[stops calling systemd-notify WATCHDOG=1]
    ↓
[systemd WatchdogSec timeout expires]
[systemd sends SIGABRT to wrapper process group]
    ↓
[wrapper exits]
[systemd Restart=on-failure triggers]
[wrapper relaunches with same mode args]
```

OR (simpler periodic-restart path):

```
[scheduled: every 6 hours]
    ↓
[cron/systemd timer calls: claude-restart]
[RESTART_FILE written, claude killed]
    ↓
[wrapper relaunches — same args — fresh process state]
```

---

## Integration Points

### New vs Modified Components

| Component | Status | Integration Point |
|-----------|--------|-------------------|
| `claude-wrapper` | Modified | Add mode-selection arg handling; add keep-alive loop; add watchdog subshell |
| `claude-restart` | Unchanged | Already works; mode args are just args |
| `install.sh` | Modified | Add systemd unit install; add `loginctl enable-linger`; add mode config |
| `claude.service` | New | systemd user unit; `ExecStart=claude-wrapper $CLAUDE_MODE_ARGS` |
| `claude-watchdog` (optional) | New or inline | Pings systemd watchdog; may be inline in wrapper |

### systemd Unit Integration

The unit file must:
- Use `Type=simple` (wrapper is the main process, runs in foreground)
- Set `Restart=on-failure` (not `always` — user intentional quit should not restart)
- Set `WatchdogSec=120` (2 minutes; adjust based on expected Telegram response latency)
- Set `NotifyAccess=main` (wrapper's subshell can send notifications)
- Set `Environment=CLAUDE_MODE=channels` or use `EnvironmentFile=~/.config/claude-wrapper/mode`
- Use `User=` and be a user service (no root required; `loginctl enable-linger` for boot persistence)

```
# ~/.config/systemd/user/claude.service
[Unit]
Description=Claude Code Wrapper
After=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/claude-wrapper --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions
Restart=on-failure
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=300
WatchdogSec=120
NotifyAccess=main
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| systemd ↔ claude-wrapper | Process lifecycle (start/stop/kill), notify socket | Wrapper is ExecStart; must not fork |
| claude-wrapper ↔ claude | Fork/exec (foreground), exit code, SIGTERM | Same as v1.0 |
| claude-wrapper ↔ RESTART_FILE | File read/write | Same as v1.0 |
| claude-wrapper ↔ systemd watchdog | `systemd-notify WATCHDOG=1` via subshell | New — only active under systemd |
| claude-restart ↔ claude | SIGTERM via PPID walk | Same as v1.0; works in both modes |

---

## Anti-Patterns

### Anti-Pattern 1: systemd Restart=always on the Wrapper

**What people do:** Set `Restart=always` so the service always comes back.

**Why it's wrong:** When the user intentionally quits claude (Ctrl+C exits wrapper with 130, or wrapper exits 0), systemd immediately restarts it. There is no way to stop the service without `systemctl stop`. The max-restarts circuit breaker in the wrapper also triggers systemd restarts in an unwanted cascade.

**Do this instead:** Use `Restart=on-failure`. The wrapper exits 0 on clean user quit (no RESTART_FILE), exit 130 on SIGINT. systemd only restarts on abnormal exit. Add `RestartPreventExitStatus=0 130` to be explicit.

### Anti-Pattern 2: Type=forking for the Wrapper

**What people do:** Use `Type=forking` because the wrapper "starts child processes."

**Why it's wrong:** The wrapper does not fork-and-exit. It stays in the foreground running the loop. Type=forking tells systemd the initial process will exit after forking the real daemon — that is not what happens here. systemd will declare the service "failed" immediately when it sees the wrapper is still running.

**Do this instead:** Use `Type=simple`. The wrapper is the main process. systemd tracks it directly.

### Anti-Pattern 3: Running Watchdog from a Grand-Child Process

**What people do:** Have the claude process (or a script it spawns) call `systemd-notify WATCHDOG=1`.

**Why it's wrong:** systemd only accepts watchdog notifications from the main process (wrapper PID) or processes in its cgroup, depending on `NotifyAccess`. Grand-child processes (wrapper → claude → subshell) may not have the right credentials to deliver the notification. This is a known systemd limitation (issue #25961).

**Do this instead:** Run the watchdog subshell directly from the wrapper script, before or alongside the claude invocation. The subshell inherits the wrapper's process group and credentials.

### Anti-Pattern 4: Replacing the Wrapper Loop with Pure systemd

**What people do:** Remove claude-wrapper, set `ExecStart=claude ...` directly in the unit file, and rely on systemd's `Restart=` for all restarts.

**Why it's wrong:** The v1.0 restart mechanism depends on the wrapper loop reading RESTART_FILE to pass new CLI args on relaunch. systemd cannot do this — it always restarts with the same `ExecStart` command. The `/clear` use case (restart with different mode) requires the wrapper.

**Do this instead:** Keep the wrapper as `ExecStart`. systemd manages wrapper-level crashes; wrapper manages within-session restarts with arg changes.

### Anti-Pattern 5: tmux as the Persistence Layer

**What people do:** `ExecStart=tmux new-session -d -s claude ...` so the service runs in tmux.

**Why it's wrong:** tmux uses `Type=forking` incompatibly, exits immediately after spawning the detached session confusing systemd, and the watchdog cannot reach the inner process. The session also doesn't attach to journald for log capture.

**Do this instead:** Run the wrapper directly as `ExecStart`. Use `journalctl -fu claude` to see logs. If interactive access is needed, `systemctl stop claude` and run manually in tmux for that session.

---

## Build Order (Dependencies)

| Order | Component | Depends On | Rationale |
|-------|-----------|------------|-----------|
| 1 | Mode selection in wrapper | Nothing | Wrapper changes are prerequisite for everything else |
| 2 | remote-control compatibility test | Mode selection | Validate restart works with `claude remote-control` args |
| 3 | channels/Telegram compatibility test | Mode selection | Validate restart works with `--channels` args |
| 4 | systemd unit file | Validated wrapper | Unit file must reference working wrapper |
| 5 | install.sh systemd integration | systemd unit | Install adds systemd unit deployment + linger |
| 6 | Keep-alive (inline in wrapper) | Wrapper mode selection | Idle prevention only needed after mode works |
| 7 | Watchdog (inline in wrapper) | systemd unit installed | Watchdog subshell only useful when systemd WatchdogSec is set |

---

## Scaling Considerations

This is a personal VPS — one user, one claude session. Scaling is irrelevant. The architecture should optimize for simplicity and debuggability over throughput.

| Concern | Approach |
|---------|----------|
| Multiple claude sessions | Out of scope (PROJECT.md) |
| Multiple VPS machines | Each VPS gets its own service instance; no coordination |
| Log retention | journald handles rotation; no additional tooling needed |

---

## Sources

- [systemd.service official docs — Type, WatchdogSec, Restart, NotifyAccess](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [sd_notify official docs — WATCHDOG=1 protocol](https://www.freedesktop.org/software/systemd/man/latest/sd_notify.html)
- [systemd GitHub issue #25961 — NotifyAccess grand-child limitation](https://github.com/systemd/systemd/issues/25961)
- [Claude Code Remote Control docs](https://code.claude.com/docs/en/remote-control)
- [Claude Code Channels docs](https://code.claude.com/docs/en/channels)
- [systemd user services — ArchWiki](https://wiki.archlinux.org/title/Systemd/User)
- [systemd-notify for bash scripts — Baeldung](https://www.baeldung.com/linux/systemd-notify)

---
*Architecture research for: VPS reliability layer — claude-wrapper + systemd + watchdog integration*
*Researched: 2026-03-20*
