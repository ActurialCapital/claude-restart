# Project Research Summary

**Project:** claude-restart — VPS Reliability Extension
**Domain:** Linux process management for persistent CLI sessions (systemd, watchdog, keep-alive)
**Researched:** 2026-03-20
**Confidence:** HIGH

## Executive Summary

This project extends an existing v1.0 bash wrapper (restart-on-exit loop + file-based restart signal) with VPS reliability features: crash recovery, boot persistence, hung-process detection, and mode-aware launch. The established approach for persistent Linux processes is a systemd user service — not tmux, not nohup, not cron. systemd with `loginctl enable-linger` handles boot persistence and crash recovery at the OS level, while the existing wrapper loop handles in-session restart-with-args-change. These two layers are complementary, not redundant, when configured correctly: the wrapper is the `ExecStart` target and systemd only acts when the wrapper itself dies unexpectedly.

The key architectural decision is that `claude remote-control` and `claude --channels plugin:telegram@...` have fundamentally different failure modes. Remote-control self-terminates after a ~10-minute network outage (systemd restart is the correct recovery). The Telegram plugin hangs silently without crashing — requiring a hung-process watchdog that no native systemd primitive fully handles. The recommended v1.1 approach is: (1) systemd user service with `Type=simple`, `Restart=on-failure`, and `WatchdogSec=120`; (2) a wrapper-inline watchdog subshell that pings `systemd-notify WATCHDOG=1` and stops pinging when the process is detected as hung; and (3) a periodic-restart fallback as the pragmatic health check, since a true semantic health probe for the Telegram plugin requires a live Telegram API round-trip.

The critical risks are: (a) the double-restart loop — using `Restart=always` instead of `Restart=on-failure` causes both systemd and the wrapper to react to the same exit; (b) SIGTERM not being forwarded from the bash wrapper to the Claude child process, causing `systemctl stop` to hang 90 seconds before SIGKILL; and (c) `StartLimitBurst` silently ignored if placed in the `[Service]` section instead of `[Unit]`. All three are mechanical bash/systemd issues with known fixes, not fundamental design problems.

## Key Findings

### Recommended Stack

The entire implementation is pure bash + systemd unit files — no new language dependencies, no external daemons, no monitoring agents. All reliability capabilities are available through primitives already on any modern Linux VPS. The only new executables are the systemd unit file template and minor modifications to the existing `claude-wrapper` script.

**Core technologies:**
- `systemd user service` (`~/.config/systemd/user/claude.service`): crash restart + boot persistence — native Linux init system, no external deps, correct lifecycle management for the wrapper process
- `loginctl enable-linger`: keeps user services running after SSH logout without requiring root — the canonical replacement for tmux-as-persistence on systemd distros
- `~/.config/environment.d/claude.conf`: injects env vars (CLAUDE_MODE, PATH) into the service — user services do not inherit shell environment; this is the correct systemd mechanism
- `systemd-notify` CLI (bash-compatible): sends `WATCHDOG=1` from inside bash without requiring the libsystemd C API — the wrapper subshell calls this rather than the claude process itself
- `tmux` (optional, development only): no longer needed for VPS persistence once systemd linger is active; acceptable for interactive debugging sessions

**What is NOT being added:** Python/Go watchdog daemon, custom monitoring agent, nohup-based PID tracking, screen, launchd, or system-level unit files requiring root.

### Expected Features

This is a subsequent milestone on top of a working v1.0. The discipline is to only build what `claude remote-control` and the existing wrapper do not already handle.

**Must have (table stakes) — v1.1:**
- Mode selection (`CLAUDE_MODE` env var): prerequisite for everything else; wrapper constructs the correct claude invocation from it
- Restart compatibility with remote-control mode: wrapper loop verified to handle `claude remote-control` exit behavior; sleep duration tuned for reconnect window
- Restart compatibility with Telegram channels mode: wrapper loop verified; Telegram plugin exit codes on hang documented
- systemd user service with auto-restart on crash: `Restart=on-failure`, `RestartSec=10`, `StartLimitBurst=10` in `[Unit]`
- Boot persistence via `loginctl enable-linger`: VPS must work after reboot without SSH login

**Should have (differentiators) — v1.1:**
- Watchdog for hung process detection: wrapper-inline subshell pinging `systemd-notify WATCHDOG=1`; stops pinging on hung detection; periodic-restart as pragmatic fallback
- SIGTERM forwarding in wrapper: run claude with `&`, capture PID, trap SIGTERM to forward — prevents 90-second `systemctl stop` delays

