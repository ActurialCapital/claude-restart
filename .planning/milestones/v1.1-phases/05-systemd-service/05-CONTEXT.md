# Phase 5: systemd Service - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Claude runs as a systemd user service that survives crashes, VPS reboots, and SSH logouts without any manual intervention. The installer handles all setup in a single SSH session. User manages the VPS from their phone — minimal logins.

</domain>

<decisions>
## Implementation Decisions

### Unit file design
- **D-01:** Unit file installed to `~/.config/systemd/user/claude.service`
- **D-02:** All env vars (ANTHROPIC_API_KEY, PATH, CLAUDE_CONNECT) in a single EnvironmentFile at `~/.config/claude-restart/env` — no Environment= lines in the unit file
- **D-03:** `--dangerously-skip-permissions` hardcoded in ExecStart — always needed on personal VPS
- **D-04:** `Restart=on-failure` (not `always`) to avoid double-restart loop with wrapper
- **D-05:** `StartLimitBurst=5` and `StartLimitIntervalSec=60` in `[Unit]` section (not `[Service]`)
- **D-06:** WorkingDirectory set to a specific project directory, baked in by installer

### Installer Linux path
- **D-07:** Single `install.sh` with platform detection — macOS gets zshrc-only (current behavior), Linux gets systemd setup only (no zshrc)
- **D-08:** Installer auto-runs `loginctl enable-linger $USER` (fails gracefully if not permitted)
- **D-09:** Installer runs `systemctl --user daemon-reload`, `enable claude`, and `start claude` — service is running immediately after install
- **D-10:** Installer asks for working directory path during setup and bakes it into the unit file
- **D-11:** Installer creates env file at `~/.config/claude-restart/env`, prompts for API key, pre-fills PATH and CLAUDE_CONNECT, sets chmod 600

### Service management
- **D-12:** `claude-service` helper script with 5 subcommands: start, stop, restart, status, logs
- **D-13:** `logs` subcommand wraps `journalctl --user -u claude -f`
- **D-14:** Logs go to journald only — no separate log file

### Claude's Discretion
- ExecStart path construction (absolute paths to wrapper)
- RestartSec value (delay between crash and restart)
- claude-service script location (alongside other scripts in ~/.local/bin)
- Unit file [Install] section (WantedBy=default.target)
- How installer detects Linux vs macOS (uname check)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Wrapper (what systemd wraps)
- `bin/claude-wrapper` — The script ExecStart points to. Has SIGTERM handling, CLAUDE_CONNECT mode selection, restart loop
- `bin/install.sh` — Current installer that must be extended with Linux/systemd branch

### Project state
- `.planning/STATE.md` — Prior decisions on Restart=on-failure, StartLimitBurst placement, exit code concerns
- `.planning/REQUIREMENTS.md` — SYSD-01, SYSD-02, SYSD-03 requirement definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/claude-wrapper` — Already handles SIGTERM forwarding, CLAUDE_CONNECT, and restart loop. Systemd just needs to exec it.
- `bin/install.sh` — Has sentinel-based idempotent install pattern. Linux branch can follow same structure.

### Established Patterns
- Sentinel markers (`>>> claude-restart >>>`) for idempotent file modifications
- Environment variable overrides for testability (CLAUDE_RESTART_FILE, CLAUDE_WRAPPER_MAX_RESTARTS, etc.)
- Platform-specific behavior gated by simple conditionals

### Integration Points
- ExecStart must point to the installed `claude-wrapper` (in `~/.local/bin/`)
- EnvironmentFile must set CLAUDE_CONNECT so wrapper's mode_args are populated
- Wrapper's SIGTERM trap must work when systemd sends SIGTERM on `systemctl stop`

</code_context>

<specifics>
## Specific Ideas

- User manages VPS from phone — installer must be fully self-contained, ask all questions during one SSH session, service works immediately after
- No manual file editing after install — everything configured upfront
- `claude remote-control` with `--dangerously-skip-permissions` is the primary use case

</specifics>

<deferred>
## Deferred Ideas

- Watchdog/periodic restart timer — Phase 6
- Keep-alive heartbeat — Phase 6
- `claude remote-control` exit code on 10-min network timeout — resolve during planning (affects RestartPreventExitStatus)

</deferred>

---

*Phase: 05-systemd-service*
*Context gathered: 2026-03-21*
