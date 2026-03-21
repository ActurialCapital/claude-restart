# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

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

### Cumulative Quality

| Milestone | Tests | Assertions | Zero-Dep Additions |
|-----------|-------|------------|-------------------|
| v1.0 | 23 | 41 | 3 (pure bash, no deps) |

### Top Lessons (Verified Across Milestones)

1. (First milestone — lessons to be verified in future milestones)
