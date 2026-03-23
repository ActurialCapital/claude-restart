---
status: resolved
phase: 09-autonomous-orchestra
source: [09-VERIFICATION.md]
started: 2026-03-23T17:50:00Z
updated: 2026-03-24T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Dynamic Instrument Discovery at Runtime
expected: Deploy orchestra and add a new instrument while orchestra is running. On the next GSD loop cycle, orchestra discovers the new instrument via list_peers, spawns an assessment agent, and begins driving it.
result: issue
reported: "The error: Unknown argument: --dangerously-load-development-channels -- the remote-control subcommand doesn't accept the --dangerously-load-development-channels flag from CLAUDE_CHANNELS. The channel args are being placed after the subcommand. The command being built is: claude remote-control --permission-mode bypassPermissions --name orchestra --dangerously-load-development-channels server:claude-peers. --dangerously-load-development-channels is a top-level claude flag, not a remote-control flag. The wrapper puts channel_args after mode_args, so they end up as arguments to the subcommand. For remote-control mode, channel args need to go before the subcommand."
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
