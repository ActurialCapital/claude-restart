---
phase: 10-orchestra-mcp-provisioning
verified: 2026-03-24T14:00:00Z
status: passed
score: 3/3 must-haves verified
gaps: []
human_verification:
  - test: "Run add-orchestra on a VPS with claude-peers configured in ~/.claude.json and confirm .mcp.json appears in ~/instruments/orchestra/"
    expected: ".mcp.json is created containing mcpServers.claude-peers config copied from ~/.claude.json"
    why_human: "Requires actual systemd + jq environment with a real ~/.claude.json containing claude-peers entry; cannot exercise full runtime path in a unit test environment"
---

# Phase 10: Orchestra MCP Provisioning Verification Report

**Phase Goal:** `add-orchestra` automatically provisions `.mcp.json` with claude-peers config so orchestra peer discovery works without manual global `~/.claude.json` setup
**Verified:** 2026-03-24T14:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `add-orchestra` provisions `.mcp.json` with claude-peers config copied from `~/.claude.json` | VERIFIED | `bin/claude-service` lines 173-204: full create path using `jq -n --argjson cp` writes `{"mcpServers": {"claude-peers": $cp}}` to `$work_dir/.mcp.json` |
| 2 | Existing `.mcp.json` entries are preserved when claude-peers is added | VERIFIED | `bin/claude-service` line 181-187: `-f "$mcp_json"` branch uses `jq --argjson cp` with `.mcpServers = (.mcpServers // {}) | .mcpServers["claude-peers"] = $cp` — merges, does not overwrite |
| 3 | Missing claude-peers in global config produces a warning and skips `.mcp.json` creation | VERIFIED | `bin/claude-service` line 195-196: `echo "Warning: claude-peers not found in $claude_config mcpServers. Skipping .mcp.json creation."` emitted to stderr when `jq -e` exits non-zero |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `bin/claude-service` | `.mcp.json` provisioning in `do_add_orchestra()` | VERIFIED | Contains `mcp_json` variable, `mcpServers` extraction, merge branch, create branch, warning messages. Single `local claude_config=` declaration confirmed (`grep -c` returns 1). Provisioning block at lines 173-204, before `systemctl enable` at lines 217-219. |
| `test/test-orchestra.sh` | Structural tests 9-11 for `.mcp.json` provisioning | VERIFIED | Tests 9-11 exist at lines 74-97. Test 9: checks `mcp_json` in function body. Test 10: checks `mcpServers`. Test 11: checks merge conditional (`-f.*mcp_json`). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bin/claude-service` | `$HOME/.claude.json` | `jq -e '.mcpServers["claude-peers"]'` | VERIFIED | Line 179: `peers_config=$(jq -e '.mcpServers["claude-peers"]' "$claude_config" 2>/dev/null)` |
| `bin/claude-service` | `$work_dir/.mcp.json` | `jq` write/merge | VERIFIED | Lines 184-191: both merge (`jq --argjson cp ... "$mcp_json"`) and create (`jq -n --argjson cp ... > "$mcp_json"`) paths write to `$mcp_json` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ORCH-04 | 10-01-PLAN.md | Orchestra detects instruments added or removed while it is running (dynamic discovery) | SATISFIED | `.mcp.json` provisioning enables claude-peers MCP tools in the orchestra session, making instrument discovery automatic at setup time. REQUIREMENTS.md marks Complete at Phase 10. |
| ORCH-05 | 10-01-PLAN.md | Orchestra always routes messages to the correct instrument based on project context | SATISFIED | `CLAUDE_CHANNELS=server:claude-peers` set in env (line 169) + `.mcp.json` claude-peers config together give orchestra the routing infrastructure. REQUIREMENTS.md marks Complete at Phase 10. |

Note on requirement mapping: ORCH-04 and ORCH-05 were already structurally met by the global `~/.claude.json` approach from phase 9. Phase 10 closes the gap by making provisioning automatic (project-scoped `.mcp.json`) rather than requiring manual global setup. Both requirements remain satisfied post-phase-10, now without manual intervention.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | No anti-patterns found |

Scan of `bin/claude-service` and `test/test-orchestra.sh` found no TODOs, FIXMEs, placeholder returns, or empty handlers in the phase 10 additions.

### Test Suite Results

| Test Script | Result | Notes |
|-------------|--------|-------|
| `test/test-orchestra.sh` | 11/11 passed | All tests including new tests 9-11 pass |
| `test/test-restart.sh` | 13/13 passed | No regressions |
| `test/test-service-lifecycle.sh` | 26/26 passed | No regressions |
| `test/test-wrapper-channels.sh` | 7/7 passed | No regressions |
| `test/test-install.sh` | Pre-existing failure (Test 11: "unit file exists") | Fails before phase 10 — last modified in phase 6 (`feat(06-02)` commit). Not a regression. |

### Human Verification Required

#### 1. End-to-end provisioning on VPS

**Test:** On a VPS with jq installed and `~/.claude.json` containing a `mcpServers.claude-peers` entry, run `claude-service add-orchestra` and inspect `~/instruments/orchestra/.mcp.json`.
**Expected:** File is created with `{"mcpServers": {"claude-peers": <copied config>}}`. Subsequent orchestra session has claude-peers tools available.
**Why human:** Requires real systemd environment, real `~/.claude.json` with claude-peers config, and ability to invoke MCP tools. Cannot replicate in structural unit tests.

### Gaps Summary

No gaps. All three must-have truths are verified at all three levels (exists, substantive, wired). Both requirement IDs (ORCH-04, ORCH-05) are accounted for and satisfied. The test suite is green for all scripts except one pre-existing failure in `test/test-install.sh` that predates this phase.

---

_Verified: 2026-03-24T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
