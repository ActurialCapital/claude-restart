---
phase: quick
plan: 260327-ph1
subsystem: installer
tags: [skills, commands, git, deploy]
key-files:
  modified:
    - bin/install.sh
    - test/test-install.sh
    - test/test-phase14-validation.sh
    - skills/README.md
    - commands/README.md
  removed:
    - skills/get-shit-done/ (entire vendored directory)
    - commands/gsd/ (entire vendored directory)
decisions:
  - "Repo URLs configurable via env vars (CLAUDE_RESTART_GSD_REPO, CLAUDE_RESTART_SUPERPOWERS_REPO) for testing and forks"
  - "git pull --ff-only used for updates to avoid merge conflicts during install"
  - "Clone failure is non-fatal with warning, matching previous graceful skip behavior"
metrics:
  duration: 312s
  completed: 2026-03-27
  tasks: 3
  files: 7
---

# Quick Task 260327-ph1: Replace Vendored Skills and Commands with Git Clone

Git-based deployment of GSD skills and superpowers commands, replacing 193 vendored files with upstream git clone/pull in deploy_skills()

## What Changed

### 1. Removed Vendored Content
- Deleted entire `skills/get-shit-done/` directory (GSD skills, templates, workflows, references, bin)
- Deleted entire `commands/gsd/` directory (GSD slash commands)
- Replaced with documentation stubs (`skills/README.md`, `commands/README.md`) pointing to upstream repos

### 2. Rewrote deploy_skills() in install.sh
- GSD skills: `git clone https://github.com/gsd-build/get-shit-done` -> `~/.claude/get-shit-done/`
- Superpowers commands: `git clone https://github.com/obra/superpowers` -> `~/.claude/commands/`
- Fresh install: clones repo (removes any stale non-git directory first)
- Re-install/update: `git pull --ff-only` on existing clone
- Failure handling: warns and continues (non-fatal)
- Repo URLs overridable via `CLAUDE_RESTART_GSD_REPO` and `CLAUDE_RESTART_SUPERPOWERS_REPO` env vars

### 3. Updated Tests
- Added git mock to `setup_linux_mocks()` so all Linux install tests use mocked git
- Added HOME isolation to `run_linux_install()` to prevent tests from touching real `~/.claude/`
- Test 21: Verifies git clone called with correct repo URLs
- Test 22: Verifies graceful handling when git clone fails
- Test 23: Verifies git pull for existing repos (update path)
- Updated phase14 validation tests to check for git-based patterns instead of vendored cp patterns

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added git mock to setup_linux_mocks()**
- **Found during:** Task 3
- **Issue:** Existing Linux tests (11-20) used `run_linux_install` which only mocked systemctl/loginctl, not git. With deploy_skills now using git, these tests would hit real git commands.
- **Fix:** Added git mock to `setup_linux_mocks()` and HOME isolation to `run_linux_install()`
- **Files modified:** test/test-install.sh

## Pre-existing Issues (Out of Scope)

- **Test 20 (Custom watchdog hours):** Fails because `CLAUDE_WATCHDOG_HOURS` env var is not applied during timer template copy. This failure pre-dates this change (confirmed by running tests on prior commit). Not related to skills deployment.

## Known Stubs

None - all functionality is fully wired.

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Remove vendored skills and commands | ca02a7f |
| 2 | Rewrite deploy_skills for git clone/pull | 64eda90 |
| 3 | Update tests for git-based deployment | 7b84204 |

## Self-Check: PASSED
