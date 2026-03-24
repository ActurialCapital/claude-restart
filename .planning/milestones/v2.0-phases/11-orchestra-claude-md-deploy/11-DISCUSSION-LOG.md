# Phase 11: Orchestra CLAUDE.md Auto-deploy - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 11-orchestra-claude-md-deploy
**Areas discussed:** Copy behavior, ROADMAP cleanup scope, Test coverage

---

## Copy Behavior

### Missing Source File Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Fail with error | Abort add-orchestra entirely -- orchestra without its CLAUDE.md is broken. Consistent with how it already fails on missing env.template. | Y |
| Warn and continue | Print a warning but still start the service. User can place CLAUDE.md manually later (current behavior, basically). | |
| You decide | Claude picks the best approach based on existing patterns in claude-service. | |

**User's choice:** Fail with error
**Notes:** Matches existing error handling pattern for env.template.

### Source Path Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| $SCRIPT_DIR relative | Uses the same pattern as env.template lookup -- works regardless of where the repo is cloned. Already the convention in claude-service. | Y |
| You decide | Claude picks based on existing patterns in the codebase. | |

**User's choice:** $SCRIPT_DIR relative
**Notes:** None

---

## ROADMAP Cleanup Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Fix all stale ROADMAP docs | Clean up all 5 trivial ROADMAP issues from the audit in one pass. They're all in the same file and trivial to fix together. | Y |
| Only Phase 11 entries | Only fix ROADMAP entries that Phase 11 itself touches. Leave other stale counts for a separate cleanup. | |
| You decide | Claude picks based on what makes sense for milestone closure. | |

**User's choice:** Fix all stale ROADMAP docs
**Notes:** All issues are trivial and in the same file.

---

## Test Coverage

### Happy Path Assertion

| Option | Description | Selected |
|--------|-------------|----------|
| File existence check | Assert CLAUDE.md exists in the orchestra working directory after add-orchestra. Simple, matches existing test patterns in test-orchestra.sh. | Y |
| File content check | Also verify the copied CLAUDE.md content matches the source. Catches partial copies or corruption. | |
| You decide | Claude picks based on existing test patterns. | |

**User's choice:** File existence check
**Notes:** None

### Failure Case Test

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add failure test | Test that add-orchestra fails with appropriate error when orchestra/CLAUDE.md source doesn't exist. Validates the error-on-missing behavior. | Y |
| Skip failure test | Only test the happy path. The failure case is simple enough to trust. | |
| You decide | Claude picks based on test coverage patterns. | |

**User's choice:** Yes, add failure test
**Notes:** None

---

## Claude's Discretion

- Exact error message wording for missing CLAUDE.md
- Placement of the cp command within do_add_orchestra
- Order of ROADMAP.md fixes

## Deferred Ideas

None
