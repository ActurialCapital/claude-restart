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

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected NOT to contain: '$needle')"
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

# =============================================================================
# Linux Install Path Tests
# =============================================================================

# Helper: set up mock environment for Linux tests
setup_linux_mocks() {
    local test_tmpdir="$1"

    # Create mock bin dir with systemctl and loginctl
    local mock_bin="$test_tmpdir/mock-bin"
    mkdir -p "$mock_bin"

    local mock_log="$test_tmpdir/mock-calls.log"
    touch "$mock_log"

    # Mock systemctl - logs all calls
    cat > "$mock_bin/systemctl" << 'MOCKEOF'
#!/bin/bash
echo "systemctl $*" >> "$MOCK_LOG"
MOCKEOF
    chmod +x "$mock_bin/systemctl"

    # Mock loginctl - logs all calls
    cat > "$mock_bin/loginctl" << 'MOCKEOF'
#!/bin/bash
echo "loginctl $*" >> "$MOCK_LOG"
MOCKEOF
    chmod +x "$mock_bin/loginctl"

    echo "$mock_bin:$mock_log"
}

# Helper: run Linux install with provided stdin
run_linux_install() {
    local test_tmpdir="$1"
    local stdin_input="$2"

    local mock_info
    mock_info=$(setup_linux_mocks "$test_tmpdir")
    local mock_bin="${mock_info%%:*}"
    local mock_log="${mock_info#*:}"

    local test_install_dir="$test_tmpdir/install-bin"
    local test_systemd_dir="$test_tmpdir/systemd-user"
    local test_env_dir="$test_tmpdir/env-dir"

    export CLAUDE_RESTART_INSTALL_DIR="$test_install_dir"
    export CLAUDE_RESTART_PLATFORM="Linux"
    export CLAUDE_RESTART_SYSTEMD_DIR="$test_systemd_dir"
    export CLAUDE_RESTART_ENV_DIR="$test_env_dir"
    export MOCK_LOG="$mock_log"

    echo "$stdin_input" | PATH="$mock_bin:$PATH" bash "$INSTALL_SCRIPT" 2>&1

    # Return values via files
    echo "$test_install_dir" > "$test_tmpdir/_install_dir"
    echo "$test_systemd_dir" > "$test_tmpdir/_systemd_dir"
    echo "$test_env_dir" > "$test_tmpdir/_env_dir"
    echo "$mock_log" > "$test_tmpdir/_mock_log"
}

# --- Test 11: Linux install creates systemd unit file ---
echo "Test 11: Linux install creates systemd unit file"
TEST11_DIR="$TMPDIR/test11"
mkdir -p "$TEST11_DIR"
# stdin: working dir, API key, connection mode
run_linux_install "$TEST11_DIR" "/tmp/test-workdir
sk-test-key-123
remote-control"

T11_SYSTEMD_DIR=$(cat "$TEST11_DIR/_systemd_dir")
assert_eq "template unit file exists" "true" "$(test -f "$T11_SYSTEMD_DIR/claude@.service" && echo true || echo false)"

unit_content=$(cat "$T11_SYSTEMD_DIR/claude@.service")
assert_contains "unit has Restart=on-failure" "Restart=on-failure" "$unit_content"

# --- Test 12: Linux install creates env file with correct permissions ---
echo "Test 12: Linux install creates env file with correct permissions"
T12_ENV_DIR=$(cat "$TEST11_DIR/_env_dir")
assert_eq "env file exists" "true" "$(test -f "$T12_ENV_DIR/default/env" && echo true || echo false)"

# Check permissions (macOS stat format)
env_perms=$(stat -f "%Lp" "$T12_ENV_DIR/default/env" 2>/dev/null || stat -c "%a" "$T12_ENV_DIR/default/env" 2>/dev/null)
assert_eq "env file permissions 600" "600" "$env_perms"

