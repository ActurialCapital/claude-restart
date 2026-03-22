---
status: partial
phase: 05-systemd-service
source: [05-VERIFICATION.md]
started: 2026-03-21T00:00:00Z
updated: 2026-03-21T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Real VPS deployment
expected: Run `bash bin/install.sh` on Linux VPS. Unit file deployed to `~/.config/systemd/user/claude.service`, env file at `~/.config/claude-restart/env` (mode 600), `claude-service` in `~/.local/bin/`, `systemctl --user status claude.service` shows active/running.
result: [pending]

### 2. Boot persistence after SSH logout
expected: After install, log out of SSH, wait a few seconds, log back in, run `systemctl --user status claude.service`. Service is still active/running (linger effective, unit enabled).
result: [pending]

### 3. Crash recovery (Restart=on-failure)
expected: `kill $(systemctl --user show -p MainPID --value claude.service)` to simulate crash. Wait 5 seconds. `systemctl --user status claude.service` shows active/running again.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
