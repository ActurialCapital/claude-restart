# Stack Research

**Domain:** VPS reliability for CLI process management (systemd, watchdog, keep-alive)
**Researched:** 2026-03-20
**Confidence:** HIGH (systemd primitives are stable and well-documented; bash patterns are established)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| systemd user services | 252+ (most current distros) | Auto-restart on crash, boot persistence | Native Linux init system; no external deps; handles restart, backoff, and failure limits without added tooling |
| `systemd-notify` CLI | bundled with systemd | Send WATCHDOG=1 and READY=1 from bash | Bash cannot call `sd_notify()` C API directly; `systemd-notify` wraps the Unix socket protocol without requiring libsystemd in scripts |
| `loginctl enable-linger` | bundled with systemd | Keep user services running after SSH logout | Without linger, user systemd units stop when the last session ends; linger spawns user manager at boot and keeps it across logouts |
| bash (existing) | 5.x | Wrapper loop and watchdog ping background loop | No new language dependency; watchdog ping is a 3-line background subshell inside the existing wrapper |
| tmux | 3.x (any recent) | Session persistence across SSH disconnects | Claude's TUI requires an attached terminal; tmux decouples the terminal from the SSH connection; SSH disconnect does not kill the session |

### Supporting Technologies

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| `systemctl --user` | bundled with systemd | Manage user-scoped services without root | All service management for this project; system-level (`sudo systemctl`) is unnecessary for a personal VPS user account |
| `~/.config/environment.d/*.conf` | systemd 233+ | Inject environment variables into user service | User services do not inherit shell env (PATH, CLAUDE_RESTART_FILE, etc.); this is the canonical way to set them for systemd user units |
| `~/.ssh/config` ServerAliveInterval | OpenSSH 3.8+ (universal) | Prevent SSH client-side idle disconnect | Keeps the SSH connection alive from the client; complements tmux for users who want to stay connected rather than detach |

### What Is NOT Being Added

This project stays pure bash + systemd unit files. No external languages, daemons, or monitoring agents are introduced.

## Unit File Architecture

### Service Type Decision

**Use `Type=forking` for the systemd unit that starts a tmux session containing claude-wrapper.**

Rationale: `tmux new-session -d` forks and the parent exits immediately — this is exactly the Type=forking lifecycle. `Type=simple` would cause systemd to track the wrong PID (the tmux command itself rather than the server). `Type=notify` is only appropriate when the `ExecStart` process itself sends `READY=1`, which claude-wrapper does not do natively (it is a TUI, not a notify-aware daemon).

Alternative: `Type=oneshot` with `RemainAfterExit=yes` is used by many tmux-as-service examples and avoids the PID tracking problem of Type=forking. This is acceptable when watchdog signaling is not needed. For this project (no active watchdog from inside the tmux session), `Type=oneshot RemainAfterExit=yes` is the safer choice.

**Recommendation: `Type=oneshot` with `RemainAfterExit=yes` and `KillMode=none`.**

`KillMode=none` is required so that `systemctl --user stop` does not kill the tmux session (and thus claude) without giving it a chance to exit cleanly.

### Watchdog Decision

**Watchdog is NOT recommended as a systemd unit directive for this project.** Here is why:

- `WatchdogSec` + `Type=notify` requires the foreground process to call `systemd-notify WATCHDOG=1` on a regular cadence. Claude (the node process) does not do this.
- The wrapper script (claude-wrapper) runs inside tmux, not as the direct `ExecStart` process. Systemd cannot monitor it as a notify-aware service through tmux.
- The problem to solve (Telegram plugin goes unresponsive without crashing) is an application-level hang, not a process crash. Systemd's `WatchdogSec` detects the service process disappearing — it does not detect application-level hangs.

**Alternative watchdog approach (correct for this use case):** A separate bash watchdog script, run on a cron/systemd timer, that checks for application-level responsiveness — e.g., monitoring a heartbeat file that claude-wrapper touches on each restart, or detecting stale process state via `ps` + elapsed time heuristics. This does not require `Type=notify` and works inside the tmux session boundary.

### Keep-Alive Decision

**Claude Telegram plugin idle timeout is an application-level event, not an SSH/network event.** The plugin goes unresponsive when Claude has no work to do and the Telegram channel sits idle. The correct keep-alive is an activity signal to the claude session itself (e.g., a periodic no-op message or a `/clear` via the restart mechanism), not an SSH keepalive.

SSH keepalive (`ServerAliveInterval`) prevents SSH client disconnects and is worth documenting but does not address the plugin hang.

## Installation

No `npm install` or package installation. All new artifacts are plain files:

