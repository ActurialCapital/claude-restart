# Claude Restart

## What This Is

A restart mechanism for Claude Code that lets you restart the CLI session with new options from within a running session. Two shell scripts (wrapper + restart trigger) and an installer provide seamless restart-and-relaunch with full argument forwarding.

## Core Value

Claude can be restarted with new CLI options from within a session without manual exit-and-retype.

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
- ✓ SIGTERM forwarding to child process, SIGHUP ignore — Phase 04
- ✓ Mode selection via CLAUDE_CONNECT env var (remote-control, telegram, interactive) — Phase 04
- ✓ Mode-aware restart (mode base args preserved across restarts) — Phase 04
- ✓ Installer uses CLAUDE_CONNECT instead of hardcoded channel string — Phase 04
- ✓ systemd user service with Restart=on-failure and StartLimitBurst — Phase 05
- ✓ Environment file template for API keys and config — Phase 05
- ✓ claude-service management helper (start/stop/restart/status/logs) — Phase 05
- ✓ Linux installer path deploying systemd artifacts with linger — Phase 05
- ✓ Watchdog timer for periodic forced restart (mode-aware, skips remote-control) — Phase 06
- ✓ Keep-alive heartbeat via FIFO stdin in telegram mode — Phase 06
- ✓ Installer deploys watchdog timer/oneshot with configurable interval — Phase 06
- ✓ claude-service watchdog and heartbeat status subcommands — Phase 06

### Active

(none — all v1.1 requirements validated)

### Out of Scope

- Slash command integration (`/restart`) — future milestone
- Multi-instance support — assumes one claude session at a time
- Session resume/context preservation across restarts — not in scope
- Running both modes simultaneously — either remote-control or Telegram, not both

## Current Milestone: v1.1 VPS Reliability

**Goal:** Make Claude Code resilient on a personal Linux VPS — survive crashes, SSH drops, and idle timeouts.

**Target features:**
- Restart compatibility with `claude remote-control` and `claude --channels plugin:telegram@...`
- Mode selection (either mode, not both simultaneously)
- systemd service for auto-restart
- Watchdog for hung/unresponsive detection
- Keep-alive for idle timeout prevention
- Only build what remote-control doesn't already handle

## Context

Shipped v1.0 with 201 LOC shell + 415 LOC tests. Phase 04 added signal handling, mode selection, and mode-aware restart. Phase 05 added systemd service layer and Linux installer path. Phase 06 added watchdog timer for periodic forced restarts and FIFO-based keep-alive heartbeat for telegram mode.
Tech stack: Pure bash, zsh shell integration, systemd for Linux service management.
Scripts: `bin/claude-wrapper`, `bin/claude-restart`, `bin/install.sh`, `bin/claude-service`.
Artifacts: `systemd/claude.service`, `systemd/claude-watchdog.timer`, `systemd/claude-watchdog.service`, `systemd/env.template`.
82 assertions across 3 test suites, all passing.

VPS environment: Personal Linux server with systemd and tmux. Currently SSH in, start tmux, run claude manually. Telegram plugin (`--channels plugin:telegram@claude-plugins-official`) goes unresponsive without crashing — process alive but no response to messages. `claude remote-control` is an alternative mode but doesn't support `/clear`, so v1.0 restart mechanism is needed for context resets.

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
*Last updated: 2026-03-21 after Phase 06 watchdog-and-keep-alive complete*
