---
status: complete
phase: 01-wrapper-script
source: [01-01-SUMMARY.md]
started: 2026-03-20T23:36:00Z
updated: 2026-03-20T23:50:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Wrapper launches claude with CLI args
expected: Run `bin/claude-wrapper --resume`. Claude starts with `--resume` passed through as an argument.
result: pass

### 2. Restart on signal file
expected: While claude is running via the wrapper, create `~/.claude-restart` (in home dir, not project root) and exit claude normally. The wrapper detects the file and relaunches claude automatically after a brief pause.
result: pass

### 3. New args from restart file
expected: Write new args (e.g., `--verbose`) into `~/.claude-restart` (home dir) and exit claude. The wrapper relaunches claude with the new args from the file instead of the original ones.
result: pass

### 4. Clean exit without restart file
expected: Run claude via the wrapper. Exit claude normally without creating `~/.claude-restart`. The wrapper exits cleanly (no restart loop).
result: pass

### 5. Ctrl+C kills wrapper
expected: Run claude via the wrapper. Press Ctrl+C. Both claude and the wrapper exit immediately — no restart occurs.
result: pass

### 6. Safety valve after max restarts
expected: If the restart file keeps reappearing (10 consecutive restarts), the wrapper stops with a warning message instead of looping forever.
result: skipped
reason: user skipped

## Summary

total: 6
passed: 5
issues: 0
pending: 0
skipped: 1

## Gaps

[none]
