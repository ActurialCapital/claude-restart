---
phase: 12-peers-teardown
validated: 2026-03-27
status: green
requirements_covered: [CLNP-01, CLNP-02, CLNP-03, CLNP-04, CLNP-05]
test_file: test/test-peers-teardown.sh
test_command: bash test/test-peers-teardown.sh
---

# Phase 12: Peers Teardown -- Validation Map

## Automated Test Coverage

| Requirement | Test Description | Test Command | Status |
|-------------|-----------------|--------------|--------|
| CLNP-01 | claude-service has no .mcp.json/claude-peers provisioning; no .mcp.json in repo | `bash test/test-peers-teardown.sh` | green |
| CLNP-02 | CLAUDE_CHANNELS absent from env.template, claude-wrapper, claude-service, install.sh | `bash test/test-peers-teardown.sh` | green |
| CLNP-03 | No --dangerously-load-development-channels, no channel_args; 3 clean claude invocations | `bash test/test-peers-teardown.sh` | green |
| CLNP-04 | bin/message-watcher absent; no sidecar refs in wrapper; install.sh clean; channels test deleted | `bash test/test-peers-teardown.sh` | green |
| CLNP-05 | No claude-peers/broker refs in install.sh, claude-service, env.template, systemd templates | `bash test/test-peers-teardown.sh` | green |

## Test Inventory (21 assertions)

| # | Requirement | Assertion |
|---|-------------|-----------|
| 1 | CLNP-01 | claude-service has no .mcp.json or claude-peers provisioning |
| 2 | CLNP-01 | no .mcp.json files in repository |
| 3 | CLNP-02 | env.template has no CLAUDE_CHANNELS |
| 4 | CLNP-02 | claude-wrapper has no CLAUDE_CHANNELS references |
| 5 | CLNP-02 | claude-service has no CLAUDE_CHANNELS references |
| 6 | CLNP-02 | install.sh has no CLAUDE_CHANNELS references |
| 7 | CLNP-03 | claude-wrapper has no --dangerously-load-development-channels flag |
| 8 | CLNP-03 | claude-wrapper has no channel_args variable |
| 9 | CLNP-03 | exactly 3 claude command invocations use mode_args + current_args |
| 10 | CLNP-04 | bin/message-watcher does not exist |
| 11 | CLNP-04 | claude-wrapper has no message-watcher sidecar references |
| 12 | CLNP-04 | install.sh does not deploy message-watcher |
| 13 | CLNP-04 | test-wrapper-channels.sh has been deleted |
| 14 | CLNP-05 | install.sh has no claude-peers/broker references |
| 15 | CLNP-05 | claude-service has no claude-peers/broker references |
| 16 | CLNP-05 | env.template has no claude-peers/broker references |
| 17 | CLNP-05 | systemd templates have no claude-peers/broker dependencies |
| 18 | cross | bash syntax valid: bin/claude-wrapper |
| 19 | cross | bash syntax valid: bin/install.sh |
| 20 | cross | bash syntax valid: bin/claude-service |
| 21 | cross | test-orchestra.sh passes (regression check) |

## Human Verification (from VERIFICATION.md)

Two items remain human-only (cannot be automated without a live environment):

1. **CLNP-01 traceability** -- Confirm REQUIREMENTS.md row updated to Complete per D-02 scope
2. **do_add_orchestra runtime** -- Run `claude-service add-orchestra` on a VPS to confirm ~/.claude.json gets remoteDialogSeen=true

## Compliance

- All 5 requirements have automated test coverage
- 21/21 assertions pass
- No implementation files were modified
- Test follows project conventions (bash test script in test/ directory)
