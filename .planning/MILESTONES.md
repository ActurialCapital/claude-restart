# Milestones

## v3.0 Synchronous Dispatch Architecture (Shipped: 2026-03-27)

**Phases completed:** 3 phases, 5 plans, 8 tasks

**Key accomplishments:**

- Removed channel_args block and CLAUDE_CHANNELS env var -- instruments launch claude with only mode_args and current_args, no peers infrastructure
- Removed CLAUDE_CHANNELS injection, .mcp.json provisioning, and peers-specific tests from claude-service and test suite
- Orchestra CLAUDE.md rewritten for synchronous claude -p dispatch with parallel backgrounding, --continue chaining, fleet discovery, and escalation protocol
- deploy_skills function added to install.sh copying GSD and superpowers from repo to ~/.claude/ on VPS, with 3 new tests and pre-existing test fixes
- Per-instrument identity CLAUDE.md template deployed via claude-service add with INSTANCE_PLACEHOLDER substitution, plus session naming fix for default instance

---

## v2.0 Multi-Instance Orchestration (Shipped: 2026-03-24)

**Phases completed:** 5 phases, 13 plans, 26 tasks

**Key accomplishments:**

- systemd template unit claude@.service with %i-based per-instance config, dynamic MemoryMax via ExecStartPre, and env template with 4 new instance-aware variables
- Three shell scripts made instance-aware: wrapper passes --name to remote-control, restart targets instruments via systemctl, service routes to template units
- Instance-aware installer deploying claude@.service template unit with v1.1 migration function that preserves existing config in per-instance default/ directory
- Per-instance watchdog template units (claude-watchdog@.service/timer) with hardcoded 8h intervals and installer migration from old non-template units
- Single-command instrument add/remove/list via claude-service with automatic watchdog pairing, env template provisioning, and git clone
- Channel flag injection in wrapper, Bun in PATH, and add-orchestra subcommand for git-free orchestra registration with claude-peers enabled
- Autonomous supervisor CLAUDE.md with 8 sections covering tools, GSD workflow dispatch, parallel driving, user escalation, and anti-patterns
- Fixed two blockers preventing remote-control mode startup: replaced invalid --dangerously-skip-permissions with --permission-mode bypassPermissions and added auto-confirm for Enable Remote Control prompt
- Swapped channel_args before mode_args at all three claude invocation sites, unblocking orchestra startup
- Remote-control mode now uses FIFO-based stdin with heartbeat writer, fixing EOF/session-death and confirmation prompt issues
- Fixed remote-control session spawning: pre-set remoteDialogSeen + workspace trust, silent FIFO, skip eager session, skip unsupported channel flag
- Auto-provision .mcp.json with claude-peers config from ~/.claude.json during add-orchestra, with merge support and graceful skip
- Auto-deploy orchestra/CLAUDE.md during add-orchestra with fail-fast guard and 13-test suite

---

## v1.1 VPS Reliability (Shipped: 2026-03-23)

**Phases completed:** 3 phases, 6 plans, 11 tasks

**Key accomplishments:**

- SIGTERM forwarding to child process, SIGHUP ignore, and CLAUDE_CONNECT env var mode selection (remote-control/telegram/interactive)
- Mode-aware restart preserving CLAUDE_CONNECT mode args across restarts, installer migrated from hardcoded channel string to CLAUDE_CONNECT env var
- systemd user service unit file, env template with API key/PATH/mode placeholders, and claude-service helper with start/stop/restart/status/logs subcommands
- Platform-aware installer that deploys systemd unit file, env file with prompted API key/mode, enables linger, and starts service -- with 7 new test cases using mocked systemctl/loginctl
- Systemd watchdog timer with mode-aware oneshot restart and FIFO-based stdin heartbeat for telegram mode
- Installer deploys watchdog timer/oneshot with configurable hours, claude-service gains watchdog and heartbeat subcommands, 49 tests passing

---

## v1.0 MVP (Shipped: 2026-03-21)

**Phases:** 3 | **Plans:** 3 | **Tasks:** 6
**LOC:** 201 shell (+ 415 tests) | **Commits:** 34
**Timeline:** 1 day (2026-03-20)
**Git range:** 102b06d → 8eea330

**Delivered:** Complete restart mechanism for Claude Code — wrapper loop, restart trigger, and shell integration with full TDD coverage.

**Key accomplishments:**

1. Wrapper loop with restart-file protocol, SIGINT trapping, and 10-restart safety valve
2. Restart trigger with PPID chain walk to find and SIGTERM the claude process
3. Graceful degradation — restart file always written even when PID not found
4. Shell integration with sentinel-based idempotent zshrc config and clean uninstall
5. Full TDD coverage — 23 test cases, 41 assertions, all passing

---