**Defer (v2+):**
- Keep-alive for Telegram idle: periodic no-op message to bot — only if idle-timeout is confirmed as an actual user-facing problem post-v1.1
- Native `WatchdogSec` with `Type=notify`: upgrade from external health check — adds complexity for marginal gain
- `/restart` slash command: already called out in PROJECT.md as a future milestone
- Multi-instance support: explicitly out of scope per PROJECT.md

**Anti-features (explicitly excluded):**
- Running both modes simultaneously
- Custom watchdog daemon as a second long-lived process
- tmux inside systemd service (cgroup conflict)
- Heartbeat via Claude API calls (burns credits, changes context)
- Session resume / context preservation across restarts

### Architecture Approach

The architecture is a two-level restart hierarchy with the existing wrapper unchanged as the primary unit. systemd wraps the wrapper: `systemd → watches → claude-wrapper → watches → claude`. The wrapper's internal restart loop is transparent to systemd — systemd sees the wrapper as "always running" while the loop continues. systemd only intervenes when the wrapper itself exits (crash or watchdog kill). The watchdog subshell runs inside the wrapper's process group, satisfying `NotifyAccess=main` without `NotifyAccess=all`. The unit file uses `Type=simple` (not `Type=forking` — the wrapper runs in the foreground and never forks).

**Major components:**
1. `claude-wrapper` (modified): foreground restart loop + mode-selection arg handling + watchdog subshell + SIGTERM forwarding
2. `claude.service` (new): systemd user unit — `Type=simple`, `Restart=on-failure`, `WatchdogSec=120`, `NotifyAccess=main`, `WantedBy=default.target`
3. `install.sh` (extended): OS detection (`uname`), systemd unit deployment to `~/.config/systemd/user/`, `loginctl enable-linger`, env var setup via `~/.config/environment.d/claude.conf`
4. `claude-restart` (unchanged): writes RESTART_FILE, kills claude via PPID walk — works identically in both modes
5. `~/.config/environment.d/claude.conf` (new): `CLAUDE_MODE`, `PATH`, and any other env vars the service needs at boot

**Build order enforced by dependencies:**
Mode selection → restart compatibility tests → systemd unit file → install.sh extension → keep-alive → watchdog

### Critical Pitfalls

1. **Double-restart loop (wrapper + systemd both restart on same exit)** — use `Restart=on-failure` not `Restart=always`; the wrapper handles intentional restarts, systemd handles crashes only; add `RestartPreventExitStatus=0 130` to be explicit
2. **SIGTERM not forwarded to Claude child** — switch from foreground `claude "${args[@]}"` to background `claude "${args[@]}" & claude_pid=$!; trap 'kill -TERM $claude_pid; wait $claude_pid' TERM; wait $claude_pid` — prevents 90s `systemctl stop` hangs and SIGKILL
3. **`StartLimitBurst` placed in `[Service]` section (silently ignored)** — must be in `[Unit]` section per systemd man page; verify with `systemctl show claude | grep StartLimit`
4. **Watchdog false positive on long-running Claude tasks** — use CPU activity + network connections as liveness signals, not output silence; set threshold to 10+ minutes minimum; CPU=0% alone is insufficient
5. **tmux and systemd cgroup conflict** — do not run `claude-wrapper` inside a tmux session managed as a service; choose one ownership model; `loginctl enable-linger` with systemd user service is the correct replacement for tmux-as-persistence

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Wrapper Hardening and Mode Selection

**Rationale:** Mode selection is the prerequisite for every other feature — the systemd unit's `ExecStart` must know which mode to invoke. SIGTERM forwarding must be in place before wrapping in a service, because `systemctl stop` will be broken without it. These wrapper changes are zero-dependency and unblock all subsequent phases.

**Delivers:** A wrapper that handles both modes cleanly, exits correctly on SIGTERM, and does not require any service infrastructure to test.

**Addresses:** Mode selection (P1), restart compatibility for both modes (P1), SIGTERM forwarding pitfall.

**Avoids:** Pitfall 4 (SIGTERM not forwarded) — must be fixed before service installation.

**Research flag:** Standard patterns — bash signal handling and env var mode selection are well-documented. No phase-level research needed.

---

### Phase 2: systemd Service Foundation

**Rationale:** Service installation depends on a working wrapper (Phase 1). This phase establishes the reliability platform — crash recovery, boot persistence, and the environment infrastructure — that the watchdog and keep-alive layers build on top of. All pitfalls related to systemd configuration (restart policy, StartLimitBurst placement, linger) must be addressed here before going unattended.

