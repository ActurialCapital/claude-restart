# Phase 10: Orchestra MCP Provisioning - Research

**Researched:** 2026-03-24
**Domain:** Shell scripting (jq JSON manipulation), Claude Code MCP configuration
**Confidence:** HIGH

## Summary

Phase 10 is a focused gap closure: adding approximately 15-25 lines of bash to `do_add_orchestra()` in `bin/claude-service`. The function already uses `jq` to manipulate `~/.claude.json`, and the new code extends this pattern to (1) read the `mcpServers.claude-peers` entry from `~/.claude.json`, (2) write or merge it into `.mcp.json` in the orchestra working directory. The `.mcp.json` format is a standard JSON file with an `mcpServers` object that Claude Code auto-discovers from the working directory.

The implementation is low-risk because the exact `jq` patterns needed are already established in the codebase (lines 174-182 of `do_add_orchestra()`), the `.mcp.json` schema is simple and well-documented, and existing tests in `test/test-orchestra.sh` provide a structural validation framework that can be extended with 2-3 new test cases.

**Primary recommendation:** Insert the `.mcp.json` provisioning block between the `chmod 600` (line 171) and the `remoteDialogSeen` block (line 174), using `jq` to extract from `~/.claude.json` and write/merge into `$work_dir/.mcp.json`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Orchestra only. Only `add-orchestra` creates `.mcp.json`. Regular instruments added via `claude-service add` continue to rely on global `~/.claude.json` or manual setup. This keeps the phase scope minimal and focused on the audit gap.
- **D-02:** Copy from global config. `add-orchestra` reads the existing `mcpServers.claude-peers` entry from `~/.claude.json` and writes it into `.mcp.json`. This mirrors the proven VPS setup and adapts to non-standard installation paths (bun location, claude-peers-mcp clone directory). If `~/.claude.json` doesn't have a claude-peers entry, `add-orchestra` warns and skips .mcp.json creation.
- **D-03:** Merge (add/update entry). If `.mcp.json` already exists in the orchestra working directory, read it, add or update the `claude-peers` entry, and preserve all other MCP server entries. Uses `jq` for JSON manipulation (already used elsewhere in `add-orchestra` for `~/.claude.json`).

### Claude's Discretion
- Error message wording when global config lacks claude-peers entry
- Whether to also remove the global claude-peers entry after copying (likely not -- leave global config untouched)
- JSON formatting/indentation of generated .mcp.json

### Deferred Ideas (OUT OF SCOPE)
- Provisioning .mcp.json for regular instruments (not just orchestra) -- future phase if needed
- Removing global claude-peers config after local .mcp.json works -- cleanup task, not in scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORCH-04 | Orchestra detects instruments added or removed while it is running (dynamic discovery) | claude-peers `list_peers` requires MCP server to be loaded. `.mcp.json` in working directory ensures claude-peers loads automatically without global config dependency. |
| ORCH-05 | Orchestra always routes messages to the correct instrument based on project context | claude-peers `send_message` requires MCP server to be loaded. Same `.mcp.json` provisioning ensures the tool is available for routing. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| jq | system-installed | JSON manipulation for reading ~/.claude.json and writing .mcp.json | Already used in do_add_orchestra() for remoteDialogSeen manipulation |
| bash | system shell | Script modification target (bin/claude-service) | All project scripts are bash |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| claude-peers-mcp | latest (main branch) | MCP server whose config is being provisioned | Already installed on VPS; config entry is what gets copied |

No new dependencies. This phase modifies existing code only.

## Architecture Patterns

### Insertion Point in do_add_orchestra()

The new code goes between the `chmod 600` (line 171) and `remoteDialogSeen` block (line 174):

```
Line 171: chmod 600 "$env_dir/env"
          <-- INSERT .mcp.json provisioning here -->
Line 174: # Pre-set remoteDialogSeen...
```

This ordering ensures:
1. Environment file is fully configured before MCP provisioning
2. MCP provisioning is independent of remoteDialogSeen (no dependency)
3. MCP provisioning happens before systemd enable (line 185) so the service starts with .mcp.json already in place

### Pattern: Extract-and-Write with jq

This is the core implementation pattern. Extract `mcpServers.claude-peers` from `~/.claude.json`, wrap it, and write/merge into `.mcp.json`:

