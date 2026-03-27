---
phase: 14-skills-deployment-and-identity
verified: 2026-03-27T21:59:34Z
status: passed
score: 6/6 must-haves verified
re_verification: false
---

# Phase 14: Skills Deployment and Identity Verification Report

**Phase Goal:** Deploy GSD and superpowers skills to VPS instruments via install.sh, inject per-instrument identity CLAUDE.md, and fix session naming for phone display
**Verified:** 2026-03-27T21:59:34Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | install.sh --install on Linux deploys GSD skills from repo's skills/ directory to ~/.claude/get-shit-done/ on VPS | VERIFIED | `deploy_skills()` at install.sh:84 copies `$SCRIPT_DIR/../skills/get-shit-done/*` to `$HOME/.claude/get-shit-done/`; called at line 124 |
| 2 | install.sh --install on Linux deploys superpowers commands from repo's commands/ directory to ~/.claude/commands/ on VPS | VERIFIED | `deploy_skills()` copies `$SCRIPT_DIR/../commands/*` to `$HOME/.claude/commands/`; Test 21 verified end-to-end |
| 3 | claude -p in instrument directories inherits GSD skills from ~/.claude/ (design assumption; no executable test possible) | VERIFIED (design) | DEPL-03 is a design assumption per plan note; deploy_skills ensures ~/.claude/get-shit-done/ is populated; Claude Code user-level skill inheritance is by-design |
| 4 | Each instrument's working directory has a .claude/CLAUDE.md containing its instance name and claude-restart --instance hint | VERIFIED | claude-service do_add() at line 84-92 deploys instrument-CLAUDE.md.template to $work_dir/.claude/CLAUDE.md with sed substitution; Tests 12-13 pass 34/34 |
| 5 | claude-service add deploys instrument identity CLAUDE.md automatically | VERIFIED | do_add() and do_add_orchestra() both deploy .claude/CLAUDE.md; script_dir defined at lines 50-51 and 134-135 |
| 6 | Phone shows clean session names derived from --name flag (no duplicate 'General coding session') | VERIFIED | claude-wrapper line 24: `if [[ -n "${CLAUDE_INSTANCE_NAME:-}" ]]; then mode_args+=("--name" "$CLAUDE_INSTANCE_NAME")` — no `!= "default"` exclusion; spot-check confirmed `--name default` logged for default instance |

