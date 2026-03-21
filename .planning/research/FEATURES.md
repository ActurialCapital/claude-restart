# Feature Research

**Domain:** VPS reliability for persistent Claude Code sessions (systemd, watchdog, keep-alive, mode selection)
**Researched:** 2026-03-20
**Confidence:** HIGH

## Context

This is a subsequent milestone. v1.0 already ships: wrapper loop, restart trigger, shell integration, installer.
The question is what NEW features are needed for VPS reliability. Remote-control mode has its own built-in
behaviors — the key discipline is "only build what remote-control doesn't already handle."

## What remote-control Already Provides (Do Not Rebuild)

`claude remote-control` (server mode) provides out of the box:
- Automatic reconnection after network drop or laptop sleep
- Session URL + QR code for mobile/browser access
- Multi-device sync (terminal + web + phone interchangeably)
- Local environment preservation (filesystem, MCP, tools)
- `--spawn` for multiple concurrent sessions from one process

**Confirmed gaps in remote-control** (from official docs + GitHub issues):
- **Terminal must stay open**: if the process dies, session ends — requires external process management
- **Network timeout**: if machine is unreachable for ~10 minutes, session exits — requires restart
- **No crash recovery**: does not restart itself on non-zero exit
- **No boot persistence**: does not survive VPS reboot without external service manager
- **Hung process**: process alive but unresponsive is not detected (known GitHub issues #15945, #13224, #33949)
- **No /clear equivalent**: remote-control mode does not support `/clear` — v1.0 restart mechanism is required for context resets

## Feature Landscape

### Table Stakes (Users Expect These)

Features that make the VPS setup feel complete and reliable. Missing these = "why even run it on a VPS?"

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **systemd service with auto-restart on crash** | Standard Linux daemon pattern — any persistent VPS process should survive crashes | LOW | `Restart=always`, `RestartSec=5`. `Type=simple` works since wrapper runs in foreground. Requires install step. |
| **Boot persistence** | VPS should work after reboot without SSH login | LOW | `WantedBy=multi-user.target` in unit file. Comes free with systemd service. |
| **Restart compatibility with remote-control mode** | The wrapper loop must not break when wrapping `claude remote-control` | LOW | Wrapper already loops on exit — verify exit code behavior and 2s sleep still appropriate. May need longer sleep for reconnect window. |
| **Restart compatibility with Telegram channel mode** | The wrapper loop must not break when wrapping `claude --channels plugin:telegram@...` | LOW | Same wrapper loop — verify Telegram plugin exit codes on hang vs crash. |
| **Mode selection at launch** | Choosing remote-control vs Telegram is the entry point — must be explicit and simple | LOW | Single env var or argument: `CLAUDE_MODE=remote-control` or `CLAUDE_MODE=telegram`. Wrapper reads it to construct the claude command. |

### Differentiators (Add Real Value Beyond Table Stakes)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Watchdog for unresponsive process detection** | Process alive but hung is the Telegram plugin's documented failure mode — without this, the VPS setup silently fails | MEDIUM | Two implementation paths: (1) systemd `WatchdogSec` + `systemd-notify WATCHDOG=1` loop in wrapper — requires `Type=notify` in unit file; (2) external health check script with `kill -0` + response probe on a schedule. Path 2 is simpler for a bash-only approach without modifying the wrapper to call `systemd-notify`. |
| **Keep-alive / idle heartbeat** | Prevents idle timeout on long-running sessions where Claude is waiting for input | MEDIUM | Two sub-problems: (a) prevent SSH/network idle disconnect — handled by systemd service running detached; (b) prevent Claude's own session idle timeout — requires periodic no-op input or a known Claude keepalive mechanism. Telegram mode: send a periodic message. Remote-control mode: the session does not appear to have a user-facing idle timeout distinct from the network 10-min timeout. |

### Anti-Features (Do Not Build)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Running both modes simultaneously** | More coverage | Out of scope per PROJECT.md; single claude instance assumption; wrapper handles one process | Choose mode at launch via `CLAUDE_MODE` |
| **Custom watchdog daemon / external monitor process** | Seems robust | Adds a second long-lived process to manage; systemd already has first-class watchdog support via `WatchdogSec` | Use systemd's built-in watchdog with `systemd-notify` |
| **tmux session management** | Familiar VPS pattern for interactive sessions | Complicates systemd integration; tmux session != systemd service lifecycle; adds dependency | systemd service manages the process directly; use `--remote-control` flag for interactive access from phone/browser |
| **Heartbeat via Claude API calls** | Ensures Claude is responsive | Consumes API credits; response is not guaranteed; changes Claude's context | systemd watchdog via wrapper-level health check; restart is cheaper than credit burn |
| **Session resume / context preservation** | Continuity across restarts | Out of scope per PROJECT.md; v1.0 restart already resets intentionally; remote-control preserves conversation via Anthropic infra | Accept restart = fresh context; remote-control handles conversation continuity |
| **Rate-limit-aware restart backoff** | Avoid hammering API on repeated failures | Complex; rate limit behavior is not predictable from exit codes alone | `StartLimitBurst` + `StartLimitIntervalSec` in systemd unit provides simple backoff |

## Feature Dependencies

```
[systemd service unit]
    └──requires──> [Restart compatibility: remote-control mode]
    └──requires──> [Restart compatibility: Telegram mode]
    └──requires──> [Mode selection]

[Watchdog]
    └──requires──> [systemd service unit]
    └──enhances──> [Keep-alive] (watchdog fires when keepalive stops working)

[Mode selection]
    └──enables──> [Restart compatibility: remote-control mode]
    └──enables──> [Restart compatibility: Telegram mode]

[Keep-alive]
    └──requires──> [Mode selection] (keepalive strategy differs per mode)
```

### Dependency Notes

- **Mode selection must come first**: the systemd unit's `ExecStart` must know which mode to invoke; mode selection is the prerequisite for everything else.
- **Restart compatibility before watchdog**: confirm the wrapper loop works correctly with each mode's exit behavior before adding watchdog complexity on top.
- **Watchdog enhances keep-alive**: if keep-alive stops firing (process hung), watchdog catches it — they are complementary, not redundant.
- **systemd service is the platform for watchdog**: `WatchdogSec` lives in the unit file; cannot build watchdog without the service layer.

## MVP Definition

### Launch With (v1.1)

Minimum viable VPS reliability — survives crashes and reboots, runs correct mode.

- [ ] **Mode selection** — `CLAUDE_MODE` env var (`remote-control` or `telegram`); wrapper builds the claude command from it — *prerequisite for everything*
- [ ] **Restart compatibility: remote-control mode** — wrapper loop verified to work; sleep duration appropriate for reconnect window
- [ ] **Restart compatibility: Telegram mode** — wrapper loop verified to work; Telegram plugin exit codes on hang understood
- [ ] **systemd service with auto-restart** — unit file with `Restart=always`, `RestartSec=5`, `WantedBy=multi-user.target`; install step in `bin/install.sh`
- [ ] **Watchdog for hung process** — external health check approach (simpler than `Type=notify`): a timer-based script that probes the process and kills it if unresponsive, allowing systemd to restart

### Add After Validation (v1.x)

- [ ] **Keep-alive for Telegram idle** — periodic no-op message to bot if no activity within configurable window; only needed if Telegram plugin is confirmed to idle-timeout
- [ ] **systemd `WatchdogSec` integration** — upgrade from external health check to native systemd watchdog if `Type=notify` proves manageable in bash wrapper

### Future Consideration (v2+)

- [ ] **Slash command `/restart`** — already called out in PROJECT.md as future milestone
- [ ] **Multi-instance support** — out of scope per PROJECT.md

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Mode selection | HIGH | LOW | P1 |
| Restart compat: remote-control | HIGH | LOW | P1 |
| Restart compat: Telegram | HIGH | LOW | P1 |
| systemd service (crash + boot) | HIGH | LOW | P1 |
| Watchdog for hung process | HIGH | MEDIUM | P1 |
| Keep-alive for Telegram idle | MEDIUM | MEDIUM | P2 |
| systemd native WatchdogSec | LOW | MEDIUM | P3 |

## Technical Notes by Feature

### systemd Service

- `Type=simple` is correct — wrapper runs in foreground, does not fork
- `Restart=always` catches all exits including non-zero
- `RestartSec=5` plus `StartLimitBurst=5` / `StartLimitIntervalSec=60` prevents restart storms
- User service (`systemctl --user`) vs system service: user service avoids root and is simpler for personal VPS
- `WantedBy=default.target` for user service; `WantedBy=multi-user.target` for system service
- `loginctl enable-linger <user>` required for user services to persist after logout

### Watchdog (External Health Check Approach)

- Simpler than native `WatchdogSec` for bash scripts: a separate `ExecStartPost` or systemd timer runs `kill -0 $PID` to confirm process exists, then probes responsiveness (e.g., checks a heartbeat file timestamp)
- Wrapper updates a timestamp file every N seconds as its "I am alive" signal
- Health check script compares timestamp to now; if stale beyond threshold, sends `SIGTERM` to wrapper PID — systemd restarts it
- This is the "log staleness" pattern used by tools like `sdlogwatchdog` — well-established for shell-based services

### Mode Selection

- Env var approach (`CLAUDE_MODE=remote-control`) fits existing pattern: PROJECT.md already uses env vars for testability
- Wrapper reads `CLAUDE_MODE`, constructs the appropriate `claude` invocation
- Default: if unset, fall back to `CLAUDE_MODE=telegram` (the primary VPS use case per PROJECT.md context)

### Restart Compatibility

- `claude remote-control`: exits with non-zero if network unreachable for ~10 min — wrapper's existing loop handles this; 2s sleep may need to be 5-10s to allow Anthropic infra to clear the session before reconnect
- `claude --channels plugin:telegram@...`: exits on hang only if process is killed externally (watchdog); otherwise stays alive but unresponsive — this is why watchdog is P1, not P2

## Sources

- [Claude Code Remote Control official docs](https://code.claude.com/docs/en/remote-control) — HIGH confidence
- [systemd.service man page](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) — HIGH confidence
- [systemd watchdog overview (Lennart Poettering)](http://0pointer.de/blog/projects/watchdog.html) — HIGH confidence
- [systemd-notify man page](https://www.freedesktop.org/software/systemd/man/latest/sd_notify.html) — HIGH confidence
- [Telegram plugin README](https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/telegram/README.md) — HIGH confidence
- [GitHub issue #15945: MCP Server 16+ hour hang](https://github.com/anthropics/claude-code/issues/15945) — MEDIUM confidence (confirms hung-without-crash pattern)
- [GitHub issue #33949: SSE streaming hangs with no timeout](https://github.com/anthropics/claude-code/issues/33949) — MEDIUM confidence
- [GitHub issue #34255: Remote Control silent connection drop](https://github.com/anthropics/claude-code/issues/34255) — MEDIUM confidence
- [sdlogwatchdog: staleness-based watchdog for systemd](https://github.com/detecttechnologies/sdlogwatchdog) — MEDIUM confidence (reference pattern)

---
*Feature research for: VPS reliability — systemd, watchdog, keep-alive, mode selection*
*Researched: 2026-03-20*
