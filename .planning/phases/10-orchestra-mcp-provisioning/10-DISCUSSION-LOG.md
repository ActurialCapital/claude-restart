# Phase 10: Orchestra MCP Provisioning - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 10-orchestra-mcp-provisioning
**Areas discussed:** .mcp.json scope, claude-peers server path, Existing config handling

---

## .mcp.json Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Orchestra only | Only add-orchestra creates .mcp.json. Regular instruments rely on global config or manual setup. | ✓ |
| All instruments | Both add-orchestra and add create .mcp.json in each instrument's working directory. | |
| You decide | Claude picks the approach | |

**User's choice:** Orchestra only
**Notes:** Keeps phase scope minimal and focused on the audit gap.

---

## claude-peers Server Path

| Option | Description | Selected |
|--------|-------------|----------|
| Copy from global config | Read mcpServers.claude-peers from ~/.claude.json and write to .mcp.json. Mirrors proven setup. | ✓ |
| Hardcode convention | Write `bun ~/claude-peers-mcp/server.ts` directly. Simpler but fragile. | |
| Env template variable | Add CLAUDE_PEERS_CMD to env.template for customization. | |

**User's choice:** Copy from global config
**Notes:** User asked "what is best practice?" -- presented analysis showing copy-from-global mirrors the existing copy-from-default pattern (API key, PATH) and adapts to non-standard installations. User agreed with recommendation.

---

## Existing Config Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Merge (add/update entry) | Read existing .mcp.json, add/update claude-peers entry, preserve others. | ✓ |
| Skip with warning | Leave existing .mcp.json untouched, warn user. | |
| Overwrite | Replace .mcp.json entirely. | |

**User's choice:** Merge (add/update entry)
**Notes:** None

---

## Claude's Discretion

- Error message wording when global config lacks claude-peers entry
- JSON formatting of generated .mcp.json
- Whether to leave global config untouched after copying (likely yes)

## Deferred Ideas

- .mcp.json provisioning for regular instruments (not just orchestra)
- Cleanup of global claude-peers config after local .mcp.json works
