# Roadmap: Claude Restart

## Milestones

- ✅ **v1.0 MVP** -- Phases 1-3 (shipped 2026-03-21)
- ✅ **v1.1 VPS Reliability** -- Phases 4-6 (shipped 2026-03-22)
- [ ] **v2.0 Multi-Instance Orchestration** -- Phases 7-11 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-3) -- SHIPPED 2026-03-21</summary>

- [x] Phase 1: Wrapper Script (1/1 plans) -- completed 2026-03-20
- [x] Phase 2: Restart Script (1/1 plans) -- completed 2026-03-20
- [x] Phase 3: Shell Integration (1/1 plans) -- completed 2026-03-21

</details>

<details>
<summary>v1.1 VPS Reliability (Phases 4-6) -- SHIPPED 2026-03-22</summary>

- [x] Phase 4: Wrapper Hardening (2/2 plans) -- completed 2026-03-22
- [x] Phase 5: systemd Service (2/2 plans) -- completed 2026-03-22
- [x] Phase 6: Watchdog and Keep-Alive (2/2 plans) -- completed 2026-03-22

</details>

### v2.0 Multi-Instance Orchestration

- [x] **Phase 7: Template Unit Foundation** - Isolated multi-instance infrastructure with per-instance env, restart files, memory limits, and instance-aware wrapper/restart scripts (completed)
- [x] **Phase 8: Instrument Lifecycle** - Single-command add/remove/list with automatic watchdog pairing per instrument (completed)
- [x] **Phase 9: Autonomous Orchestra** - Supervisor session that dispatches work, restarts instruments, and dynamically discovers changes (completed)
- [x] **Phase 10: Orchestra MCP Provisioning** - Gap closure: auto-provision .mcp.json for claude-peers so orchestra doesn't depend on manual global config (completed 2026-03-24)
- [x] **Phase 11: Orchestra CLAUDE.md Auto-deploy** - Gap closure: auto-deploy orchestra/CLAUDE.md during add-orchestra + fix stale ROADMAP.md documentation (completed 2026-03-24)

## Phase Details

### Phase 7: Template Unit Foundation
**Goal**: Any instrument can run as an isolated systemd instance with its own config, restart file, and memory limit -- and the wrapper/restart scripts know which instance they belong to
**Depends on**: Phase 6 (v1.1 systemd infrastructure)
**Requirements**: INST-01, INST-02, INST-03, INST-04, INST-05, WRAP-05, WRAP-06
**Success Criteria** (what must be TRUE):
  1. User can start an instrument by name with `systemctl --user start claude@myproject` and it reads from `~/.config/claude-restart/myproject/env`
  2. Two instruments running simultaneously use separate restart files and do not interfere with each other
  3. Each instrument is cgroup-limited by MemoryMax so one runaway instance cannot OOM the VPS
  4. Running scripts without an instance name behaves identically to v1.1 single-instance mode (backward compatibility)
  5. The wrapper passes `--name <instance>` to `claude remote-control` and `claude-restart --instance <name>` targets the correct instrument
**Plans**: 3 plans

Plans:
- [x] 07-01-PLAN.md — Create systemd template unit and updated env template
- [x] 07-02-PLAN.md — Make wrapper, restart, and service scripts instance-aware
- [x] 07-03-PLAN.md — Update installer with template deployment and v1.1 migration

### Phase 8: Instrument Lifecycle
**Goal**: User manages the full instrument fleet with single commands, and every instrument automatically gets a watchdog timer
**Depends on**: Phase 7
**Requirements**: LIFE-01, LIFE-02, LIFE-03, WDOG-04, WDOG-05
**Success Criteria** (what must be TRUE):
  1. User can add a new instrument with one command that creates env file, enables service, and registers it in the manifest
  2. User can remove an instrument with one command that stops it, cleans up config, and deregisters it
  3. User can list all instruments and see each one's status (running/stopped/failed)
  4. Adding an instrument automatically enables its per-instance watchdog timer; removing disables it
**Plans**: 2 plans

Plans:
- [x] 08-01-PLAN.md — Watchdog template units and install.sh migration
- [x] 08-02-PLAN.md — claude-service add/remove/list subcommands and lifecycle tests

