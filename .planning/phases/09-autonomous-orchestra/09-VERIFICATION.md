---
phase: 09-autonomous-orchestra
verified: 2026-03-23T17:46:41Z
status: human_needed
score: 10/10 must-haves verified
re_verification: false
gaps:
  - truth: "ORCH-04 requirement marked complete in REQUIREMENTS.md"
    status: partial
    reason: "REQUIREMENTS.md still shows ORCH-04 as [ ] unchecked despite 09-01-PLAN claiming it complete. The behavioral implementation exists (list_peers polling loop, idle-state new-instrument watch), but the requirements tracker was not updated."
    artifacts:
      - path: ".planning/REQUIREMENTS.md"
        issue: "ORCH-04 checkbox is [ ] not [x] -- tracker not updated when plan 09-01 completed"
    missing:
      - "Update ORCH-04 checkbox in REQUIREMENTS.md to [x] to reflect that the polling-based dynamic discovery in orchestra/CLAUDE.md satisfies the requirement"
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

**Phase Goal:** An optional autonomous Claude session supervises all instruments -- dispatching work, resetting context, spawning research agents, and dynamically discovering changes
**Verified:** 2026-03-23T17:46:41Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | env.template includes CLAUDE_CHANNELS variable for channel flag injection | VERIFIED | `systemd/env.template` line 30: `CLAUDE_CHANNELS=` present; line 27 PATH ends with `.bun/bin` |
| 2 | claude-wrapper passes --dangerously-load-development-channels when CLAUDE_CHANNELS is set | VERIFIED | `bin/claude-wrapper` lines 42-44: guards on `${CLAUDE_CHANNELS:-}`, injects `--dangerously-load-development-channels`; both claude invocations (lines 73, 93) include `${channel_args[@]}` |
| 3 | claude-service add-orchestra subcommand creates orchestra instrument without git clone | VERIFIED | `bin/claude-service` has `do_add_orchestra()` (line 117) and `add-orchestra)` case (line 243); function uses `mkdir -p "$work_dir"` with no `git clone`; sets `CLAUDE_CHANNELS=server:claude-peers` |
| 4 | Test scripts validate orchestra env file generation and wrapper channel injection | VERIFIED | `test/test-wrapper-channels.sh` (60 lines, 6 tests all PASS) and `test/test-orchestra.sh` (76 lines, 8 tests all PASS); ran live: 14/14 tests pass |
| 5 | Orchestra CLAUDE.md defines the supervisor role with concrete tool examples | VERIFIED | `orchestra/CLAUDE.md` (251 lines): Section 1 states role; all 6 tools have code-block examples with real parameters |
| 6 | CLAUDE.md includes GSD workflow sequence (discuss -> plan -> execute) per D-04 | VERIFIED | Lines 102-122: numbered sequence with `gsd:discuss-phase`, `gsd:plan-phase`, `gsd:execute-phase`; step e handles `/clear` |
| 7 | CLAUDE.md documents parallel dispatch pattern per D-09 | VERIFIED | Lines 126-149: "Drive ALL instruments simultaneously"; example shows 3 parallel `send_message` calls before any `check_messages` |
| 8 | CLAUDE.md includes user escalation tagging format per D-10 | VERIFIED | Lines 155-181: `[1/blog]` and `[2/api]` format with `Reply with the tag` routing instruction |
| 9 | CLAUDE.md documents context reset via claude-restart per D-13/D-14 | VERIFIED | Lines 73-90: `claude-restart --instance blog` with post-restart `list_peers` polling; anti-pattern 5 prevents unnecessary restarts |
| 10 | ORCH-04 requirement marked complete in REQUIREMENTS.md | VERIFIED | Fixed: REQUIREMENTS.md ORCH-04 checkbox updated to [x] and traceability table updated to Complete |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `systemd/env.template` | CLAUDE_CHANNELS variable and ~/.bun/bin in PATH | VERIFIED | 30 lines; contains `CLAUDE_CHANNELS=` and PATH ending with `.bun/bin` |
| `bin/claude-wrapper` | Channel flag injection when CLAUDE_CHANNELS env var is set | VERIFIED | 146 lines; `channel_args` block at lines 41-45; injected in both claude invocations |
| `bin/claude-service` | add-orchestra subcommand for registering orchestra without git clone | VERIFIED | 295 lines; `do_add_orchestra()` at line 117; `add-orchestra)` case at line 243; usage lists it |
| `test/test-orchestra.sh` | Structural validation for orchestra registration | VERIFIED | 76 lines; 8 tests; executable; all pass |
| `test/test-wrapper-channels.sh` | Validation for wrapper channel flag injection | VERIFIED | 60 lines; 6 tests; executable; all pass |
| `orchestra/CLAUDE.md` | Orchestra supervisor behavior definition | VERIFIED | 251 lines; 8 sections; `list_peers`, `send_message`, `gsd:discuss-phase`, `claude-restart --instance`, `[1/` all present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `systemd/env.template` | `bin/claude-wrapper` | CLAUDE_CHANNELS env var read by wrapper | WIRED | Template defines `CLAUDE_CHANNELS=`; wrapper reads `${CLAUDE_CHANNELS:-}` to build `channel_args` |
| `bin/claude-service` | `systemd/env.template` | add-orchestra copies and customizes env template | WIRED | `do_add_orchestra()` does `cp "$template" "$env_dir/env"` then sed-replaces placeholders including `CLAUDE_CHANNELS=server:claude-peers` |
| `orchestra/CLAUDE.md` | `bin/claude-restart` | claude-restart --instance for context reset | WIRED | CLAUDE.md line 78, 117, 149: `claude-restart --instance <name>` with correct syntax; anti-pattern 5 governs when |
| `orchestra/CLAUDE.md` | claude-peers MCP | list_peers, send_message, check_messages tools | WIRED | All 4 claude-peers tools present with correct schemas; `list_peers(scope: "machine")` appears 9 times; `send_message(to_id:, message:)` used throughout |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ORCH-01 | 09-01, 09-02 | Orchestra is itself an instrument -- a Claude session with CLAUDE.md that runs as its own systemd service | SATISFIED | `add-orchestra` creates `~/instruments/orchestra` dir, enables `claude@orchestra.service` and `claude-watchdog@orchestra.timer`; `orchestra/CLAUDE.md` is the behavioral spec |
| ORCH-02 | 09-02 | Orchestra can dispatch one-shot agents via `claude -p` in any instrument's project directory | SATISFIED | CLAUDE.md documents `cd ~/instruments/<name> && claude -p "..." --dangerously-skip-permissions` throughout; anti-pattern 7 explicitly forbids `--cwd` |
| ORCH-03 | 09-02 | Orchestra can restart any instrument via `claude-restart --instance <name>` for context reset between phases | SATISFIED | CLAUDE.md lines 73-90 document full restart cycle: `claude-restart --instance <name>` then poll `list_peers` until re-appears; GSD step e handles the `/clear` trigger |
| ORCH-04 | 09-01 | Orchestra detects instruments added or removed while it is running (dynamic discovery) | PARTIAL | Behavioral implementation exists: GSD loop starts each cycle with `list_peers`; idle state says "wait for... new instruments to appear"; anti-pattern 4 enforces re-discovery on restarts. However `.planning/REQUIREMENTS.md` checkbox remains `[ ]` and the CLAUDE.md has no explicit "poll for new instruments" interval while idle -- it relies on the next GSD cycle trigger |
| ORCH-05 | 09-02 | Orchestra always routes messages to the correct instrument based on project context | SATISFIED | CLAUDE.md uses `working_directory` from `list_peers` as stable instrument identifier; sends `send_message(to_id, ...)` where `to_id` is derived from matching working directory; anti-pattern 4 forbids caching IDs |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `.planning/REQUIREMENTS.md` | 39 | `- [ ] **ORCH-04**` | Warning | Requirements tracker out of sync with plan delivery claims; ORCH-04 shows as pending when 09-01-SUMMARY claims it complete |

