---
phase: 12-peers-teardown
verified: 2026-03-27T19:15:00Z
status: passed
score: 9/9 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 7/9
  gaps_closed:
    - "bin/message-watcher deleted from filesystem"
    - "local claude_config declaration restored in do_add_orchestra"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Confirm CLNP-01 traceability in REQUIREMENTS.md reflects D-02 scoped completion"
    expected: "CLNP-01 row updated to Complete and checkbox marked [x] — provisioning code was removed per D-02 scope"
    why_human: "Policy/scope judgment call — whether D-02 satisfies CLNP-01 fully is for the project owner to confirm"
  - test: "Run claude-service add-orchestra in a test environment"
    expected: "~/.claude.json receives remoteDialogSeen=true; no empty-path file created"
    why_human: "Runtime behavior — bash -n cannot catch variable-expansion bugs; only confirms syntax"
---

# Phase 12: Peers Teardown Verification Report

**Phase Goal:** Strip claude-peers infrastructure from wrapper, services, and config
**Verified:** 2026-03-27T19:15:00Z
**Status:** human_needed — all automated checks pass; 2 items need human confirmation
**Re-verification:** Yes — after gap closure (2 gaps fixed since initial verification)

## Re-verification Summary

| Gap | Previous Status | Current Status |
|-----|-----------------|----------------|
| bin/message-watcher not deleted | FAILED | CLOSED — file is absent from disk |
| Undefined $claude_config in do_add_orchestra | PARTIAL | CLOSED — `local claude_config="$HOME/.claude.json"` restored at line 124 |

No regressions detected. Score improved from 7/9 to 9/9.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | claude-wrapper launches claude without --dangerously-load-development-channels flag | VERIFIED | `grep -c 'dangerously-load-development-channels' bin/claude-wrapper` = 0 |
| 2 | claude-wrapper does not spawn a message-watcher sidecar | VERIFIED | `grep -c 'stop_watcher\|watcher_pid\|message.watcher' bin/claude-wrapper` = 0 |
| 3 | claude-wrapper has no channel_args variable or CLAUDE_CHANNELS references | VERIFIED | `grep -c 'channel_args\|CLAUDE_CHANNELS' bin/claude-wrapper` = 0 |
| 4 | env.template contains no CLAUDE_CHANNELS variable | VERIFIED | `grep -c 'CLAUDE_CHANNELS' systemd/env.template` = 0 |
| 5 | bin/message-watcher file does not exist | VERIFIED | `ls bin/message-watcher` returns no such file — confirmed absent |
| 6 | install.sh does not deploy message-watcher | VERIFIED | `grep -c 'message-watcher' bin/install.sh` = 0 |
| 7 | install.sh uninstall does not reference message-watcher | VERIFIED | `grep -c 'message-watcher' bin/install.sh` = 0 (covers both deploy and uninstall) |
| 8 | claude-service add-orchestra does not set CLAUDE_CHANNELS or provision .mcp.json | VERIFIED | `grep -c 'CLAUDE_CHANNELS\|mcp_json\|mcpServers\|claude-peers' bin/claude-service` = 0; `claude_config` declared at line 124; remoteDialogSeen block at lines 186-192 wired correctly |
| 9 | test/test-wrapper-channels.sh does not exist | VERIFIED | File is deleted; `ls test/test-wrapper-channels.sh` returns no such file |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `bin/claude-wrapper` | Clean wrapper without peers infrastructure | VERIFIED | Zero channel_args, CLAUDE_CHANNELS, message-watcher, stop_watcher, watcher_pid, dangerously-load-development-channels references; bash -n passes; 3 claude invocations using only mode_args and current_args |
| `systemd/env.template` | Clean env template without CLAUDE_CHANNELS | VERIFIED | No CLAUDE_CHANNELS or claude-peers references; all non-peers config vars preserved |
| `bin/install.sh` | Clean installer without peers infrastructure | VERIFIED | No message-watcher references; claude-wrapper, claude-restart, claude-service deployments intact; bash -n passes |
| `bin/claude-service` | Clean service manager without peers provisioning | VERIFIED | CLAUDE_CHANNELS and .mcp.json provisioning removed; `local claude_config="$HOME/.claude.json"` declared at line 124; remoteDialogSeen block properly wired to that variable; bash -n passes |
| `test/test-orchestra.sh` | Orchestra tests without peers-specific assertions | VERIFIED | 9 tests (renumbered); zero CLAUDE_CHANNELS, mcp_json, mcpServers, claude-peers references; all 9 tests pass |
| `bin/message-watcher` | Must NOT exist | VERIFIED | File absent from filesystem |
| `test/test-wrapper-channels.sh` | Must NOT exist | VERIFIED | File deleted |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| bin/claude-wrapper | claude CLI | direct invocation without channel_args | VERIFIED | Lines contain `claude "${mode_args[@]}" "${current_args[@]}"` — exactly 3 invocations, zero channel_args; `grep -c 'claude.*mode_args' bin/claude-wrapper` = 3 |
| bin/install.sh | bin/claude-wrapper | cp to install dir | VERIFIED | `grep -c 'cp.*claude-wrapper' bin/install.sh` = 2 (deploy + chmod) |
| bin/claude-service | systemd/env.template | cp template to env dir | VERIFIED | `grep -c 'cp.*template' bin/claude-service` = 2 (do_add + do_add_orchestra) |

