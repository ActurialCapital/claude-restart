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

(none — planning next milestone)

### Out of Scope

- Slash command integration (`/restart`) — future milestone
- Multi-instance support — assumes one claude session at a time
- Session resume/context preservation across restarts — not in scope
- Cross-platform (Linux/Windows) — macOS-only for now

## Context

Shipped v1.0 with 201 LOC shell + 415 LOC tests.
Tech stack: Pure bash, zsh shell integration, no external dependencies.
3 scripts: `bin/claude-wrapper` (55 lines), `bin/claude-restart` (60 lines), `bin/install.sh` (86 lines).
23 test cases, 41 assertions, all passing.

## Constraints

- **Shell**: zsh on macOS — script and alias must work in zsh
- **Platform**: macOS (Darwin) — process management uses macOS-compatible tools
- **Simplicity**: Two scripts + one alias, no external dependencies

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wrapper loop pattern over background process | Background processes can't reliably take over the terminal for a TUI app | ✓ Good |
| Fixed restart file (`~/.claude-restart`) | Simple coordination, no PID tracking needed between wrapper and restart script | ✓ Good |
| Kill via process tree walk (`$PPID` chain) | More reliable than `pkill` pattern matching for finding the right claude process | ✓ Good |
| Environment variable overrides for testability | Tests run in <1s instead of 20s+ with real delays | ✓ Good |
| Sentinel markers for zshrc modification | Enables idempotent install and clean uninstall | ✓ Good |
| Graceful degradation when PID not found | File still written so wrapper can restart even if kill fails | ✓ Good |

---
*Last updated: 2026-03-21 after v1.0 milestone*