env_content=$(cat "$T12_ENV_DIR/default/env")
assert_contains "env has API key" "ANTHROPIC_API_KEY=sk-test-key-123" "$env_content"
assert_contains "env has CLAUDE_CONNECT" "CLAUDE_CONNECT=remote-control" "$env_content"
assert_not_contains "HOME placeholder replaced" "HOME_PLACEHOLDER" "$env_content"

# --- Test 13: Linux install copies claude-service to INSTALL_DIR ---
echo "Test 13: Linux install copies claude-service to INSTALL_DIR"
T13_INSTALL_DIR=$(cat "$TEST11_DIR/_install_dir")
assert_eq "claude-service exists" "true" "$(test -f "$T13_INSTALL_DIR/claude-service" && echo true || echo false)"
assert_eq "claude-service executable" "true" "$(test -x "$T13_INSTALL_DIR/claude-service" && echo true || echo false)"

# --- Test 14: Linux install calls systemctl daemon-reload, enable, start ---
echo "Test 14: Linux install calls systemctl daemon-reload, enable, start"
T14_MOCK_LOG=$(cat "$TEST11_DIR/_mock_log")
mock_calls=$(cat "$T14_MOCK_LOG")
assert_contains "daemon-reload called" "daemon-reload" "$mock_calls"
assert_contains "enable called" "enable claude@default.service" "$mock_calls"
assert_contains "start called" "start claude@default.service" "$mock_calls"

# --- Test 15: Linux install calls loginctl enable-linger ---
echo "Test 15: Linux install calls loginctl enable-linger"
assert_contains "enable-linger called" "enable-linger" "$mock_calls"

# --- Test 16: macOS install does NOT create systemd files ---
echo "Test 16: macOS install does NOT create systemd files"
TEST16_DIR="$TMPDIR/test16"
mkdir -p "$TEST16_DIR"
T16_INSTALL_DIR="$TEST16_DIR/install-bin"
T16_SYSTEMD_DIR="$TEST16_DIR/systemd-user"
T16_ZSHRC="$TEST16_DIR/fake-zshrc"
touch "$T16_ZSHRC"

export CLAUDE_RESTART_INSTALL_DIR="$T16_INSTALL_DIR"
export CLAUDE_RESTART_PLATFORM="Darwin"
export CLAUDE_RESTART_SYSTEMD_DIR="$T16_SYSTEMD_DIR"
export CLAUDE_RESTART_ZSHRC="$T16_ZSHRC"

bash "$INSTALL_SCRIPT" 2>&1

assert_eq "no systemd dir created" "false" "$(test -d "$T16_SYSTEMD_DIR" && echo true || echo false)"
assert_eq "no unit file" "false" "$(test -f "$T16_SYSTEMD_DIR/claude.service" && echo true || echo false)"

t16_zshrc_content=$(cat "$T16_ZSHRC")
assert_contains "zshrc has sentinel" "# >>> claude-restart >>>" "$t16_zshrc_content"

# --- Test 17: Linux install skips existing env file ---
echo "Test 17: Linux install skips existing env file"
TEST17_DIR="$TMPDIR/test17"
mkdir -p "$TEST17_DIR"

# Pre-create env file in per-instance directory layout
T17_ENV_DIR="$TEST17_DIR/env-dir"
mkdir -p "$T17_ENV_DIR/default"
echo "EXISTING=true" > "$T17_ENV_DIR/default/env"

mock_info=$(setup_linux_mocks "$TEST17_DIR")
mock_bin="${mock_info%%:*}"
mock_log="${mock_info#*:}"

export CLAUDE_RESTART_INSTALL_DIR="$TEST17_DIR/install-bin"
export CLAUDE_RESTART_PLATFORM="Linux"
export CLAUDE_RESTART_SYSTEMD_DIR="$TEST17_DIR/systemd-user"
export CLAUDE_RESTART_ENV_DIR="$T17_ENV_DIR"
export MOCK_LOG="$mock_log"

