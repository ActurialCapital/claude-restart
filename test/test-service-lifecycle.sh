#!/bin/bash
# Test suite for claude-service add/remove/list lifecycle commands
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_SCRIPT="$SCRIPT_DIR/../bin/claude-service"
PASS=0
FAIL=0
TOTAL=0

# Setup
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# Assert functions (same pattern as test-install.sh)
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

assert_file_exists() {
    local desc="$1" path="$2"
    TOTAL=$((TOTAL + 1))
    if [[ -f "$path" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (file not found: $path)"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_not_exists() {
    local desc="$1" path="$2"
    TOTAL=$((TOTAL + 1))
    if [[ ! -e "$path" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (path still exists: $path)"
        FAIL=$((FAIL + 1))
    fi
}

# Create mock binaries
MOCK_BIN="$TMPDIR/mock-bin"
mkdir -p "$MOCK_BIN"

# Mock systemctl -- records calls to a log file
SYSTEMCTL_LOG="$TMPDIR/systemctl.log"
cat > "$MOCK_BIN/systemctl" << 'MOCK'
#!/bin/bash
echo "systemctl $*" >> "${SYSTEMCTL_LOG}"
# Return "inactive" for is-active queries
if [[ "${*}" == *"is-active"* ]]; then
    echo "inactive"
fi
MOCK
chmod +x "$MOCK_BIN/systemctl"

# Mock git -- creates directory instead of actual clone
GIT_LOG="$TMPDIR/git.log"
cat > "$MOCK_BIN/git" << 'MOCK'
#!/bin/bash
echo "git $*" >> "${GIT_LOG}"
if [[ "${1:-}" == "clone" ]]; then
    mkdir -p "${3}"
fi
MOCK
chmod +x "$MOCK_BIN/git"

# Mock loginctl
cat > "$MOCK_BIN/loginctl" << 'MOCK'
#!/bin/bash
# no-op
MOCK
chmod +x "$MOCK_BIN/loginctl"

# Override HOME and PATH for test isolation
export HOME="$TMPDIR/fakehome"
mkdir -p "$HOME"
export PATH="$MOCK_BIN:$PATH"
export SYSTEMCTL_LOG
export GIT_LOG

# Setup: create default instance env (required for add)
CONFIG_DIR="$HOME/.config/claude-restart"
mkdir -p "$CONFIG_DIR/default"
cat > "$CONFIG_DIR/default/env" << 'ENV'
ANTHROPIC_API_KEY=sk-test-key-12345
CLAUDE_CONNECT=remote-control
CLAUDE_INSTANCE_NAME=default
WORKING_DIRECTORY=/home/testuser
CLAUDE_RESTART_FILE=/home/testuser/.config/claude-restart/default/restart
CLAUDE_MEMORY_MAX=1G
CLAUDE_WATCHDOG_HOURS=8
PATH=/usr/local/bin:/usr/bin:/bin:/home/testuser/.local/bin
ENV

# Setup: deploy env.template
cp "$SCRIPT_DIR/../systemd/env.template" "$CONFIG_DIR/env.template"

# --- Test 1: add validates name format ---
echo "Test 1: add rejects invalid name"
output=$(bash "$SERVICE_SCRIPT" add "bad name" "https://example.com/repo.git" 2>&1 || true)
assert_contains "rejects spaces" "must match" "$output"

output=$(bash "$SERVICE_SCRIPT" add "/badname" "https://example.com/repo.git" 2>&1 || true)
assert_contains "rejects slash" "must match" "$output"

# --- Test 2: add creates env file and directories ---
echo "Test 2: add creates env file and directories"
> "$SYSTEMCTL_LOG"  # clear log
> "$GIT_LOG"
bash "$SERVICE_SCRIPT" add "testproject" "https://github.com/user/repo.git"

assert_file_exists "env file created" "$CONFIG_DIR/testproject/env"
assert_eq "env file permissions" "600" "$(stat -f '%A' "$CONFIG_DIR/testproject/env" 2>/dev/null || stat -c '%a' "$CONFIG_DIR/testproject/env" 2>/dev/null)"

# --- Test 3: add populates env correctly ---
echo "Test 3: add populates env correctly"
env_content=$(cat "$CONFIG_DIR/testproject/env")
assert_contains "instance name set" "CLAUDE_INSTANCE_NAME=testproject" "$env_content"
assert_contains "working dir set" "WORKING_DIRECTORY=$HOME/instruments/testproject" "$env_content"
assert_contains "API key copied" "ANTHROPIC_API_KEY=sk-test-key-12345" "$env_content"
assert_contains "restart file set" "CLAUDE_RESTART_FILE=$HOME/.config/claude-restart/testproject/restart" "$env_content"

# --- Test 4: add calls git clone ---
echo "Test 4: add calls git clone"
git_calls=$(cat "$GIT_LOG")
assert_contains "git clone called" "clone https://github.com/user/repo.git $HOME/instruments/testproject" "$git_calls"

# --- Test 5: add enables systemd units ---
echo "Test 5: add enables systemd units"
systemctl_calls=$(cat "$SYSTEMCTL_LOG")
assert_contains "service enabled" "enable --now claude@testproject.service" "$systemctl_calls"
assert_contains "watchdog enabled" "enable --now claude-watchdog@testproject.timer" "$systemctl_calls"
assert_contains "daemon-reload called" "daemon-reload" "$systemctl_calls"

# --- Test 6: add rejects duplicate ---
echo "Test 6: add rejects duplicate instrument"
output=$(bash "$SERVICE_SCRIPT" add "testproject" "https://example.com/other.git" 2>&1 || true)
assert_contains "duplicate rejected" "already exists" "$output"

# --- Test 7: list shows instruments ---
echo "Test 7: list shows instruments"
output=$(bash "$SERVICE_SCRIPT" list)
assert_contains "header shown" "INSTRUMENT" "$output"
assert_contains "default listed" "default" "$output"
assert_contains "testproject listed" "testproject" "$output"

# --- Test 8: remove cleans up everything ---
echo "Test 8: remove cleans up everything"
> "$SYSTEMCTL_LOG"
bash "$SERVICE_SCRIPT" remove "testproject"

assert_file_not_exists "env dir deleted" "$CONFIG_DIR/testproject"
assert_file_not_exists "work dir deleted" "$HOME/instruments/testproject"

systemctl_calls=$(cat "$SYSTEMCTL_LOG")
assert_contains "service stopped" "stop claude@testproject.service" "$systemctl_calls"
assert_contains "service disabled" "disable claude@testproject.service" "$systemctl_calls"
assert_contains "watchdog stopped" "stop claude-watchdog@testproject.timer" "$systemctl_calls"
assert_contains "watchdog disabled" "disable claude-watchdog@testproject.timer" "$systemctl_calls"

# --- Test 9: remove rejects default ---
echo "Test 9: remove rejects default instance"
output=$(bash "$SERVICE_SCRIPT" remove "default" 2>&1 || true)
assert_contains "default rejected" "cannot remove the default" "$output"

# --- Test 10: remove rejects nonexistent ---
echo "Test 10: remove rejects nonexistent instrument"
output=$(bash "$SERVICE_SCRIPT" remove "doesnotexist" 2>&1 || true)
assert_contains "nonexistent rejected" "not found" "$output"

# --- Test 11: add missing args ---
echo "Test 11: add requires name and git-url"
output=$(bash "$SERVICE_SCRIPT" add 2>&1 || true)
assert_contains "usage shown" "Usage" "$output"

output=$(bash "$SERVICE_SCRIPT" add "onlyname" 2>&1 || true)
assert_contains "usage shown for missing url" "Usage" "$output"

# --- Test 12: add deploys instrument identity CLAUDE.md ---
echo "Test 12: add deploys instrument identity CLAUDE.md"
> "$SYSTEMCTL_LOG"
> "$GIT_LOG"
bash "$SERVICE_SCRIPT" add "identity-test" "https://github.com/user/identity.git"

assert_file_exists "identity CLAUDE.md created" "$HOME/instruments/identity-test/.claude/CLAUDE.md"
id_content=$(cat "$HOME/instruments/identity-test/.claude/CLAUDE.md")
assert_contains "instance name in identity" "identity-test" "$id_content"
assert_contains "restart hint in identity" "claude-restart --instance identity-test" "$id_content"
assert_contains "remote access hint" "remote-control --name identity-test" "$id_content"

# Cleanup for other tests
bash "$SERVICE_SCRIPT" remove "identity-test"

# --- Test 13: identity CLAUDE.md is in .claude/ not root ---
echo "Test 13: identity CLAUDE.md is in .claude/ subdir not root"
> "$SYSTEMCTL_LOG"
> "$GIT_LOG"
# Pre-create a repo CLAUDE.md to verify it's not overwritten
bash "$SERVICE_SCRIPT" add "nooverwrite" "https://github.com/user/nooverwrite.git"
echo "ORIGINAL_REPO_CONTENT" > "$HOME/instruments/nooverwrite/CLAUDE.md"
# Verify .claude/CLAUDE.md exists separately
assert_file_exists ".claude/CLAUDE.md exists" "$HOME/instruments/nooverwrite/.claude/CLAUDE.md"
repo_claude=$(cat "$HOME/instruments/nooverwrite/CLAUDE.md")
assert_eq "repo CLAUDE.md not overwritten" "ORIGINAL_REPO_CONTENT" "$repo_claude"

bash "$SERVICE_SCRIPT" remove "nooverwrite"

# --- Test 14: add-orchestra deploys identity in .claude/ ---
echo "Test 14: add-orchestra deploys identity in .claude/ subdir"
> "$SYSTEMCTL_LOG"
# Need to ensure orchestra/CLAUDE.md exists for add-orchestra
# The script uses $script_dir/../orchestra/CLAUDE.md
# In test env, SERVICE_SCRIPT points to real bin/claude-service, so orchestra/CLAUDE.md should exist
output=$(bash "$SERVICE_SCRIPT" add-orchestra 2>&1)
assert_file_exists "orchestra .claude/CLAUDE.md exists" "$HOME/instruments/orchestra/.claude/CLAUDE.md"
orch_id_content=$(cat "$HOME/instruments/orchestra/.claude/CLAUDE.md")
assert_contains "orchestra name in identity" "orchestra" "$orch_id_content"

bash "$SERVICE_SCRIPT" remove "orchestra" 2>/dev/null || true

# --- Results ---
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
