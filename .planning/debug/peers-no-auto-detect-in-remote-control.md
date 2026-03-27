---
status: awaiting_human_verify
trigger: "In remote-control mode, instruments don't automatically detect incoming peer messages. Channel notifications silently dropped. Instruments only see messages when human manually says check messages."
created: 2026-03-27T12:00:00Z
updated: 2026-03-27T12:00:00Z
---

## Current Focus

hypothesis: CONFIRMED. A message-watcher sidecar that polls the broker HTTP API and dispatches via `claude -p --continue` is the viable approach. MCP tools are NOT available in -p mode, but Bash tool IS, so Claude can curl the broker to send responses. Channel notifications fundamentally don't work in remote-control mode.
test: Build and deploy the watcher, verify end-to-end message flow.
expecting: Orchestra sends message -> watcher detects it -> claude -p processes it -> response sent back via broker.
next_action: Implement message-watcher script, integrate with broker, deploy to VPS.

## Symptoms

expected: When orchestra sends a message to an instrument via send_message, the instrument should automatically detect and respond to it — same as in interactive mode where channel notifications wake Claude up
actual: Instrument never detects the message until a human connects and manually says "check messages". The polling loop in server.ts peeks at messages every 1 second but channel push is silently dropped by Claude Code in remote-control mode.
errors: No errors — channel notifications are silently dropped because remote-control doesn't support --dangerously-load-development-channels
reproduction: Orchestra sends message to instrument. Instrument sits idle indefinitely. Message only processed when human manually triggers check_messages.
started: Has never worked in remote-control mode. Channel notifications only work in interactive mode with the development channels flag.

## Eliminated

## Evidence

- timestamp: 2026-03-27T12:00:00Z
  checked: Knowledge base for prior related issues
  found: Two related entries — (1) orchestra-peers-invisible (missing --no-create-session-in-dir fix), (2) peers-message-not-received (peek/ack pattern to prevent message loss). The peek/ack fix prevents message LOSS but doesn't solve message DETECTION in remote-control mode.
  implication: The current architecture correctly preserves messages (they stay undelivered in broker) but has no mechanism to wake the Claude session to process them.

- timestamp: 2026-03-27T12:01:00Z
  checked: Claude Code CLI help and remote-control subcommand help
  found: Version 2.1.85. remote-control accepts --permission-mode, --name, --spawn, --capacity, --[no-]create-session-in-dir. No --channels or --dangerously-load-development-channels support. CLI supports -p/--print with --resume/--continue for non-interactive session injection. Also supports --input-format stream-json for bidirectional programmatic communication.
  implication: Channel notifications are fundamentally unsupported in remote-control mode. Must find alternative mechanism to inject turns.

- timestamp: 2026-03-27T12:02:00Z
  checked: MCP elicitation and sampling support in Claude Code 2.1.85
  found: MCP elicitation was added in Claude Code 2.1.76. Allows MCP servers to request user input mid-task. Sampling allows servers to prompt the LLM directly. However, both require an ACTIVE turn — they are responses to tool calls, not server-initiated cold-start mechanisms.
  implication: Elicitation and sampling cannot wake a sleeping session. They only work during active tool execution.

- timestamp: 2026-03-27T12:03:00Z
  checked: FIFO stdin injection feasibility for remote-control
  found: GitHub issue #15553 documents that Ink's text-input component treats programmatic stdin \n differently from keyboard Enter — programmatic newlines do NOT trigger submit. The FIFO in claude-wrapper is held open but never written to. Even if we wrote to it, remote-control sessions don't process stdin as conversation input — they respond to cloud bridge input.
  implication: FIFO stdin injection is not viable for remote-control mode.

- timestamp: 2026-03-27T12:04:00Z
  checked: claude -p --resume / --continue as session injection mechanism
  found: claude -p --resume <session-id> "prompt" can inject a turn into an existing session. Sessions are persisted in ~/.claude/projects/. The --continue flag picks up the most recent session in the current directory. MCP tools and full context are preserved on resume.
  implication: This is the most promising approach. A sidecar script could run `claude -p --continue "check_messages"` in the instrument's working directory when messages arrive, injecting a turn that processes peer messages.

- timestamp: 2026-03-27T15:55:00Z
  checked: claude -p --continue in same directory as active remote-control session
  found: Works! Claude resumes the session with full context. MCP tools NOT available (only cloud integrations like Gmail load in -p mode, not stdio servers from .mcp.json). But Bash tool IS available, so Claude can use curl to call broker HTTP API directly.
  implication: The dispatch path is: watcher peeks messages -> formats as prompt -> claude -p --continue processes with full session context -> Claude uses Bash+curl to send responses via broker API. No MCP tools needed.

- timestamp: 2026-03-27T15:59:00Z
  checked: Full end-to-end flow on VPS
  found: Message sent from orchestra (knmd926m) to claude-restart (jugviegc). Watcher detected within one poll cycle (~3s), dispatched via claude -p --continue, Claude processed the message and sent PONG response back. Response confirmed in orchestra's broker queue with msg ID 23.
  implication: The solution works. Message watcher bridges the gap between broker and remote-control sessions.

## Resolution

root_cause: Remote-control mode does not support --dangerously-load-development-channels, so MCP channel notifications (the mechanism that wakes interactive sessions) are silently dropped. There is no built-in mechanism in remote-control mode for MCP servers to initiate a conversation turn. The polling loop detects messages (via /peek-messages) but has no way to notify the Claude session. Additionally, `claude -p` mode does not load stdio MCP servers from .mcp.json, so MCP tools are unavailable in one-shot dispatch sessions.
fix: Created a message-watcher sidecar script that runs alongside remote-control instruments. The watcher polls the broker HTTP API for undelivered messages, and when messages arrive, dispatches them via `claude -p --continue` (which resumes the instrument's session with full context). Claude processes messages using the Bash tool + curl to send responses back through the broker API. The wrapper auto-launches the watcher for remote-control sessions when CLAUDE_CHANNELS is set.
verification: End-to-end test on VPS: sent message from orchestra peer to claude-restart peer. Watcher detected the message within 5s, dispatched via claude -p --continue, Claude read the message, sent "PONG" response back to orchestra peer via broker API. Response confirmed in orchestra's message queue.
files_changed: [bin/message-watcher, bin/claude-wrapper, bin/install.sh]
