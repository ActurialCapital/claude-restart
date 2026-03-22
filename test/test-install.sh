#!/bin/bash
# Test suite for install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../bin/install.sh"
PASS=0
FAIL=0
TOTAL=0

# Setup
TMPDIR=$(mktemp -d)

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

# Test isolation: override install dir and zshrc
INSTALL_DIR="$TMPDIR/install-bin"
FAKE_ZSHRC="$TMPDIR/fake-zshrc"
touch "$FAKE_ZSHRC"
export CLAUDE_RESTART_INSTALL_DIR="$INSTALL_DIR"
export CLAUDE_RESTART_ZSHRC="$FAKE_ZSHRC"

# --- Test 1: Install copies claude-wrapper ---
echo "Test 1: Install copies claude-wrapper"
bash "$INSTALL_SCRIPT"
assert_eq "claude-wrapper copied" "true" "$(test -f "$INSTALL_DIR/claude-wrapper" && echo true || echo false)"
assert_eq "claude-wrapper executable" "true" "$(test -x "$INSTALL_DIR/claude-wrapper" && echo true || echo false)"

# --- Test 2: Install copies claude-restart ---
echo "Test 2: Install copies claude-restart"
assert_eq "claude-restart copied" "true" "$(test -f "$INSTALL_DIR/claude-restart" && echo true || echo false)"
assert_eq "claude-restart executable" "true" "$(test -x "$INSTALL_DIR/claude-restart" && echo true || echo false)"

# --- Test 3: Install appends function block with sentinels ---
echo "Test 3: Install appends function block with sentinels"
zshrc_content=$(cat "$FAKE_ZSHRC")
assert_contains "start sentinel in zshrc" "# >>> claude-restart >>>" "$zshrc_content"
assert_contains "end sentinel in zshrc" "# <<< claude-restart <<<" "$zshrc_content"
assert_contains "function defined" "claude-restart()" "$zshrc_content"

# --- Test 4: Idempotent — second run does not duplicate ---
echo "Test 4: Idempotent - second run does not duplicate"
output=$(bash "$INSTALL_SCRIPT" 2>&1)
sentinel_count=$(grep -c '# >>> claude-restart >>>' "$FAKE_ZSHRC")
assert_eq "only one sentinel block" "1" "$sentinel_count"
assert_contains "skipping message" "skipping" "$output"

# --- Test 5: Uninstall removes scripts ---
echo "Test 5: Uninstall removes scripts"
bash "$INSTALL_SCRIPT" --uninstall
assert_eq "claude-wrapper removed" "false" "$(test -f "$INSTALL_DIR/claude-wrapper" && echo true || echo false)"
assert_eq "claude-restart removed" "false" "$(test -f "$INSTALL_DIR/claude-restart" && echo true || echo false)"

# --- Test 6: Uninstall removes zshrc block ---
echo "Test 6: Uninstall removes zshrc block"
# Reinstall first, then uninstall
echo "" > "$FAKE_ZSHRC"
bash "$INSTALL_SCRIPT"
bash "$INSTALL_SCRIPT" --uninstall
sentinel_after=$(grep -c '# >>> claude-restart >>>' "$FAKE_ZSHRC" 2>/dev/null) || sentinel_after=0
assert_eq "sentinel removed" "0" "$sentinel_after"

# --- Test 7: Uninstall on clean state no error ---
echo "Test 7: Uninstall on clean state does not error"
rm -f "$INSTALL_DIR/claude-wrapper" "$INSTALL_DIR/claude-restart"
echo "" > "$FAKE_ZSHRC"
exit_code=0
bash "$INSTALL_SCRIPT" --uninstall 2>&1 || exit_code=$?
assert_eq "uninstall on clean state exits 0" "0" "$exit_code"

# --- Test 8: Function uses absolute path ---
echo "Test 8: Function uses absolute path to wrapper"
echo "" > "$FAKE_ZSHRC"
bash "$INSTALL_SCRIPT"
zshrc_content=$(cat "$FAKE_ZSHRC")
assert_contains "absolute path to wrapper" "$INSTALL_DIR/claude-wrapper" "$zshrc_content"

# --- Test 9: CLAUDE_CONNECT and CLAUDE_RESTART_DEFAULT_OPTS exports ---
echo "Test 9: CLAUDE_CONNECT and CLAUDE_RESTART_DEFAULT_OPTS exports"
assert_contains "CLAUDE_CONNECT export" 'CLAUDE_CONNECT="telegram"' "$zshrc_content"
assert_contains "default opts without channel string" 'CLAUDE_RESTART_DEFAULT_OPTS="--dangerously-skip-permissions"' "$zshrc_content"

# --- Test 10: No hardcoded telegram channel string in DEFAULT_OPTS ---
echo "Test 10: No hardcoded telegram channel string in DEFAULT_OPTS"
# Ensure the channel string is NOT in the zshrc block's DEFAULT_OPTS line
default_opts_line=$(grep "CLAUDE_RESTART_DEFAULT_OPTS" "$FAKE_ZSHRC" || true)
TOTAL=$((TOTAL + 1))
if [[ "$default_opts_line" != *"plugin:telegram"* ]]; then
    echo "  PASS: no telegram channel string in DEFAULT_OPTS"
    PASS=$((PASS + 1))
else
    echo "  FAIL: DEFAULT_OPTS still contains telegram channel string"
    FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
