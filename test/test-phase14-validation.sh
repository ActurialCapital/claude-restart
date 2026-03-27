#!/bin/bash
# Nyquist validation tests for Phase 14: Skills Deployment and Identity
# These tests verify behavioral requirements DEPL-01, DEPL-02, INST-01, INST-02, SESS-01
# DEPL-03 is a design assumption (claude -p skill inheritance) and cannot be tested.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
PASS=0
FAIL=0
TOTAL=0

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
        echo "  FAIL: $desc (expected to contain: '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_ge() {
    local desc="$1" minimum="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$actual" -ge "$minimum" ]]; then
        echo "  PASS: $desc ($actual >= $minimum)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected >= $minimum, got: $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# =============================================================================
# DEPL-01: Installer deploys GSD skills to ~/.claude/get-shit-done/
# =============================================================================

echo "DEPL-01: install.sh deploy_skills clones GSD to ~/.claude/get-shit-done/"

# Verify deploy_skills function exists and uses git clone
install_content=$(cat "$REPO_ROOT/bin/install.sh")
assert_contains "deploy_skills function defined" "deploy_skills()" "$install_content"
assert_contains "GSD repo URL configured" 'gsd-build/get-shit-done' "$install_content"
assert_contains "GSD target is ~/.claude/get-shit-done" 'gsd_dir' "$install_content"
assert_contains "git clone used for GSD" 'git clone' "$install_content"

# Verify deploy_skills is wired into do_install_linux
deploy_call_count=$(grep -c "deploy_skills" "$REPO_ROOT/bin/install.sh")
assert_ge "deploy_skills appears at least twice in install.sh (def + call)" 2 "$deploy_call_count"

# Verify skills README stub exists (vendored content removed)
assert_eq "skills/README.md exists" "true" "$(test -f "$REPO_ROOT/skills/README.md" && echo true || echo false)"

# =============================================================================
# DEPL-02: Installer deploys superpowers commands to ~/.claude/commands/
# =============================================================================

echo "DEPL-02: install.sh deploy_skills clones commands to ~/.claude/commands/"

assert_contains "superpowers repo URL configured" 'obra/superpowers' "$install_content"
assert_contains "commands target is ~/.claude/commands" 'commands_dir' "$install_content"
assert_eq "commands/README.md exists" "true" "$(test -f "$REPO_ROOT/commands/README.md" && echo true || echo false)"

# =============================================================================
# INST-01: Instruments know their own instance name via CLAUDE.md
# =============================================================================

echo "INST-01: INSTRUMENT.md.template provides instance identity"

assert_eq "INSTRUMENT.md.template exists" "true" "$(test -f "$REPO_ROOT/INSTRUMENT.md.template" && echo true || echo false)"

template_content=$(cat "$REPO_ROOT/INSTRUMENT.md.template")
placeholder_count=$(grep -c "INSTANCE_PLACEHOLDER" "$REPO_ROOT/INSTRUMENT.md.template")
assert_ge "template has at least 5 INSTANCE_PLACEHOLDER markers" 5 "$placeholder_count"
assert_contains "template has instance name field" "Instance name" "$template_content"

# Verify claude-service wires template into do_add
service_content=$(cat "$REPO_ROOT/bin/claude-service")
assert_contains "do_add deploys .claude/CLAUDE.md" '.claude/CLAUDE.md' "$service_content"
assert_contains "do_add uses INSTRUMENT.md.template" 'INSTRUMENT.md.template' "$service_content"
assert_contains "do_add substitutes INSTANCE_PLACEHOLDER" 'INSTANCE_PLACEHOLDER' "$service_content"

# =============================================================================
# INST-02: Template includes restart hint and instance name
# =============================================================================

echo "INST-02: template contains restart hint and remote access"

assert_contains "template has claude-restart --instance hint" "claude-restart --instance INSTANCE_PLACEHOLDER" "$template_content"
assert_contains "template has remote-control --name hint" "remote-control --name INSTANCE_PLACEHOLDER" "$template_content"

# =============================================================================
# SESS-01: All instances get --name flag (no default exclusion)
# =============================================================================

echo "SESS-01: claude-wrapper passes --name for all instances including default"

wrapper_content=$(cat "$REPO_ROOT/bin/claude-wrapper")

# Verify no default exclusion
TOTAL=$((TOTAL + 1))
if echo "$wrapper_content" | grep -q '!= "default"'; then
    echo "  FAIL: wrapper still has default exclusion for --name"
    FAIL=$((FAIL + 1))
else
    echo "  PASS: no default exclusion in --name logic"
    PASS=$((PASS + 1))
fi

# Verify --name is set from CLAUDE_INSTANCE_NAME
assert_contains "wrapper references CLAUDE_INSTANCE_NAME for --name" 'CLAUDE_INSTANCE_NAME' "$wrapper_content"
assert_contains "wrapper adds --name to mode_args" '"--name"' "$wrapper_content"

# =============================================================================
# DEPL-01/02 graceful skip: deploy_skills warns when git clone fails
# =============================================================================

echo "DEPL-01/02 edge case: graceful fallback on clone failure"

assert_contains "GSD clone failure warning" "Warning" "$install_content"
assert_contains "clone handles pull failure" "pull failed" "$install_content"
assert_contains "deploy_skills handles fresh clone and update" "pull --ff-only" "$install_content"

# =============================================================================
# INST-01 orchestra: add-orchestra deploys .claude/CLAUDE.md identity
# =============================================================================

echo "INST-01 orchestra: add-orchestra deploys orchestra identity"

assert_contains "do_add_orchestra creates .claude/CLAUDE.md" '.claude/CLAUDE.md' "$service_content"

# Verify orchestra identity mentions context reset
assert_contains "orchestra identity has restart hint" 'claude-restart --instance orchestra' "$service_content"

# --- Summary ---
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
echo "All phase 14 validation tests passed!"