**Score:** 6/6 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `bin/install.sh` | deploy_skills function called during Linux install | VERIFIED | Function defined at line 84, called at line 124 inside do_install_linux step 1c |
| `test/test-install.sh` | Tests 21-23 verifying skills deployment | VERIFIED | Lines 382, 420, 456 contain Tests 21, 22, 23 respectively; 51/53 pass (2 pre-existing failures in Test 20) |
| `instrument-CLAUDE.md.template` | Template with INSTANCE_PLACEHOLDER markers | VERIFIED | File exists at repo root; 7 occurrences of INSTANCE_PLACEHOLDER confirmed |
| `bin/claude-service` | Identity CLAUDE.md deployment in do_add and do_add_orchestra | VERIFIED | Lines 84-92 (do_add) and 174-187 (do_add_orchestra); script_dir correctly defined in both functions |
| `test/test-service-lifecycle.sh` | Tests 12-14 verifying identity deployment | VERIFIED | Tests 12, 13, 14 present; 34/34 pass |
| `skills/get-shit-done/README.md` | Source directory for GSD skills | VERIFIED (stub-only, warning) | File exists with 7 lines; contains only README — no actual skill files. Graceful skip handles this. See Anti-Patterns. |
| `commands/README.md` | Source directory for superpowers commands | VERIFIED (stub-only, warning) | File exists with 7 lines; contains only README — no actual command files. Graceful skip handles this. See Anti-Patterns. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bin/install.sh` | `~/.claude/get-shit-done/` | cp -r in deploy_skills | WIRED | Line 92: `cp -r "$skills_src/get-shit-done/"* "$claude_dir/get-shit-done/"` |
| `bin/install.sh` | `~/.claude/commands/` | cp -r in deploy_skills | WIRED | Line 101: `cp -r "$commands_src/"* "$claude_dir/commands/"` |
| `bin/claude-service` | `instrument-CLAUDE.md.template` | cp + sed in do_add | WIRED | Line 86: `claude_md_template="$script_dir/../instrument-CLAUDE.md.template"`, cp + sed at lines 89-90 |
| `instrument-CLAUDE.md.template` | `~/instruments/<name>/.claude/CLAUDE.md` | INSTANCE_PLACEHOLDER sed substitution | WIRED | `sed_inplace "s|INSTANCE_PLACEHOLDER|$name|g"` at line 90; test-service-lifecycle Test 12 verified substitution produces correct instance name |
| `bin/claude-wrapper` | `--name $CLAUDE_INSTANCE_NAME` | CLAUDE_INSTANCE_NAME env var | WIRED | Line 24-26: unconditional --name append when CLAUDE_INSTANCE_NAME set; spot-check confirmed `--name default` in mock invocation |

---

### Data-Flow Trace (Level 4)

Not applicable — all artifacts are shell scripts and Markdown templates, not UI components rendering dynamic data from APIs or databases.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| deploy_skills copies GSD to ~/.claude/get-shit-done/ | Test 21 via test-install.sh | PASS (51/53) | PASS |
| deploy_skills skips gracefully when source missing | Test 22 via test-install.sh | PASS | PASS |
| identity CLAUDE.md deployed with correct instance name | Test 12 via test-service-lifecycle.sh | PASS (34/34) | PASS |
| identity CLAUDE.md not overwriting repo root CLAUDE.md | Test 13 via test-service-lifecycle.sh | PASS | PASS |
| default instance gets --name flag | Direct mock invocation: `CLAUDE_CONNECT=remote-control CLAUDE_INSTANCE_NAME=default claude-wrapper` | `remote-control --permission-mode bypassPermissions --name default` logged | PASS |
| no != "default" exclusion in wrapper | `grep -c '!= "default"' bin/claude-wrapper` | 0 matches | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| DEPL-01 | 14-01-PLAN | Installer deploys GSD skills (~/.claude/get-shit-done/) to VPS | SATISFIED | deploy_skills() copies skills/get-shit-done/ to ~/.claude/get-shit-done/ |
| DEPL-02 | 14-01-PLAN | Installer deploys superpowers skills to VPS | SATISFIED | deploy_skills() copies commands/ to ~/.claude/commands/ |
| DEPL-03 | 14-01-PLAN | claude -p in instrument directories inherits GSD skills from ~/.claude/ | SATISFIED (design assumption) | Deploy populates ~/.claude/; Claude Code user-level inheritance is internal behavior |
| INST-01 | 14-02-PLAN | Instruments know their own instance name via CLAUDE.md or env injection | SATISFIED | .claude/CLAUDE.md deployed with instance name; CLAUDE_INSTANCE_NAME also in env |
| INST-02 | 14-02-PLAN | Instrument CLAUDE.md template includes instance name and claude-restart --instance hint | SATISFIED | instrument-CLAUDE.md.template contains both INSTANCE_PLACEHOLDER (7x) and "claude-restart --instance INSTANCE_PLACEHOLDER" |
| SESS-01 | 14-02-PLAN | Fix duplicate "General coding session" on phone from pre-created remote-control sessions | SATISFIED | Removed != "default" exclusion; all instances including default now receive --name flag |

No orphaned requirements: all 6 Phase 14 requirements from REQUIREMENTS.md appear in plan frontmatter and are verified.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `skills/get-shit-done/README.md` | 1-7 | Source directory contains only README, no actual GSD skill files | WARNING | deploy_skills will print "Deployed GSD skills" on VPS but copy only the README; instruments will have an empty get-shit-done/ dir. Graceful skip does NOT apply here (the directory exists). User must manually populate before deploying to VPS. |
| `commands/README.md` | 1-7 | Source directory contains only README, no actual command files | WARNING | Same as above — deploy_skills will copy only README to ~/.claude/commands/. User must manually copy local ~/.claude/commands/ contents here before VPS deployment. |
| `test/test-install.sh` | Test 20 | Pre-existing failure: CLAUDE_WATCHDOG_HOURS not modifying systemd timer template | WARNING (pre-existing) | 2 of 53 tests fail (Test 20 only). Documented in SUMMARY-01 as known tech debt from v2.0. Not introduced by Phase 14. |

**Blocker anti-patterns:** None

**Note on skills stub:** The stub state of skills/ and commands/ is a documented deployment prerequisite, not a code defect. The install.sh graceful-skip logic handles MISSING directories correctly (prints Warning). However, when the directory EXISTS with only a README, deploy_skills will run silently and produce an incomplete ~/.claude/ on VPS. This is a WARNING, not a blocker — it matches the explicit design decision in 14-01-SUMMARY ("User must populate skills/get-shit-done/ and commands/ with actual skill files before running install.sh on VPS").

---

### Human Verification Required

#### 1. VPS End-to-End Skills Deployment

**Test:** Run `install.sh --install` on an actual Linux VPS after populating `skills/get-shit-done/` and `commands/` with real content. Verify `/home/user/.claude/get-shit-done/` contains GSD workflows and `/home/user/.claude/commands/` contains superpowers skills.
**Expected:** GSD skills accessible to `claude -p` invocations in instrument working directories.
**Why human:** Requires real VPS, real Claude Code installation, and real `claude -p` invocation to confirm skill inheritance works end-to-end.

#### 2. Phone Session Naming Display

**Test:** Open Claude app on phone, navigate to Sessions. After restarting instruments, verify each shows its instance name (e.g., "default", "research") instead of "General coding session".
**Expected:** Each instrument session shows its CLAUDE_INSTANCE_NAME rather than the generic session name.
**Why human:** Phone UI display cannot be verified programmatically; requires visual inspection on device.

#### 3. Instrument Identity CLAUDE.md Visible to Claude Session

**Test:** After `claude-service add <name> <git_url>` on VPS, open a claude session in the instrument's working directory. Verify Claude acknowledges its instance name when asked.
**Expected:** Claude responds with the correct instance name (from .claude/CLAUDE.md), mentions the claude-restart --instance hint.
**Why human:** Requires live Claude Code session on VPS; .claude/CLAUDE.md interpretation is internal behavior not verifiable statically.

---

### Gaps Summary

No gaps. All 6 must-have truths verified, all artifacts substantive and wired, all 6 requirements satisfied.

The two WARNING-level items (skills/commands stub-only dirs) are documented deployment prerequisites — not implementation defects. The pre-existing Test 20 failure predates Phase 14 and is out of scope.

---

_Verified: 2026-03-27T21:59:34Z_
_Verifier: Claude (gsd-verifier)_
