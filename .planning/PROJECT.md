# Claude Restart

## What This Is

A restart mechanism for Claude Code that lets you restart the CLI session with new options from within a running session. Consists of a wrapper script that runs claude in a loop, a restart script that Claude executes to trigger the cycle, and a shell alias for convenience.

## Core Value

Claude can be restarted with new CLI options from within a session without manual exit-and-retype.

## Requirements

### Validated

- [x] Wrapper script runs claude in a loop, checking a restart file on exit — Validated in Phase 01: wrapper-script
- [x] Restart script writes options to a file and kills the current claude process — Validated in Phase 02: restart-script
- [x] After kill, wrapper sleeps 2s then relaunches `claude` with the new options — Validated in Phase 02: restart-script
- [x] Restarts in the same terminal and working directory — Validated in Phase 02: restart-script
- [x] All valid claude CLI flags pass through (especially `--dangerously-skip-permissions`, `--channels`) — Validated in Phase 02: restart-script

### Active
- [ ] Shell alias/function for launching claude via the wrapper

### Out of Scope

- Slash command integration (`/restart`) — v2, not v1
- Multi-instance support — assumes one claude session at a time
- Session resume/context preservation across restarts — not in scope for v1

## Context

- Claude Code is a Node.js TUI that runs as a foreground process
- Process chain when Claude runs a tool: wrapper → claude (node) → bash (sandbox) → script
- The restart script can find claude's PID by walking up the process tree (grandparent of the script)
- A fixed restart file at `~/.claude-restart` coordinates between wrapper and restart script
- Key flags the user regularly passes: `--dangerously-skip-permissions`, `--channels plugin:telegram@claude-plugins-official`

## Constraints

- **Shell**: zsh on macOS — script and alias must work in zsh
- **Platform**: macOS (Darwin) — process management uses macOS-compatible tools
- **Simplicity**: Two scripts + one alias, no external dependencies

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wrapper loop pattern over background process | Background processes can't reliably take over the terminal for a TUI app | ✓ Implemented |
| Fixed restart file (`~/.claude-restart`) | Simple coordination, no PID tracking needed between wrapper and restart script | ✓ Implemented |
| Kill via process tree walk (`$PPID` chain) | More reliable than `pkill` pattern matching for finding the right claude process | ✓ Implemented |

---
*Last updated: 2026-03-20 — Phase 02 complete*
