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
# Drain stdin in background to prevent FIFO blocking in telegram mode
cat > /dev/null &
_drain_pid=\$!
echo "\$@" >> "$LOG"
kill \$_drain_pid 2>/dev/null; wait \$_drain_pid 2>/dev/null || true
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

# Speed up tests by eliminating the restart delay
export CLAUDE_WRAPPER_DELAY=0
# Prevent heartbeat from firing during short-lived tests (Test 17 overrides to 1)
export CLAUDE_WRAPPER_HEARTBEAT_INTERVAL=9999

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
exit_code=0
"$WRAPPER" 2>&1 || exit_code=$?
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

exit_code=0
output=$("$WRAPPER" 2>&1) || exit_code=$?
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

# --- Test 7: SIGTERM forwarding ---
echo "Test 7: SIGTERM forwarded to child, wrapper exits 0"
rm -f "$LOG" "$RESTART_FILE"
SIGLOG="$TMPDIR/sigterm.log"
PIDFILE="$TMPDIR/child.pid"
rm -f "$SIGLOG" "$PIDFILE"
cat > "$MOCK_CLAUDE" << MOCKEOF
#!/bin/bash
echo \$\$ > "$PIDFILE"
trap 'echo GOT_SIGTERM > "$SIGLOG"; exit 0' TERM
sleep 10 &
wait \$!
MOCKEOF
chmod +x "$MOCK_CLAUDE"

"$WRAPPER" &
wrapper_pid=$!
# Wait for mock claude to start and write its PID
for i in $(seq 1 50); do
    [[ -f "$PIDFILE" ]] && break
    sleep 0.1
done
assert_eq "child PID file created" "true" "$(test -f "$PIDFILE" && echo true || echo false)"
kill -TERM "$wrapper_pid" 2>/dev/null
wait "$wrapper_pid" 2>/dev/null
wrapper_exit=$?
assert_eq "wrapper exits 0 on SIGTERM" "0" "$wrapper_exit"
# Give a moment for signal log to be written
sleep 0.2
assert_eq "child received SIGTERM" "GOT_SIGTERM" "$(cat "$SIGLOG" 2>/dev/null || echo MISSING)"

# --- Test 8: SIGHUP ignored ---
echo "Test 8: SIGHUP ignored (wrapper survives)"
rm -f "$LOG" "$RESTART_FILE" "$PIDFILE"
HUPLOG="$TMPDIR/hup.log"
rm -f "$HUPLOG"
cat > "$MOCK_CLAUDE" << MOCKEOF
#!/bin/bash
echo \$\$ > "$PIDFILE"
sleep 10 &
wait \$!
MOCKEOF
chmod +x "$MOCK_CLAUDE"

"$WRAPPER" &
wrapper_pid=$!
for i in $(seq 1 50); do
    [[ -f "$PIDFILE" ]] && break
    sleep 0.1
done
kill -HUP "$wrapper_pid" 2>/dev/null
sleep 0.3
# Wrapper should still be running
kill -0 "$wrapper_pid" 2>/dev/null
alive=$?
assert_eq "wrapper survives SIGHUP" "0" "$alive"
# Clean up: send TERM to stop it
kill -TERM "$wrapper_pid" 2>/dev/null
wait "$wrapper_pid" 2>/dev/null || true

# --- Test 9: CLAUDE_CONNECT=remote-control ---
echo "Test 9: CLAUDE_CONNECT=remote-control prepends subcommand"
rm -f "$LOG" "$RESTART_FILE"
create_mock 0
CLAUDE_CONNECT=remote-control "$WRAPPER" --verbose 2>&1
logged_args=$(cat "$LOG")
assert_eq "remote-control mode args" "remote-control --permission-mode bypassPermissions --verbose" "$logged_args"

# --- Test 10: CLAUDE_CONNECT=telegram ---
echo "Test 10: CLAUDE_CONNECT=telegram prepends channel args"
rm -f "$LOG" "$RESTART_FILE"
create_mock 0
CLAUDE_CONNECT=telegram "$WRAPPER" 2>&1
logged_args=$(cat "$LOG")
assert_contains "telegram has --channels" "--channels" "$logged_args"
assert_contains "telegram has plugin string" "plugin:telegram@claude-plugins-official" "$logged_args"

# --- Test 11: CLAUDE_CONNECT unset (backwards compat) ---
echo "Test 11: CLAUDE_CONNECT unset uses passed args only"
rm -f "$LOG" "$RESTART_FILE"
create_mock 0
unset CLAUDE_CONNECT 2>/dev/null || true
"$WRAPPER" --foo 2>&1
logged_args=$(cat "$LOG")
assert_eq "interactive mode passes args only" "--foo" "$logged_args"

# --- Test 12: CLAUDE_CONNECT=bogus exits 1 ---
echo "Test 12: Invalid CLAUDE_CONNECT exits 1 with error"
rm -f "$LOG" "$RESTART_FILE"
create_mock 0
exit_code=0
output=$(CLAUDE_CONNECT=bogus "$WRAPPER" 2>&1) || exit_code=$?
assert_eq "invalid mode exits 1" "1" "$exit_code"
assert_contains "error mentions unknown mode" "unknown CLAUDE_CONNECT" "$output"

