---
phase: 09-autonomous-orchestra
verified: 2026-03-24T01:35:00Z
status: human_needed
score: 19/19 must-haves verified
re_verification:
  previous_status: human_needed
  previous_score: 16/16
  gaps_closed: []
  gaps_remaining: []
  regressions: []
  note: "Full re-verification adding plan 09-06 must_haves (remoteDialogSeen pre-set, echo y removal). Previous verification covered plans 09-01 through 09-05 only. Test suite grew from 39 to 41 tests (Tests 21 rewritten, Test 23 added)."
human_verification:
  - test: "Deploy orchestra and add a new instrument while orchestra is running"
    expected: "On the next GSD loop cycle, orchestra discovers the new instrument via list_peers, spawns an assessment agent, and begins driving it"
    why_human: "list_peers polling is behavioral -- cannot verify runtime detection programmatically from static files"
  - test: "Remove an instrument (stop its service) while orchestra is running"
    expected: "Orchestra stops sending messages to the removed instrument and does not error-loop on stale peer IDs"
    why_human: "Removal handling depends on runtime behavior of check_messages and list_peers -- not verifiable statically"
  - test: "Run claude-service add-orchestra on a VPS with a running default instance"
    expected: "Orchestra service starts, remoteDialogSeen=true is written to ~/.claude.json before launch, CLAUDE_CHANNELS is set to server:claude-peers, claude-peers MCP connects, list_peers returns at least one peer, and remote-control session stays alive (FIFO heartbeat keeps stdin open, no prompt blocking)"
    why_human: "Requires live VPS environment with claude-peers MCP server actually running; confirm session spawns (no 'Enable Remote Control?' prompt, no echo y stale stdin data) -- can only be confirmed against a live service"
---

# Phase 9: Autonomous Orchestra Verification Report

**Phase Goal:** An optional autonomous Claude session supervises all instruments -- dispatching work, resetting context, spawning research agents, and adapting to fleet changes
**Verified:** 2026-03-24T01:35:00Z
**Status:** human_needed
**Re-verification:** Yes -- full coverage of all six plans (09-01 through 09-06); previous verification covered 09-01 through 09-05 only.

## Goal Achievement

All 19 must-have truths verified. Three human verification items remain (runtime behavioral, require live VPS).

### Observable Truths

