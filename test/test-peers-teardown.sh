#!/bin/bash
# Validation tests for Phase 12: Peers Teardown (CLNP-01 through CLNP-05)
# Verifies all claude-peers infrastructure has been removed from the codebase.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Phase 12: Peers Teardown Validation ==="
echo ""

# ---------------------------------------------------------------------------
# CLNP-01: Remove claude-peers MCP server config from instruments and orchestra
# ---------------------------------------------------------------------------
echo "--- CLNP-01: claude-peers MCP server config removed ---"

# Test: claude-service does not provision .mcp.json with claude-peers
if grep -q 'mcp_json\|mcpServers\|claude-peers' "$SCRIPT_DIR/bin/claude-service" 2>/dev/null; then
    fail "CLNP-01: claude-service still references .mcp.json / mcpServers / claude-peers"
else
    pass "CLNP-01: claude-service has no .mcp.json or claude-peers provisioning"
fi

# Test: No .mcp.json files exist in the repository
mcp_count=$(find "$SCRIPT_DIR" -name ".mcp.json" -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$mcp_count" -eq 0 ]]; then
    pass "CLNP-01: no .mcp.json files in repository"
else
    fail "CLNP-01: found $mcp_count .mcp.json file(s) in repository"
fi

# ---------------------------------------------------------------------------
# CLNP-02: Remove CLAUDE_CHANNELS env var from env files and env.template
# ---------------------------------------------------------------------------
echo ""
echo "--- CLNP-02: CLAUDE_CHANNELS env var removed ---"

# Test: env.template has no CLAUDE_CHANNELS
if grep -q 'CLAUDE_CHANNELS' "$SCRIPT_DIR/systemd/env.template" 2>/dev/null; then
    fail "CLNP-02: env.template still contains CLAUDE_CHANNELS"
else
    pass "CLNP-02: env.template has no CLAUDE_CHANNELS"
fi

# Test: claude-wrapper has no CLAUDE_CHANNELS
if grep -q 'CLAUDE_CHANNELS' "$SCRIPT_DIR/bin/claude-wrapper" 2>/dev/null; then
    fail "CLNP-02: claude-wrapper still references CLAUDE_CHANNELS"
else
    pass "CLNP-02: claude-wrapper has no CLAUDE_CHANNELS references"
fi

# Test: claude-service has no CLAUDE_CHANNELS
if grep -q 'CLAUDE_CHANNELS' "$SCRIPT_DIR/bin/claude-service" 2>/dev/null; then
    fail "CLNP-02: claude-service still references CLAUDE_CHANNELS"
else
    pass "CLNP-02: claude-service has no CLAUDE_CHANNELS references"
fi

# Test: install.sh has no CLAUDE_CHANNELS
if grep -q 'CLAUDE_CHANNELS' "$SCRIPT_DIR/bin/install.sh" 2>/dev/null; then
    fail "CLNP-02: install.sh still references CLAUDE_CHANNELS"
else
    pass "CLNP-02: install.sh has no CLAUDE_CHANNELS references"
fi

# ---------------------------------------------------------------------------
# CLNP-03: Remove --dangerously-load-development-channels flag from claude-wrapper
# ---------------------------------------------------------------------------
echo ""
echo "--- CLNP-03: --dangerously-load-development-channels removed ---"

# Test: claude-wrapper has no dangerously-load-development-channels
if grep -q 'dangerously-load-development-channels' "$SCRIPT_DIR/bin/claude-wrapper" 2>/dev/null; then
    fail "CLNP-03: claude-wrapper still has --dangerously-load-development-channels"
else
    pass "CLNP-03: claude-wrapper has no --dangerously-load-development-channels flag"
fi

# Test: no channel_args variable in claude-wrapper
if grep -q 'channel_args' "$SCRIPT_DIR/bin/claude-wrapper" 2>/dev/null; then
    fail "CLNP-03: claude-wrapper still has channel_args variable"
else
    pass "CLNP-03: claude-wrapper has no channel_args variable"
fi

# Test: claude command invocations use only mode_args and current_args (not echo/print lines)
claude_invocations=$(grep -c '^\s*claude "\${mode_args' "$SCRIPT_DIR/bin/claude-wrapper" || true)
if [[ "$claude_invocations" -eq 3 ]]; then
    pass "CLNP-03: exactly 3 claude command invocations use mode_args + current_args (no channel injection)"
else
    fail "CLNP-03: expected 3 claude command invocations with mode_args+current_args, found $claude_invocations"
fi

# ---------------------------------------------------------------------------
# CLNP-04: Remove message-watcher sidecar from claude-wrapper
# ---------------------------------------------------------------------------
echo ""
echo "--- CLNP-04: message-watcher sidecar removed ---"

# Test: bin/message-watcher file does not exist
if [[ ! -f "$SCRIPT_DIR/bin/message-watcher" ]]; then
    pass "CLNP-04: bin/message-watcher does not exist"
else
    fail "CLNP-04: bin/message-watcher still exists"
fi

# Test: claude-wrapper has no message-watcher references
if grep -q 'message.watcher\|watcher_pid\|stop_watcher\|MESSAGE_WATCHER' "$SCRIPT_DIR/bin/claude-wrapper" 2>/dev/null; then
    fail "CLNP-04: claude-wrapper still references message-watcher/watcher_pid/stop_watcher"
else
    pass "CLNP-04: claude-wrapper has no message-watcher sidecar references"
fi

# Test: install.sh does not deploy message-watcher
if grep -q 'message-watcher' "$SCRIPT_DIR/bin/install.sh" 2>/dev/null; then
    fail "CLNP-04: install.sh still references message-watcher"
else
    pass "CLNP-04: install.sh does not deploy message-watcher"
fi

# Test: test-wrapper-channels.sh (peers-only test file) is deleted
if [[ ! -f "$SCRIPT_DIR/test/test-wrapper-channels.sh" ]]; then
    pass "CLNP-04: test-wrapper-channels.sh has been deleted"
else
    fail "CLNP-04: test-wrapper-channels.sh still exists"
fi

# ---------------------------------------------------------------------------
# CLNP-05: Remove claude-peers broker startup/dependency from systemd services
# ---------------------------------------------------------------------------
echo ""
echo "--- CLNP-05: claude-peers broker dependencies removed ---"

# Test: no broker references in install.sh
if grep -q 'claude-peers\|broker' "$SCRIPT_DIR/bin/install.sh" 2>/dev/null; then
    fail "CLNP-05: install.sh still references claude-peers or broker"
else
    pass "CLNP-05: install.sh has no claude-peers/broker references"
fi

# Test: no broker references in claude-service
if grep -q 'claude-peers\|broker' "$SCRIPT_DIR/bin/claude-service" 2>/dev/null; then
    fail "CLNP-05: claude-service still references claude-peers or broker"
else
    pass "CLNP-05: claude-service has no claude-peers/broker references"
fi

# Test: no broker references in env.template
if grep -q 'claude-peers\|broker' "$SCRIPT_DIR/systemd/env.template" 2>/dev/null; then
    fail "CLNP-05: env.template still references claude-peers or broker"
else
    pass "CLNP-05: env.template has no claude-peers/broker references"
fi

# Test: systemd template has no peers-related After/Requires directives
for tmpl in "$SCRIPT_DIR"/systemd/*.service "$SCRIPT_DIR"/systemd/*.service.template; do
    [[ -f "$tmpl" ]] || continue
    if grep -q 'claude-peers\|broker' "$tmpl" 2>/dev/null; then
        fail "CLNP-05: $(basename "$tmpl") still references claude-peers/broker"
    fi
done
pass "CLNP-05: systemd templates have no claude-peers/broker dependencies"

# ---------------------------------------------------------------------------
# Cross-cutting: bash syntax validity of all modified files
# ---------------------------------------------------------------------------
echo ""
echo "--- Syntax validation ---"

for script in bin/claude-wrapper bin/install.sh bin/claude-service; do
    if bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
        pass "bash syntax valid: $script"
    else
        fail "bash syntax invalid: $script"
    fi
done

# ---------------------------------------------------------------------------
# Cross-cutting: existing test suite still passes
# ---------------------------------------------------------------------------
echo ""
echo "--- Regression: test-orchestra.sh ---"

if bash "$SCRIPT_DIR/test/test-orchestra.sh" >/dev/null 2>&1; then
    pass "test-orchestra.sh passes (no regressions)"
else
    fail "test-orchestra.sh has failures"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All Phase 12 validation tests passed!"
