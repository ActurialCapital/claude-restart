# Claude Restart

## What This Is

A multi-instance management system for Claude Code on Linux VPS. Provides a reliability layer (wrapper loop, systemd services, watchdog timers) and an orchestration platform where multiple isolated Claude "instruments" — each in its own project folder and repo — are managed by systemd template units, with an optional autonomous "orchestra" session that supervises, dispatches work, and controls instrument lifecycle across projects.

## Core Value

Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.

## Requirements

### Validated

- ✓ Wrapper script runs claude in a loop, checking a restart file on exit — v1.0
- ✓ Wrapper sleeps 2s before relaunching claude — v1.0
- ✓ Wrapper passes through initial CLI options on first launch — v1.0
- ✓ Wrapper reads new options from restart file on subsequent launches — v1.0
- ✓ Wrapper stays in same terminal and working directory — v1.0
- ✓ Restart script writes CLI args to restart file — v1.0
- ✓ Restart script finds and kills claude via PPID chain walk — v1.0
- ✓ Default restart writes env var defaults when no args given — v1.0
- ✓ Shell alias/function launches claude via the wrapper — v1.0
- ✓ Install script with idempotent zshrc modification — v1.0
- ✓ SIGTERM forwarding to child process, SIGHUP ignore — v1.1
- ✓ Mode selection via CLAUDE_CONNECT env var (remote-control, telegram, interactive) — v1.1
- ✓ Mode-aware restart (mode base args preserved across restarts) — v1.1
- ✓ Installer uses CLAUDE_CONNECT instead of hardcoded channel string — v1.1
- ✓ systemd user service with Restart=on-failure and StartLimitBurst — v1.1
- ✓ Environment file template for API keys and config — v1.1
- ✓ claude-service management helper (start/stop/restart/status/logs) — v1.1
- ✓ Linux installer path deploying systemd artifacts with linger — v1.1
- ✓ Watchdog timer for periodic forced restart (mode-aware, skips remote-control) — v1.1
- ✓ Keep-alive heartbeat via FIFO stdin in telegram mode — v1.1
- ✓ Installer deploys watchdog timer/oneshot with configurable interval — v1.1
- ✓ claude-service watchdog and heartbeat status subcommands — v1.1
- ✓ systemd template units (`claude@.service`) for multi-instance instrument management — v2.0
- ✓ Per-instance env files with isolated API key, CLAUDE_CONNECT, working directory — v2.0
- ✓ Per-instance restart files via CLAUDE_RESTART_FILE — v2.0
- ✓ MemoryMax cgroup limits per instrument — v2.0
- ✓ Backward-compatible single-instance mode when no name provided — v2.0
- ✓ Instrument lifecycle tooling — add/remove/list with single command — v2.0
- ✓ Per-instance watchdog timers auto-paired with instrument lifecycle — v2.0
- ✓ Wrapper passes --name to remote-control, restart accepts --instance — v2.0
- ✓ Dynamic instrument awareness — detect hot-added/removed instruments while running — v2.0
- ✓ Optional autonomous orchestra — supervisor/dispatcher across projects — v2.0
- ✓ Orchestra uses `claude-restart` to reboot instruments between phases (context reset) — v2.0
- ✓ Orchestra spawns ad-hoc agents in project directories for research questions — v2.0
- ✓ Orchestra auto-provisioned with MCP config and CLAUDE.md — zero manual setup — v2.0
- ✓ All sessions use `remote-control` mode, both interaction models coexist (direct + orchestra) — v2.0

### Active

(none — planning next milestone)

### Out of Scope

- Slash command integration (`/restart`) — future milestone
- Session resume/context preservation across restarts — not in scope
- Smart watchdog with activity detection — periodic restart is simpler and avoids false positives
- launchd (macOS service management) — personal VPS is Linux; macOS is dev only
- Telegram integration — future add-on on top of remote-control
- Orchestra relay mode — autonomous only; direct access covers manual interaction
- Orchestra making project-level implementation decisions — instruments hold project intelligence
- Claude Agent Teams integration — designed for single-repo coordination, not cross-project orchestration
- Custom IPC protocol between sessions — `claude -p` and `claude-restart` are sufficient
- Running both modes simultaneously per instrument — either remote-control or telegram, not both

## Current State

**Shipped:** v2.0 Multi-Instance Orchestration (2026-03-24)
**Next:** Planning next milestone