### Phase 9: Autonomous Orchestra
**Goal**: An optional autonomous Claude session supervises all instruments -- dispatching work, resetting context, spawning research agents, and adapting to fleet changes
**Depends on**: Phase 8
**Requirements**: ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-05
**Success Criteria** (what must be TRUE):
  1. Orchestra runs as its own instrument (`claude@orchestra`) with a CLAUDE.md that describes its supervisor role and available tools
  2. Orchestra can dispatch a one-shot `claude -p` task in any instrument's project directory and receive the result
  3. Orchestra can restart any instrument via `claude-restart --instance <name>` for context reset between work phases
  4. Orchestra detects instruments added or removed while it is running (reads manifest before each action)
  5. Orchestra routes messages to the correct instrument based on project context without manual configuration
**Plans**: 6 plans

Plans:
- [x] 09-01-PLAN.md — Infrastructure: channel flag support, env template updates, add-orchestra subcommand
- [x] 09-02-PLAN.md — Orchestra CLAUDE.md: supervisor behavior specification with tools, workflow, and protocols
- [x] 09-03-PLAN.md — Gap closure: fix remote-control permission flag and auto-confirm prompt in wrapper
- [x] 09-04-PLAN.md — Gap closure: fix channel flag argument ordering in wrapper
- [x] 09-05-PLAN.md — Gap closure: FIFO-based stdin for remote-control mode (persistent session)
- [x] 09-06-PLAN.md — Gap closure: pre-set remoteDialogSeen to bypass confirmation prompt

### Phase 10: Orchestra MCP Provisioning
**Goal**: `add-orchestra` automatically provisions `.mcp.json` with claude-peers config so orchestra peer discovery works without manual global `~/.claude.json` setup
**Depends on**: Phase 9
**Requirements**: ORCH-04, ORCH-05 (gap closure — already satisfied via global config, this makes provisioning automatic)
**Gap Closure**: Closes integration gap from v2.0 audit
**Success Criteria** (what must be TRUE):
  1. `add-orchestra` creates `.mcp.json` in the orchestra working directory with claude-peers MCP server config
  2. Orchestra can discover and message instruments without any manual MCP configuration
**Plans**: 1 plan

Plans:
- [x] 10-01-PLAN.md — Auto-provision .mcp.json in add-orchestra subcommand

### Phase 11: Orchestra CLAUDE.md Auto-deploy
**Goal**: `add-orchestra` automatically copies `orchestra/CLAUDE.md` into the orchestra working directory so the orchestra session starts with its behavioral spec
**Depends on**: Phase 9
**Requirements**: ORCH-01 (gap closure — already satisfied, this fixes the deployment path)
**Gap Closure**: Closes FINDING-01 from v2.0 audit + fixes stale ROADMAP.md documentation
**Success Criteria** (what must be TRUE):
  1. `add-orchestra` copies `orchestra/CLAUDE.md` to the orchestra working directory automatically
  2. "Add Orchestra E2E" flow completes without manual CLAUDE.md copy step
  3. ROADMAP.md progress table and plan checkboxes are accurate
**Plans**: 1 plan

Plans:
- [x] 11-01-PLAN.md — Auto-deploy CLAUDE.md in add-orchestra + fix stale ROADMAP documentation

## Progress

**Execution Order:** Phase 7 -> Phase 8 -> Phase 9 -> Phase 10 -> Phase 11

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Wrapper Script | v1.0 | 1/1 | Complete | 2026-03-20 |
| 2. Restart Script | v1.0 | 1/1 | Complete | 2026-03-20 |
| 3. Shell Integration | v1.0 | 1/1 | Complete | 2026-03-21 |
| 4. Wrapper Hardening | v1.1 | 2/2 | Complete | 2026-03-22 |
| 5. systemd Service | v1.1 | 2/2 | Complete | 2026-03-22 |
| 6. Watchdog and Keep-Alive | v1.1 | 2/2 | Complete | 2026-03-22 |
| 7. Template Unit Foundation | v2.0 | 3/3 | Complete | 2026-03-23 |
| 8. Instrument Lifecycle | v2.0 | 2/2 | Complete | 2026-03-23 |
| 9. Autonomous Orchestra | v2.0 | 6/6 | Complete | 2026-03-24 |
| 10. Orchestra MCP Provisioning | v2.0 | 1/1 | Complete | 2026-03-24 |
| 11. Orchestra CLAUDE.md Auto-deploy | v2.0 | 1/1 | Complete    | 2026-03-24 |