```bash
# Provision .mcp.json with claude-peers MCP server config
local claude_config="$HOME/.claude.json"
local mcp_json="$work_dir/.mcp.json"

if [[ -f "$claude_config" ]] && command -v jq &>/dev/null; then
    local peers_config
    peers_config=$(jq -e '.mcpServers["claude-peers"]' "$claude_config" 2>/dev/null)
    if [[ $? -eq 0 && -n "$peers_config" ]]; then
        if [[ -f "$mcp_json" ]]; then
            # Merge: add/update claude-peers entry, preserve others
            local tmp
            tmp=$(jq --argjson cp "$peers_config" '.mcpServers["claude-peers"] = $cp' "$mcp_json")
            echo "$tmp" > "$mcp_json"
        else
            # Create new .mcp.json with claude-peers entry
            jq -n --argjson cp "$peers_config" '{"mcpServers": {"claude-peers": $cp}}' > "$mcp_json"
        fi
        echo "Provisioned claude-peers MCP config at $mcp_json"
    else
        echo "Warning: claude-peers not found in $claude_config mcpServers. Skipping .mcp.json creation." >&2
        echo "  Orchestra will not have claude-peers MCP tools until configured manually." >&2
    fi
else
    if ! command -v jq &>/dev/null; then
        echo "Warning: jq not found. Cannot provision .mcp.json." >&2
    elif [[ ! -f "$claude_config" ]]; then
        echo "Warning: $claude_config not found. Cannot provision .mcp.json." >&2
    fi
fi
```

### Pattern: Variable Reuse

Note that `claude_config` is already declared on line 174 of the existing function. The new block must either:
- (a) Move the `local claude_config` declaration earlier (before the new block), or
- (b) Use its own variable name, or
- (c) Declare it once before both blocks

Recommended: Move the existing `local claude_config="$HOME/.claude.json"` declaration to just before the new block, and remove the duplicate from the remoteDialogSeen block. Both blocks use the same variable.

### .mcp.json Format

Claude Code auto-discovers `.mcp.json` from the project/working directory. The format for a stdio transport MCP server:

```json
{
  "mcpServers": {
    "claude-peers": {
      "command": "bun",
      "args": [
        "/home/user/claude-peers-mcp/server.ts"
      ]
    }
  }
}
```

The exact `command` and `args` values come from whatever is in `~/.claude.json` -- the D-02 decision means we copy verbatim rather than hardcoding paths.

### Anti-Patterns to Avoid
- **Hardcoding bun path or claude-peers-mcp location:** D-02 explicitly says copy from global config to adapt to non-standard installations. Never hardcode `~/.bun/bin/bun` or `~/claude-peers-mcp/server.ts`.
- **Writing .mcp.json after systemd enable:** The service would start without .mcp.json, creating a race condition where the first Claude session might not have claude-peers tools.
- **Overwriting existing .mcp.json:** D-03 says merge. If the user has other MCP servers configured, they must be preserved.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON extraction from config | sed/grep/awk parsing of JSON | `jq -e '.mcpServers["claude-peers"]'` | JSON has nested structures, escaping, optional fields -- jq handles all edge cases |
| JSON merging | Concatenation or template substitution | `jq --argjson cp "$val" '.mcpServers["claude-peers"] = $cp'` | Preserves existing entries, handles empty objects, proper formatting |
| Config file format discovery | Guessing .mcp.json schema | Copy structure from ~/.claude.json mcpServers entry | D-02 decision: the proven global config IS the source of truth |

**Key insight:** The entire implementation is a jq pipeline: read from one JSON file, transform, write to another. No custom logic needed.

## Common Pitfalls

### Pitfall 1: claude_config Variable Declared Twice
**What goes wrong:** `local claude_config` is already declared on line 174 for the remoteDialogSeen block. Declaring it again in the new block causes a bash warning or shadowing.
**Why it happens:** The new code is inserted before the existing block that uses the same variable.
**How to avoid:** Refactor: declare `local claude_config="$HOME/.claude.json"` once near the top of the new block, remove the duplicate from the remoteDialogSeen block. Both blocks reference the same file.
**Warning signs:** `local: claude_config: already declared` warning in bash.

### Pitfall 2: jq -e Exit Code on Missing Key
**What goes wrong:** `jq '.mcpServers["claude-peers"]'` returns `null` (exit 0) when the key doesn't exist. The script proceeds with `"null"` as the config value.
**Why it happens:** jq normally exits 0 even when extracting null values.
**How to avoid:** Use `jq -e` which exits non-zero if the result is null or false. Check both exit code AND non-empty string.
**Warning signs:** `.mcp.json` contains `"claude-peers": null`.

### Pitfall 3: Project-Scoped MCP Server Approval Prompt
**What goes wrong:** Claude Code prompts for approval before using project-scoped MCP servers from `.mcp.json`. On a headless VPS with remote-control mode, this interactive prompt could block startup.
**Why it happens:** Security feature -- project `.mcp.json` files are considered less trusted than user-scoped `~/.claude.json` config.
**How to avoid:** The existing `ensure_remote_config` pattern in `claude-wrapper` pre-sets trust in `~/.claude.json` projects section (workspace trust via `hasTrustDialogAccepted`). Verify this also covers MCP server approval, or check if `allowedMcpServers` needs to be pre-configured. If approval is needed, add it to the `ensure_remote_config` function.
**Warning signs:** Orchestra starts but claude-peers tools are not available; logs show MCP server approval pending.

### Pitfall 4: Empty or Malformed ~/.claude.json
**What goes wrong:** Script assumes `~/.claude.json` is valid JSON with an `mcpServers` object. If the file is empty, malformed, or missing `mcpServers`, jq errors out.
**Why it happens:** User may have manually edited the file, or it was created by the remoteDialogSeen block with only `{"remoteDialogSeen": true}`.
**How to avoid:** Use `jq -e` with explicit null checks. The guard-and-warn pattern (D-02: "warn and skip") handles this gracefully.
**Warning signs:** jq parse errors in add-orchestra output.

