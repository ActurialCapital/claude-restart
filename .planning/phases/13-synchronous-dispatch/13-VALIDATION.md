---
phase: 13
slug: synchronous-dispatch
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + diff-based validation |
| **Config file** | none — validation via grep/diff on CLAUDE.md output |
| **Quick run command** | `grep -c 'claude -p' orchestra/CLAUDE.md` |
| **Full suite command** | `bash tests/validate-orchestra-claude-md.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `grep -c 'claude -p' orchestra/CLAUDE.md`
- **After every plan wave:** Run `bash tests/validate-orchestra-claude-md.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | DISP-01 | grep | `grep 'claude -p' orchestra/CLAUDE.md` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | DISP-02 | grep | `grep -E 'parallel\|background\|&' orchestra/CLAUDE.md` | ❌ W0 | ⬜ pending |
| 13-01-03 | 01 | 1 | DISP-03 | grep | `grep '\-\-continue' orchestra/CLAUDE.md` | ❌ W0 | ⬜ pending |
| 13-01-04 | 01 | 1 | DISP-04 | grep | `grep -E 'long.running\|timeout\|background' orchestra/CLAUDE.md` | ❌ W0 | ⬜ pending |
| 13-02-01 | 02 | 1 | ORCH-01 | grep | `grep 'claude -p' orchestra/CLAUDE.md` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 1 | ORCH-02 | grep | `! grep -E 'send_message\|check_messages\|claude-peers' orchestra/CLAUDE.md` | ❌ W0 | ⬜ pending |
| 13-02-03 | 02 | 1 | ORCH-03 | grep | `grep 'escalat' orchestra/CLAUDE.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/validate-orchestra-claude-md.sh` — validation script for all requirement checks
- [ ] Existing infrastructure covers dispatch validation via grep patterns

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Parallel dispatch non-blocking | DISP-04 | Requires runtime observation | Launch 2+ parallel dispatches, verify orchestra remains responsive |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
