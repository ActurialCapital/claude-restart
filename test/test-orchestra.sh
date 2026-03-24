#!/bin/bash
# Test: claude-service add-orchestra subcommand
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE="$SCRIPT_DIR/bin/claude-service"
TEMPLATE="$SCRIPT_DIR/systemd/env.template"
PASS=0; FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Orchestra Registration Tests ==="

# Test 1: claude-service contains add-orchestra subcommand
if grep -q 'add-orchestra)' "$SERVICE"; then
    pass "claude-service has add-orchestra case"
else
    fail "claude-service missing add-orchestra case"
fi

# Test 2: do_add_orchestra function exists
if grep -q 'do_add_orchestra()' "$SERVICE"; then
    pass "do_add_orchestra function exists"
else
    fail "do_add_orchestra function missing"
fi

# Extract do_add_orchestra function body for targeted tests
FUNC_BODY=$(sed -n '/^do_add_orchestra()/,/^}/p' "$SERVICE")

# Test 3: add-orchestra does NOT git clone (as a command, comments don't count)
if echo "$FUNC_BODY" | grep -v '^[[:space:]]*#' | grep -q 'git clone'; then
    fail "do_add_orchestra should not git clone"
else
    pass "do_add_orchestra does not git clone"
fi

# Test 4: add-orchestra creates instruments/orchestra via mkdir
if echo "$FUNC_BODY" | grep -q 'mkdir -p'; then
    pass "do_add_orchestra creates working directory via mkdir"
else
    fail "do_add_orchestra missing mkdir for working directory"
fi

# Test 5: add-orchestra sets CLAUDE_CHANNELS=server:claude-peers
if echo "$FUNC_BODY" | grep -q 'CLAUDE_CHANNELS=server:claude-peers'; then
    pass "do_add_orchestra sets CLAUDE_CHANNELS=server:claude-peers"
else
    fail "do_add_orchestra missing CLAUDE_CHANNELS=server:claude-peers"
fi

# Test 6: add-orchestra enables claude@orchestra.service
if echo "$FUNC_BODY" | grep -q 'claude@${name}.service'; then
    pass "do_add_orchestra enables claude@orchestra.service"
else
    fail "do_add_orchestra missing systemd enable"
fi

# Test 7: usage function mentions add-orchestra
if grep -A 30 'usage()' "$SERVICE" | grep -q 'add-orchestra'; then
    pass "usage lists add-orchestra"
else
    fail "usage missing add-orchestra"
fi

# Test 8: add-orchestra prints CLAUDE.md guidance
if echo "$FUNC_BODY" | grep -q 'CLAUDE.md'; then
    pass "do_add_orchestra mentions CLAUDE.md placement"
else
    fail "do_add_orchestra missing CLAUDE.md guidance"
fi

# Test 9: add-orchestra provisions .mcp.json
if echo "$FUNC_BODY" | grep -q 'mcp_json'; then
    pass "do_add_orchestra provisions .mcp.json"
else
    fail "do_add_orchestra missing .mcp.json provisioning"
fi

# Test 10: add-orchestra reads mcpServers from global config
if echo "$FUNC_BODY" | grep -q 'mcpServers'; then
    pass "do_add_orchestra reads mcpServers from global config"
else
    fail "do_add_orchestra missing mcpServers extraction"
fi

# Test 11: add-orchestra handles existing .mcp.json (merge case)
if echo "$FUNC_BODY" | grep -q 'mcp_json'; then
    # Check for conditional logic around existing file
    if echo "$FUNC_BODY" | grep -q '\-f.*mcp_json\|mcp_json.*-f'; then
        pass "do_add_orchestra handles existing .mcp.json merge"
    else
        fail "do_add_orchestra missing .mcp.json merge handling"
    fi
else
    fail "do_add_orchestra missing .mcp.json provisioning entirely"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
