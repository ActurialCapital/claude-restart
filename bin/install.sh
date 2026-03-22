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
ENV_FILE="$ENV_DIR/env"

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

do_install_linux() {
    # 1. Copy scripts to install dir
    mkdir -p "$INSTALL_DIR"
    cp "$SCRIPT_DIR/claude-wrapper" "$INSTALL_DIR/claude-wrapper"
    chmod +x "$INSTALL_DIR/claude-wrapper"
    cp "$SCRIPT_DIR/claude-restart" "$INSTALL_DIR/claude-restart"
    chmod +x "$INSTALL_DIR/claude-restart"
    cp "$SCRIPT_DIR/claude-service" "$INSTALL_DIR/claude-service"
    chmod +x "$INSTALL_DIR/claude-service"

    # 2. Prompt for working directory (per D-10)
    read -rp "Working directory for Claude [$(pwd)]: " WORK_DIR
    WORK_DIR="${WORK_DIR:-$(pwd)}"

    # 3. Create env file (per D-11)
    mkdir -p "$ENV_DIR"
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
        if [[ -n "$NODE_VERSION" ]]; then
            sed_inplace "s|NODEVERSION_PLACEHOLDER|$NODE_VERSION|g" "$ENV_FILE"
        else
            # Remove the nvm path segment if no node found
            sed_inplace "/NODEVERSION_PLACEHOLDER/d" "$ENV_FILE"
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

    # 4. Install systemd unit file (per D-01, D-06)
    mkdir -p "$SYSTEMD_USER_DIR"
    cp "$SCRIPT_DIR/../systemd/claude.service" "$SYSTEMD_USER_DIR/claude.service"
    sed_inplace "s|WORKING_DIR_PLACEHOLDER|$WORK_DIR|" "$SYSTEMD_USER_DIR/claude.service"
    echo "Installed systemd unit file to $SYSTEMD_USER_DIR/claude.service"

    # 5. Enable linger and start service (per D-08, D-09)
    # Enable linger for boot persistence (per D-08)
    loginctl enable-linger "$USER" 2>/dev/null || echo "Warning: loginctl enable-linger failed (may need root)"

    # Reload, enable, and start (per D-09)
    systemctl --user daemon-reload
    systemctl --user enable claude.service
    systemctl --user start claude.service
    echo "Claude service enabled and started"
    echo "Manage with: claude-service {start|stop|restart|status|logs}"
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

    # 3. Remove systemd service if on Linux
    if [[ "$PLATFORM" == "Linux" ]]; then
        systemctl --user stop claude.service 2>/dev/null || true
        systemctl --user disable claude.service 2>/dev/null || true
        rm -f "$SYSTEMD_USER_DIR/claude.service"
        rm -f "$ENV_FILE"
        echo "Removed systemd service and env file"
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