| # | Truth | Plan | Status | Evidence |
|---|-------|------|--------|----------|
| 1 | env.template includes CLAUDE_CHANNELS variable for channel flag injection | 09-01 | VERIFIED | `systemd/env.template` line 30: `CLAUDE_CHANNELS=` present; PATH ends with `.bun/bin` |
| 2 | claude-wrapper passes --dangerously-load-development-channels when CLAUDE_CHANNELS is set | 09-01 | VERIFIED | `bin/claude-wrapper` lines 54-57: guards on `${CLAUDE_CHANNELS:-}`, builds `channel_args`; all three invocations include `${channel_args[@]}` |
| 3 | claude-service add-orchestra subcommand creates orchestra instrument without git clone | 09-01 | VERIFIED | `bin/claude-service`: `do_add_orchestra()` uses `mkdir -p "$work_dir"`, no `git clone`; sets `CLAUDE_CHANNELS=server:claude-peers` |
| 4 | Test scripts validate orchestra env file generation and wrapper channel injection | 09-01 | VERIFIED | `test/test-wrapper-channels.sh` 7/7 pass; `test/test-orchestra.sh` 8/8 pass |
| 5 | Orchestra CLAUDE.md defines the supervisor role with concrete tool examples | 09-02 | VERIFIED | `orchestra/CLAUDE.md` 251 lines; all 6 tools (list_peers, send_message, check_messages, set_summary, claude -p, claude-restart) have code-block examples |
| 6 | CLAUDE.md includes GSD workflow sequence (discuss -> plan -> execute) per D-04 | 09-02 | VERIFIED | Lines 106-122: numbered sequence with `gsd:discuss-phase`, `gsd:plan-phase`, `gsd:execute-phase`; step e handles `/clear` restart |
| 7 | CLAUDE.md documents parallel dispatch pattern per D-09 | 09-02 | VERIFIED | Lines 127-154: "Drive ALL instruments simultaneously"; example shows 3 parallel `send_message` calls before any `check_messages` |
| 8 | CLAUDE.md includes user escalation tagging format per D-10 | 09-02 | VERIFIED | Lines 160-173: `[1/blog]` and `[2/api]` format with `Reply with the tag` routing instruction |
| 9 | CLAUDE.md documents context reset via claude-restart per D-13/D-14 | 09-02 | VERIFIED | Lines 73-91: `claude-restart --instance blog` with post-restart `list_peers` polling; anti-pattern 5 prevents unnecessary restarts |
| 10 | CLAUDE.md documents one-shot dispatch via cd + claude -p per D-06 | 09-02 | VERIFIED | Lines 58-71: `cd ~/instruments/<name> && claude -p "..."` pattern; anti-pattern 7 and line 61 explicitly forbid `--cwd` |
| 11 | claude-wrapper in remote-control mode uses --permission-mode bypassPermissions | 09-03 | VERIFIED | `bin/claude-wrapper` line 23: `mode_args=("remote-control" "--permission-mode" "bypassPermissions")`; filter block at lines 43-51 removes `--dangerously-skip-permissions` |
| 12 | Existing wrapper behavior for telegram, interactive, and restart modes is unchanged | 09-03 | VERIFIED | `test/test-wrapper.sh` 41/41 pass; tests 1-16 cover all pre-existing modes |
| 13 | channel_args appear before mode_args in all three claude invocations | 09-04 | VERIFIED | `bin/claude-wrapper` lines 114, 137, 155: all three show `claude "${channel_args[@]}" "${mode_args[@]}"` pattern; test-wrapper-channels.sh Test 7 enforces as regression guard |
| 14 | Remote-control session stays alive indefinitely via FIFO stdin (no EOF) | 09-05 | VERIFIED | `bin/claude-wrapper` lines 133-153: `elif remote-control` branch uses `mkfifo` + heartbeat writer loop identical to telegram pattern; session is backgrounded reading from FIFO |
| 15 | Heartbeat keeps stdin open in remote-control mode, same as telegram mode | 09-05 | VERIFIED | Lines 143-151: heartbeat loop in remote-control branch mirrors telegram branch (lines 122-130); `test/test-wrapper.sh` Test 18 asserts heartbeat fires in remote-control mode |
| 16 | Remote-control mode pre-sets remoteDialogSeen=true in ~/.claude.json before launching claude, eliminating the 'Enable Remote Control?' prompt entirely | 09-06 | VERIFIED | `bin/claude-wrapper` lines 59-86: `ensure_remote_dialog_seen()` function; called at line 134 before FIFO setup in remote-control branch; jq path with python3 fallback; creates minimal config if missing |
| 17 | The FIFO 'y' write is removed since no prompt exists to consume it, preventing stale stdin data | 09-06 | VERIFIED | `grep -c 'echo.*"y".*>&3' bin/claude-wrapper` returns 0; `test/test-wrapper.sh` Test 21 asserts stdin does not receive 'y' (got empty string) |
| 18 | Orchestra add-orchestra and install.sh both ensure remoteDialogSeen is set for the user running the service | 09-06 | VERIFIED | `bin/claude-service` lines 173-182: `do_add_orchestra()` sets remoteDialogSeen; `bin/install.sh` lines 144-158: reads CLAUDE_CONNECT from env file, sets remoteDialogSeen when mode is remote-control |
| 19 | Test suite verifies remoteDialogSeen is set and echo y is removed | 09-06 | VERIFIED | `test/test-wrapper.sh` Test 21 (no 'y' on stdin, PASS), Test 23 (config file created with remoteDialogSeen, PASS); 41/41 total |

