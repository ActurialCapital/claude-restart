# Requirements: Claude Restart

**Defined:** 2026-03-20
**Core Value:** Claude can be restarted with new CLI options from within a session without manual exit-and-retype.

## v1.1 Requirements

Requirements for VPS reliability milestone. Each maps to roadmap phases.

### Wrapper Hardening

- [x] **WRAP-01**: Wrapper forwards SIGTERM to Claude child process for graceful shutdown
- [x] **WRAP-02**: Wrapper supports mode selection (remote-control vs telegram) via config or env var
- [x] **WRAP-03**: Restart mechanism works with `claude remote-control` (PPID chain walk, restart file)
- [x] **WRAP-04**: Restart mechanism works with `claude --channels plugin:telegram@claude-plugins-official`

### systemd Service

- [x] **SYSD-01**: User service unit file runs wrapper with `Restart=on-failure`
- [x] **SYSD-02**: Service starts on boot and survives SSH logout via `loginctl enable-linger`
- [x] **SYSD-03**: Install script detects Linux and installs systemd unit file (macOS path unchanged)

### Watchdog

- [ ] **WDOG-01**: Periodic forced restart via systemd timer every N hours (configurable)

### Keep-Alive

- [ ] **KALV-01**: Heartbeat mechanism prevents Telegram plugin idle timeout

## Future Requirements

### Advanced Watchdog

- **WDOG-02**: Smart liveness detection via CPU/network activity instead of periodic restart
- **WDOG-03**: Per-mode health check (different strategies for remote-control vs telegram)

### Cross-Platform

- **XPLAT-01**: Linux compatibility for all scripts (not just installer)
- **XPLAT-02**: launchd support for macOS service management

## Out of Scope

| Feature | Reason |
|---------|--------|
| Running both modes simultaneously | Either remote-control or Telegram, not both |
| Slash command integration (`/restart`) | Future milestone |
| Session resume/context preservation | Not in scope for restart mechanism |
| launchd (macOS service management) | Personal VPS is Linux; macOS is dev only |
| Smart watchdog with activity detection | Periodic restart is simpler and avoids false positives |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WRAP-01 | Phase 4 | Complete |
| WRAP-02 | Phase 4 | Complete |
| WRAP-03 | Phase 4 | Complete |
| WRAP-04 | Phase 4 | Complete |
| SYSD-01 | Phase 5 | Complete |
| SYSD-02 | Phase 5 | Complete |
| SYSD-03 | Phase 5 | Complete |
| WDOG-01 | Phase 6 | Pending |
| KALV-01 | Phase 6 | Pending |

**Coverage:**
- v1.1 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after v1.1 roadmap creation*
