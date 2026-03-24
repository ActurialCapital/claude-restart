---
phase: 10
slug: orchestra-mcp-provisioning
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test scripts (project convention) |
| **Config file** | None — standalone scripts in `test/` |
| **Quick run command** | `bash test/test-orchestra.sh` |
| **Full suite command** | `for f in test/test-*.sh; do bash "$f"; done` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash test/test-orchestra.sh`
- **After every plan wave:** Run `for f in test/test-*.sh; do bash "$f"; done`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | ORCH-04 | unit (structural) | `bash test/test-orchestra.sh` | Partial — needs new tests 9-11 | ⬜ pending |
| 10-01-02 | 01 | 1 | ORCH-05 | unit (structural) | `bash test/test-orchestra.sh` | Partial — needs new tests 9-11 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add test 9 to `test/test-orchestra.sh` — `do_add_orchestra` references `.mcp.json` (grep for mcp_json or .mcp.json in function body)
- [ ] Add test 10 to `test/test-orchestra.sh` — `do_add_orchestra` reads mcpServers from claude_config (grep for mcpServers in function body)
- [ ] Add test 11 to `test/test-orchestra.sh` — `do_add_orchestra` handles merge case (grep for existing .mcp.json check in function body)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| MCP server approval in remote-control mode | ORCH-04, ORCH-05 | Requires running Claude Code on VPS with remote-control mode | 1. Deploy to VPS 2. Run `add-orchestra` 3. Start orchestra session 4. Verify claude-peers tools are available without manual approval |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
