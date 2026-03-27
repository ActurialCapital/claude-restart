# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v3.0 — Synchronous Dispatch Architecture

**Shipped:** 2026-03-27
**Phases:** 3 | **Plans:** 5 | **Sessions:** ~3

### What Was Built
- Stripped all claude-peers infrastructure (channels, broker, message-watcher, MCP server) from wrapper, services, env files, and install script
- Rewrote orchestra CLAUDE.md for synchronous `claude -p` dispatch with parallel backgrounding, `--continue` chaining, fleet discovery, and escalation protocol
- Added `deploy_skills()` to install.sh copying GSD workflows and superpowers commands from repo to `~/.claude/` on VPS
- Created per-instrument identity CLAUDE.md template deployed via `claude-service add` with instance name substitution
- Fixed session naming by removing default instance exclusion from `--name` flag logic

### What Worked
- Clean architectural pivot: replacing async peer messaging with synchronous `claude -p` removed ~200 lines of infrastructure and simplified the mental model
- Parallel phase execution (13 and 14 could run independently since both depended on 12, not each other)
- Milestone audit + gap closure workflow caught all tech debt items before shipping
- Nyquist validation finally achieved 100% compliance (65 tests across 3 phases) after being flagged in v1.0, v1.1, and v2.0 retros
- VPS verification via SSH caught stale env files (`CLAUDE_CHANNELS` still set) that code-level testing couldn't detect

### What Was Inefficient
- VPS was 20+ commits behind remote — all v3.0 work was done locally without pushing until tech debt resolution. Should push incrementally after each phase
- Content stubs (skills/, commands/) sat empty throughout development — should populate during the phase that creates them, not as post-audit tech debt
- Phase 14 plan count shows 1/2 in ROADMAP progress table despite both being complete — the drift pattern continues

### Patterns Established
- `claude -p` as the sole dispatch primitive (replacing claude-peers entirely)
- `deploy_skills()` function in installer for VPS skill deployment from repo source directories
- Identity CLAUDE.md in `.claude/CLAUDE.md` per instrument (avoids conflicting with project CLAUDE.md)
- SSH-based VPS verification as part of milestone tech debt resolution

### Key Lessons
1. Push to remote after each phase, not just at milestone end — VPS fell 20 commits behind
2. Populate content directories in the same phase that creates the wiring — empty stubs become tech debt
3. Nyquist validation is achievable when treated as a first-class deliverable rather than deferred audit item
4. VPS verification requires SSH access and is not replaceable by local testing — stale config is invisible to code analysis
5. `claude -p` dispatch is simpler and more reliable than any form of inter-session messaging

### Cost Observations
- Model mix: 100% opus
- Sessions: ~3
- Notable: Entire v3.0 milestone (3 phases, 5 plans, peers teardown + dispatch rewrite + skills deployment) completed in a single day. Tech debt resolution and Nyquist validation done in one session

---

## Milestone: v2.0 — Multi-Instance Orchestration

**Shipped:** 2026-03-24
**Phases:** 5 | **Plans:** 13 | **Sessions:** ~8

### What Was Built
- systemd template unit (`claude@.service`) with %i-based per-instance config, dynamic MemoryMax, and instance-aware env template
- Instance-aware wrapper, restart, and service scripts — backward-compatible with v1.1 single-instance mode
- Installer with v1.1 migration preserving existing config in per-instance default/ directory
- Per-instance watchdog template units (`claude-watchdog@.service/timer`) with installer migration
- Single-command instrument lifecycle: `claude-service add/remove/list` with automatic watchdog pairing
- Autonomous orchestra supervisor via CLAUDE.md behavioral spec with GSD workflow dispatch and parallel driving
- FIFO-based remote-control stdin with heartbeat writer and auto-confirm patterns
- Auto-provisioned MCP config (`.mcp.json`) and CLAUDE.md deployment — zero manual orchestra setup

### What Worked
- Pure prompt engineering for orchestra (CLAUDE.md IS the supervisor) — no orchestration code needed
- Reusing FIFO-based stdin pattern from v1.1 telegram mode for remote-control solved session persistence
- 4 gap closure phases (09-03 through 09-06, plus 10 and 11) caught integration issues before deployment
- Milestone audit workflow caught documentation drift and missing deployment automation
- Architecture decision: instruments hold project intelligence, orchestra is just dispatcher — clean separation

### What Was Inefficient
- Phase 9 required 4 gap closure sub-plans (09-03 through 09-06) to fix remote-control startup issues — each one discovered the next blocker sequentially rather than catching them all upfront
- `claude remote-control` undocumented behavior (exit codes, permission flags, channel args ordering) caused trial-and-error debugging
- ROADMAP.md progress table continued to drift — now a 3-milestone pattern
- Nyquist validation files still never fully created (partial in 3 phases, missing in 2)

### Patterns Established
- systemd template units with %i substitution for multi-instance management
- Instrument manifest (`manifest.json`) for fleet tracking
- FIFO + heartbeat + auto-confirm as universal stdin strategy for non-interactive Claude sessions
- `claude -p` as the dispatch primitive for orchestrated one-shot tasks
- CLAUDE.md-as-supervisor pattern: behavioral spec replaces orchestration code

### Key Lessons
1. Integration gaps between phases are best caught by milestone audit, not by hoping phase-level verification is sufficient
2. Remote-control mode has undocumented quirks — budget extra time for any phase touching claude CLI startup
3. Gap closure phases are a feature, not a failure — they're cheaper than getting Phase 9 right on the first attempt
4. Auto-provisioning deployment artifacts (MCP config, CLAUDE.md) during lifecycle commands prevents "manual step" gaps
5. Orchestra as pure prompt engineering validates that CLAUDE.md specifications are powerful enough to define autonomous agents

