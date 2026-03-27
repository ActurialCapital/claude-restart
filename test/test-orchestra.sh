#!/bin/bash
# Test: orchestra CLAUDE.md dispatch patterns and claude-service add-orchestra subcommand
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE="$SCRIPT_DIR/bin/claude-service"
TEMPLATE="$SCRIPT_DIR/systemd/env.template"
CLAUDE_MD="$SCRIPT_DIR/orchestra/CLAUDE.md"
PASS=0; FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Orchestra CLAUDE.md Dispatch Tests ==="

# Test 1: CLAUDE.md exists
if [[ -f "$CLAUDE_MD" ]]; then
    pass "orchestra CLAUDE.md exists"
else
    fail "orchestra CLAUDE.md missing"
fi

# Test 2: Contains claude -p dispatch pattern
if grep -q 'claude -p' "$CLAUDE_MD"; then
    pass "contains claude -p dispatch pattern"
else
    fail "missing claude -p dispatch pattern"
fi

# Test 3: Contains --dangerously-skip-permissions
if grep -q '\-\-dangerously-skip-permissions' "$CLAUDE_MD"; then
    pass "contains --dangerously-skip-permissions flag"
else
    fail "missing --dangerously-skip-permissions flag"
fi

# Test 4: Contains parallel dispatch with backgrounding
if grep -q '&' "$CLAUDE_MD" && grep -qi 'parallel' "$CLAUDE_MD"; then
    pass "contains parallel dispatch with backgrounding"
else
    fail "missing parallel dispatch pattern"
fi

# Test 5: Contains --continue for multi-step sequences
if grep -q '\-\-continue\|-c -p' "$CLAUDE_MD"; then
    pass "contains --continue for continuation"
else
    fail "missing --continue pattern"
fi

# Test 6: Contains fleet discovery via claude-service list
if grep -q 'claude-service list' "$CLAUDE_MD"; then
    pass "contains fleet discovery via claude-service list"
else
    fail "missing claude-service list"
fi

# Test 7: Contains escalation protocol
if grep -q '\[.*/..*\]' "$CLAUDE_MD" && grep -qi 'escalat' "$CLAUDE_MD"; then
    pass "contains escalation protocol with tagged format"
else
    fail "missing escalation protocol"
fi

# Test 8: No peer messaging references (send_message)
if ! grep -q 'send_message' "$CLAUDE_MD"; then
    pass "no send_message references"
else
    fail "still contains send_message"
fi

# Test 9: No peer messaging references (check_messages)
if ! grep -q 'check_messages' "$CLAUDE_MD"; then
    pass "no check_messages references"
else
    fail "still contains check_messages"
fi

# Test 10: No peer messaging references (list_peers)
if ! grep -q 'list_peers' "$CLAUDE_MD"; then
    pass "no list_peers references"
else
    fail "still contains list_peers"
fi

# Test 11: Contains context reset pattern
if grep -q 'claude-restart --instance' "$CLAUDE_MD"; then
    pass "contains context reset via claude-restart"
else
    fail "missing claude-restart --instance pattern"
fi

# Test 12: Contains long-running task handling
if grep -qi 'long.running\|max-turns' "$CLAUDE_MD"; then
    pass "contains long-running task handling"
else
    fail "missing long-running task guidance"
fi

echo ""

echo "=== Orchestra Registration Tests ==="

# Test 13: claude-service contains add-orchestra subcommand
if grep -q 'add-orchestra)' "$SERVICE"; then
    pass "claude-service has add-orchestra case"
else
    fail "claude-service missing add-orchestra case"
fi

# Test 14: do_add_orchestra function exists
if grep -q 'do_add_orchestra()' "$SERVICE"; then
    pass "do_add_orchestra function exists"
else
    fail "do_add_orchestra function missing"
fi

# Extract do_add_orchestra function body for targeted tests
FUNC_BODY=$(sed -n '/^do_add_orchestra()/,/^}/p' "$SERVICE")

# Test 15: add-orchestra does NOT git clone (as a command, comments don't count)
if echo "$FUNC_BODY" | grep -v '^[[:space:]]*#' | grep -q 'git clone'; then
    fail "do_add_orchestra should not git clone"
else
    pass "do_add_orchestra does not git clone"
fi

# Test 16: add-orchestra creates instruments/orchestra via mkdir
if echo "$FUNC_BODY" | grep -q 'mkdir -p'; then
    pass "do_add_orchestra creates working directory via mkdir"
else
    fail "do_add_orchestra missing mkdir for working directory"
fi

# Test 17: add-orchestra enables claude@orchestra.service
if echo "$FUNC_BODY" | grep -q 'claude@${name}.service'; then
    pass "do_add_orchestra enables claude@orchestra.service"
else
    fail "do_add_orchestra missing systemd enable"
fi

# Test 18: usage function mentions add-orchestra
if grep -A 30 'usage()' "$SERVICE" | grep -q 'add-orchestra'; then
    pass "usage lists add-orchestra"
else
    fail "usage missing add-orchestra"
fi

# Test 19: add-orchestra deploys CLAUDE.md (not just mentions it)
if echo "$FUNC_BODY" | grep -v '^[[:space:]]*#' | grep -q 'Deployed orchestra CLAUDE.md'; then
    pass "do_add_orchestra deploys CLAUDE.md"
else
    fail "do_add_orchestra missing CLAUDE.md deployment"
fi

# Test 20: add-orchestra copies orchestra/CLAUDE.md to working directory
if echo "$FUNC_BODY" | grep -v '^[[:space:]]*#' | grep -q 'cp.*claude_md_src.*CLAUDE.md'; then
    pass "do_add_orchestra copies CLAUDE.md to working directory"
else
    fail "do_add_orchestra missing CLAUDE.md copy"
fi

# Test 21: add-orchestra fails if orchestra/CLAUDE.md source is missing
if echo "$FUNC_BODY" | grep -q 'claude_md_src' && echo "$FUNC_BODY" | grep -q 'exit 1'; then
    pass "do_add_orchestra fails when source CLAUDE.md missing"
else
    fail "do_add_orchestra missing CLAUDE.md existence check"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
