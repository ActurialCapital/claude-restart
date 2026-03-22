# Roadmap: Claude Restart

## Milestones

- ✅ **v1.0 MVP** — Phases 1-3 (shipped 2026-03-21)
- 🚧 **v1.1 VPS Reliability** — Phases 4-6 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-3) — SHIPPED 2026-03-21</summary>

- [x] Phase 1: Wrapper Script (1/1 plans) — completed 2026-03-20
- [x] Phase 2: Restart Script (1/1 plans) — completed 2026-03-20
- [x] Phase 3: Shell Integration (1/1 plans) — completed 2026-03-21

</details>

### 🚧 v1.1 VPS Reliability (In Progress)

**Milestone Goal:** Make Claude Code resilient on a personal Linux VPS — survive crashes, SSH drops, and idle timeouts. Both remote-control and Telegram modes are supported, with the wrapper doing only what each mode doesn't already handle.

- [ ] **Phase 4: Wrapper Hardening** — SIGTERM forwarding, mode selection, and restart compatibility with both claude modes
- [x] **Phase 5: systemd Service** — Crash recovery, boot persistence, and Linux install support via systemd user service (completed 2026-03-22)
- [ ] **Phase 6: Watchdog and Keep-Alive** — Periodic forced restart via systemd timer and Telegram idle prevention

## Phase Details

### Phase 4: Wrapper Hardening
**Goal**: The wrapper runs both modes cleanly, exits gracefully on SIGTERM, and the restart mechanism works end-to-end with `claude remote-control` and `claude --channels plugin:telegram@...`
**Depends on**: Phase 3 (v1.0 wrapper is the starting point)
**Requirements**: WRAP-01, WRAP-02, WRAP-03, WRAP-04
**Success Criteria** (what must be TRUE):
  1. Running `systemctl stop claude` (or any SIGTERM sender) stops the service within 5 seconds — no 90-second wait for SIGKILL
  2. Setting `CLAUDE_CONNECT=remote-control` or `CLAUDE_CONNECT=telegram` at launch starts claude in the correct mode without manual argument editing
  3. Triggering a restart while in remote-control mode applies the new options and claude resumes — PPID chain walk finds the right process
  4. Triggering a restart while in Telegram channels mode applies the new options and claude resumes — plugin reconnects after wrapper relaunches
**Plans:** 2 plans
Plans:
- [x] 04-01-PLAN.md — Signal handling (SIGTERM/SIGHUP) and CLAUDE_CONNECT mode selection
- [x] 04-02-PLAN.md — Mode-aware restart logic and installer update

### Phase 5: systemd Service
**Goal**: Claude runs as a systemd user service that survives crashes, VPS reboots, and SSH logouts without any manual intervention
**Depends on**: Phase 4 (wrapper must handle SIGTERM and mode selection before being wrapped in a service)
**Requirements**: SYSD-01, SYSD-02, SYSD-03
**Success Criteria** (what must be TRUE):
  1. Killing the claude process causes systemd to restart it automatically within 10 seconds
  2. After a VPS reboot, the claude service starts without SSH login required
  3. Running `install.sh` on Linux deploys the systemd unit file and enables linger; running it on macOS leaves existing zshrc-based setup unchanged
  4. `systemctl --user status claude` shows the service active and the correct mode is running
**Plans:** 2/2 plans complete
Plans:
- [x] 05-01-PLAN.md — Create systemd unit file, env template, and claude-service helper
- [x] 05-02-PLAN.md — Extend installer with Linux/systemd deployment path

### Phase 6: Watchdog and Keep-Alive
**Goal**: Hung Telegram plugin sessions are detected and forcibly restarted on a schedule, and idle timeout is prevented by a periodic heartbeat
**Depends on**: Phase 5 (systemd timer infrastructure required for periodic restart; service must be running to validate watchdog behavior)
**Requirements**: WDOG-01, KALV-01
**Success Criteria** (what must be TRUE):
  1. After N hours (configurable), a systemd timer fires and triggers a forced restart — even if the process appears alive
  2. The forced-restart timer is mode-aware: it fires in Telegram mode and is suppressed or skipped in remote-control mode where built-in reconnection handles recovery
  3. The Telegram plugin does not go idle and stop responding within a configured window — heartbeat is active and measurable (e.g., wrapper log shows periodic keep-alive signals)
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 4 → 5 → 6

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Wrapper Script | v1.0 | 1/1 | Complete | 2026-03-20 |
| 2. Restart Script | v1.0 | 1/1 | Complete | 2026-03-20 |
| 3. Shell Integration | v1.0 | 1/1 | Complete | 2026-03-21 |
| 4. Wrapper Hardening | v1.1 | 2/2 | Complete | 2026-03-22 |
| 5. systemd Service | v1.1 | 2/2 | Complete   | 2026-03-22 |
| 6. Watchdog and Keep-Alive | v1.1 | 0/? | Not started | - |
