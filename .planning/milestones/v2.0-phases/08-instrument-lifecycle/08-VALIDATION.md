---
phase: 8
slug: instrument-lifecycle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test scripts (custom assert functions) |
| **Config file** | none — test scripts in `test/` directory |
| **Quick run command** | `bash test/test-service-lifecycle.sh` |
| **Full suite command** | `for t in test/test-*.sh; do bash "$t"; done` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash test/test-service-lifecycle.sh`
- **After every plan wave:** Run `for t in test/test-*.sh; do bash "$t"; done`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | LIFE-01 | unit | `bash test/test-service-lifecycle.sh` | No — W0 | pending |
| 08-01-02 | 01 | 1 | LIFE-02 | unit | `bash test/test-service-lifecycle.sh` | No — W0 | pending |
| 08-01-03 | 01 | 1 | LIFE-03 | unit | `bash test/test-service-lifecycle.sh` | No — W0 | pending |
| 08-02-01 | 02 | 1 | WDOG-04 | unit | `bash test/test-service-lifecycle.sh` | No — W0 | pending |
| 08-02-02 | 02 | 1 | WDOG-05 | unit | `bash test/test-service-lifecycle.sh` | No — W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/test-service-lifecycle.sh` — covers LIFE-01, LIFE-02, LIFE-03, WDOG-04, WDOG-05
  - Must mock `systemctl`, `git clone`, filesystem operations (same tmpdir pattern as test-install.sh)
  - Tests run on macOS (dev machine) so systemctl calls must be stubbed

*Existing test infrastructure (test-install.sh) provides the assert/mock pattern.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Service actually starts on VPS | LIFE-01 | Requires real systemd (Linux) | SSH to VPS, run `claude-service add test https://github.com/test/repo`, verify `systemctl --user is-active claude@test.service` returns `active` |
| Watchdog timer fires | WDOG-04 | Requires real systemd timer | SSH to VPS, check `systemctl --user list-timers` shows `claude-watchdog@test.timer` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