# --- Test 13: Mode + extra args combined ---
echo "Test 13: Mode + extra args combined correctly"
rm -f "$LOG" "$RESTART_FILE"
create_mock 0
CLAUDE_CONNECT=remote-control "$WRAPPER" --verbose --model opus 2>&1
logged_args=$(cat "$LOG")
assert_eq "mode + extra args" "remote-control --permission-mode bypassPermissions --verbose --model opus" "$logged_args"

# --- Test 14: Restart in remote-control mode preserves mode args ---
echo "Test 14: Restart in remote-control mode preserves mode args"
rm -f "$LOG" "$RESTART_FILE"
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

output=$(CLAUDE_CONNECT=remote-control "$WRAPPER" --debug 2>&1)
first_call=$(sed -n '1p' "$LOG")
second_call=$(sed -n '2p' "$LOG")
assert_eq "first call: remote-control + extra args" "remote-control --permission-mode bypassPermissions --debug" "$first_call"
assert_eq "second call: remote-control + restart args" "remote-control --permission-mode bypassPermissions --model sonnet" "$second_call"

# --- Test 15: Restart in telegram mode preserves mode args ---
echo "Test 15: Restart in telegram mode preserves mode args"
rm -f "$LOG" "$RESTART_FILE"
cat > "$MOCK_CLAUDE" << 'MOCKEOF'
#!/bin/bash
cat > /dev/null &
_drain_pid=$!
echo "$@" >> LOGFILE
CALL_COUNT=$(wc -l < LOGFILE)
if [[ $CALL_COUNT -eq 1 ]]; then
    echo "--verbose" > RESTARTFILE
fi
kill $_drain_pid 2>/dev/null; wait $_drain_pid 2>/dev/null || true
exit 0
MOCKEOF
sed -i '' "s|LOGFILE|$LOG|g" "$MOCK_CLAUDE"
sed -i '' "s|RESTARTFILE|$RESTART_FILE|g" "$MOCK_CLAUDE"
chmod +x "$MOCK_CLAUDE"

output=$(CLAUDE_CONNECT=telegram "$WRAPPER" 2>&1)
first_call=$(sed -n '1p' "$LOG")
second_call=$(sed -n '2p' "$LOG")
assert_contains "first call has channel args" "--channels plugin:telegram@claude-plugins-official" "$first_call"
assert_contains "second call has channel args" "--channels plugin:telegram@claude-plugins-official" "$second_call"
assert_contains "second call has restart extra args" "--verbose" "$second_call"

# --- Test 16: Empty restart file in mode preserves mode + original extra args ---
echo "Test 16: Empty restart file in mode preserves mode + original extra args"
rm -f "$LOG" "$RESTART_FILE"
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

output=$(CLAUDE_CONNECT=remote-control "$WRAPPER" --debug 2>&1)
first_call=$(sed -n '1p' "$LOG")
second_call=$(sed -n '2p' "$LOG")
assert_eq "first call: remote-control + debug" "remote-control --permission-mode bypassPermissions --debug" "$first_call"
assert_eq "second call: remote-control + original debug" "remote-control --permission-mode bypassPermissions --debug" "$second_call"

# --- Test 17: Heartbeat starts in telegram mode ---
echo "Test 17: Heartbeat starts in telegram mode"
rm -f "$LOG" "$RESTART_FILE"
STDERR_LOG="$TMPDIR/heartbeat_stderr.log"
rm -f "$STDERR_LOG"
# Mock claude that sleeps 3 seconds then exits
cat > "$MOCK_CLAUDE" << 'MOCKEOF'
#!/bin/bash
echo "$@" >> LOGFILE
# Read from stdin in background to keep FIFO consumer alive
cat > /dev/null &
CAT_PID=$!
sleep 3
kill $CAT_PID 2>/dev/null; wait $CAT_PID 2>/dev/null || true
exit 0
MOCKEOF
sed -i '' "s|LOGFILE|$LOG|g" "$MOCK_CLAUDE"
chmod +x "$MOCK_CLAUDE"

CLAUDE_CONNECT=telegram CLAUDE_WRAPPER_HEARTBEAT_INTERVAL=1 "$WRAPPER" 2>"$STDERR_LOG" || true
stderr_output=$(cat "$STDERR_LOG" 2>/dev/null || echo "")
assert_contains "heartbeat sent in telegram mode" "heartbeat sent" "$stderr_output"

# --- Test 18: remote-control mode uses /dev/null stdin (no FIFO) ---
echo "Test 18: remote-control mode uses /dev/null stdin (no heartbeat)"
rm -f "$LOG" "$RESTART_FILE"
STDIN_LOG="$TMPDIR/stdin18.log"
rm -f "$STDIN_LOG"
cat > "$MOCK_CLAUDE" << MOCKEOF
#!/bin/bash
echo "\$@" >> "$LOG"
# stdin should be /dev/null — read should fail immediately
read -t 1 line < /dev/stdin 2>/dev/null && echo "\$line" > "$STDIN_LOG" || true
exit 0
MOCKEOF
chmod +x "$MOCK_CLAUDE"

CLAUDE_CONNECT=remote-control "$WRAPPER" 2>&1
TOTAL=$((TOTAL + 1))
if [[ ! -s "$STDIN_LOG" ]]; then
    echo "  PASS: remote-control stdin is /dev/null (no data received)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: remote-control unexpectedly received stdin: $(cat "$STDIN_LOG")"
    FAIL=$((FAIL + 1))
fi

# --- Test 19: remote-control mode includes --permission-mode bypassPermissions ---
echo "Test 19: remote-control mode includes --permission-mode bypassPermissions"
rm -f "$LOG" "$RESTART_FILE"
create_mock 0
CLAUDE_CONNECT=remote-control "$WRAPPER" 2>&1
logged_args=$(cat "$LOG")
assert_contains "remote-control has --permission-mode" "--permission-mode bypassPermissions" "$logged_args"

# --- Test 20: remote-control mode filters --dangerously-skip-permissions from args ---
echo "Test 20: remote-control mode filters --dangerously-skip-permissions"
rm -f "$LOG" "$RESTART_FILE"
create_mock 0
CLAUDE_CONNECT=remote-control "$WRAPPER" --dangerously-skip-permissions --verbose 2>&1
logged_args=$(cat "$LOG")
assert_contains "has --permission-mode" "--permission-mode bypassPermissions" "$logged_args"
assert_contains "has --verbose" "--verbose" "$logged_args"
TOTAL=$((TOTAL + 1))
if [[ "$logged_args" != *"--dangerously-skip-permissions"* ]]; then
    echo "  PASS: --dangerously-skip-permissions filtered out"
    PASS=$((PASS + 1))
else
    echo "  FAIL: --dangerously-skip-permissions still present in args"
    FAIL=$((FAIL + 1))
fi

# --- Test 21: remote-control mode reads from /dev/null, no FIFO ---
echo "Test 21: remote-control mode has no FIFO (stdin is /dev/null)"
rm -f "$LOG" "$RESTART_FILE"
# Verify no FIFO is created by checking that no heartbeat subshell runs
STDERR_LOG="$TMPDIR/stderr21.log"
rm -f "$STDERR_LOG"
create_mock 0
CLAUDE_CONNECT=remote-control CLAUDE_WRAPPER_HEARTBEAT_INTERVAL=1 "$WRAPPER" 2>"$STDERR_LOG" || true
stderr_output=$(cat "$STDERR_LOG" 2>/dev/null || echo "")
TOTAL=$((TOTAL + 1))
if [[ "$stderr_output" != *"heartbeat sent"* ]]; then
    echo "  PASS: no heartbeat in remote-control mode (uses /dev/null)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: heartbeat still running in remote-control mode"
    FAIL=$((FAIL + 1))
fi

# --- Test 22: interactive mode does NOT pipe y to stdin ---
echo "Test 22: interactive mode does not pipe stdin"
rm -f "$LOG" "$RESTART_FILE" "$STDIN_LOG"
cat > "$MOCK_CLAUDE" << MOCKEOF
#!/bin/bash
echo "\$@" >> "$LOG"
# Try to read stdin with timeout -- should get nothing
read -t 1 line < /dev/stdin 2>/dev/null && echo "\$line" > "$STDIN_LOG" || true
exit 0
MOCKEOF
chmod +x "$MOCK_CLAUDE"

unset CLAUDE_CONNECT 2>/dev/null || true
"$WRAPPER" --foo 2>&1
TOTAL=$((TOTAL + 1))
if [[ ! -s "$STDIN_LOG" ]]; then
    echo "  PASS: interactive mode has no piped stdin"
    PASS=$((PASS + 1))
else
    echo "  FAIL: interactive mode unexpectedly received stdin: $(cat "$STDIN_LOG")"
    FAIL=$((FAIL + 1))
fi

# --- Test 23: ensure_remote_dialog_seen creates ~/.claude.json ---
echo "Test 23: ensure_remote_dialog_seen creates config with remoteDialogSeen"
rm -f "$LOG" "$RESTART_FILE"
FAKE_HOME="$TMPDIR/fakehome"
mkdir -p "$FAKE_HOME"
rm -f "$FAKE_HOME/.claude.json"
create_mock 0
HOME="$FAKE_HOME" CLAUDE_CONNECT=remote-control CLAUDE_WRAPPER_HEARTBEAT_INTERVAL=1 "$WRAPPER" 2>&1 || true
TOTAL=$((TOTAL + 1))
if [[ -f "$FAKE_HOME/.claude.json" ]]; then
    echo "  PASS: ~/.claude.json created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: ~/.claude.json not created"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if grep -q "remoteDialogSeen" "$FAKE_HOME/.claude.json" 2>/dev/null; then
    echo "  PASS: remoteDialogSeen found in config"
    PASS=$((PASS + 1))
else
    echo "  FAIL: remoteDialogSeen not found in config"
    FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