# Only need working dir prompt (env file skipped, so no API key / mode prompts)
t17_output=$(echo "/tmp/workdir" | PATH="$mock_bin:$PATH" bash "$INSTALL_SCRIPT" 2>&1)

assert_contains "skip message shown" "already exists" "$t17_output"
t17_env_content=$(cat "$T17_ENV_DIR/default/env")
assert_contains "existing env preserved" "EXISTING=true" "$t17_env_content"

# Restore defaults for summary line
export CLAUDE_RESTART_INSTALL_DIR="$INSTALL_DIR"
export CLAUDE_RESTART_ZSHRC="$FAKE_ZSHRC"
unset CLAUDE_RESTART_PLATFORM
unset CLAUDE_RESTART_SYSTEMD_DIR
unset CLAUDE_RESTART_ENV_DIR
unset MOCK_LOG

# =============================================================================
# Watchdog Timer Install/Uninstall Tests
# =============================================================================

# --- Test 18: Linux install deploys watchdog timer and oneshot ---
echo "Test 18: Linux install deploys watchdog timer and oneshot"
TEST18_DIR="$TMPDIR/test18"
mkdir -p "$TEST18_DIR"
run_linux_install "$TEST18_DIR" "/tmp/test-workdir
sk-test-key-456
telegram"

T18_SYSTEMD_DIR=$(cat "$TEST18_DIR/_systemd_dir")
T18_MOCK_LOG=$(cat "$TEST18_DIR/_mock_log")
t18_mock_calls=$(cat "$T18_MOCK_LOG")

assert_eq "watchdog timer file exists" "true" "$(test -f "$T18_SYSTEMD_DIR/claude-watchdog@.timer" && echo true || echo false)"
assert_eq "watchdog oneshot file exists" "true" "$(test -f "$T18_SYSTEMD_DIR/claude-watchdog@.service" && echo true || echo false)"

t18_timer_content=$(cat "$T18_SYSTEMD_DIR/claude-watchdog@.timer")
assert_contains "timer has 8h interval" "OnUnitActiveSec=8h" "$t18_timer_content"
assert_not_contains "placeholder replaced" "CLAUDE_WATCHDOG_HOURS_PLACEHOLDER" "$t18_timer_content"

assert_contains "enable watchdog timer called" "enable claude-watchdog@default.timer" "$t18_mock_calls"
assert_contains "start watchdog timer called" "start claude-watchdog@default.timer" "$t18_mock_calls"

# --- Test 19: Linux uninstall removes watchdog files ---
echo "Test 19: Linux uninstall removes watchdog files"
TEST19_DIR="$TMPDIR/test19"
mkdir -p "$TEST19_DIR"
run_linux_install "$TEST19_DIR" "/tmp/test-workdir
sk-test-key-789
telegram"

T19_SYSTEMD_DIR=$(cat "$TEST19_DIR/_systemd_dir")
T19_MOCK_LOG=$(cat "$TEST19_DIR/_mock_log")

# Run uninstall
T19_ZSHRC="$TEST19_DIR/fake-zshrc"
touch "$T19_ZSHRC"
export CLAUDE_RESTART_INSTALL_DIR="$(cat "$TEST19_DIR/_install_dir")"
export CLAUDE_RESTART_PLATFORM="Linux"
export CLAUDE_RESTART_SYSTEMD_DIR="$T19_SYSTEMD_DIR"
export CLAUDE_RESTART_ENV_DIR="$(cat "$TEST19_DIR/_env_dir")"
export CLAUDE_RESTART_ZSHRC="$T19_ZSHRC"
export MOCK_LOG="$T19_MOCK_LOG"

mock_info=$(setup_linux_mocks "$TEST19_DIR")
mock_bin="${mock_info%%:*}"
# Use the same mock log so uninstall calls are appended
export MOCK_LOG="$T19_MOCK_LOG"

PATH="$mock_bin:$PATH" bash "$INSTALL_SCRIPT" --uninstall 2>&1

