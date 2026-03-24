# Phase 11: Orchestra CLAUDE.md Auto-deploy - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

`add-orchestra` automatically copies `orchestra/CLAUDE.md` into the orchestra working directory so the orchestra session starts with its behavioral spec. Also fixes stale ROADMAP.md documentation across all v2.0 phases.

Closes FINDING-01 from the v2.0 milestone audit.

</domain>

<decisions>
## Implementation Decisions

### Copy Behavior
- **D-01:** If `orchestra/CLAUDE.md` source file is missing at install time, `add-orchestra` MUST fail with an error and abort entirely (do not start the service). Consistent with existing error handling for missing `env.template`.
- **D-02:** Source path uses `$SCRIPT_DIR/../orchestra/CLAUDE.md` (relative to the script), matching the existing convention for `env.template` lookup in `claude-service`.

### ROADMAP Cleanup Scope
- **D-03:** Fix ALL stale ROADMAP.md documentation issues identified in the v2.0 audit, not just Phase 11 entries. This includes: stale plan counts for phases 7-10, unchecked plan checkboxes for completed phases, and the 10-01-PLAN.md checkbox.

### Test Coverage
- **D-04:** Add assertion in `test-orchestra.sh` that CLAUDE.md exists in the orchestra working directory after `add-orchestra` completes. File existence check only (no content verification needed).
- **D-05:** Add a failure test that verifies `add-orchestra` fails with appropriate error when the source `orchestra/CLAUDE.md` doesn't exist.

### Claude's Discretion
- Exact error message wording for missing CLAUDE.md
- Placement of the cp command within `do_add_orchestra` (before or after other provisioning steps)
- Order of ROADMAP.md fixes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Audit Findings
- `.planning/v2.0-MILESTONE-AUDIT.md` -- Defines FINDING-01 and all tech debt items to fix

### Source Code
- `bin/claude-service` -- Contains `do_add_orchestra()` function to modify (lines 117-228)
- `orchestra/CLAUDE.md` -- Source file to be auto-deployed

### Tests
- `test/test-orchestra.sh` -- Existing orchestra test suite to extend

### Documentation
- `.planning/ROADMAP.md` -- Progress table and plan checkboxes to fix

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `do_add_orchestra()` in `bin/claude-service` (line 117) -- already provisions env, .mcp.json, systemd units; just needs CLAUDE.md copy added
- Error pattern for missing files already established (lines 130-133 check for env.template)

### Established Patterns
- `$SCRIPT_DIR` relative path resolution for repo files (used for env.template)
- Fail-fast error handling with `exit 1` and stderr messages
- `test-orchestra.sh` uses mock environment with temporary directories

### Integration Points
- The `echo "Next: place orchestra CLAUDE.md..."` on line 227 should be replaced by the actual copy operation
- Test assertions follow `assert_*` helper pattern in `test-orchestra.sh`

</code_context>

<specifics>
## Specific Ideas

- The audit explicitly suggests the fix: `cp "$SCRIPT_DIR/../orchestra/CLAUDE.md" "$work_dir/CLAUDE.md"` in `do_add_orchestra`
- Remove the manual instruction echo on line 227 after adding the automatic copy

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 11-orchestra-claude-md-deploy*
*Context gathered: 2026-03-24*
