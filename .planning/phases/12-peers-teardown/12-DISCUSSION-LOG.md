# Phase 12: Peers Teardown - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 12-peers-teardown
**Areas discussed:** Test handling, .mcp.json cleanup, Rollout safety

---

## Test Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Delete and replace | Delete `test-wrapper-channels.sh` entirely, add new tests verifying wrapper starts without channel args | |
| Delete, no replacement | Delete channel tests; wrapper has other tests, removal is simple enough to verify by diff | |
| You decide | Claude picks the right approach based on what the test files actually cover | ✓ |

**User's choice:** You decide (Claude's discretion)
**Notes:** User deferred to Claude to read test files during planning and decide what to delete, keep, or replace.

---

## `.mcp.json` Cleanup on Live VPS

| Option | Description | Selected |
|--------|-------------|----------|
| Remove provisioning code only | Stop writing claude-peers to `.mcp.json` on new `add` calls. Existing VPS files cleaned manually. | ✓ |
| Add cleanup subcommand | `claude-service cleanup-peers` one-time migration command to strip claude-peers from all existing instrument `.mcp.json` files | |
| Auto-strip on re-run | `add` command removes claude-peers from `.mcp.json` when called for an existing instrument | |

**User's choice:** Remove provisioning code only
**Notes:** Existing `.mcp.json` files on VPS cleaned up manually or during deploy.

---

## Rollout Safety

| Option | Description | Selected |
|--------|-------------|----------|
| Clean cut | Remove all peers infrastructure in one pass. Stale env vars are dead config, nothing reads them. | ✓ |
| Warn on stale config | Wrapper emits stderr warning if `CLAUDE_CHANNELS` is set, helping notice stale env files on VPS | |
| You decide | Claude picks based on what makes the code simplest | |

**User's choice:** Clean cut — no backward compat
**Notes:** No deprecation warnings, no shims. If stale `CLAUDE_CHANNELS` values exist in VPS env files, they are ignored.

---

## Claude's Discretion

- Test handling: delete, refactor, or replace channel tests based on actual coverage
- Ordering of removals across files

## Deferred Ideas

None — discussion stayed within phase scope.
