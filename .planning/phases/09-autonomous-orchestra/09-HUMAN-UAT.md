---
status: partial
phase: 09-autonomous-orchestra
source: [09-VERIFICATION.md]
started: 2026-03-23T17:50:00Z
updated: 2026-03-23T17:50:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Dynamic Instrument Discovery at Runtime
expected: Add a new instrument while orchestra is running and idle. On the next check cycle, orchestra discovers the new instrument via list_peers, spawns an assessment agent, and begins driving it.
result: [pending]

### 2. Instrument Removal Handling
expected: Stop an instrument's service while orchestra is supervising it. Orchestra stops sending messages to the removed instrument and does not error-loop on stale peer IDs.
result: [pending]

### 3. End-to-End VPS Deployment
expected: Run `claude-service add-orchestra` on VPS. Orchestra service starts, CLAUDE_CHANNELS=server:claude-peers is set, claude-peers MCP connects, list_peers returns at least one peer.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
