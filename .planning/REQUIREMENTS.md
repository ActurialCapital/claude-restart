# Requirements: Claude Restart

**Defined:** 2026-03-27
**Core Value:** Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.

## v3.0 Requirements

Requirements for Synchronous Dispatch Architecture milestone. Each maps to roadmap phases.

### Dispatch

- [x] **DISP-01**: Orchestra dispatches GSD commands to instruments via `claude -p` with stdout captured synchronously
- [x] **DISP-02**: Orchestra runs parallel `claude -p` across multiple instruments simultaneously (backgrounded)
- [x] **DISP-03**: Orchestra uses `--continue` for multi-step GSD sequences within same instrument
- [x] **DISP-04**: Orchestra handles long-running `claude -p` tasks without blocking other instrument dispatch

### Cleanup

- [x] **CLNP-01**: Remove claude-peers MCP server config (`.mcp.json`) from instruments and orchestra
- [x] **CLNP-02**: Remove `CLAUDE_CHANNELS` env var from env files and env.template
- [x] **CLNP-03**: Remove `--dangerously-load-development-channels` flag handling from claude-wrapper
- [x] **CLNP-04**: Remove message-watcher sidecar from claude-wrapper
- [x] **CLNP-05**: Remove claude-peers broker startup/dependency from systemd services

### Orchestra

- [x] **ORCH-01**: Orchestra CLAUDE.md rewritten for `claude -p` dispatch (no send_message/check_messages)
- [x] **ORCH-02**: Orchestra parallel dispatch pattern documented with backgrounding and output collection
- [x] **ORCH-03**: Orchestra escalation protocol preserved (user questions routed via remote-control)

### Deployment

- [ ] **DEPL-01**: Installer deploys GSD skills (`~/.claude/get-shit-done/`) to VPS
- [ ] **DEPL-02**: Installer deploys superpowers skills to VPS
- [ ] **DEPL-03**: `claude -p` in instrument directories inherits GSD skills from `~/.claude/`

### Instance Identity

- [ ] **INST-01**: Instruments know their own instance name via CLAUDE.md or env injection
- [ ] **INST-02**: Instrument CLAUDE.md template includes instance name and `claude-restart --instance <name>` hint

### Session Fix

- [ ] **SESS-01**: Fix duplicate "General coding session" appearing on phone from pre-created remote-control sessions

## Future Requirements

- **NOTIF-01**: Orchestra notifies user via Telegram when instrument needs input
- **SCALE-01**: Rate limit awareness when running 3+ concurrent `claude -p` instances

## Out of Scope

| Feature | Reason |
|---------|--------|
| claude-peers messaging | Replaced by `claude -p` dispatch -- async messaging was working around remote-control channel limitation |
| `/clear` command support | Irrelevant with `claude -p` fresh context model |
| Telegram mode for instruments | Remote-control covers phone access; Telegram deferred |
| Orchestra relay mode | Autonomous only; direct access covers manual interaction |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISP-01 | Phase 13 | Complete |
| DISP-02 | Phase 13 | Complete |
| DISP-03 | Phase 13 | Complete |
| DISP-04 | Phase 13 | Complete |
| CLNP-01 | Phase 12 | Complete |
| CLNP-02 | Phase 12 | Complete |
| CLNP-03 | Phase 12 | Complete |
| CLNP-04 | Phase 12 | Complete |
| CLNP-05 | Phase 12 | Complete |
| ORCH-01 | Phase 13 | Complete |
| ORCH-02 | Phase 13 | Complete |
| ORCH-03 | Phase 13 | Complete |
| DEPL-01 | Phase 14 | Pending |
| DEPL-02 | Phase 14 | Pending |
| DEPL-03 | Phase 14 | Pending |
| INST-01 | Phase 14 | Pending |
| INST-02 | Phase 14 | Pending |
| SESS-01 | Phase 14 | Pending |

**Coverage:**
- v3.0 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation*