**Score:** 19/19 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `systemd/env.template` | CLAUDE_CHANNELS variable and ~/.bun/bin in PATH | VERIFIED | `CLAUDE_CHANNELS=` present; PATH ends with `:HOME_PLACEHOLDER/.bun/bin` |
| `bin/claude-wrapper` | Channel injection + permission fix + FIFO stdin for remote-control + correct argument ordering + ensure_remote_dialog_seen + no echo y | VERIFIED | 209 lines; channel_args lines 54-57; `--permission-mode bypassPermissions` line 23; FIFO remote-control block lines 133-153; channel_args before mode_args at lines 114/137/155; `ensure_remote_dialog_seen()` function lines 59-86; no echo y in remote-control FIFO |
| `bin/claude-service` | add-orchestra subcommand + remoteDialogSeen pre-set | VERIFIED | `do_add_orchestra()` function; `add-orchestra)` case; remoteDialogSeen block lines 173-182 |
| `bin/install.sh` | Linux install pre-sets remoteDialogSeen for remote-control mode | VERIFIED | Lines 144-158: reads CLAUDE_CONNECT from env file, conditional remoteDialogSeen set |
| `test/test-orchestra.sh` | Structural validation for orchestra registration (8 tests) | VERIFIED | 76 lines; 8/8 pass |
| `test/test-wrapper-channels.sh` | Channel flag injection + argument-order regression (7 tests) | VERIFIED | 68 lines; 7/7 pass including Test 7 argument-order regression guard |
| `test/test-wrapper.sh` | Full wrapper test suite including remoteDialogSeen pre-set and no echo y (41 tests) | VERIFIED | Tests 18 (heartbeat in remote-control), 19 (permission-mode flag), 21 (no y on stdin), 22 (interactive no pipe), 23 (config file creation); 41/41 pass |
| `orchestra/CLAUDE.md` | Orchestra supervisor behavioral specification | VERIFIED | 251 lines; 8 sections; all required tool references, workflow sequence, parallel dispatch, escalation format, anti-patterns present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `systemd/env.template` | `bin/claude-wrapper` | CLAUDE_CHANNELS env var read by wrapper | WIRED | Template defines `CLAUDE_CHANNELS=`; wrapper reads `${CLAUDE_CHANNELS:-}` to build `channel_args` |
| `bin/claude-service` | `systemd/env.template` | add-orchestra copies and customizes env template | WIRED | `do_add_orchestra()` does `cp "$template" "$env_dir/env"` then sed-replaces `CLAUDE_CHANNELS=server:claude-peers` |
| `orchestra/CLAUDE.md` | `bin/claude-restart` | claude-restart --instance for context reset | WIRED | CLAUDE.md lines 73, 80, 117, 149: `claude-restart --instance <name>` with correct syntax; anti-pattern 5 prevents overuse |
| `orchestra/CLAUDE.md` | claude-peers MCP | list_peers, send_message, check_messages, set_summary tools | WIRED | All 4 tools present with correct schemas and concrete parameter examples; `list_peers(scope: "machine")` appears 9 times |
| `bin/claude-wrapper` | `claude remote-control` | mode_args with --permission-mode bypassPermissions | WIRED | Line 23: `mode_args=("remote-control" "--permission-mode" "bypassPermissions")` |
| `bin/claude-wrapper` | FIFO heartbeat writer | mkfifo + background writer for remote-control stdin (no echo y) | WIRED | Lines 133-153: `ensure_remote_dialog_seen` called, `mkfifo "$HEARTBEAT_FIFO"`, heartbeat subshell opens fd 3 and loops -- no `echo "y"` |
| `bin/claude-wrapper` | `~/.claude.json` | ensure_remote_dialog_seen writes remoteDialogSeen=true before launch | WIRED | Lines 59-86: jq/python3 path creates or edits `~/.claude.json`; called at line 134 before FIFO setup |
| `bin/claude-service` | `~/.claude.json` | do_add_orchestra pre-sets remoteDialogSeen after env file creation | WIRED | Lines 173-182: jq sets remoteDialogSeen=true or creates minimal config; positioned after `chmod 600 env` |
| `bin/install.sh` | `~/.claude.json` | post-env-file block sets remoteDialogSeen when CLAUDE_CONNECT=remote-control | WIRED | Lines 144-158: reads CLAUDE_CONNECT from env file (not interactive variable), sets remoteDialogSeen for remote-control mode |
| `bin/claude-wrapper` | `claude` top-level flags | channel_args before mode_args at all invocation sites | WIRED | Lines 114, 137, 155: `${channel_args[@]}` precedes `${mode_args[@]}` at all three invocation sites |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ORCH-01 | 09-01, 09-02, 09-03, 09-04, 09-05, 09-06 | Orchestra is itself an instrument -- a Claude session with CLAUDE.md that runs as its own systemd service | SATISFIED | `add-orchestra` creates `~/instruments/orchestra`, enables `claude@orchestra.service` and watchdog; `orchestra/CLAUDE.md` is the behavioral spec; wrapper starts non-interactively (FIFO stdin + permission fix + remoteDialogSeen pre-set + no stale echo y + correct arg order) |
| ORCH-02 | 09-02 | Orchestra can dispatch one-shot agents via `claude -p` in any instrument's project directory | SATISFIED | CLAUDE.md documents `cd ~/instruments/<name> && claude -p "..." --dangerously-skip-permissions` throughout; anti-pattern 7 explicitly forbids `--cwd` |
| ORCH-03 | 09-02 | Orchestra can restart any instrument via `claude-restart --instance <name>` for context reset between phases | SATISFIED | CLAUDE.md lines 73-91 document full restart cycle with `list_peers` re-discovery polling |
| ORCH-04 | 09-01 | Orchestra detects instruments added or removed while it is running (dynamic discovery) | SATISFIED | REQUIREMENTS.md `[x]`; CLAUDE.md GSD loop step 1 always calls `list_peers`; idle state says "wait for... new instruments to appear"; anti-pattern 4 enforces re-discovery on restarts |
| ORCH-05 | 09-02 | Orchestra always routes messages to the correct instrument based on project context | SATISFIED | CLAUDE.md uses `working_directory` from `list_peers` as stable instrument identifier; anti-pattern 4 forbids caching peer IDs |

