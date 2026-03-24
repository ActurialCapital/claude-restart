#!/bin/bash
# install.sh: install claude-restart scripts and shell integration
set -euo pipefail

INSTALL_DIR="${CLAUDE_RESTART_INSTALL_DIR:-$HOME/.local/bin}"
ZSHRC="${CLAUDE_RESTART_ZSHRC:-$HOME/.zshrc}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM="${CLAUDE_RESTART_PLATFORM:-$(uname -s)}"

SENTINEL_START="# >>> claude-restart >>>"
SENTINEL_END="# <<< claude-restart <<<"

SYSTEMD_USER_DIR="${CLAUDE_RESTART_SYSTEMD_DIR:-$HOME/.config/systemd/user}"
ENV_DIR="${CLAUDE_RESTART_ENV_DIR:-$HOME/.config/claude-restart}"
DEFAULT_INSTANCE="default"
INSTANCE_DIR="$ENV_DIR/$DEFAULT_INSTANCE"
ENV_FILE="$INSTANCE_DIR/env"

# Portable sed in-place (macOS needs '' argument, Linux does not)
# Uses actual OS (uname), not PLATFORM which may be overridden for testing
sed_inplace() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

usage() {
    echo "Usage: install.sh [--install | --uninstall | --help]"
}

# Migrate v1.1 flat env to v2.0 per-instance directory (per D-08)
migrate_v1_env() {
    local old_env="$ENV_DIR/env"
    local new_dir="$ENV_DIR/$DEFAULT_INSTANCE"
    local new_env="$new_dir/env"

    # Only migrate if flat env exists AND instance dir does not
    if [[ -f "$old_env" && ! -d "$new_dir" ]]; then
        echo "claude-restart: migrating v1.1 env to per-instance layout..."
        mkdir -p "$new_dir"
        cp "$old_env" "$new_env"

        # Add new variables if missing from migrated env
        if ! grep -q 'CLAUDE_INSTANCE_NAME' "$new_env"; then
            echo "" >> "$new_env"
            echo "# Instance name (used by wrapper for --name flag)" >> "$new_env"
            echo "CLAUDE_INSTANCE_NAME=$DEFAULT_INSTANCE" >> "$new_env"
        fi
        if ! grep -q 'CLAUDE_RESTART_FILE' "$new_env"; then
            echo "" >> "$new_env"
            echo "# Per-instance restart file path" >> "$new_env"
            echo "CLAUDE_RESTART_FILE=$HOME/.config/claude-restart/$DEFAULT_INSTANCE/restart" >> "$new_env"
        fi
        if ! grep -q 'CLAUDE_MEMORY_MAX' "$new_env"; then
            echo "" >> "$new_env"
            echo "# Memory limit for this instance (systemd MemoryMax)" >> "$new_env"
            echo "CLAUDE_MEMORY_MAX=1G" >> "$new_env"
        fi
        if ! grep -q 'WORKING_DIRECTORY' "$new_env"; then
            # Try to extract WorkingDirectory from existing systemd unit
            local work_dir=""
            if [[ -f "$SYSTEMD_USER_DIR/claude.service" ]]; then
                work_dir=$(grep '^WorkingDirectory=' "$SYSTEMD_USER_DIR/claude.service" 2>/dev/null | cut -d= -f2)
            fi
            if [[ -z "$work_dir" ]]; then
                work_dir="$HOME"
            fi
            echo "" >> "$new_env"
            echo "# Working directory for this instrument" >> "$new_env"
            echo "WORKING_DIRECTORY=$work_dir" >> "$new_env"
        fi

        chmod 600 "$new_env"

        # Backup and remove old flat env
        cp "$old_env" "$old_env.v1-backup"
        rm -f "$old_env"
        echo "claude-restart: migrated $old_env -> $new_env (backup at $old_env.v1-backup)"
    fi
}