### Cost Observations
- Model mix: 100% opus
- Sessions: ~8
- Notable: 13 plans across 5 phases in ~2 days; gap closure phases (4 of 13 plans) were fast single-issue fixes

---

## Milestone: v1.1 — VPS Reliability

**Shipped:** 2026-03-22
**Phases:** 3 | **Plans:** 6 | **Sessions:** ~4

### What Was Built
- SIGTERM forwarding and CLAUDE_CONNECT mode selection for remote-control/telegram/interactive modes
- Mode-aware restart preserving mode args across restarts
- systemd user service with crash recovery, env template, and claude-service management helper
- Platform-aware installer deploying systemd + linger on Linux (macOS path unchanged)
- Watchdog timer with mode-aware periodic forced restart (telegram only)
- FIFO-based keep-alive heartbeat preventing Telegram idle timeout

### What Worked
- TDD continued to deliver zero rework — grew from 41 to 82 assertions with no regression
- Phase dependency ordering (4->5->6) meant each phase built cleanly on the last
- Mode-aware design (CLAUDE_CONNECT gating) kept watchdog/heartbeat from interfering with remote-control mode
- Shared EnvironmentFile pattern unified config across service, wrapper, and watchdog
- Mock-based testing scaled well — mocked systemctl/loginctl for installer tests without needing real Linux

### What Was Inefficient
- ROADMAP.md progress table drifted again — Phase 6 showed "0/2 Not started" when actually complete
- Nyquist validation files still never created despite being flagged in v1.0 retro
- Phase 4 roadmap checkbox never got ticked despite being complete

### Patterns Established
- CLAUDE_CONNECT env var as single source of truth for mode selection across all components
- EnvironmentFile sharing between systemd service and watchdog oneshot
- FIFO-based stdin delivery for cross-platform process communication
- Backgrounded sleep with tracked PID and TERM trap to prevent orphaned processes

### Key Lessons
1. Shared config (EnvironmentFile) between related systemd units prevents drift — don't duplicate env vars
2. systemd gotchas are real: StartLimitBurst silently ignored in [Service], must be in [Unit]
3. Cross-platform sed needs runtime detection (`uname -s`), not build-time — test env may differ from target

### Cost Observations
- Model mix: 100% opus
- Sessions: ~4
- Notable: 6 plans across 3 phases executed in ~21 minutes total (per STATE.md metrics)

---

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-21
**Phases:** 3 | **Plans:** 3 | **Sessions:** ~3

### What Was Built
- Wrapper script that runs claude in a restart loop with signal handling and safety valve
- Restart trigger script with PPID chain walk to find and kill the correct claude process
- Install script with sentinel-based idempotent zshrc modification and clean uninstall

### What Worked
- TDD approach delivered 41 assertions across 23 tests with zero rework
- Environment variable overrides for testability enabled fast tests (<1s instead of 20s+)
- Mock-based testing (PATH prepend with fake claude) gave full isolation without process complexity
- Small, focused scripts (55-86 lines each) kept each phase tractable

### What Was Inefficient
- ROADMAP.md progress table got out of sync with actual completion (Phase 1 and 2 showed "Not started" when complete)
- Nyquist validation files were never created despite config enabling them — not blocking but extra audit noise

### Patterns Established
- Restart file protocol: file presence = restart signal, file content = new args, empty = use originals
- Sentinel-guarded shell config blocks for reversible, idempotent rc file modification
- PPID chain walk pattern for finding ancestor processes by command pattern

### Key Lessons
1. Environment variable overrides for all configurable paths/delays should be designed in from the start — retrofitting is harder
2. Graceful degradation (write file even if kill fails) makes the system more resilient than failing atomically

### Cost Observations
- Model mix: 100% opus
- Sessions: ~3
- Notable: All 3 phases executed in under 10 minutes total wall time

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~3 | 3 | Initial process — TDD with mock-based isolation |
| v1.1 | ~4 | 3 | Scaled TDD to systemd mocking, shared config patterns |
| v2.0 | ~8 | 5 | Multi-phase orchestration, gap closure workflow, milestone audits |
| v3.0 | ~3 | 3 | Architecture pivot (peers→dispatch), full Nyquist compliance, VPS verification |

### Cumulative Quality

| Milestone | Tests | Assertions | Zero-Dep Additions |
|-----------|-------|------------|-------------------|
| v1.0 | 23 | 41 | 3 (pure bash, no deps) |
| v1.1 | 82 | 123 | 4 (claude-service, systemd units, watchdog, heartbeat) |
| v2.0 | 95+ | 150+ | 5 (template units, lifecycle, orchestra, MCP, CLAUDE.md deploy) |
| v3.0 | 150+ | 215+ | 3 (deploy_skills, identity template, orchestra dispatch rewrite) |

### Top Lessons (Verified Across Milestones)

1. TDD with environment variable overrides delivers zero-rework implementations — verified in v1.0, v1.1, v2.0, v3.0
2. ROADMAP.md progress tables drift from actual completion — persistent across all 4 milestones, needs tooling fix
3. Gap closure phases are a natural part of multi-phase milestones — budget for them rather than treating as failures
4. Milestone audits catch documentation and integration drift that phase-level verification misses
5. Push incrementally to remote — verified in v3.0 where VPS fell 20 commits behind
6. VPS verification via SSH is essential — local testing cannot detect stale deployed config
