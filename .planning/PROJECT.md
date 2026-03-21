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

### Active

- [ ] Restart mechanism works with `claude remote-control`
- [ ] Restart mechanism works with `claude --channels plugin:telegram@...`
- [ ] Mode selection — choose which mode to run at launch
- [ ] systemd service for auto-restart on crash and boot
- [ ] Watchdog for detecting unresponsive state (process alive but hung)
- [ ] Keep-alive to prevent idle timeout
- [ ] Only build VPS infrastructure for gaps not covered by remote-control

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

Shipped v1.0 with 201 LOC shell + 415 LOC tests.
Tech stack: Pure bash, zsh shell integration, no external dependencies.
3 scripts: `bin/claude-wrapper` (55 lines), `bin/claude-restart` (60 lines), `bin/install.sh` (86 lines).
23 test cases, 41 assertions, all passing.

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
*Last updated: 2026-03-20 after v1.1 milestone started*
