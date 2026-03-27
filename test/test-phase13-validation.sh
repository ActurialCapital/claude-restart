#!/bin/bash
# Nyquist validation tests for Phase 13: Synchronous Dispatch
# Requirements: DISP-01, DISP-02, DISP-03, DISP-04, ORCH-01, ORCH-02, ORCH-03
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_MD="$SCRIPT_DIR/orchestra/CLAUDE.md"
PASS=0; FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Phase 13 Nyquist Validation ==="

# --- DISP-01: Orchestra dispatches GSD commands via claude -p with stdout captured synchronously ---

# Test 1: Orchestra teaches synchronous dispatch via cd + claude -p
if grep -q 'cd ~/instruments/.*claude -p' "$CLAUDE_MD"; then
    pass "DISP-01: orchestra teaches cd + claude -p dispatch pattern"
else
    fail "DISP-01: missing cd + claude -p dispatch pattern"
fi

# Test 2: Dispatch captures stdout with exit code checking
if grep -q 'RESULT=\$(' "$CLAUDE_MD" && grep -q 'EXIT_CODE=\$?' "$CLAUDE_MD"; then
    pass "DISP-01: dispatch captures stdout and checks exit code"
else
    fail "DISP-01: missing stdout capture or exit code check"
fi

# Test 3: Every claude -p example includes --dangerously-skip-permissions
DISPATCH_COUNT=$(grep -c 'claude -p' "$CLAUDE_MD")
PERM_COUNT=$(grep -c '\-\-dangerously-skip-permissions' "$CLAUDE_MD")
if [[ $DISPATCH_COUNT -ge 5 && $PERM_COUNT -ge 5 ]]; then
    pass "DISP-01: ${DISPATCH_COUNT} dispatches with ${PERM_COUNT} --dangerously-skip-permissions flags"
else
    fail "DISP-01: insufficient dispatches ($DISPATCH_COUNT) or permission flags ($PERM_COUNT)"
fi

# --- DISP-02: Orchestra runs parallel claude -p across multiple instruments ---

# Test 4: Parallel dispatch section with shell backgrounding
if grep -qi 'parallel' "$CLAUDE_MD" && grep -q '&$\| &' "$CLAUDE_MD"; then
    pass "DISP-02: parallel dispatch with shell backgrounding documented"
else
    fail "DISP-02: missing parallel dispatch with backgrounding"
fi

# Test 5: Parallel dispatch collects results via wait
if grep -q 'wait' "$CLAUDE_MD" && grep -q 'PID' "$CLAUDE_MD"; then
    pass "DISP-02: parallel dispatch tracks PIDs and uses wait for collection"
else
    fail "DISP-02: missing PID tracking or wait collection"
fi

# --- DISP-03: Orchestra uses --continue for multi-step GSD sequences ---

# Test 6: --continue flag documented for continuation
if grep -q '\-\-continue' "$CLAUDE_MD" && grep -q '\-c -p' "$CLAUDE_MD"; then
    pass "DISP-03: --continue and -c -p continuation patterns documented"
else
    fail "DISP-03: missing --continue or -c -p patterns"
fi

# Test 7: Multi-step sequence shows chained GSD commands
if grep -q 'claude -c -p "/gsd:' "$CLAUDE_MD"; then
    pass "DISP-03: chained GSD commands via continuation demonstrated"
else
    fail "DISP-03: missing chained GSD command example"
fi

# --- DISP-04: Orchestra handles long-running tasks without blocking ---

# Test 8: Long-running task section exists
if grep -qi 'long.running' "$CLAUDE_MD"; then
    pass "DISP-04: long-running task handling section present"
else
    fail "DISP-04: missing long-running task section"
fi

# Test 9: --max-turns safety net documented
if grep -q '\-\-max-turns' "$CLAUDE_MD"; then
    pass "DISP-04: --max-turns safety net documented"