do_install_linux() {
    # 1. Copy scripts to install dir
    mkdir -p "$INSTALL_DIR"
    cp "$SCRIPT_DIR/claude-wrapper" "$INSTALL_DIR/claude-wrapper"
    chmod +x "$INSTALL_DIR/claude-wrapper"
    cp "$SCRIPT_DIR/claude-restart" "$INSTALL_DIR/claude-restart"
    chmod +x "$INSTALL_DIR/claude-restart"
    cp "$SCRIPT_DIR/claude-service" "$INSTALL_DIR/claude-service"
    chmod +x "$INSTALL_DIR/claude-service"

    # 1b. Copy env.template to config dir for claude-service add (Phase 8)
    mkdir -p "$ENV_DIR"
    cp "$SCRIPT_DIR/../systemd/env.template" "$ENV_DIR/env.template"
    echo "Installed env.template to $ENV_DIR/env.template"

    # 1c. Migrate v1.1 env if present (per D-08)
    migrate_v1_env

    # 2. Prompt for working directory (stored in env file per D-04)
    read -rp "Working directory for Claude [$(pwd)]: " WORK_DIR
    WORK_DIR="${WORK_DIR:-$(pwd)}"

    # 3. Create per-instance env file (per D-02)
    mkdir -p "$INSTANCE_DIR"
    if [[ -f "$ENV_FILE" ]]; then
        echo "claude-restart: env file already exists at $ENV_FILE (skipping)"
    else
        # Detect node version for PATH
        NODE_VERSION=""
        if command -v node &>/dev/null; then
            NODE_VERSION="$(node --version | sed 's/^v//')"
        fi

        cp "$SCRIPT_DIR/../systemd/env.template" "$ENV_FILE"
        sed_inplace "s|HOME_PLACEHOLDER|$HOME|g" "$ENV_FILE"
        sed_inplace "s|INSTANCE_PLACEHOLDER|$DEFAULT_INSTANCE|g" "$ENV_FILE"
        sed_inplace "s|WORKING_DIR_PLACEHOLDER|$WORK_DIR|g" "$ENV_FILE"
        if [[ -n "$NODE_VERSION" ]]; then
            sed_inplace "s|NODEVERSION_PLACEHOLDER|$NODE_VERSION|g" "$ENV_FILE"
        else
            # Remove just the nvm segment from PATH (not the whole line)
            # HOME_PLACEHOLDER already replaced at this point, so match with $HOME
            sed_inplace "s|:$HOME/.nvm/versions/node/NODEVERSION_PLACEHOLDER/bin||g" "$ENV_FILE"
        fi

        # Prompt for API key
        read -rp "Anthropic API key: " API_KEY
        if [[ -n "$API_KEY" ]]; then
            sed_inplace "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$API_KEY|" "$ENV_FILE"
        fi

        # Prompt for connection mode
        read -rp "Connection mode (remote-control/telegram) [remote-control]: " CONN_MODE
        CONN_MODE="${CONN_MODE:-remote-control}"
        sed_inplace "s|^CLAUDE_CONNECT=.*|CLAUDE_CONNECT=$CONN_MODE|" "$ENV_FILE"

        chmod 600 "$ENV_FILE"
        echo "Created env file at $ENV_FILE"
    fi

    # Pre-set remoteDialogSeen in claude global config for non-interactive remote-control startup
    # Read CLAUDE_CONNECT from the env file (works for both fresh installs and re-runs)
    EFFECTIVE_CONN_MODE=$(grep '^CLAUDE_CONNECT=' "$ENV_FILE" 2>/dev/null | cut -d= -f2 || echo "")
    if [[ "$EFFECTIVE_CONN_MODE" == "remote-control" ]]; then
        CLAUDE_CONFIG="$HOME/.claude.json"
        if [[ -f "$CLAUDE_CONFIG" ]] && command -v jq &>/dev/null; then
            tmp=$(jq '.remoteDialogSeen = true' "$CLAUDE_CONFIG") && echo "$tmp" > "$CLAUDE_CONFIG"
            echo "Set remoteDialogSeen=true in $CLAUDE_CONFIG"
        elif [[ ! -f "$CLAUDE_CONFIG" ]]; then
            echo '{"remoteDialogSeen": true}' > "$CLAUDE_CONFIG"
            echo "Created $CLAUDE_CONFIG with remoteDialogSeen=true"
        else
            echo "Warning: install jq to auto-set remoteDialogSeen (or run 'claude' interactively once)"
        fi
    fi

    # 4. Install systemd template unit file (per D-05)
    mkdir -p "$SYSTEMD_USER_DIR"
    cp "$SCRIPT_DIR/../systemd/claude@.service" "$SYSTEMD_USER_DIR/claude@.service"
    echo "Installed systemd template unit to $SYSTEMD_USER_DIR/claude@.service"

    # Remove old non-template unit if present (migration from v1.1)
    if [[ -f "$SYSTEMD_USER_DIR/claude.service" ]]; then
        systemctl --user stop claude.service 2>/dev/null || true
        systemctl --user disable claude.service 2>/dev/null || true
        rm -f "$SYSTEMD_USER_DIR/claude.service"
        echo "Removed old claude.service (replaced by template unit)"
    fi

    # 5. Install watchdog template units (Phase 8: per-instance watchdog)
    cp "$SCRIPT_DIR/../systemd/claude-watchdog@.service" "$SYSTEMD_USER_DIR/claude-watchdog@.service"
    cp "$SCRIPT_DIR/../systemd/claude-watchdog@.timer" "$SYSTEMD_USER_DIR/claude-watchdog@.timer"
    echo "Installed watchdog template units to $SYSTEMD_USER_DIR/"

    # Migrate old non-template watchdog units if present
    if [[ -f "$SYSTEMD_USER_DIR/claude-watchdog.timer" ]]; then
        systemctl --user stop claude-watchdog.timer 2>/dev/null || true
        systemctl --user disable claude-watchdog.timer 2>/dev/null || true
        rm -f "$SYSTEMD_USER_DIR/claude-watchdog.timer"
        rm -f "$SYSTEMD_USER_DIR/claude-watchdog.service"
        echo "Removed old non-template watchdog units (replaced by template units)"
    fi

    # 6. Enable linger and start default instance (per D-06)
    loginctl enable-linger "$USER" 2>/dev/null || echo "Warning: loginctl enable-linger failed (may need root)"

    systemctl --user daemon-reload
    systemctl --user enable "claude@${DEFAULT_INSTANCE}.service"
    systemctl --user start "claude@${DEFAULT_INSTANCE}.service"
    echo "Claude service (default instance) enabled and started"

    systemctl --user enable "claude-watchdog@${DEFAULT_INSTANCE}.timer"
    systemctl --user start "claude-watchdog@${DEFAULT_INSTANCE}.timer"
    echo "Watchdog timer enabled for default instance"

    echo "Manage with: claude-service {start|stop|restart|status|logs} [instance]"
}

