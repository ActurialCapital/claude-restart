# Phase 3: Shell Integration - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Shell function and install script that make launching claude through the wrapper seamless. User types `claude-restart` in any terminal to launch claude with the wrapper loop and default flags. An install script copies scripts into place and adds the function to `.zshrc`.

</domain>

<decisions>
## Implementation Decisions

### Shell function design
- Shell function (not alias) for proper argument forwarding and flexibility
- Function calls the wrapper script with arguments forwarded via `"$@"`
- Claude's discretion on whether the function sets `CLAUDE_RESTART_DEFAULT_OPTS` inline or relies on a separate env var export in `.zshrc`
- Claude's discretion on PATH handling (function uses absolute path to wrapper vs adding install dir to PATH)

### Install script
- `bin/install.sh` copies `claude-wrapper` and `claude-restart` to install directory and appends the shell function to `.zshrc`
- Must be idempotent — safe to re-run without duplicating `.zshrc` entries (check for existing marker before appending)
- Supports `--uninstall` flag to remove scripts and `.zshrc` entries cleanly
- Claude's discretion on install directory (`~/.claude/bin/` or `~/.local/bin/` — pick the cleanest approach)

### Naming & invocation
- Shell function name: `claude-restart`
- `claude-restart` with no args launches claude with default flags baked in (`--dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official`)
- When args are provided, they replace defaults entirely (no merging/appending) — matches Phase 2's restart script behavior
- Default flags are configurable (not hardcoded in the function itself) so users can customize

### Claude's Discretion
- Install directory choice (`~/.claude/bin/` vs `~/.local/bin/`)
- Whether defaults live in the function body or as an env var export
- PATH management approach
- Install script output/feedback messaging
- How idempotency marker works (comment sentinel, grep check, etc.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — SHEL-01 (alias/function launches via wrapper), SHEL-02 (install instructions or script for .zshrc)

### Existing scripts (integration points)
- `bin/claude-wrapper` — The wrapper loop script that the shell function must invoke
- `bin/claude-restart` — The restart script that must be on PATH or discoverable by Claude at runtime

### Prior phase context
- `.planning/phases/01-wrapper-script/01-CONTEXT.md` — Distribution model (install into ~/.claude/), env var override pattern, command name decisions
- `.planning/phases/02-restart-script/02-CONTEXT.md` — CLAUDE_RESTART_DEFAULT_OPTS env var, process chain context, note that env var for defaults should live in .zshrc alongside alias

### Architecture decisions
- `.planning/PROJECT.md` §Key Decisions — Wrapper loop pattern, fixed restart file, process tree walk

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/claude-wrapper` — Target of the shell function invocation; uses env var overrides (CLAUDE_RESTART_FILE, CLAUDE_WRAPPER_DELAY, CLAUDE_WRAPPER_MAX_RESTARTS)
- `bin/claude-restart` — Must be findable by Claude when it runs `claude-restart` as a bash tool; needs to be on PATH
- `test/test-wrapper.sh` — Test pattern with assert helpers and env var overrides; follow same pattern for install script tests

### Established Patterns
- Env var overrides for all configurable values (CLAUDE_RESTART_FILE, CLAUDE_WRAPPER_DELAY, CLAUDE_RESTART_DEFAULT_OPTS)
- Bash scripts with `set -euo pipefail`
- Scripts in `bin/` directory

### Integration Points
- Shell function → `bin/claude-wrapper` (invokes wrapper with args)
- `claude-restart` script must be on PATH so Claude can execute it as a bash tool
- `.zshrc` is the integration target for persistent shell configuration

</code_context>

<specifics>
## Specific Ideas

- User's daily workflow: type `claude-restart` and get claude with `--dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official` automatically
- Explicit args override defaults entirely — `claude-restart --model sonnet` does NOT include the default flags
- Phase 2 specifically noted: "The env var for defaults should be set in `.zshrc` alongside the shell alias"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-shell-integration*
*Context gathered: 2026-03-20*
