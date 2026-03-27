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

