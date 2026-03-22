# Phase 4: Wrapper Hardening - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

The wrapper runs both modes cleanly, exits gracefully on SIGTERM, and the restart mechanism works end-to-end with `claude remote-control` and `claude --channels plugin:telegram@...`. Mode selection, signal handling, and restart-file interaction are the three implementation areas.

</domain>

<decisions>
## Implementation Decisions

### Signal handling
- **D-01:** SIGTERM is forwarded to the claude child process; wrapper waits for child to exit, then exits cleanly with code 0 (no restart loop). This is the standard systemd stop pattern.
- **D-02:** SIGHUP is trapped and ignored so the wrapper survives SSH disconnects (belt-and-suspenders with systemd/tmux).
- **D-03:** SIGINT handling stays as-is (exit 130).

### Mode selection
- **D-04:** Single env var `CLAUDE_CONNECT` selects the mode. Values: `telegram`, `remote-control`, or unset (interactive).
- **D-05:** The wrapper maps `CLAUDE_CONNECT` to CLI args internally. Channel strings are built into the wrapper — no separate env var required for the channel path.
- **D-06:** When `CLAUDE_CONNECT` is unset, the wrapper defaults to interactive mode (plain `claude` with passed args). Backwards-compatible with v1.0.
- **D-07:** Mode is fixed at launch. A restart cannot switch modes — switching requires stopping and restarting the service.
- **D-08:** Mode base args + extra args model: `CLAUDE_CONNECT` determines base args (e.g., `--channels plugin:telegram@...`), any additional CLI args are appended after.

### Restart file interaction
- **D-09:** Mode base args are always applied. Restart file content replaces only the extra args, never the mode's base args. Mode is never lost on restart.
- **D-10:** Empty restart file = relaunch with mode defaults + original extra args from first launch (same as v1.0 empty-file behavior, but mode-aware).

### Claude's Discretion
- Signal forwarding implementation details (trap + wait pattern)
- Mode-to-args mapping structure in the wrapper
- Error messages for invalid CLAUDE_CONNECT values
- Test structure for new functionality

</decisions>

<specifics>
## Specific Ideas

- Mode system should be extensible — adding a new mode (e.g., discord) should be as simple as adding another mapping entry
- `CLAUDE_CONNECT` chosen over `CLAUDE_MODE` because "mode" is too generic and could be confused with other things

</specifics>

<canonical_refs>
## Canonical References

### Requirements
- `.planning/REQUIREMENTS.md` — WRAP-01 through WRAP-04 define the four requirements for this phase

### Existing implementation
- `bin/claude-wrapper` — Current wrapper (55 lines), starting point for hardening
- `bin/claude-restart` — Restart trigger script, PPID chain walk logic
- `bin/install.sh` — Installer with zshrc integration and default opts

### Prior decisions
- `.planning/STATE.md` §Accumulated Context — SIGTERM must land before systemd wraps the wrapper; mode selection is Phase 4 prerequisite for systemd unit's ExecStart

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `claude-wrapper` trap pattern (line 14): Already traps SIGINT, can extend to SIGTERM/SIGHUP
- `claude-wrapper` args management (lines 10-11, 35-48): `original_args`/`current_args` split already exists — mode base args slot in naturally
- `claude-restart` PPID chain walk (lines 38-52): Needs validation with remote-control process tree but pattern is solid

### Established Patterns
- Env var overrides for all configurable values (`CLAUDE_RESTART_FILE`, `CLAUDE_WRAPPER_MAX_RESTARTS`, etc.)
- Test-time PID override via `CLAUDE_RESTART_TARGET_PID`
- Word-splitting `read -ra` for restart file args parsing

### Integration Points
- `install.sh` currently hardcodes `CLAUDE_RESTART_DEFAULT_OPTS` with telegram channel string — needs updating to use `CLAUDE_CONNECT` instead
- systemd unit file (Phase 5) will set `CLAUDE_CONNECT` via `Environment=` directive

</code_context>

<deferred>
## Deferred Ideas

- Discord mode support (`CLAUDE_CONNECT=discord`) — future milestone, but mode system designed to accommodate it
- Smart watchdog with activity detection (WDOG-02, WDOG-03) — future requirements, not v1.1

</deferred>

---

*Phase: 04-wrapper-hardening*
*Context gathered: 2026-03-21*
