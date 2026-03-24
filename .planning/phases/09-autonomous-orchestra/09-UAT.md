---
status: diagnosed
phase: 09-autonomous-orchestra
source: [09-01-SUMMARY.md, 09-02-SUMMARY.md, 09-03-SUMMARY.md, 09-04-SUMMARY.md, 09-05-SUMMARY.md]
started: 2026-03-23T18:30:00Z
updated: 2026-03-23T19:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. All Test Suites Pass
expected: Run `bash test/test-wrapper.sh && bash test/test-wrapper-channels.sh && bash test/test-orchestra.sh`. All tests pass (39 wrapper + 7 channel + 8 orchestra = 54 total). No failures.
result: pass

### 2. Orchestra CLAUDE.md Completeness
expected: File `orchestra/CLAUDE.md` exists and contains all 8 sections: Identity, Tools, Workflow, Parallel Dispatch, Escalation, State Tracking, Anti-Patterns, and Startup. It references list_peers, send_message, check_messages, set_summary tools and describes the GSD discuss/plan/execute sequence.
result: pass

### 3. Remote-Control FIFO Stdin (Fix Verification)
expected: In `bin/claude-wrapper`, the remote-control mode branch uses mkfifo + heartbeat writer pattern (same as telegram mode), NOT `echo "y" | claude ...`. An `echo "y" >&3` is written before the heartbeat loop for auto-confirm. This fixes the original blocker where EOF killed the session.
result: pass

### 4. Channel Flag Ordering (Fix Verification)
expected: In `bin/claude-wrapper`, all three claude invocation sites place `${channel_args[@]}` BEFORE `${mode_args[@]}` in the command. This ensures `--dangerously-load-development-channels` is parsed as a top-level flag, not a subcommand argument.
result: pass

### 5. add-orchestra Subcommand
expected: `bin/claude-service` contains a `do_add_orchestra` function that creates an orchestra instrument WITHOUT running git clone, and sets `CLAUDE_CHANNELS=server:claude-peers` in the instance env file. Running `claude-service --help` shows `add-orchestra` in usage.
result: pass

### 6. Orchestra Stays Alive on VPS
expected: Deploy orchestra via `claude-service add-orchestra` on VPS with a running default instance. Orchestra service starts, remote-control session persists beyond 30 seconds, FIFO heartbeat keeps stdin open. Orchestra CLAUDE.md drives the session (discovers instruments via list_peers).
result: issue
reported: "The service stays alive (FIFO fix works, running 5+ minutes), but no session was spawned. The process tree shows only claude remote-control and the heartbeat subshell — no child session process (--print --sdk-url ...), no claude-peers MCP server started by the session, no orchestra peer registered with the broker. The only peer is lwqq3kq4 from an older manual session. This means: the 'Enable Remote Control? (y/n)' confirmation may not have been consumed from the FIFO (remote-control might read the prompt from TTY, not stdin), or remote-control accepted but --create-session-in-dir didn't pre-create a session in non-TTY mode. Either way, the CLAUDE.md never executes — no instrument discovery happens. Service alive: yes. Session created: no. CLAUDE.md driving: no."
severity: blocker

## Summary

total: 6
passed: 5
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Orchestra service spawns a remote-control session that executes CLAUDE.md and discovers instruments"
  status: failed
  reason: "User reported: Service stays alive (FIFO fix works), but no session spawned. Process tree shows only claude remote-control + heartbeat subshell, no child session. 'Enable Remote Control?' confirmation not consumed from FIFO — remote-control may read from TTY not stdin. CLAUDE.md never executes."
  severity: blocker
  test: 6
  root_cause: "The 'Enable Remote Control?' prompt uses readline on stdin (confirmed from CLI source), BUT the prompt is gated by `remoteDialogSeen` global config flag. If previously confirmed interactively, the flag is already true and the 'y' sits unconsumed in stdin. The real blocker is likely post-confirmation: either (A) remoteDialogSeen=true means 'y' is never consumed and pollutes the session, (B) readline behaves differently with FIFO vs pipe on certain Node versions, or (C) a silent post-confirmation failure (auth, network, spawn mode prompt gated by isTTY). Fix: pre-set remoteDialogSeen=true in claude global config during install, eliminating the prompt entirely."
  artifacts:
    - path: "bin/claude-wrapper"
      issue: "FIFO 'y' write may be unconsumed if remoteDialogSeen already true, or readline may not emit line event from FIFO"
  missing:
    - "Pre-set remoteDialogSeen=true in claude global config during service install"
    - "Investigate journalctl output for post-confirmation errors on VPS"
    - "Remove echo 'y' from FIFO setup or make it conditional on first-run"
  debug_session: ".planning/debug/remote-control-no-session.md"
