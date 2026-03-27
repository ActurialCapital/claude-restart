---
phase: 13
slug: synchronous-dispatch
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-27
validated: 2026-03-27
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + grep-based content verification |
| **Config file** | none — validation via grep/diff on orchestra/CLAUDE.md content |
| **Quick run command** | `bash test/test-phase13-validation.sh` |
| **Full suite command** | `bash test/test-orchestra.sh && bash test/test-phase13-validation.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash test/test-phase13-validation.sh`
- **After every plan wave:** Run `bash test/test-orchestra.sh && bash test/test-phase13-validation.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | DISP-01 | grep/unit | `bash test/test-phase13-validation.sh` (tests 1-3) | test/test-phase13-validation.sh | green |
| 13-01-02 | 01 | 1 | DISP-02 | grep/unit | `bash test/test-phase13-validation.sh` (tests 4-5) | test/test-phase13-validation.sh | green |
| 13-01-03 | 01 | 1 | DISP-03 | grep/unit | `bash test/test-phase13-validation.sh` (tests 6-7) | test/test-phase13-validation.sh | green |
| 13-01-04 | 01 | 1 | DISP-04 | grep/unit | `bash test/test-phase13-validation.sh` (tests 8-9) | test/test-phase13-validation.sh | green |
| 13-02-01 | 01 | 1 | ORCH-01 | grep/unit | `bash test/test-phase13-validation.sh` (tests 10-11) | test/test-phase13-validation.sh | green |
| 13-02-02 | 01 | 1 | ORCH-02 | grep/unit | `bash test/test-phase13-validation.sh` (tests 12-16) | test/test-phase13-validation.sh | green |
| 13-02-03 | 01 | 1 | ORCH-03 | grep/unit | `bash test/test-phase13-validation.sh` (tests 17-18) | test/test-phase13-validation.sh | green |

*Status: pending · green · red · flaky*

---

## Wave 0 Requirements

- [x] `test/test-phase13-validation.sh` — Nyquist validation script covering all 7 requirements (21 tests)
- [x] `test/test-orchestra.sh` — existing test suite (21 tests, pre-existing from phase execution)
- [x] Existing infrastructure covers dispatch validation via grep patterns

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Parallel dispatch non-blocking at runtime | DISP-04 | Requires runtime observation of actual claude -p processes | Launch 2+ parallel dispatches, verify orchestra remains responsive |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-03-27
