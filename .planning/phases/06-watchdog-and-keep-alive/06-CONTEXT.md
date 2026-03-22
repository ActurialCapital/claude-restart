# Phase 6: Watchdog and Keep-Alive - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Hung Telegram plugin sessions are detected and forcibly restarted on a schedule, and idle timeout is prevented by a periodic heartbeat. The watchdog is mode-aware: active for Telegram, suppressed for remote-control. User manages VPS from phone via Telegram — reliability is critical since SSH access for manual recovery is inconvenient.

</domain>

<decisions>
## Implementation Decisions

### Restart schedule
- **D-01:** Default forced restart every 8 hours, configurable via `CLAUDE_WATCHDOG_HOURS` in `~/.config/claude-restart/env`
- **D-02:** systemd timer (`claude-watchdog.timer`) triggers a oneshot service (`claude-watchdog.service`) that runs `systemctl --user restart claude`
- **D-03:** Graceful restart — SIGTERM via `systemctl restart`, uses existing TimeoutStopSec=10, then starts fresh

### Keep-alive mechanism
- **D-04:** Wrapper sends periodic newline/empty input to claude's stdin every 5 minutes when `CLAUDE_CONNECT=telegram`
- **D-05:** Each heartbeat logs a timestamp to journald (visible via `claude-service logs`)
- **D-06:** Heartbeat is first line of defense; 8-hour forced restart is safety net if heartbeat doesn't prevent hang
- **D-07:** Heartbeat frequency not configurable in v1.1 — hardcoded 5 minutes in wrapper

### Mode-aware suppression
- **D-08:** Timer always runs regardless of mode. The oneshot service reads `CLAUDE_CONNECT` from env file at fire time
- **D-09:** If `CLAUDE_CONNECT=remote-control`, oneshot logs "watchdog skipped: remote-control mode" and exits without restarting
- **D-10:** If `CLAUDE_CONNECT=telegram` (or any other value), oneshot proceeds with restart
- **D-11:** Wrapper heartbeat also gated on `CLAUDE_CONNECT=telegram` — no heartbeat in remote-control or interactive mode

### Installer and service integration
- **D-12:** Installer deploys 2 new systemd files: `claude-watchdog.timer` and `claude-watchdog.service`
- **D-13:** Installer runs `systemctl --user enable --now claude-watchdog.timer` alongside the main service
- **D-14:** `claude-service` gets 2 new subcommands: `watchdog` (timer status) and `heartbeat` (grep recent journald for heartbeat entries)
- **D-15:** env template gets `CLAUDE_WATCHDOG_HOURS=8` default
- **D-16:** Keep-alive heartbeat is built into claude-wrapper (no separate service)

### Claude's Discretion
- Timer unit OnBootSec vs OnUnitActiveSec configuration details
- Exact heartbeat implementation in wrapper (background subshell, loop integration, etc.)
- Watchdog oneshot script implementation (inline ExecStart or separate script)
- journald log format for heartbeat entries

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Wrapper (heartbeat goes here)
- `bin/claude-wrapper` — Main loop where heartbeat logic must be added. Has SIGTERM handling, CLAUDE_CONNECT mode selection, background wait pattern
- `bin/claude-service` — Gets 2 new subcommands (watchdog, heartbeat)

### systemd (timer/oneshot go here)
- `systemd/claude.service` — Existing service unit. Watchdog timer restarts this.
- `systemd/env.template` — Gets CLAUDE_WATCHDOG_HOURS variable

### Installer
- `bin/install.sh` — Must deploy new timer/oneshot files and enable timer

### Project state
- `.planning/STATE.md` — Prior decisions on Restart=on-failure, keep-alive is Telegram-only
- `.planning/REQUIREMENTS.md` — WDOG-01, KALV-01 requirement definitions
- `.planning/phases/05-systemd-service/05-CONTEXT.md` — Phase 5 decisions on unit file design, env file, installer patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/claude-wrapper` — Already runs claude in background with `wait`, has CLAUDE_CONNECT case statement. Heartbeat can use the same mode check.
- `bin/install.sh` — Has Linux systemd deployment path from Phase 5. Timer/oneshot deployment follows same pattern.
- `bin/claude-service` — Has case statement for subcommands. Adding watchdog/heartbeat follows existing pattern.
- `systemd/env.template` — Already has CLAUDE_CONNECT. Adding CLAUDE_WATCHDOG_HOURS is one line.

### Established Patterns
- Environment variable overrides for testability (CLAUDE_RESTART_FILE, CLAUDE_WRAPPER_MAX_RESTARTS, etc.)
- systemd files in `systemd/` directory, installed to `~/.config/systemd/user/`
- `claude-service` wraps systemctl commands with friendly output

### Integration Points
- Wrapper's `while true` loop and `wait` call — heartbeat must not interfere with signal handling or restart detection
- Oneshot service reads env file via `EnvironmentFile=` or sources it directly
- Installer's Linux branch (platform detection already exists) deploys timer alongside service

</code_context>

<specifics>
## Specific Ideas

- User runs multiple projects from phone, each with its own Claude instance and Telegram bot. Design watchdog/keep-alive to work naturally with future template units (claude@.service)
- The timer/oneshot naming should accommodate future per-instance timers (e.g., claude-watchdog@.timer)
- Heartbeat logging should include enough info to distinguish instances in future multi-instance setup

</specifics>

<deferred>
## Deferred Ideas

- Multi-instance support via systemd template units (claude@.service, claude-watchdog@.timer) — separate phase
- Smart watchdog with CPU/network activity detection (WDOG-02) — future requirement
- Configurable heartbeat frequency — hardcoded 5min is fine for v1.1
- Per-mode health check strategies (WDOG-03) — future requirement

</deferred>

---

*Phase: 06-watchdog-and-keep-alive*
*Context gathered: 2026-03-21*
