---
phase: 14-skills-deployment-and-identity
plan: 02
subsystem: instrument-identity
tags: [claude-service, claude-wrapper, identity, session-naming, CLAUDE.md]

requires:
  - phase: 12-peers-teardown
    provides: Clean instrument infrastructure without peers dependencies

provides:
  - Per-instrument identity CLAUDE.md deployed to .claude/CLAUDE.md during add
  - Orchestra identity CLAUDE.md deployed during add-orchestra
  - Session naming fix for all instances including default

affects: [instrument-lifecycle, orchestra, vps-deployment]

tech-stack:
  added: []
  patterns: [identity-template-substitution, project-level-claude-md]

key-files:
  created:
    - instrument-CLAUDE.md.template
  modified:
    - bin/claude-service
    - bin/claude-wrapper
    - test/test-service-lifecycle.sh
    - test/test-wrapper.sh

key-decisions:
  - "D-03: Identity CLAUDE.md goes in .claude/CLAUDE.md (project-level config), not repo root -- avoids overwriting repo CLAUDE.md"
  - "SESS-01: Removed default exclusion from --name flag so all instances get distinct session names on phone"

patterns-established:
  - "Identity template: instrument-CLAUDE.md.template with INSTANCE_PLACEHOLDER sed substitution during claude-service add"
  - "Project-level .claude/CLAUDE.md for per-instrument config that does not overwrite repo root CLAUDE.md"

requirements-completed: [INST-01, INST-02, SESS-01]

duration: 4min
completed: 2026-03-27
---

# Phase 14 Plan 02: Instrument Identity CLAUDE.md Injection and Session Naming Fix Summary

**Per-instrument identity CLAUDE.md template deployed via claude-service add with INSTANCE_PLACEHOLDER substitution, plus session naming fix for default instance**

## What Was Built

1. **instrument-CLAUDE.md.template** -- Template file at repo root with 7 INSTANCE_PLACEHOLDER markers covering instance name, working directory, config path, restart hint, and remote access command
2. **claude-service add identity deployment** -- do_add() now deploys identity CLAUDE.md to `$work_dir/.claude/CLAUDE.md` after git clone, with sed substitution replacing all placeholders with the actual instance name
3. **claude-service add-orchestra identity** -- do_add_orchestra() now deploys a supplementary identity file to `.claude/CLAUDE.md` alongside the behavioral spec at repo root
4. **Session naming fix** -- Removed `!= "default"` exclusion from claude-wrapper's --name flag check, so all instances including "default" get `--name <instance>` for distinct phone session names

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | b6c77cd | feat(14-02): add instrument identity CLAUDE.md template and deploy during add |
| 2 | 8113484 | test(14-02): add tests for identity CLAUDE.md deployment and session naming |

## Test Results

- **test/test-service-lifecycle.sh**: 34/34 passed (added Tests 12-14)
- **test/test-wrapper.sh**: 44/44 passed (added Tests 24-25)

### New Tests Added

- Test 12: add deploys instrument identity CLAUDE.md with correct instance name, restart hint, and remote access hint
- Test 13: identity CLAUDE.md in .claude/ subdir does not overwrite repo root CLAUDE.md
- Test 14: add-orchestra deploys orchestra identity in .claude/ subdir
- Test 24: default instance gets --name flag with CLAUDE_INSTANCE_NAME=default
- Test 25: wrapper source has no default exclusion for --name

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- all functionality is fully wired.

## Self-Check: PASSED

All files exist, all commits verified.
