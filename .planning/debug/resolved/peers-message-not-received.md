---
status: resolved
trigger: "Orchestra sends messages to instruments via claude-peers send_message, but instruments never receive or respond"
created: 2026-03-27T00:00:00Z
updated: 2026-03-27T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED and FIXED - Channel notifications silently dropped; now using peek+poll split
test: Sent test message, waited 3s, verified it stayed undelivered (delivered=0). Then called poll-messages to simulate check_messages -- message consumed correctly.
expecting: User verifies orchestra->instrument messaging works via claude.ai/code
next_action: Awaiting human verification

## Symptoms

expected: Orchestra sends message to instrument via send_message, instrument receives it via claude-peers channel notification and responds
actual: Message sends successfully (confirmed by orchestra) but instrument never receives/responds — orchestra says "No reply yet" after check_messages
errors: None — send succeeds with no error, instrument just never sees the message
reproduction: Connect to orchestra via remote-control on claude.ai/code, ask it to send a message to the claude-restart instrument. Orchestra calls send_message successfully but instrument never responds.
started: Has never worked. Known bug #1 in PROJECT.md.

## Eliminated

## Evidence

- timestamp: 2026-03-27T15:00:00Z
  checked: Broker health and peers
  found: Broker running, 3 peers registered (orchestra, claude-restart, duplicate orchestra)
  implication: MCP servers are running and connected to broker

- timestamp: 2026-03-27T15:01:00Z
  checked: Messages table in broker SQLite DB
  found: 16 messages total, recent ones to claude-restart (id 15,16) marked delivered=1
  implication: pollAndPushMessages() IS polling and consuming messages from broker

- timestamp: 2026-03-27T15:02:00Z
  checked: claude-wrapper script channel_args logic
  found: channel_args is explicitly empty for remote-control mode with comment "remote-control sessions load channels from project config instead"
  implication: --dangerously-load-development-channels never passed to claude remote-control

- timestamp: 2026-03-27T15:03:00Z
  checked: F88 channel gate function in cli.js (minified)
  found: Gate checks gH() (allowedChannels list) populated only by --channels or --dangerously-load-development-channels. No settings.json or .mcp.json mechanism. Gate returns {action:"skip", kind:"session"} when server not in list.
  implication: Channel notifications from claude-peers MCP server are silently dropped by Claude Code

- timestamp: 2026-03-27T15:04:00Z
  checked: Data flow end-to-end
  found: pollAndPushMessages() calls /poll-messages (marks delivered=1) then mcp.notification() (silently dropped). Messages consumed from broker but never reach Claude session.
  implication: Messages permanently lost - broker thinks delivered, Claude never sees them

## Resolution

root_cause: Two-layer failure: (1) remote-control mode does not support --dangerously-load-development-channels flag, so Claude Code's F88 channel gate silently drops all channel notifications from MCP servers. (2) The MCP server's pollAndPushMessages() loop calls /poll-messages which marks messages as delivered in the broker DB BEFORE attempting the channel notification that gets dropped. Messages are consumed from the broker but never reach the Claude session.
fix: |
  1. broker.ts: Added /peek-messages endpoint (returns undelivered messages WITHOUT marking delivered) and /ack-messages endpoint (explicit ack by message IDs).
  2. server.ts: Changed pollAndPushMessages() to use /peek-messages instead of /poll-messages. Channel notification is still attempted (best-effort) but messages are NOT consumed from the broker. Only check_messages tool (which calls /poll-messages) marks messages as delivered.
  3. server.ts: Updated MCP instructions to tell Claude to call check_messages at the start of every conversation turn, since channel push may not work in remote-control mode.
  4. Restarted broker daemon and both Claude services on VPS.
verification: |
  Self-verified: Sent test message (from_id=knmd926m, to_id=jugviegc, text="test-peek-fix-works"). After 3 seconds, message still showed delivered=0 via /peek-messages. Then called /poll-messages (simulating check_messages) -- message returned and marked delivered=1. Subsequent /peek-messages returned empty.
  Awaiting human verification of end-to-end flow via claude.ai/code.
files_changed:
  - ~/claude-peers-mcp/broker.ts (on VPS)
  - ~/claude-peers-mcp/server.ts (on VPS)
