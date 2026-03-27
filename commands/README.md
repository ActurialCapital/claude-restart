# Commands

Commands are no longer vendored in this repository.

During installation, `install.sh` clones commands from their upstream repositories:

- **Superpowers:** https://github.com/obra/superpowers -> `~/.claude/commands/`

The `deploy_skills()` function in `bin/install.sh` handles both fresh clones and updates (git pull).
