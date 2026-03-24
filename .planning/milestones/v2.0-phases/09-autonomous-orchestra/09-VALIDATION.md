---
phase: 9
slug: autonomous-orchestra
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test scripts (project convention from phases 7-8) |
| **Config file** | None -- tests are standalone bash scripts in `test/` |
| **Quick run command** | `bash test/test-orchestra.sh` |
| **Full suite command** | `for f in test/test-*.sh; do bash "$f"; done` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash test/test-orchestra.sh`
- **After every plan wave:** Run `for f in test/test-*.sh; do bash "$f"; done`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | ORCH-01 | smoke | `bash test/test-orchestra.sh` (env file, CLAUDE.md, systemd unit) | No -- W0 | pending |
| 09-01-02 | 01 | 1 | ORCH-01 | smoke | `bash test/test-orchestra.sh` (CLAUDE.md content validation) | No -- W0 | pending |
| 09-01-03 | 01 | 1 | ORCH-03 | unit | `bash test/test-restart.sh` (--instance flag) | Yes (partial) | pending |
| 09-02-01 | 02 | 2 | ORCH-02 | manual | Manual -- requires live Claude session | N/A manual | pending |
| 09-02-02 | 02 | 2 | ORCH-04 | manual | Manual -- requires live claude-peers broker | N/A manual | pending |
| 09-02-03 | 02 | 2 | ORCH-05 | manual | Manual -- requires live claude-peers + instruments | N/A manual | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/test-orchestra.sh` -- verify orchestra env file, CLAUDE.md placement, systemd unit registration
- [ ] `test/test-wrapper-channels.sh` -- verify wrapper correctly injects channel flags when CLAUDE_CHANNELS is set

*Existing `test/test-restart.sh` partially covers ORCH-03 (--instance flag).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| One-shot dispatch via `claude -p` | ORCH-02 | Requires live Claude session with API key | Start orchestra, send work request, verify instrument receives and executes task |
| Dynamic instrument discovery | ORCH-04 | Requires live claude-peers broker + multiple registered instruments | Start broker, register 2+ instruments, verify `list_peers` returns all, add/remove instrument, verify orchestra sees change |
| Message routing to correct instrument | ORCH-05 | Requires live claude-peers + multiple instruments with different projects | Start 2+ instruments with different project dirs, send project-specific task, verify correct instrument receives it |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