t19_mock_calls=$(cat "$T19_MOCK_LOG")
assert_contains "stop watchdog timer called" "stop claude-watchdog@default.timer" "$t19_mock_calls"
assert_contains "disable watchdog timer called" "disable claude-watchdog@default.timer" "$t19_mock_calls"
assert_eq "watchdog timer removed" "false" "$(test -f "$T19_SYSTEMD_DIR/claude-watchdog@.timer" && echo true || echo false)"
assert_eq "watchdog oneshot removed" "false" "$(test -f "$T19_SYSTEMD_DIR/claude-watchdog@.service" && echo true || echo false)"

# --- Test 20: Custom watchdog hours ---
echo "Test 20: Custom watchdog hours"
TEST20_DIR="$TMPDIR/test20"
mkdir -p "$TEST20_DIR"

export CLAUDE_WATCHDOG_HOURS=4
run_linux_install "$TEST20_DIR" "/tmp/test-workdir
sk-test-key-custom
telegram"

T20_SYSTEMD_DIR=$(cat "$TEST20_DIR/_systemd_dir")
t20_timer_content=$(cat "$T20_SYSTEMD_DIR/claude-watchdog@.timer")
assert_contains "timer has custom 4h interval" "OnUnitActiveSec=4h" "$t20_timer_content"
assert_not_contains "timer does not have default 8h" "OnUnitActiveSec=8h" "$t20_timer_content"
unset CLAUDE_WATCHDOG_HOURS

# =============================================================================
# Skills Deployment Tests (Phase 14)
# =============================================================================

ORIG_HOME="$HOME"

# --- Test 21: Linux install deploys GSD skills ---
echo "Test 21: Linux install deploys GSD skills"
TEST21_DIR="$TMPDIR/test21"
mkdir -p "$TEST21_DIR"
# Create fake skills source in a mock repo layout
FAKE_REPO="$TEST21_DIR/fake-repo"
mkdir -p "$FAKE_REPO/bin" "$FAKE_REPO/systemd" "$FAKE_REPO/skills/get-shit-done" "$FAKE_REPO/commands"
echo "fake-gsd-content" > "$FAKE_REPO/skills/get-shit-done/test-skill.md"
echo "fake-command-content" > "$FAKE_REPO/commands/test-command.md"
# Copy real scripts into fake repo
cp "$SCRIPT_DIR/../bin/install.sh" "$FAKE_REPO/bin/install.sh"
cp "$SCRIPT_DIR/../bin/claude-wrapper" "$FAKE_REPO/bin/claude-wrapper"
cp "$SCRIPT_DIR/../bin/claude-restart" "$FAKE_REPO/bin/claude-restart"
cp "$SCRIPT_DIR/../bin/claude-service" "$FAKE_REPO/bin/claude-service"
cp "$SCRIPT_DIR/../systemd/env.template" "$FAKE_REPO/systemd/env.template"
cp "$SCRIPT_DIR/../systemd/claude@.service" "$FAKE_REPO/systemd/claude@.service"
cp "$SCRIPT_DIR/../systemd/claude-watchdog@.service" "$FAKE_REPO/systemd/claude-watchdog@.service"
cp "$SCRIPT_DIR/../systemd/claude-watchdog@.timer" "$FAKE_REPO/systemd/claude-watchdog@.timer"

mock_info=$(setup_linux_mocks "$TEST21_DIR")
mock_bin="${mock_info%%:*}"
mock_log="${mock_info#*:}"

export CLAUDE_RESTART_INSTALL_DIR="$TEST21_DIR/install-bin"
export CLAUDE_RESTART_PLATFORM="Linux"
export CLAUDE_RESTART_SYSTEMD_DIR="$TEST21_DIR/systemd-user"
export CLAUDE_RESTART_ENV_DIR="$TEST21_DIR/env-dir"
export MOCK_LOG="$mock_log"
export HOME="$TEST21_DIR/fakehome"
mkdir -p "$HOME"

