#!/bin/bash
# Test suite for claude-wrapper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="$SCRIPT_DIR/../bin/claude-wrapper"
RESTART_FILE="$HOME/.claude-restart"
PASS=0
FAIL=0
TOTAL=0

# Setup
TMPDIR=$(mktemp -d)
MOCK_CLAUDE="$TMPDIR/claude"
LOG="$TMPDIR/invocations.log"

cleanup() {
    rm -rf "$TMPDIR"
    rm -f "$RESTART_FILE"
}
trap cleanup EXIT

# Create mock claude that logs its args and exits
create_mock() {
    local exit_code="${1:-0}"
    cat > "$MOCK_CLAUDE" << MOCKEOF
#!/bin/bash
echo "\$@" >> "$LOG"
exit $exit_code
MOCKEOF
    chmod +x "$MOCK_CLAUDE"
}

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

# Prepend mock dir to PATH
export PATH="$TMPDIR:$PATH"

# --- Test 1: Normal exit without restart file ---
echo "Test 1: Normal exit (no restart file)"
rm -f "$RESTART_FILE" "$LOG"
create_mock 0
output=$("$WRAPPER" --foo --bar 2>&1)
exit_code=$?
assert_eq "exits 0" "0" "$exit_code"
assert_eq "passes args to claude" "--foo --bar" "$(cat "$LOG")"

# --- Test 2: One restart then exit ---
echo "Test 2: Restart with new options then exit"
rm -f "$LOG"
# Mock that creates restart file on first call, then exits clean on second
cat > "$MOCK_CLAUDE" << 'MOCKEOF'
#!/bin/bash
echo "$@" >> LOGFILE
CALL_COUNT=$(wc -l < LOGFILE)
if [[ $CALL_COUNT -eq 1 ]]; then
    echo "--model sonnet" > RESTARTFILE
fi
exit 0
MOCKEOF
sed -i '' "s|LOGFILE|$LOG|g" "$MOCK_CLAUDE"
sed -i '' "s|RESTARTFILE|$RESTART_FILE|g" "$MOCK_CLAUDE"
chmod +x "$MOCK_CLAUDE"

output=$("$WRAPPER" --initial-opt 2>&1)
exit_code=$?
assert_eq "exits 0 after restart cycle" "0" "$exit_code"
# First call should have --initial-opt, second should have --model sonnet
first_call=$(sed -n '1p' "$LOG")
second_call=$(sed -n '2p' "$LOG")
assert_eq "first call gets initial args" "--initial-opt" "$first_call"
assert_eq "second call gets restart file args" "--model sonnet" "$second_call"
assert_contains "prints restart message" "Restarting claude" "$output"

# --- Test 3: Empty restart file = restart with original args ---
echo "Test 3: Empty restart file uses original args"
rm -f "$LOG"
cat > "$MOCK_CLAUDE" << 'MOCKEOF'
#!/bin/bash
echo "$@" >> LOGFILE
CALL_COUNT=$(wc -l < LOGFILE)
if [[ $CALL_COUNT -eq 1 ]]; then
    touch RESTARTFILE
fi
exit 0
MOCKEOF
sed -i '' "s|LOGFILE|$LOG|g" "$MOCK_CLAUDE"
sed -i '' "s|RESTARTFILE|$RESTART_FILE|g" "$MOCK_CLAUDE"
chmod +x "$MOCK_CLAUDE"

output=$("$WRAPPER" --original-flag 2>&1)
first_call=$(sed -n '1p' "$LOG")
second_call=$(sed -n '2p' "$LOG")
assert_eq "first call gets original args" "--original-flag" "$first_call"
assert_eq "second call also gets original args" "--original-flag" "$second_call"

# --- Test 4: Claude exit code preserved on normal exit ---
echo "Test 4: Exit code preserved"
rm -f "$LOG" "$RESTART_FILE"
create_mock 42
"$WRAPPER" 2>&1 || true
# Run again capturing exit code
rm -f "$LOG"
create_mock 42
"$WRAPPER" 2>&1
exit_code=$?
assert_eq "preserves claude exit code" "42" "$exit_code"

# --- Test 5: Max restarts safety valve ---
echo "Test 5: Max restarts (10) triggers exit"
rm -f "$LOG"
# Mock that always creates restart file
cat > "$MOCK_CLAUDE" << 'MOCKEOF'
#!/bin/bash
echo "$@" >> LOGFILE
echo "" > RESTARTFILE
exit 0
MOCKEOF
sed -i '' "s|LOGFILE|$LOG|g" "$MOCK_CLAUDE"
sed -i '' "s|RESTARTFILE|$RESTART_FILE|g" "$MOCK_CLAUDE"
chmod +x "$MOCK_CLAUDE"

output=$("$WRAPPER" 2>&1)
exit_code=$?
call_count=$(wc -l < "$LOG" | tr -d ' ')
assert_eq "ran claude 11 times (initial + 10 restarts)" "11" "$call_count"
assert_contains "prints max restart warning" "Maximum restarts" "$output"
assert_eq "exits with error code" "1" "$exit_code"

# --- Test 6: Restart file deleted after reading ---
echo "Test 6: Restart file is deleted after reading"
rm -f "$LOG"
create_mock 0
echo "--new-opt" > "$RESTART_FILE"
"$WRAPPER" 2>&1 || true
assert_eq "restart file deleted" "false" "$(test -f "$RESTART_FILE" && echo true || echo false)"

# --- Summary ---
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
