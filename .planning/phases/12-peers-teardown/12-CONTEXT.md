# Phase 12: Peers Teardown - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove all claude-peers infrastructure from the codebase. After this phase, instruments start and run without broker, watcher, channel dependencies, or any claude-peers MCP server config. This is a pure teardown — no new capabilities are introduced.

Requirements: CLNP-01, CLNP-02, CLNP-03, CLNP-04, CLNP-05

</domain>

<decisions>
## Implementation Decisions

### Test Handling
- **D-01:** Claude's discretion — read existing test files (`test/test-wrapper-channels.sh`, `test/test-orchestra.sh`) during planning and decide what to delete, keep, or replace based on actual coverage.

### `.mcp.json` Cleanup
- **D-02:** Remove provisioning code only — stop writing claude-peers to `.mcp.json` on new `claude-service add` calls. Existing `.mcp.json` files on VPS are cleaned up manually or during a separate deploy step. No migration command or auto-strip logic.

### Rollout Safety
- **D-03:** Clean cut, no backward compatibility — remove all peers infrastructure in one pass. No deprecation warnings, no shims. If stale `CLAUDE_CHANNELS` values exist in VPS env files, they are dead config that nothing reads.

### Claude's Discretion
- Test handling approach (D-01): delete, refactor, or replace channel tests based on what they actually cover
- Any ordering decisions for removal across files

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — CLNP-01 through CLNP-05 define the five removal targets

### Teardown Targets
- `bin/claude-wrapper` — Lines 53-60 (channel args), 133-135 (message-watcher resolution), 192-196 (watcher spawn in remote-control)
- `bin/install.sh` — Lines 93-94 (message-watcher deploy), 183 (CLAUDE_CHANNELS sed), 187-211 (.mcp.json claude-peers provisioning), 247 (message-watcher uninstall rm)
- `bin/message-watcher` — Entire file (delete)
- `systemd/env.template` — Lines 29-30 (CLAUDE_CHANNELS variable)
- `bin/claude-service` — CLAUDE_CHANNELS references in `add` subcommand
- `test/test-wrapper-channels.sh` — Channel-specific test file
- `test/test-orchestra.sh` — claude-peers test references

### Prior Architecture Context
- `.planning/milestones/v2.0-phases/10-orchestra-mcp-provisioning/10-CONTEXT.md` — Original decisions for MCP provisioning (being reversed)
- `.planning/milestones/v2.0-phases/09-autonomous-orchestra/09-CONTEXT.md` — Original orchestra decisions referencing claude-peers

</canonical_refs>

<code_context>
## Existing Code Insights

### Teardown Inventory
- `bin/claude-wrapper`: Channel args block (lines 53-60), message-watcher path resolution (lines 133-135), watcher spawn logic in remote-control mode (lines 192-196)
- `bin/install.sh`: message-watcher copy+chmod (lines 93-94), uninstall rm (line 247), CLAUDE_CHANNELS sed in add (line 183), .mcp.json claude-peers provisioning block (lines 187-211)
- `bin/message-watcher`: Entire standalone script — delete
- `systemd/env.template`: CLAUDE_CHANNELS comment and variable (lines 29-30)
- `bin/claude-service`: CLAUDE_CHANNELS reference in add subcommand
- `test/test-wrapper-channels.sh`: Dedicated channel test file
- `test/test-orchestra.sh`: Contains claude-peers references in test assertions

### Established Patterns
- Shell scripts are pure bash, no external dependencies beyond systemd
- Tests use lightweight bash assertion patterns (see existing test files)
- Installer has install/uninstall/add/remove subcommands — all may need peers references stripped

### Integration Points
- `claude-wrapper` is the main entry point — must still launch claude correctly after removal
- `install.sh add` creates new instruments — must work without peers provisioning
- systemd template units reference env files — env.template is the source of truth

</code_context>

<specifics>
## Specific Ideas

No specific requirements — straightforward teardown guided by CLNP-01 through CLNP-05.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 12-peers-teardown*
*Context gathered: 2026-03-27*