## Code Examples

### Reading claude-peers config from ~/.claude.json
```bash
# Source: existing jq pattern in do_add_orchestra() + jq documentation
# Extract the claude-peers MCP server entry
peers_config=$(jq -e '.mcpServers["claude-peers"]' "$HOME/.claude.json" 2>/dev/null)
# $? is 0 if key exists and is not null
# $peers_config contains the JSON object: {"command":"bun","args":["/path/server.ts"]}
```

### Creating .mcp.json from scratch
```bash
# Source: Claude Code MCP docs (.mcp.json format)
jq -n --argjson cp "$peers_config" '{"mcpServers": {"claude-peers": $cp}}' > "$work_dir/.mcp.json"
# Output: {"mcpServers":{"claude-peers":{"command":"bun","args":["/home/user/claude-peers-mcp/server.ts"]}}}
```

### Merging into existing .mcp.json
```bash
# Source: jq documentation for in-place update
tmp=$(jq --argjson cp "$peers_config" '.mcpServers["claude-peers"] = $cp' "$work_dir/.mcp.json")
echo "$tmp" > "$work_dir/.mcp.json"
# Preserves all other entries in mcpServers, only adds/updates claude-peers
```

### Handling missing .mcpServers in existing .mcp.json
```bash
# If .mcp.json exists but has no mcpServers key (edge case):
jq --argjson cp "$peers_config" '.mcpServers = (.mcpServers // {}) | .mcpServers["claude-peers"] = $cp' "$work_dir/.mcp.json"
# The `// {}` provides a default empty object if mcpServers is null
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash test scripts (project convention) |
| Config file | None -- standalone scripts in `test/` |
| Quick run command | `bash test/test-orchestra.sh` |
| Full suite command | `for f in test/test-*.sh; do bash "$f"; done` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORCH-04 | .mcp.json created with claude-peers entry (enables dynamic discovery) | unit (structural) | `bash test/test-orchestra.sh` (new tests 9-11) | Partial -- file exists, needs new tests |
| ORCH-05 | .mcp.json contains valid mcpServers config (enables message routing) | unit (structural) | `bash test/test-orchestra.sh` (new tests 9-11) | Partial -- file exists, needs new tests |

### Sampling Rate
- **Per task commit:** `bash test/test-orchestra.sh`
- **Per wave merge:** `for f in test/test-*.sh; do bash "$f"; done`
- **Phase gate:** Full test suite green

### Wave 0 Gaps
- [ ] Add tests 9-11 to `test/test-orchestra.sh`:
  - Test 9: `do_add_orchestra` references `.mcp.json` (grep for mcp_json or .mcp.json in function body)
  - Test 10: `do_add_orchestra` reads mcpServers from claude_config (grep for mcpServers in function body)
  - Test 11: `do_add_orchestra` handles merge case (grep for existing .mcp.json check in function body)

## Open Questions

1. **Project-scoped MCP server approval in remote-control mode**
   - What we know: Claude Code prompts for approval before using project-scoped `.mcp.json` servers (security feature). The existing `ensure_remote_config` in `claude-wrapper` pre-sets workspace trust.
   - What's unclear: Whether workspace trust (`hasTrustDialogAccepted`) also covers MCP server approval, or if there's a separate `allowedMcpServers` or similar config needed.
   - Recommendation: Test on VPS after implementation. If approval blocks, extend `ensure_remote_config` to pre-approve the claude-peers MCP server. This is a follow-up fix, not a blocker for the code change itself.

## Sources

### Primary (HIGH confidence)
- `bin/claude-service` lines 117-196 -- existing `do_add_orchestra()` function with jq patterns
- [Claude Code MCP docs](https://code.claude.com/docs/en/mcp) -- .mcp.json format, project-scoped server behavior, precedence rules
- [claude-peers-mcp GitHub](https://github.com/louislva/claude-peers-mcp) -- MCP server config structure (command + args)
- `.planning/phases/10-orchestra-mcp-provisioning/10-CONTEXT.md` -- locked decisions D-01, D-02, D-03
- `.planning/v2.0-MILESTONE-AUDIT.md` -- gap finding for ORCH-04/ORCH-05

### Secondary (MEDIUM confidence)
- `.planning/phases/09-autonomous-orchestra/09-06-SUMMARY.md` -- confirms .mcp.json is how remote-control loads MCP servers (not CLI flags)
- `.planning/phases/09-autonomous-orchestra/09-RESEARCH.md` -- claude-peers tool schemas, installation patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, jq already in use
- Architecture: HIGH -- insertion point is clear, jq patterns are established, .mcp.json format is documented
- Pitfalls: MEDIUM -- the MCP server approval prompt behavior in remote-control mode needs VPS validation

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable domain, no fast-moving dependencies)