### Data-Flow Trace (Level 4)

Not applicable — phase is removal-only. No new data-rendering components introduced.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| claude-wrapper bash syntax valid | `bash -n bin/claude-wrapper` | exits 0 | PASS |
| install.sh bash syntax valid | `bash -n bin/install.sh` | exits 0 | PASS |
| claude-service bash syntax valid | `bash -n bin/claude-service` | exits 0 | PASS |
| test-orchestra.sh all 9 pass | `bash test/test-orchestra.sh` | 9 passed, 0 failed | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CLNP-01 | 12-02 | Remove claude-peers MCP server config (.mcp.json) from instruments and orchestra | SATISFIED (scope per D-02) | Provisioning block removed from do_add_orchestra. No .mcp.json files exist in repo. Scope was "remove provisioning code only" per D-02 — existing VPS files cleaned manually. REQUIREMENTS.md traceability row still shows Pending — needs human update. |
| CLNP-02 | 12-01, 12-02 | Remove CLAUDE_CHANNELS env var from env files and env.template | SATISFIED | 0 references in env.template, claude-wrapper, claude-service |
| CLNP-03 | 12-01 | Remove --dangerously-load-development-channels flag handling from claude-wrapper | SATISFIED | 0 references in claude-wrapper |
| CLNP-04 | 12-01 | Remove message-watcher sidecar from claude-wrapper | SATISFIED | Sidecar spawn code removed from wrapper; bin/message-watcher deleted from disk |
| CLNP-05 | 12-01, 12-02 | Remove claude-peers broker startup/dependency from systemd services | SATISFIED | No broker references in install.sh, claude-service, or env.template |

**Note on CLNP-01:** REQUIREMENTS.md still shows `[ ]` (Pending) for CLNP-01 and the traceability table shows "Pending". Decision D-02 explicitly scoped CLNP-01 to "remove provisioning code only". That code is removed. The REQUIREMENTS.md row should be updated to Complete — flagged for human confirmation.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| bin/claude-wrapper | 29 | `--channels "plugin:telegram@..."` | Info | This is the Telegram MCP plugin flag — unrelated to claude-peers. Correctly retained; not a peers artifact. |

No blockers or warnings. The only grep hit for "channel" in modified files is the intentional Telegram plugin invocation.

### Human Verification Required

#### 1. CLNP-01 Traceability Update

**Test:** Confirm that CLNP-01 in REQUIREMENTS.md reflects D-02 scoped completion — mark `[x]` and update traceability table row to "Complete".
**Expected:** CLNP-01 checkbox checked and traceability row updated to "Complete".
**Why human:** Policy/scope judgment call — whether D-02 fully satisfies CLNP-01 ("remove from instruments and orchestra") is for the project owner to decide and record.

#### 2. do_add_orchestra Runtime Behavior

**Test:** Run `claude-service add-orchestra` in a test environment. Inspect `~/.claude.json` afterward.
**Expected:** `~/.claude.json` contains `"remoteDialogSeen": true`; no spurious file created at empty path.
**Why human:** `bash -n` validates syntax only. The `$claude_config` fix is correct at the code level (declaration at line 124 feeds lines 186-192), but runtime confirmation in a real environment closes the loop on the original bug.

### Gaps Summary

No gaps remain. Both gaps from the initial verification are closed:

- **Gap 1 closed:** `bin/message-watcher` is absent from the filesystem.
- **Gap 2 closed:** `local claude_config="$HOME/.claude.json"` is declared at line 124 of `do_add_orchestra`, and the remoteDialogSeen block at lines 186-192 correctly uses it to update `~/.claude.json`.

Two items are routed to human verification: CLNP-01 traceability update in REQUIREMENTS.md, and runtime confirmation of the do_add_orchestra fix. Neither blocks the automated goal assessment.

---

_Verified: 2026-03-27T19:15:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: Yes — after gap closure_
