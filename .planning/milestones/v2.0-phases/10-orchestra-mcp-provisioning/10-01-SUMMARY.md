---
phase: 10-orchestra-mcp-provisioning
plan: 01
subsystem: infra
tags: [mcp, jq, claude-peers, orchestration, bash]

requires:
  - phase: 09-autonomous-orchestra
    provides: do_add_orchestra subcommand and orchestra CLAUDE.md supervisor
provides:
  - Automatic .mcp.json provisioning with claude-peers MCP config in add-orchestra
  - Merge support for existing .mcp.json files
  - Graceful skip when claude-peers not configured globally
affects: [orchestra-setup, instrument-lifecycle]

tech-stack:
  added: []
  patterns: [jq merge-or-create for project-scoped MCP config]

key-files:
  created: []
  modified:
    - bin/claude-service
    - test/test-orchestra.sh

key-decisions:
  - "claude_config variable refactored to single declaration shared by .mcp.json and remoteDialogSeen blocks"

patterns-established:
  - "MCP config provisioning via jq extract-from-global, write-to-project pattern"

requirements-completed: [ORCH-04, ORCH-05]

duration: 5min
completed: 2026-03-24
---

# Phase 10 Plan 01: Orchestra MCP Provisioning Summary

**Auto-provision .mcp.json with claude-peers config from ~/.claude.json during add-orchestra, with merge support and graceful skip**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-24T12:57:59Z
- **Completed:** 2026-03-24T13:03:15Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- do_add_orchestra now extracts claude-peers MCP server config from ~/.claude.json and writes project-scoped .mcp.json
- Existing .mcp.json files are merged (preserving other entries) rather than overwritten
- Missing claude-peers in global config produces a warning and skips gracefully
- Three new structural tests (9-11) verify .mcp.json provisioning code exists
- Refactored claude_config variable to single declaration (eliminated duplicate)

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Add failing tests for .mcp.json provisioning** - `e7a42c2` (test)
2. **Task 1 (GREEN): Implement .mcp.json provisioning in do_add_orchestra** - `f02e837` (feat)

## Files Created/Modified
- `bin/claude-service` - Added .mcp.json provisioning block to do_add_orchestra (create/merge/skip logic)
- `test/test-orchestra.sh` - Added tests 9-11 for .mcp.json provisioning, mcpServers extraction, and merge handling

## Decisions Made
- Refactored `local claude_config="$HOME/.claude.json"` to single declaration shared by both .mcp.json provisioning and remoteDialogSeen blocks, eliminating the duplicate variable declaration

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 10 is a single-plan gap closure phase; this completes the phase
- Orchestra MCP provisioning is automatic -- no manual ~/.claude.json setup needed for claude-peers
- v2.0 milestone gap from audit is now closed

## Self-Check: PASSED

---
*Phase: 10-orchestra-mcp-provisioning*
*Completed: 2026-03-24*
