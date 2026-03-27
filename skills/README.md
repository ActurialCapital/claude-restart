# Skills

Skills are no longer vendored in this repository.

During installation, `install.sh` clones skills from their upstream repositories:

- **GSD (Get Shit Done):** https://github.com/gsd-build/get-shit-done -> `~/.claude/get-shit-done/`

The `deploy_skills()` function in `bin/install.sh` handles both fresh clones and updates (git pull).