```bash
# Create user systemd unit directory (if not exists)
mkdir -p ~/.config/systemd/user

# Place unit file (created by install.sh extension)
# ~/.config/systemd/user/claude.service

# Create environment config directory
mkdir -p ~/.config/environment.d

# Place env file
# ~/.config/environment.d/claude.conf

# Enable lingering (run once, requires root or the user themselves)
loginctl enable-linger "$USER"

# Enable and start the service
systemctl --user daemon-reload
systemctl --user enable claude.service
systemctl --user start claude.service
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| systemd user service | cron `@reboot` | On systems without systemd (SysV init, BSD); cron has no restart-on-crash, no proper dependency ordering |
| systemd user service | `nohup` + PID file managed in bash | Appropriate if no systemd; adds ~30 LOC of fragile bash to track PID, handle crashes, and restart; inferior to systemd |
| `Type=oneshot RemainAfterExit=yes` | `Type=forking` with PIDFile | Type=forking prevents multiple tmux sessions on the same user; Type=oneshot is cleaner for this use case |
| Application-level watchdog timer | `WatchdogSec` in unit file | `WatchdogSec` is appropriate when the ExecStart process itself can send `WATCHDOG=1`; not usable through tmux indirection |
| `loginctl enable-linger` | system-level service (`/etc/systemd/system/`) | System-level service requires root every time; linger enables user ownership of the service lifecycle |
| tmux | screen | tmux has better session management, scriptable panes, and is the current standard; screen is largely deprecated |
| `~/.config/environment.d/` | `EnvironmentFile=` in unit | Both work; `environment.d` applies to all user services and survives unit file regeneration by install.sh |
| SSH `ServerAliveInterval` | Nothing | Without it, idle SSH connections drop; the client-side config is the simplest fix with no server-side changes needed |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `Type=notify` for the tmux wrapper service | Requires the ExecStart process to call `systemd-notify READY=1`; tmux's `new-session -d` exits immediately without sending it, leaving systemd waiting forever (timeout → failure) | `Type=oneshot RemainAfterExit=yes` |
| `WatchdogSec` without a notify-aware ExecStart | Systemd kills the service if no WATCHDOG=1 arrives; claude inside tmux cannot reliably send this without a wrapper co-process — adds complexity for marginal gain | Application-level heartbeat file + systemd timer |
| System-level unit (`/etc/systemd/system/`) | Requires root for every enable/start/stop/restart; breaks the "personal VPS, run as your own user" model | `~/.config/systemd/user/` with `loginctl enable-linger` |
| Python/Go watchdog daemon | Introduces a runtime dependency on a language not already in the project; over-engineering for a single hung-process pattern | ~20 lines of bash on a systemd timer |
| `nohup` for crash recovery | Does not restart on crash; only detaches from the terminal; masquerades as a solution while providing no reliability | systemd `Restart=always` |
| launchd on macOS | macOS is the development machine, not the VPS; the systemd service file is Linux-only and should be installed conditionally | Detect OS in install.sh; skip service install on macOS |

## Stack Patterns by Platform

**On Linux VPS (production):**
- Use systemd user service (`~/.config/systemd/user/claude.service`)
- `loginctl enable-linger` for boot persistence
- tmux session for terminal persistence across SSH disconnects
- `~/.config/environment.d/claude.conf` for env vars
- Application-level watchdog via systemd timer + bash health check script

**On macOS (development):**
- No service manager integration; the existing wrapper loop + shell alias is sufficient
- tmux is optional (Mac terminal stays open)
- Skip systemd-related install steps; install.sh must detect `uname` and branch

**Detecting OS in bash (for install.sh):**
```bash
if [[ "$(uname)" == "Linux" ]] && command -v systemctl &>/dev/null; then
    # Install systemd unit
fi
```

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| systemd user services | systemd 232+ | `loginctl enable-linger` user self-service added in 232; all current Ubuntu/Debian/Fedora/Arch have 252+ |
| `~/.config/environment.d/` | systemd 233+ | Universal on any distro shipping systemd after 2018 |
| `systemd-notify` CLI | systemd 209+ | Has been stable for over a decade; safe to rely on |
| `tmux new-session -d` | tmux 1.8+ | Detached session flag is ancient; no compatibility concern |
| `loginctl enable-linger` self-invocation | systemd 232+ | A user can enable their own linger without root since 232 |
| bash 5.x | All current Linux distros | bash 4.x also works; no bash 5 features needed in the new code |

## Sources

- [systemd/User — ArchWiki](https://wiki.archlinux.org/title/Systemd/User) — user unit locations, lingering behavior, env var inheritance (HIGH confidence)
- [sd_notify(3) — freedesktop.org](https://www.freedesktop.org/software/systemd/man/latest/sd_notify.html) — WATCHDOG=1, READY=1, systemd-notify CLI (HIGH confidence)
- [How to Set Up systemd Watchdog Monitoring — OneUptime](https://oneuptime.com/blog/post/2026-03-04-set-up-systemd-watchdog-monitoring-for-critical-services/view) — concrete unit file directives (MEDIUM confidence, blog source verified against official docs)
- [Tmux systemd service — GitHub Gist](https://gist.github.com/lionell/34c6d2bc58df11462fb73d034b2d21d1) — Type=forking vs Type=oneshot for tmux (MEDIUM confidence, community example)
- [Arch Linux Forums — Tmux Autostart Systemd User Session](https://bbs.archlinux.org/viewtopic.php?id=247292) — Type=oneshot RemainAfterExit pattern (MEDIUM confidence, community-validated)
- WebSearch: systemd WatchdogSec bash sd_notify 2025 — confirms systemd-notify CLI as the bash-compatible approach (MEDIUM confidence, multiple sources)
- WebSearch: macOS launchd vs systemd cross-platform 2025 — confirms OS detection pattern is the right approach (MEDIUM confidence)

---
*Stack research for: claude-restart VPS reliability (systemd service, watchdog, keep-alive)*
*Researched: 2026-03-20*