All 3 milestones shipped:
- v1.0 MVP — wrapper loop, restart mechanism, shell integration
- v1.1 VPS Reliability — systemd service, watchdog, heartbeat, mode selection
- v2.0 Multi-Instance Orchestration — template units, instrument lifecycle, autonomous orchestra

## Context

Shipped v2.0 with ~5,200 LOC shell + tests across 3 milestones.
Tech stack: Pure bash, zsh shell integration, systemd for Linux service management.
Scripts: `bin/claude-wrapper`, `bin/claude-restart`, `bin/install.sh`, `bin/claude-service`.
Artifacts: `systemd/claude@.service` (template unit), `systemd/claude-watchdog@.service` (template watchdog), `systemd/claude-watchdog@.timer` (template timer), `systemd/env.template`. `orchestra/CLAUDE.md` (supervisor behavioral spec).

VPS environment: Personal Linux server with systemd. User manages VPS from phone, running multiple projects each with its own Claude instance and cloned repository. Architecture: "instruments" (isolated Claude sessions per project) + optional "orchestra" (autonomous supervisor). All sessions use `claude remote-control` for phone interaction. Two interaction models coexist: direct instrument access and centralized orchestra access.

Known tech debt (8 items from v2.0 audit, all low severity):
- CLAUDE_WATCHDOG_HOURS env var implies configurability but timer is hardcoded 8h
- NODEVERSION_PLACEHOLDER edge case in PATH copy
- --instance flag untested in test-restart.sh
- SUMMARY frontmatter missing 3 REQ-IDs (verified in VERIFICATION.md)
- 3 human verification items pending (live VPS runtime)
- jq/~/.claude.json graceful-skip path is warning-only
- test/test-install.sh Test 11 pre-existing failure

## Constraints

- **Shell**: bash/zsh — scripts must work on both macOS and Linux
- **Platform**: macOS (dev) + Linux VPS (production) — process management must be cross-platform where possible
- **Simplicity**: Minimal scripts, no external dependencies beyond systemd
- **VPS**: Personal setup, not a general-purpose distribution

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wrapper loop pattern over background process | Background processes can't reliably take over the terminal for a TUI app | ✓ Good |
| Fixed restart file (`~/.claude-restart`) | Simple coordination, no PID tracking needed between wrapper and restart script | ✓ Good |
| Kill via process tree walk (`$PPID` chain) | More reliable than `pkill` pattern matching for finding the right claude process | ✓ Good |
| Environment variable overrides for testability | Tests run in <1s instead of 20s+ with real delays | ✓ Good |
| Sentinel markers for zshrc modification | Enables idempotent install and clean uninstall | ✓ Good |
| Graceful degradation when PID not found | File still written so wrapper can restart even if kill fails | ✓ Good |
| CLAUDE_CONNECT env var for mode selection | Single env var maps to CLI args, shared by service + wrapper + watchdog via EnvironmentFile | ✓ Good |
| Restart=on-failure not Restart=always | Avoids double-restart loop (wrapper + systemd both reacting to same exit) | ✓ Good |
| FIFO-based stdin for heartbeat | Cross-platform (macOS + Linux), no process substitution dependency | ✓ Good |
| Mode-aware watchdog (telegram only) | remote-control has built-in reconnection, watchdog would cause unnecessary disruption | ✓ Good |
| StartLimitBurst in [Unit] not [Service] | Silently ignored in [Service] section — systemd gotcha discovered during Phase 05 | ✓ Good |
| MemoryMax via ExecStartPre + systemctl set-property | Env vars not supported in systemd resource control directives | ✓ Good |
| Hardcoded 8h watchdog timer intervals | systemd timer directives cannot read env vars; env.template variable is documentation-only | ✓ Good |
| Orchestra CLAUDE.md as pure prompt engineering | The CLAUDE.md IS the orchestra — no code needed beyond the behavioral spec | ✓ Good |
| FIFO stdin for remote-control (same as telegram) | Unified pattern, heartbeat prevents session death, `y` auto-confirms prompts | ✓ Good |
| Instruments as isolated folders with own repos | Clean separation, each instrument manages its own project intelligence | ✓ Good |
| Orchestra is optional, autonomous-only | Direct access covers manual interaction; no relay mode needed | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-24 after v2.0 milestone completion*
