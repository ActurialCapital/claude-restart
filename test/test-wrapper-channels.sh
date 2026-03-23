#!/bin/bash
# Test: claude-wrapper channel flag injection
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$SCRIPT_DIR/bin/claude-wrapper"
TEMPLATE="$SCRIPT_DIR/systemd/env.template"
PASS=0; FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Wrapper Channel Flag Tests ==="

# Test 1: env.template contains CLAUDE_CHANNELS
if grep -q '^CLAUDE_CHANNELS=' "$TEMPLATE"; then
    pass "env.template contains CLAUDE_CHANNELS"
else
    fail "env.template missing CLAUDE_CHANNELS"
fi

# Test 2: env.template PATH includes .bun/bin
if grep '^PATH=' "$TEMPLATE" | grep -q '\.bun/bin'; then
    pass "env.template PATH includes .bun/bin"
else
    fail "env.template PATH missing .bun/bin"
fi

# Test 3: wrapper contains channel_args logic
if grep -q 'channel_args=()' "$WRAPPER"; then
    pass "wrapper initializes channel_args"
else
    fail "wrapper missing channel_args initialization"
fi

# Test 4: wrapper references --dangerously-load-development-channels
if grep -q '\-\-dangerously-load-development-channels' "$WRAPPER"; then
    pass "wrapper contains --dangerously-load-development-channels"
else
    fail "wrapper missing --dangerously-load-development-channels"
fi

# Test 5: wrapper passes channel_args in claude invocations
INVOCATIONS=$(grep -c 'channel_args\[@\]' "$WRAPPER")
if [[ "$INVOCATIONS" -ge 2 ]]; then
    pass "wrapper passes channel_args in $INVOCATIONS claude invocations"
else
    fail "wrapper passes channel_args in only $INVOCATIONS invocations (expected >= 2)"
fi

# Test 6: channel_args only set when CLAUDE_CHANNELS is non-empty
if grep -q 'if \[\[ -n "${CLAUDE_CHANNELS:-}" \]\]' "$WRAPPER"; then
    pass "wrapper guards channel_args on non-empty CLAUDE_CHANNELS"
else
    fail "wrapper missing CLAUDE_CHANNELS guard"
fi

# Test 7: channel_args appears before mode_args in all invocations (regression for UAT blocker)
BAD_ORDER=$(grep 'claude "\${' "$WRAPPER" | grep -v '^\s*#' | grep -c 'mode_args.*channel_args' || true)
if [[ "$BAD_ORDER" -eq 0 ]]; then
    pass "channel_args before mode_args in all invocations (argument order)"
else
    fail "found $BAD_ORDER invocations with mode_args before channel_args"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
