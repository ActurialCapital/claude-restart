# Roadmap: Claude Restart

## Milestones

- ✅ **v1.0 MVP** -- Phases 1-3 (shipped 2026-03-21)
- ✅ **v1.1 VPS Reliability** -- Phases 4-6 (shipped 2026-03-22)
- ✅ **v2.0 Multi-Instance Orchestration** -- Phases 7-11 (shipped 2026-03-24)
- 🚧 **v3.0 Synchronous Dispatch Architecture** -- Phases 12-14 (in progress)

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

<details>
<summary>v2.0 Multi-Instance Orchestration (Phases 7-11) -- SHIPPED 2026-03-24</summary>

- [x] Phase 7: Template Unit Foundation (3/3 plans) -- completed 2026-03-23
- [x] Phase 8: Instrument Lifecycle (2/2 plans) -- completed 2026-03-23
- [x] Phase 9: Autonomous Orchestra (6/6 plans) -- completed 2026-03-24
- [x] Phase 10: Orchestra MCP Provisioning (1/1 plan) -- completed 2026-03-24
- [x] Phase 11: Orchestra CLAUDE.md Auto-deploy (1/1 plan) -- completed 2026-03-24

</details>

### 🚧 v3.0 Synchronous Dispatch Architecture (In Progress)

**Milestone Goal:** Replace async peer messaging with synchronous `claude -p` dispatch, simplifying orchestra-to-instrument communication and removing all claude-peers infrastructure.

- [ ] **Phase 12: Peers Teardown** - Strip claude-peers infrastructure from wrapper, services, and config
- [ ] **Phase 13: Synchronous Dispatch** - Orchestra CLAUDE.md rewrite and `claude -p` dispatch patterns
- [ ] **Phase 14: Skills Deployment and Identity** - GSD/superpowers on VPS, instrument self-awareness, session fix

## Phase Details

### Phase 12: Peers Teardown
**Goal**: All claude-peers infrastructure is removed and instruments run clean without broker, watcher, or channel dependencies
**Depends on**: Phase 11
**Requirements**: CLNP-01, CLNP-02, CLNP-03, CLNP-04, CLNP-05
**Success Criteria** (what must be TRUE):
  1. Instruments start without loading any claude-peers MCP server (no `.mcp.json` claude-peers entry)
  2. `claude-wrapper` launches claude without `--dangerously-load-development-channels` flag and without spawning a message-watcher sidecar
  3. `env.template` and per-instance env files contain no `CLAUDE_CHANNELS` variable
  4. systemd services have no broker startup dependency or ExecStartPre referencing claude-peers
**Plans**: 2 plans

Plans:
- [ ] 12-01-PLAN.md — Strip channel_args, message-watcher, and CLAUDE_CHANNELS from wrapper and env.template
- [ ] 12-02-PLAN.md — Strip peers from install.sh, claude-service, and tests

### Phase 13: Synchronous Dispatch
**Goal**: Orchestra drives instruments via synchronous `claude -p` commands with parallel execution, long-running task handling, and continuation support
**Depends on**: Phase 12
**Requirements**: DISP-01, DISP-02, DISP-03, DISP-04, ORCH-01, ORCH-02, ORCH-03
**Success Criteria** (what must be TRUE):
  1. Orchestra can dispatch a GSD command to an instrument via `claude -p` and capture its stdout result
  2. Orchestra can dispatch to multiple instruments in parallel (backgrounded) and collect all outputs
  3. Orchestra uses `--continue` to chain multi-step GSD sequences in the same instrument context
  4. Long-running `claude -p` tasks (minutes) do not block orchestra from dispatching to other instruments
  5. Orchestra CLAUDE.md contains no references to `send_message`, `check_messages`, or claude-peers -- only `claude -p` dispatch patterns with escalation protocol preserved
**Plans**: TBD

Plans:
- [ ] 13-01: TBD
- [ ] 13-02: TBD

### Phase 14: Skills Deployment and Identity
**Goal**: VPS instruments have GSD/superpowers skills available, know their own identity, and phone shows clean session list
**Depends on**: Phase 12
**Requirements**: DEPL-01, DEPL-02, DEPL-03, INST-01, INST-02, SESS-01
**Success Criteria** (what must be TRUE):
  1. Running `claude -p` in an instrument directory on VPS has access to `/gsd:*` commands from `~/.claude/get-shit-done/`
  2. Superpowers skills are deployed to `~/.claude/` on VPS and available to instruments
  3. Each instrument's CLAUDE.md contains its instance name and the correct `claude-restart --instance <name>` hint
  4. Phone shows only one session per instrument (no duplicate "General coding session" entries)
**Plans**: TBD
**UI hint**: no

Plans:
- [ ] 14-01: TBD
- [ ] 14-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 12 -> 13 -> 14
(Phase 14 depends on 12, not 13, so 13 and 14 could theoretically run in parallel)

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
| 11. Orchestra CLAUDE.md Auto-deploy | v2.0 | 1/1 | Complete | 2026-03-24 |
| 12. Peers Teardown | v3.0 | 0/2 | Planning | - |
| 13. Synchronous Dispatch | v3.0 | 0/? | Not started | - |
| 14. Skills Deployment and Identity | v3.0 | 0/? | Not started | - |
