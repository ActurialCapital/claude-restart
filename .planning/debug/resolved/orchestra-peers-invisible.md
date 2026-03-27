---
status: resolved
trigger: "Orchestra's list_peers() call returns empty -- cannot discover the claude-restart instrument even though both services are running with claude-peers configured."
created: 2026-03-27T00:00:00Z
updated: 2026-03-27T14:20:00Z
---

## Current Focus

hypothesis: CONFIRMED -- --no-create-session-in-dir prevents peer registration
test: Remove --no-create-session-in-dir from wrapper so remote-control pre-creates a session
expecting: Both services will pre-create sessions, MCP servers spawn, peers register with broker
next_action: Apply fix to claude-wrapper and redeploy to VPS

## Symptoms

expected: Orchestra calls list_peers() via claude-peers MCP and discovers the running claude-restart instrument
actual: Orchestra says "No instruments are currently running" - list_peers returns nothing/empty
errors: No explicit errors - just empty peer list
reproduction: Connect to orchestra via remote-control on claude.ai/code, say "hello", orchestra calls list_peers and finds no instruments
started: Since fresh VPS reinstall. Both services confirmed active via systemctl.

## Eliminated

- hypothesis: Broker not running or unhealthy
  evidence: curl http://127.0.0.1:7899/health returns {"status":"ok","peers":1}. Broker is running and orchestra is registered.
  timestamp: 2026-03-27T14:20:00Z

- hypothesis: MCP config missing or misconfigured
  evidence: Both ~/instruments/orchestra/.mcp.json and ~/instruments/claude-restart/.mcp.json have identical claude-peers MCP config pointing to /home/jean/claude-peers-mcp/server.ts
  timestamp: 2026-03-27T14:20:00Z

- hypothesis: CLAUDE_CHANNELS env var not set
  evidence: Both env files have CLAUDE_CHANNELS=server:claude-peers set (though this is skipped for remote-control mode by design)
  timestamp: 2026-03-27T14:20:00Z

## Evidence

- timestamp: 2026-03-27T14:18:00Z
  checked: systemctl --user status for both services
  found: Orchestra has Capacity 1/32 with full process tree (claude binary, MCP servers, broker). claude-restart has Capacity 0/32 with only wrapper + remote-control + sleep 60 -- NO claude binary, NO MCP servers.
  implication: claude-restart has no active session so no MCP servers spawn and no peer registration happens.

- timestamp: 2026-03-27T14:19:00Z
  checked: Direct broker query via curl POST /list-peers
  found: Only 1 peer registered (orchestra, pid 255765, cwd /home/jean/instruments/orchestra). claude-restart is completely absent from broker.
  implication: Confirms claude-restart never registered because its claude-peers MCP server never started.

- timestamp: 2026-03-27T14:19:30Z
  checked: claude remote-control --help output
  found: --[no-]create-session-in-dir flag exists. Default is ON (pre-create a session). But wrapper passes --no-create-session-in-dir explicitly.
  implication: The flag prevents automatic session pre-creation, which is needed for MCP servers to start.

- timestamp: 2026-03-27T14:19:45Z
  checked: Git history and planning docs for --no-create-session-in-dir rationale
  found: Added in commit 4bdea31 to fix "pre-created session reads inherited stdin". Original issue was that pre-created session tried to read from FIFO stdin and got confused.
  implication: The original fix was for an older version of remote-control. Current remote-control sessions get input from cloud bridge, not parent stdin. The flag is now counterproductive -- it prevents the pre-created session that's needed for MCP server startup.

- timestamp: 2026-03-27T14:20:00Z
  checked: Orchestra startup logs (journalctl from 13:44:12)
  found: Orchestra also started with Capacity 0/32. It only got a session (1/32) when someone connected via claude.ai/code bridge. The pre-created session feature is disabled for orchestra too.
  implication: Orchestra works only because someone manually connected. If no one connects, no session exists, no MCP servers start. This is fragile -- instruments should self-register on boot.

## Resolution

root_cause: claude-wrapper passes --no-create-session-in-dir to claude remote-control, which prevents automatic session pre-creation. Without a pre-created session, MCP servers (including claude-peers) never spawn, so the instrument never registers with the broker. Orchestra can only find peers that have active sessions. The --no-create-session-in-dir flag was added in commit 4bdea31 to fix a stdin-reading issue with an older remote-control implementation, but current remote-control sessions receive input from the cloud bridge (not parent stdin), making the flag unnecessary and harmful.
fix: Remove --no-create-session-in-dir from the remote-control mode_args in claude-wrapper
verification: After deploying updated wrapper and restarting both services, broker shows 2 peers registered (claude-restart at /home/jean/instruments/claude-restart, orchestra at /home/jean/instruments/orchestra). Both services show Capacity 1/32 -- sessions are pre-created on startup. All 42 wrapper tests pass locally.
files_changed: [bin/claude-wrapper, test/test-wrapper.sh]