No orphaned requirements. All five ORCH requirements are claimed by at least one plan, implemented, and marked `[x]` in REQUIREMENTS.md. The traceability table records all five as Complete at Phase 9. ORCH-06 and ORCH-07 are explicitly deferred to "Advanced Orchestra" (Future Requirements section) and do not belong to this phase.

### Anti-Patterns Found

No blockers or stubs found.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `orchestra/CLAUDE.md` | 58, 110, 221 | `--dangerously-skip-permissions` in one-shot `claude -p` examples | Info | Intentional: one-shot agents spawned by shell use this flag; the orchestra SERVICE uses `--permission-mode bypassPermissions` via the wrapper. Correct per design. |

### Human Verification Required

#### 1. Dynamic Instrument Discovery at Runtime

**Test:** Add a new instrument via `claude-service add <name> <url>` while orchestra is running and idle.
**Expected:** On the next check cycle, orchestra calls `list_peers`, finds the new instrument, spawns an assessment one-shot agent, and begins driving it through GSD if it has pending work.
**Why human:** The polling mechanism is behavioral (CLAUDE.md instruction-driven). Cannot verify the LLM session will actually re-poll `list_peers` while idle without running it live.

#### 2. Instrument Removal Handling

**Test:** Stop an instrument's service (`systemctl --user stop claude@<name>`) while orchestra has it in its mental model.
**Expected:** On the next `list_peers` call, the instrument no longer appears. Orchestra stops trying to message it and does not error-loop on stale peer IDs.
**Why human:** Runtime behavior of the idle polling loop; static analysis cannot confirm the LLM handles absence gracefully.

#### 3. End-to-End VPS Deployment with remoteDialogSeen Pre-Set

**Test:** On the VPS, run `claude-service add-orchestra` (or `install.sh` for a fresh deploy). Verify that:
- `jq .remoteDialogSeen ~/.claude.json` returns `true` immediately after installation
- `systemctl --user status claude@orchestra.service` shows active
- The orchestra session starts without hanging on the "Enable Remote Control?" prompt
- No stale `y` appears in the session's stdin (prompt was bypassed, not answered)
- The session remains alive (FIFO heartbeat)
- Orchestra calls `list_peers` and discovers running instruments

**Expected:** Service starts without prompt-blocking; remoteDialogSeen=true confirmed in config file; session remains running; orchestra discovers instruments. The plan 09-06 fix (remoteDialogSeen pre-set) resolves the root cause identified in UAT Test 6 (session spawning but immediate death due to unhandled confirmation prompt).
**Why human:** Requires live VPS environment with claude-peers MCP server actually running. Session spawn and prompt bypass can only be confirmed against a live service.

### Gaps Summary

No gaps remain. All automated checks pass on the live codebase:

- `test/test-wrapper.sh`: 41/41 passed (includes Tests 18, 19, 20, 21, 22, 23 covering FIFO remote-control, permission, remoteDialogSeen, and no-echo-y)
- `test/test-wrapper-channels.sh`: 7/7 passed (includes argument-order regression test from plan 09-04)
- `test/test-orchestra.sh`: 8/8 passed

All six plans' must_haves are fully satisfied:

- **09-01**: Channel infrastructure (env.template, wrapper injection, add-orchestra, tests)
- **09-02**: Orchestra CLAUDE.md behavioral spec (all 8 sections, all 16 locked decisions)
- **09-03**: Remote-control permission fix and auto-confirm
- **09-04**: channel_args argument ordering fix (top-level flags before subcommand)
- **09-05**: FIFO-based stdin for remote-control (replaces `echo "y" |` pipe, keeps session alive)
- **09-06**: remoteDialogSeen pre-set in ~/.claude.json (bypasses "Enable Remote Control?" prompt; echo "y" removed from FIFO)

All five ORCH requirements are marked complete in REQUIREMENTS.md with full traceability. Key commits confirmed in git history: `87bf46d`, `97c5ab7`, `c3dfa5a`, `b270595` (plans 09-01 through 09-04/05), and `26bc37f` (plan 09-06 gap closure).

The three remaining human verification items require a live VPS environment with claude-peers MCP server running. These are runtime behavioral tests -- the code, specification, and infrastructure are all complete and verified.

---

_Verified: 2026-03-24T01:35:00Z_
_Verifier: Claude (gsd-verifier)_