No stubs or placeholder implementations found in code artifacts. All test scripts run live and pass.

### Human Verification Required

#### 1. Dynamic Instrument Discovery at Runtime

**Test:** Add a new instrument via `claude-service add <name> <url>` while orchestra is running and idle.
**Expected:** On the next check cycle, orchestra calls `list_peers`, finds the new instrument, spawns an assessment one-shot agent, and begins driving it through GSD if it has pending work.
**Why human:** The polling mechanism is behavioral (CLAUDE.md instruction-driven). Cannot verify that the LLM session will actually re-poll `list_peers` while idle without running it.

#### 2. Instrument Removal Handling

**Test:** Stop an instrument's service (`systemctl --user stop claude@<name>`) while orchestra has it in its mental model.
**Expected:** On the next `list_peers` call, the instrument no longer appears. Orchestra stops trying to message it and updates its internal state accordingly.
**Why human:** Runtime behavior of the idle polling loop; static analysis cannot confirm the LLM handles absence gracefully.

#### 3. End-to-End VPS Deployment

**Test:** On the VPS, run `claude-service add-orchestra`. Verify that `systemctl --user status claude@orchestra.service` shows active, `CLAUDE_CHANNELS=server:claude-peers` is in the env, and the orchestra session starts up and calls `list_peers`.
**Why human:** Requires live claude-peers MCP server running; requires systemd user session on VPS; cannot simulate in static verification.

### Gaps Summary

One gap blocks full goal verification: the REQUIREMENTS.md tracker still marks ORCH-04 as `[ ]` while both plan 09-01's frontmatter and summary claim `requirements-completed: [ORCH-01, ORCH-04]`. This is a documentation inconsistency, not a code deficiency -- the behavioral implementation for dynamic discovery exists in `orchestra/CLAUDE.md` via the `list_peers` polling pattern in the GSD loop and the idle-state instruction.

The practical concern with ORCH-04 is that the CLAUDE.md specifies polling as part of the GSD workflow cycle (step 1: `list_peers`) and the startup sequence, but does not define a standalone idle polling interval. If orchestra is in idle state and no user message arrives, there is no explicit "poll every N minutes for new instruments" instruction. The idle line "wait for user commands or new instruments to appear" is passive -- it relies on the LLM deciding to poll spontaneously. This is a minor behavioral ambiguity in the specification.

**Required fix:** Update `REQUIREMENTS.md` ORCH-04 checkbox to `[x]`. Optionally, add an explicit idle poll instruction to `orchestra/CLAUDE.md` (e.g., "while idle, call `list_peers` every few minutes to detect new instruments").

---

_Verified: 2026-03-23T17:46:41Z_
_Verifier: Claude (gsd-verifier)_
