# Phase 10: Orchestra MCP Provisioning - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

`add-orchestra` automatically provisions `.mcp.json` with claude-peers MCP server config in the orchestra's working directory (`~/instruments/orchestra/`), so orchestra peer discovery works without manual global `~/.claude.json` setup.

Requirements: ORCH-04, ORCH-05 (gap closure -- already satisfied via global config, this makes provisioning automatic)

</domain>

<decisions>
## Implementation Decisions

### .mcp.json Scope
- **D-01:** Orchestra only. Only `add-orchestra` creates `.mcp.json`. Regular instruments added via `claude-service add` continue to rely on global `~/.claude.json` or manual setup. This keeps the phase scope minimal and focused on the audit gap.

### claude-peers Server Config Source
- **D-02:** Copy from global config. `add-orchestra` reads the existing `mcpServers.claude-peers` entry from `~/.claude.json` and writes it into `.mcp.json`. This mirrors the proven VPS setup and adapts to non-standard installation paths (bun location, claude-peers-mcp clone directory). If `~/.claude.json` doesn't have a claude-peers entry, `add-orchestra` warns and skips .mcp.json creation.

### Existing .mcp.json Handling
- **D-03:** Merge (add/update entry). If `.mcp.json` already exists in the orchestra working directory, read it, add or update the `claude-peers` entry, and preserve all other MCP server entries. Uses `jq` for JSON manipulation (already used elsewhere in `add-orchestra` for `~/.claude.json`).

### Claude's Discretion
- Error message wording when global config lacks claude-peers entry
- Whether to also remove the global claude-peers entry after copying (likely not -- leave global config untouched)
- JSON formatting/indentation of generated .mcp.json

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Infrastructure
- `bin/claude-service` lines 117-196 -- `do_add_orchestra()` function, the exact insertion point for .mcp.json provisioning
- `systemd/env.template` -- per-instance environment configuration (CLAUDE_CHANNELS already set)

### Prior Phase Context
- `.planning/phases/09-autonomous-orchestra/09-CONTEXT.md` -- D-08 (claude-peers as communication layer), D-11 (list_peers for discovery)
- `.planning/phases/09-autonomous-orchestra/09-RESEARCH.md` -- claude-peers installation, MCP tool schemas, pitfalls (especially Pitfall 4: Bun not in PATH)

### Audit Finding
- `.planning/v2.0-MILESTONE-AUDIT.md` -- documents the gap: "add-orchestra does not create .mcp.json for claude-peers"

### Requirements
- `.planning/REQUIREMENTS.md` -- ORCH-04, ORCH-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `do_add_orchestra()` already uses `jq` for manipulating `~/.claude.json` (remoteDialogSeen) -- same pattern extends to reading mcpServers and writing .mcp.json
- `jq` dependency already assumed present in `add-orchestra` code path

### Established Patterns
- Copy-from-default pattern: `add-orchestra` copies API key and PATH from default instance env -- D-02 extends this pattern to MCP config
- Guard-and-warn pattern: function checks for prerequisites (template exists, default env exists) before proceeding -- same pattern for checking claude-peers in global config

### Integration Points
- `.mcp.json` goes in `$work_dir` (`~/instruments/orchestra/`) -- Claude reads project-level `.mcp.json` automatically
- `CLAUDE_CHANNELS=server:claude-peers` already set in env by line 169 of `do_add_orchestra()` -- .mcp.json provision completes the MCP setup

</code_context>

<specifics>
## Specific Ideas

No specific requirements -- standard approaches apply. The implementation is a focused addition to an existing function.

</specifics>

<deferred>
## Deferred Ideas

- Provisioning .mcp.json for regular instruments (not just orchestra) -- future phase if needed
- Removing global claude-peers config after local .mcp.json works -- cleanup task, not in scope

</deferred>

---

*Phase: 10-orchestra-mcp-provisioning*
*Context gathered: 2026-03-24*
