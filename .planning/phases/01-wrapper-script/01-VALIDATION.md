---
phase: 01
slug: wrapper-script
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-20
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash (custom test harness with assert_eq/assert_contains) |
| **Config file** | none — self-contained in test/test-wrapper.sh |
| **Quick run command** | `bash test/test-wrapper.sh` |
| **Full suite command** | `bash test/test-wrapper.sh` |
| **Estimated runtime** | ~1 second |

---

## Sampling Rate

- **After every task commit:** Run `bash test/test-wrapper.sh`
- **After every plan wave:** Run `bash test/test-wrapper.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | WRAP-01 | integration | `bash test/test-wrapper.sh` | test/test-wrapper.sh | ✅ green |
| 01-01-02 | 01 | 1 | WRAP-02 | integration | `bash test/test-wrapper.sh` | test/test-wrapper.sh | ✅ green |
| 01-01-03 | 01 | 1 | WRAP-03 | integration | `bash test/test-wrapper.sh` | test/test-wrapper.sh | ✅ green |
| 01-01-04 | 01 | 1 | WRAP-04 | integration | `bash test/test-wrapper.sh` | test/test-wrapper.sh | ✅ green |
| 01-01-05 | 01 | 1 | WRAP-05 | inspection | N/A (no `cd` in script) | bin/claude-wrapper | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Ctrl+C kills entire wrapper in live TTY | WRAP-01 (signal handling) | Requires interactive terminal with real foreground TUI process; subshell test harness changes signal delivery | Launch `bin/claude-wrapper`, press Ctrl+C during claude — wrapper should exit 130 |
| 2-second delay perception on restart | WRAP-02 | Tests override CLAUDE_WRAPPER_DELAY=0 for speed; default `sleep 2` present but not exercised in CI | Trigger restart via `~/.claude-restart`, observe ~2s pause before relaunch |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 1s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-20

---

## Validation Audit 2026-03-20

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
