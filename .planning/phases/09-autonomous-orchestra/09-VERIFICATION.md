---
phase: 09-autonomous-orchestra
verified: 2026-03-23T23:55:00Z
status: human_needed
score: 13/13 must-haves verified
re_verification:
  previous_status: human_needed
  previous_score: 13/13
  gaps_closed: []
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Deploy orchestra and add a new instrument while orchestra is running"
    expected: "On the next GSD loop cycle, orchestra discovers the new instrument via list_peers, spawns an assessment agent, and begins driving it"
    why_human: "list_peers polling is behavioral -- cannot verify runtime detection programmatically from static files"
  - test: "Remove an instrument (stop its service) while orchestra is running"
    expected: "Orchestra stops sending messages to the removed instrument and does not error-loop on stale peer IDs"
    why_human: "Removal handling depends on runtime behavior of check_messages and list_peers -- not verifiable statically"
  - test: "Run claude-service add-orchestra on a VPS with a running default instance"
    expected: "Orchestra service starts, CLAUDE_CHANNELS is set to server:claude-peers, claude-peers MCP connects, list_peers returns at least one peer"
    why_human: "Requires live VPS environment with claude-peers server actually running"
---

# Phase 9: Autonomous Orchestra Verification Report

**Phase Goal:** An optional autonomous Claude session supervises all instruments -- dispatching work, resetting context, spawning research agents, and adapting to fleet changes
**Verified:** 2026-03-23T23:55:00Z
**Status:** human_needed
**Re-verification:** Yes -- confirming all prior verified truths hold after plan 09-04 (argument ordering fix)

## Goal Achievement

All 13 truths verified against the live codebase. Test suites run and confirmed passing.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | env.template includes CLAUDE_CHANNELS variable for channel flag injection | VERIFIED | `systemd/env.template` line 30: `CLAUDE_CHANNELS=` present; PATH ends with `.bun/bin` |
| 2 | claude-wrapper passes --dangerously-load-development-channels when CLAUDE_CHANNELS is set | VERIFIED | `bin/claude-wrapper` lines 54-57: guards on `${CLAUDE_CHANNELS:-}`, injects flag; all three invocations include `${channel_args[@]}` |
| 3 | claude-service add-orchestra subcommand creates orchestra instrument without git clone | VERIFIED | `bin/claude-service` lines 117-185: `do_add_orchestra()` function with `mkdir -p "$work_dir"`, no `git clone`; sets `CLAUDE_CHANNELS=server:claude-peers` |
| 4 | Test scripts validate orchestra env file generation and wrapper channel injection | VERIFIED | `test/test-wrapper-channels.sh` 7/7 pass; `test/test-orchestra.sh` 8/8 pass (live run confirmed) |
| 5 | Orchestra CLAUDE.md defines the supervisor role with concrete tool examples | VERIFIED | `orchestra/CLAUDE.md` 251 lines: all 6 tools have code-block examples with real parameters |
| 6 | CLAUDE.md includes GSD workflow sequence (discuss -> plan -> execute) per D-04 | VERIFIED | Lines 106-122: numbered sequence with `gsd:discuss-phase`, `gsd:plan-phase`, `gsd:execute-phase`; step e handles `/clear` |
| 7 | CLAUDE.md documents parallel dispatch pattern per D-09 | VERIFIED | Lines 127-154: "Drive ALL instruments simultaneously"; example shows 3 parallel `send_message` calls before any `check_messages` |
| 8 | CLAUDE.md includes user escalation tagging format per D-10 | VERIFIED | Lines 160-173: `[1/blog]` and `[2/api]` format with `Reply with the tag` routing instruction |
| 9 | CLAUDE.md documents context reset via claude-restart per D-13/D-14 | VERIFIED | Lines 73-91: `claude-restart --instance blog` with post-restart `list_peers` polling; anti-pattern 5 prevents unnecessary restarts |
| 10 | ORCH-04 requirement marked complete in REQUIREMENTS.md | VERIFIED | All five ORCH checkboxes are `[x]`; traceability table shows all as Complete |
| 11 | claude-wrapper in remote-control mode uses --permission-mode bypassPermissions instead of --dangerously-skip-permissions | VERIFIED | `bin/claude-wrapper` line 23: `mode_args=("remote-control" "--permission-mode" "bypassPermissions")`; filter block at lines 41-51 removes any stray `--dangerously-skip-permissions` |
| 12 | claude-wrapper in remote-control mode auto-confirms the Enable Remote Control prompt by piping y to stdin | VERIFIED | `bin/claude-wrapper` line 106: `echo "y" \| claude "${channel_args[@]}" "${mode_args[@]}" "${current_args[@]}" &` |
| 13 | channel_args appear before mode_args in all three claude invocations (argument ordering fix from plan 09-04) | VERIFIED | Lines 85, 106, 109: all three invocations show `claude "${channel_args[@]}" "${mode_args[@]}"` pattern; test/test-wrapper-channels.sh Test 7 enforces this as a regression guard |

