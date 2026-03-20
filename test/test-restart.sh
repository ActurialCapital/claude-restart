#!/bin/bash
# Test suite for claude-restart
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESTART_SCRIPT="$SCRIPT_DIR/../bin/claude-restart"
PASS=0
FAIL=0
TOTAL=0

# Setup
TMPDIR=$(mktemp -d)
RESTART_FILE="$TMPDIR/restart-signal"

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected: '$expected', got: '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected to contain: '$needle', got: '$haystack')"
        FAIL=$((FAIL + 1))
    fi
}

# Use env var to override restart file path (same as wrapper)
export CLAUDE_RESTART_FILE="$RESTART_FILE"

# --- Test 1: With args writes args to restart file ---
echo "Test 1: With args writes args to restart file"
rm -f "$RESTART_FILE"
export CLAUDE_RESTART_TARGET_PID="99999"  # skip real kill
output=$(bash "$RESTART_SCRIPT" --model sonnet 2>&1) || true
file_content=$(cat "$RESTART_FILE" 2>/dev/null || echo "FILE_NOT_FOUND")
assert_eq "restart file contains args" "--model sonnet" "$file_content"

# --- Test 2: With multiple args writes all args to restart file ---
echo "Test 2: Multiple args written correctly"
rm -f "$RESTART_FILE"
output=$(bash "$RESTART_SCRIPT" --model sonnet --verbose 2>&1) || true
file_content=$(cat "$RESTART_FILE" 2>/dev/null || echo "FILE_NOT_FOUND")
assert_eq "restart file contains all args" "--model sonnet --verbose" "$file_content"

# --- Test 3: No args with CLAUDE_RESTART_DEFAULT_OPTS set ---
echo "Test 3: No args uses CLAUDE_RESTART_DEFAULT_OPTS"
rm -f "$RESTART_FILE"
export CLAUDE_RESTART_DEFAULT_OPTS="--dangerously-skip-permissions"
output=$(bash "$RESTART_SCRIPT" 2>&1) || true
file_content=$(cat "$RESTART_FILE" 2>/dev/null || echo "FILE_NOT_FOUND")
assert_eq "restart file contains default opts" "--dangerously-skip-permissions" "$file_content"
unset CLAUDE_RESTART_DEFAULT_OPTS

# --- Test 4: No args, no default env var writes empty file ---
echo "Test 4: No args, no defaults writes empty file"
rm -f "$RESTART_FILE"
unset CLAUDE_RESTART_DEFAULT_OPTS 2>/dev/null || true
output=$(bash "$RESTART_SCRIPT" 2>&1) || true
assert_eq "restart file exists" "true" "$(test -f "$RESTART_FILE" && echo true || echo false)"
file_content=$(cat "$RESTART_FILE" 2>/dev/null || echo "FILE_NOT_FOUND")
assert_eq "restart file is empty" "" "$file_content"

# --- Test 5: PPID walk finds and kills target process ---
echo "Test 5: Kills target process via CLAUDE_RESTART_TARGET_PID"
rm -f "$RESTART_FILE"
# Start a background process to kill
sleep 999 &
SLEEP_PID=$!
export CLAUDE_RESTART_TARGET_PID="$SLEEP_PID"
output=$(bash "$RESTART_SCRIPT" --test 2>&1) || true
# Give kill a moment to propagate
sleep 0.1
alive="true"
kill -0 "$SLEEP_PID" 2>/dev/null || alive="false"
assert_eq "target process was killed" "false" "$alive"

# --- Test 6: PID not found writes file anyway with warning ---
echo "Test 6: PID not found - graceful degradation"
rm -f "$RESTART_FILE"
unset CLAUDE_RESTART_TARGET_PID
# Ensure no actual claude process is in our PPID chain
output=$(bash "$RESTART_SCRIPT" --fallback-test 2>&1) || true
assert_eq "restart file still written" "true" "$(test -f "$RESTART_FILE" && echo true || echo false)"
file_content=$(cat "$RESTART_FILE" 2>/dev/null || echo "FILE_NOT_FOUND")
assert_eq "restart file has correct content" "--fallback-test" "$file_content"
assert_contains "warning printed" "warning" "$output"

# --- Test 7: Confirmation message printed to stdout ---
echo "Test 7: Confirmation message printed"
rm -f "$RESTART_FILE"
export CLAUDE_RESTART_TARGET_PID="99999"
output=$(bash "$RESTART_SCRIPT" --model sonnet 2>&1) || true
assert_contains "prints restart confirmation" "Restarting claude with: --model sonnet" "$output"
# Also test no-args message
rm -f "$RESTART_FILE"
unset CLAUDE_RESTART_DEFAULT_OPTS 2>/dev/null || true
output=$(bash "$RESTART_SCRIPT" 2>&1) || true
assert_contains "prints generic restart message" "Restarting claude" "$output"

# --- Test 8: CLAUDE_RESTART_FILE env var overrides default path ---
echo "Test 8: CLAUDE_RESTART_FILE overrides default path"
CUSTOM_FILE="$TMPDIR/custom-restart-file"
rm -f "$CUSTOM_FILE"
export CLAUDE_RESTART_FILE="$CUSTOM_FILE"
output=$(bash "$RESTART_SCRIPT" --custom-path 2>&1) || true
assert_eq "custom restart file created" "true" "$(test -f "$CUSTOM_FILE" && echo true || echo false)"
file_content=$(cat "$CUSTOM_FILE" 2>/dev/null || echo "FILE_NOT_FOUND")
assert_eq "custom file has correct content" "--custom-path" "$file_content"
# Restore for any remaining tests
export CLAUDE_RESTART_FILE="$RESTART_FILE"

# --- Summary ---
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
