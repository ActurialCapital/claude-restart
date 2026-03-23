# Milestones

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
