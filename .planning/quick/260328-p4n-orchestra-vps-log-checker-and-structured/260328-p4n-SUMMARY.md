---
phase: quick
plan: 260328-p4n
subsystem: operations
tags: [health, monitoring, orchestra, vps]
dependency_graph:
  requires: [systemd, journalctl, claude-service]
  provides: [claude-health, claude-service-health-subcommand]
  affects: [orchestra/CLAUDE.md]
tech_stack:
  added: []
  patterns: [systemctl-show-property-queries, journalctl-filtering]
key_files:
  created:
    - bin/claude-health
  modified:
    - bin/claude-service
decisions:
  - "Standalone script (bin/claude-health) with claude-service delegation rather than inline in claude-service"
  - "JSON uses simple cat heredoc approach rather than jq dependency for portability"
  - "grep -oP for exit code parsing (Linux-only, acceptable since VPS target is Linux)"
metrics:
  duration: 104s
  completed: 2026-03-28
  tasks: 2
  files: 2
---

# Quick Task 260328-p4n: Orchestra VPS Log Checker and Structured Health Report

Standalone claude-health script querying systemd/journalctl for per-instance fleet health with markdown and JSON output modes.

## Task Summary

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create bin/claude-health report script | 8c6b9e7 | bin/claude-health |
| 2 | Wire into claude-service as health subcommand | a63cf02 | bin/claude-service |

## What Was Built

`bin/claude-health` (363 lines) -- a bash script that produces structured health reports for all `claude@` service instances on the VPS.

**Markdown mode** (default) produces per-instance sections:
1. Status Summary (state, PID, uptime, memory)
2. Recent Lifecycle Events (last 24h, filtered from journalctl)
3. Exit Codes (parsed from claude-wrapper output)
4. Memory Stats (cgroup + /proc if available)
5. Errors/Warnings (last 24h, noise-filtered)
6. Watchdog timer status

**JSON mode** (`--json`) produces a machine-readable object with `timestamp` and `instances` array, suitable for orchestra consumption via `claude-health --json`.

**Integration:** `claude-service health [--json] [instance]` delegates to `claude-health` via exec.

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED
