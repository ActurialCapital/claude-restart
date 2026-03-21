# Phase 2: Restart Script - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Script that Claude executes to trigger a restart — writes CLI options to `~/.claude-restart` and kills the current claude process via SIGTERM. The wrapper (Phase 1) detects the exit, finds the restart file, and relaunches claude. Shell integration is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Process kill strategy
- Find claude's PID by walking the PPID chain (script → bash sandbox → claude node process)
- Claude's discretion on exact PPID walk depth (fixed grandparent vs walk-until-node)
- Send SIGTERM (graceful shutdown) — not SIGKILL
- Kill only the claude process, not the wrapper or children

### Default restart (no args)
- No args = restart with configurable default options
- Default options: `--dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official`
- Configured via environment variable (follows Phase 1 pattern of env var overrides)
- When args ARE provided, they replace defaults entirely (no merging/appending)

### Script location & naming
- Script at `bin/claude-restart` (alongside `bin/claude-wrapper`)
- Discoverable via PATH after install (Phase 3); during development, use full repo path
- Print brief confirmation on execution (e.g., "Restarting claude with: --model sonnet")

### Error handling
- Claude's discretion on behavior when PID can't be found (graceful degradation preferred)
- No argument validation — script is a dumb pipe, passes through anything
- Keep error handling minimal and simple

### Testing
- Test suite follows same pattern as `test/test-wrapper.sh`
- Same assert_eq/assert_contains helpers, mock processes, env var overrides

### Claude's Discretion
- Exact PPID walk implementation (fixed depth vs walk-until-node)
- PID-not-found behavior (write file anyway with warning vs fail)
- Env var name for default options
- Restart file format when writing options (raw command line vs structured)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — REST-01, REST-02, REST-03 define restart script behavior
- `.planning/PROJECT.md` — Process chain context, key flags, kill via process tree walk decision

### Phase 1 implementation (integration point)
- `bin/claude-wrapper` — The wrapper loop that reads `~/.claude-restart` and relaunches claude; restart script must produce output this script can consume
- `test/test-wrapper.sh` — Test pattern to follow (mock claude, assert helpers, env var overrides)

### Phase 1 context
- `.planning/phases/01-wrapper-script/01-CONTEXT.md` — Prior decisions: bash scripts, env var overrides for testability, restart file handling

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/test-wrapper.sh` assert_eq/assert_contains helpers — reuse for restart script tests
- `bin/claude-wrapper` env var override pattern (CLAUDE_WRAPPER_DELAY, CLAUDE_WRAPPER_MAX_RESTARTS, CLAUDE_RESTART_FILE) — follow same convention

### Established Patterns
- Bash scripts with `set -euo pipefail` (implied from wrapper)
- Env vars for testability: `CLAUDE_RESTART_FILE` already overrides restart file path
- Mock-based testing: mock claude binary, log invocations, assert on behavior
- Restart file format: raw text content, empty = use defaults

### Integration Points
- `~/.claude-restart` — restart script WRITES this file, wrapper READS and DELETES it
- Process tree: wrapper → claude (node) → bash (sandbox) → restart script
- SIGTERM to claude PID triggers wrapper's restart-check loop

</code_context>

<specifics>
## Specific Ideas

- Default options `--dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official` reflect user's actual daily workflow
- The env var for defaults should be set in `.zshrc` alongside the shell alias (Phase 3)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-restart-script*
*Context gathered: 2026-03-20*
