# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

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
- Phase dependency ordering (4→5→6) meant each phase built cleanly on the last
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

### Cumulative Quality

| Milestone | Tests | Assertions | Zero-Dep Additions |
|-----------|-------|------------|-------------------|
| v1.0 | 23 | 41 | 3 (pure bash, no deps) |
| v1.1 | 82 | 123 | 4 (claude-service, systemd units, watchdog, heartbeat) |

### Top Lessons (Verified Across Milestones)

1. TDD with environment variable overrides delivers zero-rework implementations — verified in both v1.0 and v1.1
2. ROADMAP.md progress tables drift from actual completion — need automated sync or post-phase update discipline
