# Requirements: Claude Restart

**Defined:** 2026-03-22
**Core Value:** Multiple Claude sessions run reliably on a VPS with easy lifecycle management and optional autonomous coordination across projects.

## v2.0 Requirements

Requirements for Multi-Instance Orchestration milestone. Each maps to roadmap phases.

### Multi-Instance Foundation

- [ ] **INST-01**: systemd template unit (`claude@.service`) runs any instrument by name with per-instance EnvironmentFile
- [ ] **INST-02**: Each instrument has isolated env file at `~/.config/claude-restart/<name>/env` with its own API key, CLAUDE_CONNECT, working directory
- [ ] **INST-03**: Each instrument has isolated restart file (no shared `~/.claude-restart`) via per-instance `CLAUDE_RESTART_FILE`
- [ ] **INST-04**: Each instrument has `MemoryMax` cgroup limit in systemd to prevent OOM from memory leaks
- [ ] **INST-05**: When no instance name is provided, all scripts behave identically to v1.1 single-instance mode

### Instrument Lifecycle

- [ ] **LIFE-01**: User can add an instrument with a single command (clone repo, create env file, enable systemd service, register in manifest)
- [ ] **LIFE-02**: User can remove an instrument with a single command (stop service, clean up config, deregister from manifest)
- [ ] **LIFE-03**: User can list all instruments with their status (running/stopped/failed)

### Watchdog Migration

- [ ] **WDOG-04**: Watchdog timer is templated per-instance (`claude-watchdog@.timer`) and paired automatically with instrument lifecycle
- [ ] **WDOG-05**: Adding an instrument enables its watchdog timer; removing an instrument disables it

### Wrapper Adaptation

- [ ] **WRAP-05**: Wrapper reads `CLAUDE_INSTANCE_NAME` and passes it as `--name` flag to `claude remote-control`
- [ ] **WRAP-06**: `claude-restart` accepts `--instance <name>` to restart a specific instrument

### Autonomous Orchestra

- [ ] **ORCH-01**: Orchestra is itself an instrument — a Claude session with CLAUDE.md that runs as its own systemd service
- [ ] **ORCH-02**: Orchestra can dispatch one-shot agents via `claude -p` in any instrument's project directory
- [ ] **ORCH-03**: Orchestra can restart any instrument via `claude-restart --instance <name>` for context reset between phases
- [ ] **ORCH-04**: Orchestra detects instruments added or removed while it is running (dynamic discovery)
- [ ] **ORCH-05**: Orchestra always routes messages to the correct instrument based on project context

## Future Requirements

### Advanced Orchestra

- **ORCH-06**: Orchestra can inject prompts into a running instrument's session (blocked on `claude inject` feature — issue #24947)
- **ORCH-07**: Orchestra manages API rate limit budget across concurrent instruments

### Telegram Integration

- **TELE-01**: Orchestra exposes a Telegram bot interface for phone interaction
- **TELE-02**: Instruments can optionally run in telegram mode alongside remote-control

### Cross-Platform

- **XPLAT-01**: Instrument lifecycle tooling works on macOS for local development
- **XPLAT-02**: launchd support for macOS service management

## Out of Scope

| Feature | Reason |
|---------|--------|
| Relay mode for orchestra | Autonomous only — direct access covers manual interaction |
| Orchestra making implementation decisions | Instruments hold project intelligence; orchestra is supervisor/dispatcher |
| Running both modes simultaneously per instrument | Either remote-control or telegram, not both |
| Session resume/context preservation across restarts | Not in scope for restart mechanism |
| Smart watchdog with activity detection | Periodic restart is simpler and avoids false positives |
| Claude Agent Teams integration | Designed for single-repo coordination, not cross-project orchestration |
| Custom IPC protocol between sessions | `claude -p` and `claude-restart` are sufficient; no WebSocket/socket needed |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INST-01 | — | Pending |
| INST-02 | — | Pending |
| INST-03 | — | Pending |
| INST-04 | — | Pending |
| INST-05 | — | Pending |
| LIFE-01 | — | Pending |
| LIFE-02 | — | Pending |
| LIFE-03 | — | Pending |
| WDOG-04 | — | Pending |
| WDOG-05 | — | Pending |
| WRAP-05 | — | Pending |
| WRAP-06 | — | Pending |
| ORCH-01 | — | Pending |
| ORCH-02 | — | Pending |
| ORCH-03 | — | Pending |
| ORCH-04 | — | Pending |
| ORCH-05 | — | Pending |

**Coverage:**
- v2.0 requirements: 17 total
- Mapped to phases: 0
- Unmapped: 17

---
*Requirements defined: 2026-03-22*
*Last updated: 2026-03-22 after initial definition*
