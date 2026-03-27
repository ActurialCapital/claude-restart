# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## orchestra-peers-invisible -- Orchestra cannot discover instrument peers via list_peers
- **Date:** 2026-03-27
- **Error patterns:** list_peers empty, no peers, no instruments running, Capacity 0/32, peer not registered, broker shows 1 peer
- **Root cause:** claude-wrapper passes --no-create-session-in-dir to remote-control, preventing session pre-creation. Without a session, MCP servers never spawn, so claude-peers never registers the instrument with the broker.
- **Fix:** Remove --no-create-session-in-dir from remote-control mode_args in claude-wrapper
- **Files changed:** bin/claude-wrapper, test/test-wrapper.sh
---

## peers-message-not-received -- Instrument never receives messages sent by orchestra via claude-peers
- **Date:** 2026-03-27
- **Error patterns:** message not received, no reply, send_message succeeds but instrument never responds, channel notification dropped, delivered but not seen
- **Root cause:** Two-layer failure: (1) remote-control mode does not pass --dangerously-load-development-channels, so Claude Code's channel gate silently drops all MCP channel notifications. (2) pollAndPushMessages() calls /poll-messages which marks messages delivered BEFORE the dropped notification, permanently losing messages.
- **Fix:** Added /peek-messages (read without marking delivered) and /ack-messages (explicit ack) to broker. Changed pollAndPushMessages() to use peek instead of poll. Only check_messages tool (user-initiated) marks messages delivered. Updated MCP instructions to tell Claude to call check_messages at start of every turn.
- **Files changed:** ~/claude-peers-mcp/broker.ts, ~/claude-peers-mcp/server.ts
---