**Score:** 13/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `systemd/env.template` | CLAUDE_CHANNELS variable and ~/.bun/bin in PATH | VERIFIED | Line 30: `CLAUDE_CHANNELS=`; line 27: PATH ends with `:HOME_PLACEHOLDER/.bun/bin` |
| `bin/claude-wrapper` | Channel flag injection + remote-control permission fix + auto-confirm + correct argument ordering | VERIFIED | 163 lines; `channel_args` at lines 54-57; `--permission-mode bypassPermissions` at line 23; filter at lines 41-51; auto-confirm at line 106; channel_args before mode_args at lines 85/106/109 |
| `bin/claude-service` | add-orchestra subcommand for registering orchestra without git clone | VERIFIED | 296 lines; `do_add_orchestra()` at lines 117-185; `add-orchestra)` case at line 243; usage lists it |
| `test/test-orchestra.sh` | Structural validation for orchestra registration (8 tests) | VERIFIED | 76 lines; 8 tests; all pass |
| `test/test-wrapper-channels.sh` | Validation for wrapper channel flag injection + argument ordering (7 tests) | VERIFIED | 68 lines; 7 tests including argument-order regression; all pass |
| `test/test-wrapper.sh` | Full wrapper test suite including remote-control permission and auto-confirm (39 tests) | VERIFIED | 456+ lines; 39 tests; all pass |
| `orchestra/CLAUDE.md` | Orchestra supervisor behavior definition | VERIFIED | 251 lines; 8 sections; all required tool references, workflow sequence, and anti-patterns present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `systemd/env.template` | `bin/claude-wrapper` | CLAUDE_CHANNELS env var read by wrapper | WIRED | Template defines `CLAUDE_CHANNELS=`; wrapper reads `${CLAUDE_CHANNELS:-}` to build `channel_args` |
| `bin/claude-service` | `systemd/env.template` | add-orchestra copies and customizes env template | WIRED | `do_add_orchestra()` does `cp "$template" "$env_dir/env"` then sed-replaces `CLAUDE_CHANNELS=server:claude-peers` |
| `orchestra/CLAUDE.md` | `bin/claude-restart` | claude-restart --instance for context reset | WIRED | CLAUDE.md lines 73, 80, 117, 149: `claude-restart --instance <name>` with correct syntax |
| `orchestra/CLAUDE.md` | claude-peers MCP | list_peers, send_message, check_messages, set_summary tools | WIRED | All 4 tools present with correct schemas; `list_peers(scope: "machine")` appears 9 times |
| `bin/claude-wrapper` | `claude remote-control` | mode_args with --permission-mode bypassPermissions | WIRED | Line 23: `mode_args=("remote-control" "--permission-mode" "bypassPermissions")` |
| `bin/claude-wrapper` | `claude remote-control stdin` | echo y piped to stdin for auto-confirm | WIRED | Line 106: `echo "y" \| claude "${channel_args[@]}" "${mode_args[@]}" ...` in the `elif remote-control` branch |
| `bin/claude-wrapper` | `claude` top-level flags | channel_args before mode_args at all invocation sites | WIRED | Lines 85, 106, 109: `channel_args[@]` precedes `mode_args[@]` at all three sites |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ORCH-01 | 09-01, 09-02, 09-03, 09-04 | Orchestra is itself an instrument -- a Claude session with CLAUDE.md that runs as its own systemd service | SATISFIED | `add-orchestra` creates `~/instruments/orchestra`, enables `claude@orchestra.service` and watchdog; `orchestra/CLAUDE.md` is the behavioral spec; wrapper starts non-interactively (permission fix + auto-confirm + correct arg order) |
| ORCH-02 | 09-02 | Orchestra can dispatch one-shot agents via `claude -p` in any instrument's project directory | SATISFIED | CLAUDE.md documents `cd ~/instruments/<name> && claude -p "..." --dangerously-skip-permissions` throughout; anti-pattern 7 explicitly forbids `--cwd` |
| ORCH-03 | 09-02 | Orchestra can restart any instrument via `claude-restart --instance <name>` for context reset between phases | SATISFIED | CLAUDE.md lines 73-91 document full restart cycle with `list_peers` re-discovery polling |
| ORCH-04 | 09-01 | Orchestra detects instruments added or removed while it is running (dynamic discovery) | SATISFIED | REQUIREMENTS.md `[x]`; CLAUDE.md GSD loop step 1 always calls `list_peers`; idle state says "wait for... new instruments to appear"; anti-pattern 4 enforces re-discovery on restarts |
| ORCH-05 | 09-02 | Orchestra always routes messages to the correct instrument based on project context | SATISFIED | CLAUDE.md uses `working_directory` from `list_peers` as stable instrument identifier; anti-pattern 4 forbids caching peer IDs |