**Delivers:** `claude.service` unit file, `install.sh` extension with OS detection, `loginctl enable-linger`, `~/.config/environment.d/claude.conf`. Service survives crash and VPS reboot without SSH intervention.

**Uses:** `Type=simple`, `Restart=on-failure`, `RestartSec=10`, `StartLimitBurst=10` in `[Unit]`, `WantedBy=default.target`, `loginctl enable-linger`.

**Implements:** `claude.service` component, `install.sh` extension.

**Avoids:** Pitfall 1 (double-restart loop), Pitfall 2 (service enters failed state), Pitfall 5 (tmux/systemd cgroup conflict).

**Research flag:** Standard patterns — systemd user service with linger is extremely well-documented. No phase-level research needed. Verification checklist from PITFALLS.md should be used as acceptance criteria.

---

### Phase 3: Watchdog for Hung Process Detection

**Rationale:** The Telegram plugin's documented failure mode is alive-but-unresponsive — systemd's normal process monitoring cannot detect this. The watchdog must come after the service is installed (it requires `WatchdogSec` in the unit file and a running service to test against). This is Phase 3, not Phase 2, because the service must be validated in isolation before adding watchdog complexity.

**Delivers:** Wrapper-inline watchdog subshell pinging `systemd-notify WATCHDOG=1`; `WatchdogSec=120` in unit file; periodic-restart fallback via `claude-restart` on a systemd timer for the Telegram plugin's hung state.

**Implements:** Watchdog subshell in `claude-wrapper`, `WatchdogSec` + `NotifyAccess=main` in service unit, optional systemd timer for periodic restart.

**Avoids:** Pitfall 3 (false positive on long tasks — threshold 10+ minutes, CPU activity check), Pitfall 7 (remote-control timeout treated as crash — keep watchdog mode-aware).

**Research flag:** Needs deeper investigation during planning. The health check strategy for "alive but unresponsive" Telegram plugin has no perfect solution (see ARCHITECTURE.md options 1-5). The periodic-restart approach is recommended for v1.1, but the threshold and trigger mechanism need validation against actual Telegram plugin behavior. Consider a `/gsd:research-phase` focused on: what observable process signals distinguish a hung Telegram plugin from a busy one?

---

### Phase 4: Keep-Alive and Idle Prevention (Conditional)

**Rationale:** This phase is conditional on validation from Phase 3. If the periodic-restart watchdog (Phase 3) resolves the Telegram idle issue, this phase may be unnecessary. Keep-alive is mode-specific (Telegram only — remote-control has built-in reconnection) and adds complexity. Defer until Phase 3 is deployed and the gap is confirmed.

**Delivers:** Periodic no-op signal to the Telegram bot when no user activity within a configurable window; explicit suppression of keep-alive in remote-control mode.

**Avoids:** Pitfall 6 (keep-alive duplicating remote-control reconnection — must be mode-gated).

**Research flag:** Needs validation during planning. The Telegram Bot API mechanism for a "keep the plugin alive" signal is unclear from research. The correct approach (message frequency, content, whether a hidden heartbeat message is feasible) needs investigation. Only build if periodic restart in Phase 3 proves insufficient.

---

### Phase Ordering Rationale