do_install_macos() {
    # 1. Create install dir
    mkdir -p "$INSTALL_DIR"

    # 2-3. Copy scripts and make executable
    cp "$SCRIPT_DIR/claude-wrapper" "$INSTALL_DIR/claude-wrapper"
    chmod +x "$INSTALL_DIR/claude-wrapper"
    cp "$SCRIPT_DIR/claude-restart" "$INSTALL_DIR/claude-restart"
    chmod +x "$INSTALL_DIR/claude-restart"

    # 4. Check for existing sentinel
    if grep -qF "$SENTINEL_START" "$ZSHRC" 2>/dev/null; then
        echo "claude-restart: already configured in $ZSHRC (skipping)"
    else
        # 5. Append shell function block
        cat >> "$ZSHRC" << ZSHBLOCK
$SENTINEL_START
export CLAUDE_CONNECT="telegram"
export CLAUDE_RESTART_DEFAULT_OPTS="--dangerously-skip-permissions"
export PATH="$INSTALL_DIR:\$PATH"
claude-restart() {
    if [[ \$# -gt 0 ]]; then
        "$INSTALL_DIR/claude-wrapper" "\$@"
    else
        # shellcheck disable=SC2086
        "$INSTALL_DIR/claude-wrapper" \$CLAUDE_RESTART_DEFAULT_OPTS
    fi
}
$SENTINEL_END
ZSHBLOCK
        echo "Added shell function to $ZSHRC"
    fi

    # 6. Print success
    echo "Installed claude-wrapper to $INSTALL_DIR/claude-wrapper"
    echo "Installed claude-restart to $INSTALL_DIR/claude-restart"
    echo "Run 'source $ZSHRC' or open a new terminal to start using claude-restart"
}

do_uninstall() {
    # 1. Remove scripts
    rm -f "$INSTALL_DIR/claude-wrapper" "$INSTALL_DIR/claude-restart"
    rm -f "$INSTALL_DIR/claude-service"

    # 2. Remove sentinel block from zshrc
    if grep -qF "$SENTINEL_START" "$ZSHRC" 2>/dev/null; then
        sed_inplace "/$SENTINEL_START/,/$SENTINEL_END/d" "$ZSHRC"
        echo "Removed claude-restart configuration from $ZSHRC"
    else
        echo "claude-restart: no configuration found in $ZSHRC"
    fi

    # 3. Remove systemd services if on Linux
    if [[ "$PLATFORM" == "Linux" ]]; then
        # Stop and remove all watchdog timers (template instances)
        for env_dir in "$ENV_DIR"/*/; do
            if [[ -d "$env_dir" ]]; then
                inst_name=$(basename "$env_dir")
                systemctl --user stop "claude-watchdog@${inst_name}.timer" 2>/dev/null || true
                systemctl --user disable "claude-watchdog@${inst_name}.timer" 2>/dev/null || true
            fi
        done
        rm -f "$SYSTEMD_USER_DIR/claude-watchdog@.timer"
        rm -f "$SYSTEMD_USER_DIR/claude-watchdog@.service"
        # Also clean up old non-template units if still present
        rm -f "$SYSTEMD_USER_DIR/claude-watchdog.timer"
        rm -f "$SYSTEMD_USER_DIR/claude-watchdog.service"

        # Stop and remove all template instances
        for env_dir in "$ENV_DIR"/*/; do
            if [[ -d "$env_dir" ]]; then
                inst_name=$(basename "$env_dir")
                systemctl --user stop "claude@${inst_name}.service" 2>/dev/null || true
                systemctl --user disable "claude@${inst_name}.service" 2>/dev/null || true
            fi
        done

        # Remove template unit
        rm -f "$SYSTEMD_USER_DIR/claude@.service"
        # Remove old non-template unit if still present
        rm -f "$SYSTEMD_USER_DIR/claude.service"

        # Remove all env directories
        rm -rf "$ENV_DIR"
        echo "Removed systemd services, watchdog timer, and env files"
    fi

    # 4. Print success
    echo "Uninstalled claude-restart from $INSTALL_DIR"
}

# Parse arguments
case "${1:-}" in
    --uninstall)
        do_uninstall
        ;;
    --help)
        usage
        ;;
    --install|"")
        if [[ "$PLATFORM" == "Linux" ]]; then
            do_install_linux
        else
            do_install_macos
        fi
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
esac
