# Phase 1: Wrapper Script - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Loop mechanism that runs `claude` and relaunches it when a restart is signaled via `~/.claude-restart`. This phase covers the wrapper script only — the restart script that creates the signal file is Phase 2, and shell integration is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Script language & format
- Bash (`#!/bin/bash`) — portable across POSIX systems
- Distributed via `curl | bash` installer that copies scripts to `~/.claude/`
- Installed command name: `claude-restart`
- Repo contains both the wrapper script and the installer script; installer downloads/copies from GitHub release

### Restart file handling
- `~/.claude-restart` is deleted immediately after reading (prevents stale restarts)
- File format: Claude's discretion (simplest reliable format)
- Empty file = restart with original launch options (default restart behavior)

### Output & feedback
- Minimal output: print "Restarting claude..." on restart, nothing on normal exit
- Show the options being passed on restart (e.g., "Restarting claude with: --dangerously-skip-permissions ...")

### Signal handling & edge cases
- Ctrl+C kills the entire wrapper loop, not just claude — clean exit, no accidental restart
- Maximum 10 consecutive restarts, then wrapper exits with warning (infinite loop safety valve)
- Crash behavior (non-zero exit, no restart file): Claude's discretion

### Claude's Discretion
- Restart file format (raw command line vs one-per-line vs other)
- Crash exit behavior (pass through exit code vs print hint)
- Repo structure details (bin/ layout, installer implementation)
- Internal implementation patterns (how the loop works, signal trapping approach)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — WRAP-01 through WRAP-05 define wrapper behavior: loop, sleep, passthrough, file read, same directory
- `.planning/PROJECT.md` — Process chain context (wrapper -> claude -> bash -> script), key flags user passes

### Architecture decisions
- `.planning/PROJECT.md` §Key Decisions — Wrapper loop pattern chosen over background process; fixed restart file at `~/.claude-restart`; kill via process tree walk

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — this phase establishes the patterns

### Integration Points
- `claude` CLI must be on PATH (Node.js TUI, foreground process)
- `~/.claude-restart` is the coordination point with Phase 2's restart script
- `~/.claude/` is the install target directory

</code_context>

<specifics>
## Specific Ideas

- Distribution model is "install into existing workflow" (like npm install), not "clone this repo"
- Key flags the user regularly passes: `--dangerously-skip-permissions`, `--channels plugin:telegram@claude-plugins-official`
- Must work in zsh on macOS

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-wrapper-script*
*Context gathered: 2026-03-20*
