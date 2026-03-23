---
status: partial
phase: 09-autonomous-orchestra
source: [09-VERIFICATION.md]
started: 2026-03-23T17:50:00Z
updated: 2026-03-23T23:35:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Dynamic Instrument Discovery at Runtime
expected: Deploy orchestra and add a new instrument while orchestra is running. On the next GSD loop cycle, orchestra discovers the new instrument via list_peers, spawns an assessment agent, and begins driving it.
result: [pending]

### 2. Instrument Removal Handling
expected: Remove an instrument (stop its service) while orchestra is running. Orchestra stops sending messages to the removed instrument and does not error-loop on stale peer IDs.
result: pass
notes: |
  Broker does live PID check in handleListPeers() — dead peers filtered instantly.
  send_message() to cleaned-up peer returns {"ok":false,"error":"Peer X not found"} cleanly.
  Observation: silent-success window exists if send_message() called before list_peers() triggers cleanup, but orchestra CLAUDE.md always calls list_peers() first so this window is not hit in practice.

### 3. End-to-End VPS Deployment
expected: Run `claude-service add-orchestra` on a VPS with a running default instance. Orchestra service starts, CLAUDE_CHANNELS is set to server:claude-peers, claude-peers MCP connects, list_peers returns at least one peer.
result: [pending]

## Summary

total: 3
passed: 1
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps

- truth: "Remote-control permission flag and auto-confirm"
  status: resolved
  reason: "Fixed in plan 09-03: --permission-mode bypassPermissions replaces --dangerously-skip-permissions; echo y piped to stdin for auto-confirm"
  severity: blocker
  test: 1
  resolved_by: 09-03-PLAN.md