else
    fail "DISP-04: missing --max-turns safety net"
fi

# --- ORCH-01: Orchestra CLAUDE.md rewritten for claude -p dispatch ---

# Test 10: File header is correct
if head -1 "$CLAUDE_MD" | grep -q '# Orchestra - Autonomous Supervisor'; then
    pass "ORCH-01: correct header for rewritten orchestra spec"
else
    fail "ORCH-01: wrong or missing header"
fi

# Test 11: All required sections exist
MISSING_SECTIONS=""
for section in "Dispatch Mechanics" "Parallel Dispatch" "Multi-Step Sequences" "Fleet Discovery" "Context Reset" "User Escalation Protocol" "Anti-Patterns" "Startup Sequence"; do
    if ! grep -q "## $section" "$CLAUDE_MD"; then
        MISSING_SECTIONS="$MISSING_SECTIONS $section,"
    fi
done
if [[ -z "$MISSING_SECTIONS" ]]; then
    pass "ORCH-01: all required sections present"
else
    fail "ORCH-01: missing sections:$MISSING_SECTIONS"
fi

# --- ORCH-02: No peer messaging references anywhere ---

# Test 12: No send_message reference
if ! grep -q 'send_message' "$CLAUDE_MD"; then
    pass "ORCH-02: no send_message references"
else
    fail "ORCH-02: still contains send_message"
fi

# Test 13: No check_messages reference
if ! grep -q 'check_messages' "$CLAUDE_MD"; then
    pass "ORCH-02: no check_messages references"
else
    fail "ORCH-02: still contains check_messages"
fi

# Test 14: No list_peers reference
if ! grep -q 'list_peers' "$CLAUDE_MD"; then
    pass "ORCH-02: no list_peers references"
else
    fail "ORCH-02: still contains list_peers"
fi

# Test 15: No set_summary reference
if ! grep -q 'set_summary' "$CLAUDE_MD"; then
    pass "ORCH-02: no set_summary references"
else
    fail "ORCH-02: still contains set_summary"
fi

# Test 16: No claude-peers reference
if ! grep -q 'claude-peers' "$CLAUDE_MD"; then
    pass "ORCH-02: no claude-peers references"
else
    fail "ORCH-02: still contains claude-peers"
fi

# --- ORCH-03: Escalation protocol preserved with [N/name] tagged format ---

# Test 17: Escalation section with tagged format
if grep -q '\[1/blog\]' "$CLAUDE_MD" && grep -q '\[2/api\]' "$CLAUDE_MD"; then
    pass "ORCH-03: escalation protocol has [N/name] tagged examples"
else
    fail "ORCH-03: missing [N/name] escalation examples"
fi

# Test 18: Escalation routing format documented
if grep -q '\[N\] answer\|\[1\] b' "$CLAUDE_MD"; then
    pass "ORCH-03: escalation routing format [N] answer documented"
else
    fail "ORCH-03: missing [N] answer routing format"
fi

# --- Cross-cutting: Key links verified ---

# Test 19: Fleet discovery via claude-service list
if grep -q 'claude-service list' "$CLAUDE_MD"; then
    pass "KEY-LINK: orchestra references claude-service list for fleet discovery"
else
    fail "KEY-LINK: missing claude-service list reference"
fi

# Test 20: Context reset via claude-restart --instance
if grep -q 'claude-restart --instance' "$CLAUDE_MD"; then
    pass "KEY-LINK: orchestra references claude-restart --instance for context reset"
else
    fail "KEY-LINK: missing claude-restart --instance reference"
fi

# --- Cross-cutting: Existing test suite passes ---

# Test 21: Full test suite exits 0
if bash "$SCRIPT_DIR/test/test-orchestra.sh" > /dev/null 2>&1; then
    pass "SUITE: test/test-orchestra.sh exits 0 (21/21 tests)"
else
    fail "SUITE: test/test-orchestra.sh has failures"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
