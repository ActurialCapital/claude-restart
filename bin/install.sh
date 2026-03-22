#!/bin/bash
# install.sh: install claude-restart scripts and shell integration
set -euo pipefail

INSTALL_DIR="${CLAUDE_RESTART_INSTALL_DIR:-$HOME/.local/bin}"
ZSHRC="${CLAUDE_RESTART_ZSHRC:-$HOME/.zshrc}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SENTINEL_START="# >>> claude-restart >>>"
SENTINEL_END="# <<< claude-restart <<<"

usage() {
    echo "Usage: install.sh [--install | --uninstall | --help]"
}

do_install() {
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

    # 2. Remove sentinel block from zshrc
    if grep -qF "$SENTINEL_START" "$ZSHRC" 2>/dev/null; then
        sed -i '' "/$SENTINEL_START/,/$SENTINEL_END/d" "$ZSHRC"
        echo "Removed claude-restart configuration from $ZSHRC"
    else
        echo "claude-restart: no configuration found in $ZSHRC"
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
        do_install
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
esac
