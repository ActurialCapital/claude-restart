---
status: diagnosed
phase: 09-autonomous-orchestra
source: [09-VERIFICATION.md]
started: 2026-03-23T17:50:00Z
updated: 2026-03-23T00:00:00Z
---

## Current Test

[testing complete — 2 items outstanding]

## Tests

### 1. Dynamic Instrument Discovery at Runtime
expected: Deploy orchestra and add a new instrument while orchestra is running. On the next GSD loop cycle, orchestra discovers the new instrument via list_peers, spawns an assessment agent, and begins driving it.
result: issue
reported: "Three issues prevent orchestra from staying alive: (1) echo 'y' | closes stdin — EOF kills remote-control process shortly after startup. (2) 'y' sometimes leaks into the spawned Claude session instead of being consumed by the Remote Control confirmation prompt, producing 'It looks like you sent y' responses. (3) Session is one-shot — runs CLAUDE.md, finds no instruments, asks 'what would you like me to do?', gets no response, and exits. The remote-control server doesn't persist after session ends. Net result: orchestra service dies within 5-20 seconds on every attempt."
severity: blocker

### 2. Instrument Removal Handling
expected: Remove an instrument (stop its service) while orchestra is running. Orchestra stops sending messages to the removed instrument and does not error-loop on stale peer IDs.
result: pass
notes: |
  Broker does live PID check in handleListPeers() — dead peers filtered instantly.
  send_message() to cleaned-up peer returns {"ok":false,"error":"Peer X not found"} cleanly.
  Observation: silent-success window exists if send_message() called before list_peers() triggers cleanup, but orchestra CLAUDE.md always calls list_peers() first so this window is not hit in practice.

### 3. End-to-End VPS Deployment
expected: Run `claude-service add-orchestra` on a VPS with a running default instance. Orchestra service starts, CLAUDE_CHANNELS is set to server:claude-peers, claude-peers MCP connects, list_peers returns at least one peer.
result: blocked
blocked_by: server
reason: "Blocked — requires VPS with running instance; cannot test locally"

## Summary

total: 3
passed: 1
issues: 1
pending: 0
skipped: 0
blocked: 1

## Gaps

- truth: "Remote-control permission flag and auto-confirm"
  status: resolved
  reason: "Fixed in plan 09-03: --permission-mode bypassPermissions replaces --dangerously-skip-permissions; echo y piped to stdin for auto-confirm"
  severity: blocker
  test: 1
  resolved_by: 09-03-PLAN.md

- truth: "Orchestra discovers new instrument via list_peers and begins driving it"
  status: resolved
  reason: "Fixed in plan 09-04: swapped channel_args before mode_args at all three call sites so --dangerously-load-development-channels is parsed as a top-level flag"
  severity: blocker
  test: 1
  resolved_by: 09-04-PLAN.md

- truth: "Orchestra service stays running and maintains persistent remote-control session"
  status: failed
  reason: "User reported: Three interrelated stdin/lifecycle issues — (1) echo 'y' | causes EOF killing the process, (2) 'y' leaks into session instead of confirmation prompt, (3) session is one-shot and exits when no work arrives"
  severity: blocker
  test: 1
  root_cause: "claude-wrapper line 106 uses `echo 'y' | claude ...` for remote-control mode. echo writes 'y' then closes the pipe (EOF). This causes all three symptoms: (1) EOF on stdin kills the remote-control server, (2) no synchronization between 'y' write and the confirmation prompt means 'y' can leak into the session, (3) with stdin at EOF the session has no way to receive further input and exits after CLAUDE.md startup. The telegram mode (lines 82-103) already solves this correctly with a FIFO + heartbeat writer pattern that keeps stdin open."
  artifacts:
    - path: "bin/claude-wrapper"
      lines: "104-107"
      issue: "echo 'y' | claude pattern causes immediate EOF on stdin — kills remote-control server"
  missing:
    - "Remote-control mode needs FIFO-based stdin (like telegram mode lines 82-103)"
    - "Write 'y\\n' to FIFO for confirmation prompt, then keep fd open"
    - "Add heartbeat writer to keep remote-control session alive"