- Mode selection must precede service installation because `ExecStart` must specify which mode to launch.
- SIGTERM forwarding must precede service installation because `systemctl stop` is broken without it.
- Service validation must precede watchdog addition because `WatchdogSec` interaction with the restart loop needs a stable baseline.
- Watchdog must precede keep-alive because keep-alive is only needed if the watchdog's periodic-restart approach does not sufficiently cover the idle-hang case.
- The entire dependency chain flows: wrapper changes → service → watchdog → (optional) keep-alive.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Watchdog):** Health check strategy for Telegram plugin hung detection is unresolved. The periodic-restart fallback is recommended but the correct threshold and whether CPU/network signals are observable from the wrapper need real-world testing. Consider `/gsd:research-phase` on Telegram plugin process behavior.
- **Phase 4 (Keep-Alive):** Feasibility of a keep-alive signal to the Telegram Bot API without generating visible user messages is unclear. Only relevant if Phase 3 proves insufficient.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Wrapper Hardening):** Bash signal forwarding with `&` + `wait` + `trap` is a well-established pattern with multiple authoritative sources.
- **Phase 2 (systemd Service):** systemd user service with linger has comprehensive official documentation and community validation. The pitfalls are known and enumerated.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | systemd primitives verified against official freedesktop.org docs; `loginctl enable-linger` behavior confirmed via ArchWiki and systemd changelogs; bash compatibility confirmed |
| Features | HIGH | Remote-control gaps confirmed via official Claude Code docs and GitHub issues; Telegram plugin failure mode confirmed via multiple issues (#15945, #33949); feature scope constrained by PROJECT.md |
| Architecture | HIGH (systemd mechanics), MEDIUM (claude process behavior) | systemd layering patterns are authoritative; claude Node.js process behavior under Telegram plugin load is inferred from GitHub issues, not benchmarked |
| Pitfalls | HIGH | Core pitfalls (SIGTERM, StartLimitBurst placement, Restart=always) verified against official docs and real bug reports; watchdog false positive threshold is heuristic |

**Overall confidence:** HIGH for Phase 1 and 2; MEDIUM for Phase 3 watchdog health check strategy.

### Gaps to Address

- **Telegram plugin hung-state observability:** No verified method for detecting "alive but unresponsive" vs "alive and working slowly" from outside the claude process. Research indicates CPU=0 + no network activity over 10+ minutes is a reasonable proxy, but this has not been validated against actual plugin hang scenarios. During Phase 3 planning, run a controlled hang simulation to calibrate the threshold.
- **`claude remote-control` exit codes:** The 10-minute network timeout exit code is documented as "process exits" but the specific exit code is not confirmed. PITFALLS.md recommends `Restart=always` for remote-control mode but FEATURES.md and ARCHITECTURE.md recommend `Restart=on-failure` for the wrapper. This tension needs resolution during Phase 2: either use mode-specific service files or accept that the wrapper's own exit code logic handles the distinction.
- **macOS install.sh behavior:** The install.sh OS detection branch (`uname` check) is documented but not yet implemented. For development workflow this is low priority, but the install script must not attempt to install systemd units on the development Mac.

## Sources

### Primary (HIGH confidence)
- [systemd.service man page — freedesktop.org](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html) — Type, WatchdogSec, Restart, StartLimitBurst, NotifyAccess
- [sd_notify man page — freedesktop.org](https://www.freedesktop.org/software/systemd/man/latest/sd_notify.html) — WATCHDOG=1, READY=1, systemd-notify CLI
- [Claude Code Remote Control official docs](https://code.claude.com/docs/en/remote-control) — reconnect behavior, 10-minute timeout, /clear not supported in remote-control server mode
- [Telegram plugin README — anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/telegram/README.md) — plugin behavior and limitations
- [systemd/User — ArchWiki](https://wiki.archlinux.org/title/Systemd/User) — user unit locations, lingering behavior, env var inheritance
- [systemd watchdog overview — Lennart Poettering](http://0pointer.de/blog/projects/watchdog.html) — WatchdogSec design rationale

### Secondary (MEDIUM confidence)
- [GitHub issue #15945 — MCP Server 16+ hour hang](https://github.com/anthropics/claude-code/issues/15945) — confirms alive-but-unresponsive pattern
- [GitHub issue #33949 — SSE streaming hangs with no timeout](https://github.com/anthropics/claude-code/issues/33949) — confirms no built-in timeout on Telegram plugin hang
- [GitHub issue #34255 — Remote Control silent connection drop](https://github.com/anthropics/claude-code/issues/34255) — confirms remote-control failure mode behavior
- [systemd GitHub issue #25961 — NotifyAccess grand-child limitation](https://github.com/systemd/systemd/issues/25961) — watchdog subshell must be direct child of wrapper
- [SIGTERM propagation in bash — veithen.io](https://veithen.io/2014/11/16/sigterm-propagation.html) — background + wait + trap pattern
- [systemd StartLimitIntervalSec placement issue — copyprogramming.com](https://copyprogramming.com/howto/systemd-s-startlimitintervalsec-and-startlimitburst-never-work) — [Unit] vs [Service] placement confirmed
- [Tmux systemd service — GitHub Gist](https://gist.github.com/lionell/34c6d2bc58df11462fb73d034b2d21d1) — Type=oneshot vs Type=simple for tmux (reference for anti-pattern)
- [KillUserProcesses tmux persistence issue — tmux GitHub #438](https://github.com/tmux/tmux/issues/438) — cgroup kill on SSH logout

### Tertiary (LOW confidence)
- [sdlogwatchdog — detecttechnologies](https://github.com/detecttechnologies/sdlogwatchdog) — log staleness watchdog pattern (reference only; not used in implementation)

---
*Research completed: 2026-03-20*
*Ready for roadmap: yes*