No orphaned requirements. All five ORCH requirements are claimed by at least one plan, implemented, and checkmarked in REQUIREMENTS.md. The traceability table marks all five as Complete at Phase 9.

### Anti-Patterns Found

No blockers or stubs found.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `orchestra/CLAUDE.md` | 58, 110, 239 | `--dangerously-skip-permissions` in one-shot `claude -p` examples | Info | Intentional: one-shot agents spawned by shell use this flag; the orchestra SERVICE uses `--permission-mode bypassPermissions` via the wrapper. Correct per design. |

### Human Verification Required

#### 1. Dynamic Instrument Discovery at Runtime

**Test:** Add a new instrument via `claude-service add <name> <url>` while orchestra is running and idle.
**Expected:** On the next check cycle, orchestra calls `list_peers`, finds the new instrument, spawns an assessment one-shot agent, and begins driving it through GSD if it has pending work.
**Why human:** The polling mechanism is behavioral (CLAUDE.md instruction-driven). Cannot verify the LLM session will actually re-poll `list_peers` while idle without running it live.

#### 2. Instrument Removal Handling

**Test:** Stop an instrument's service (`systemctl --user stop claude@<name>`) while orchestra has it in its mental model.
**Expected:** On the next `list_peers` call, the instrument no longer appears. Orchestra stops trying to message it and does not error-loop on stale peer IDs.
**Why human:** Runtime behavior of the idle polling loop; static analysis cannot confirm the LLM handles absence gracefully.

#### 3. End-to-End VPS Deployment

**Test:** On the VPS, run `claude-service add-orchestra`. Verify that `systemctl --user status claude@orchestra.service` shows active, `CLAUDE_CHANNELS=server:claude-peers` is in the env, and the orchestra session starts up, auto-confirms the Enable Remote Control prompt, and calls `list_peers`.
**Expected:** Service starts without hanging on the "Enable Remote Control?" prompt; orchestra discovers running instruments.
**Why human:** Requires live VPS environment with claude-peers MCP server actually running. The `echo "y" |` auto-confirm fix (plan 09-03) and argument ordering fix (plan 09-04) specifically address the blocking issues found in UAT, but can only be confirmed against a live service.

### Gaps Summary

No gaps remain. All automated checks pass on the live codebase:

- `test/test-wrapper.sh`: 39/39 passed
- `test/test-wrapper-channels.sh`: 7/7 passed (includes new argument-order regression test from plan 09-04)
- `test/test-orchestra.sh`: 8/8 passed

All five ORCH requirements are marked complete in REQUIREMENTS.md with full traceability. Both commits documented in plan 09-04 (`c3dfa5a`, `501a769`) are confirmed present in git history.

The three remaining human verification items require a live VPS environment with claude-peers MCP server. These are runtime behavioral tests -- the code, specification, and infrastructure are all complete and verified.

---

_Verified: 2026-03-23T23:55:00Z_
_Verifier: Claude (gsd-verifier)_