echo "/tmp/test-workdir
sk-test-key-skills
remote-control" | PATH="$mock_bin:$PATH" bash "$FAKE_REPO/bin/install.sh" 2>&1

assert_eq "GSD skills deployed" "true" "$(test -f "$HOME/.claude/get-shit-done/test-skill.md" && echo true || echo false)"
assert_eq "superpowers commands deployed" "true" "$(test -f "$HOME/.claude/commands/test-command.md" && echo true || echo false)"

# --- Test 22: Linux install skips skills when source missing ---
echo "Test 22: Linux install skips skills when source missing"
TEST22_DIR="$TMPDIR/test22"
mkdir -p "$TEST22_DIR"
# No skills/commands dirs — just the scripts
FAKE_REPO22="$TEST22_DIR/fake-repo"
mkdir -p "$FAKE_REPO22/bin" "$FAKE_REPO22/systemd"
cp "$SCRIPT_DIR/../bin/install.sh" "$FAKE_REPO22/bin/install.sh"
cp "$SCRIPT_DIR/../bin/claude-wrapper" "$FAKE_REPO22/bin/claude-wrapper"
cp "$SCRIPT_DIR/../bin/claude-restart" "$FAKE_REPO22/bin/claude-restart"
cp "$SCRIPT_DIR/../bin/claude-service" "$FAKE_REPO22/bin/claude-service"
cp "$SCRIPT_DIR/../systemd/env.template" "$FAKE_REPO22/systemd/env.template"
cp "$SCRIPT_DIR/../systemd/claude@.service" "$FAKE_REPO22/systemd/claude@.service"
cp "$SCRIPT_DIR/../systemd/claude-watchdog@.service" "$FAKE_REPO22/systemd/claude-watchdog@.service"
cp "$SCRIPT_DIR/../systemd/claude-watchdog@.timer" "$FAKE_REPO22/systemd/claude-watchdog@.timer"

mock_info=$(setup_linux_mocks "$TEST22_DIR")
mock_bin="${mock_info%%:*}"
mock_log="${mock_info#*:}"

export CLAUDE_RESTART_INSTALL_DIR="$TEST22_DIR/install-bin"
export CLAUDE_RESTART_PLATFORM="Linux"
export CLAUDE_RESTART_SYSTEMD_DIR="$TEST22_DIR/systemd-user"
export CLAUDE_RESTART_ENV_DIR="$TEST22_DIR/env-dir"
export MOCK_LOG="$mock_log"
export HOME="$TEST22_DIR/fakehome"
mkdir -p "$HOME"

t22_output=$(echo "/tmp/test-workdir
sk-test-key-skip
remote-control" | PATH="$mock_bin:$PATH" bash "$FAKE_REPO22/bin/install.sh" 2>&1)
t22_exit=$?

assert_eq "install succeeds without skills dirs" "0" "$t22_exit"
assert_contains "warning about missing GSD" "Warning" "$t22_output"

# --- Test 23: Deployed skills content matches source ---
echo "Test 23: Deployed skills content matches source"
# Reuse TEST21_DIR where skills were deployed
t23_content=$(cat "$TEST21_DIR/fakehome/.claude/get-shit-done/test-skill.md" 2>/dev/null || echo "")
assert_eq "GSD content matches" "fake-gsd-content" "$t23_content"
t23_cmd_content=$(cat "$TEST21_DIR/fakehome/.claude/commands/test-command.md" 2>/dev/null || echo "")
assert_eq "command content matches" "fake-command-content" "$t23_cmd_content"

export HOME="$ORIG_HOME"

# Restore defaults for summary line
export CLAUDE_RESTART_INSTALL_DIR="$INSTALL_DIR"
export CLAUDE_RESTART_ZSHRC="$FAKE_ZSHRC"
unset CLAUDE_RESTART_PLATFORM
unset CLAUDE_RESTART_SYSTEMD_DIR
unset CLAUDE_RESTART_ENV_DIR
unset MOCK_LOG

# --- Summary ---
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
