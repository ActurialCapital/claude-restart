# Phase 7: Template Unit Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-22
**Phase:** 07-template-unit-foundation
**Areas discussed:** Instance naming & directory layout, Backward compatibility strategy, Memory limits & cgroup config, Instance-aware script behavior

---

## Instance Naming & Directory Layout

### Naming rules

| Option | Description | Selected |
|--------|-------------|----------|
| Freeform (any string) | User picks any name — risk of spaces/special chars breaking systemd | |
| Alphanumeric + hyphens only | Matches systemd conventions, safe for file paths | ✓ |
| Match directory name | Instance name must equal project folder basename | |

**User's choice:** Alphanumeric + hyphens only
**Notes:** None

### Config directory pattern

| Option | Description | Selected |
|--------|-------------|----------|
| ~/.config/claude-restart/<name>/env | Subdirectory per instance | ✓ |
| ~/.config/claude-restart/instances/<name>.env | Flat directory with named files | |
| Same dir, prefixed files | env.<name> pattern | |

**User's choice:** Subdirectory per instance
**Notes:** User asked "what is easier to debug, most intuitive and best practice?" — answered that subdirectories match systemd conventions, are most debuggable (ls shows instances), and support future per-instance files.

### Working directory storage

| Option | Description | Selected |
|--------|-------------|----------|
| In the env file | WORKING_DIRECTORY in env, single source of truth | ✓ |
| Separate path file | workdir file in instance directory | |
| You decide | Claude picks | |

**User's choice:** In the env file
**Notes:** None

---

## Backward Compatibility Strategy

### Service coexistence

| Option | Description | Selected |
|--------|-------------|----------|
| Keep both units | claude.service stays, claude@.service added | |
| Replace with template + default instance | Remove claude.service, use claude@default.service | ✓ |

**User's choice:** Replace with template + default instance
**Notes:** None

### Default instance name

| Option | Description | Selected |
|--------|-------------|----------|
| "default" | claude@default.service — clear, conventional | ✓ |
| "main" | Familiar from git branch naming | |
| "claude" | Self-referential, matches old service name | |

**User's choice:** "default"
**Notes:** None

### No-instance behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Target 'default' automatically | Seamless upgrade from v1.1 | ✓ |
| Error if multiple instances exist | Prevents accidental wrong-target | |

**User's choice:** Target 'default' automatically
**Notes:** None

---

## Memory Limits & Cgroup Config

### MemoryMax configuration method

| Option | Description | Selected |
|--------|-------------|----------|
| Env var in instance env file | CLAUDE_MEMORY_MAX in env, template reads it | ✓ |
| Hardcoded default, override via drop-in | More systemd-native but harder from phone | |

**User's choice:** Env var in instance env file
**Notes:** None

### Default MemoryMax value

| Option | Description | Selected |
|--------|-------------|----------|
| 512M | Conservative, catches leaks early | |
| 1G | Generous, less likely to hit during normal use | ✓ |
| 2G | More headroom but limits concurrent instances | |

**User's choice:** 1G
**Notes:** User has 8GB VPS. 1G per instance allows 3-4 concurrent instruments with ~4GB left for OS.

---

## Instance-Aware Script Behavior

### Wrapper instance identity

| Option | Description | Selected |
|--------|-------------|----------|
| CLAUDE_INSTANCE_NAME env var | Set in env file, wrapper reads it | ✓ |
| Derive from systemd %i specifier | Passed as argument via ExecStart | |

**User's choice:** CLAUDE_INSTANCE_NAME env var
**Notes:** Consistent with existing CLAUDE_CONNECT pattern.

### claude-restart kill mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| systemctl --user restart claude@<name> | Let systemd handle it, PPID walk as fallback | ✓ |
| PID file per instance | Wrapper writes PID, restart reads it | |

**User's choice:** systemctl --user restart
**Notes:** None

### claude-service instance awareness

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, optional instance arg | claude-service status [name], defaults to 'default' | ✓ |
| Defer to Phase 8 | Phase 8 lifecycle tooling will replace/extend it | |

**User's choice:** Yes, optional instance arg
**Notes:** None

---

## Claude's Discretion

- Template unit specifier usage (%i, %h)
- Env file variable ordering and comments
- Installer migration strategy details

## Deferred Ideas

None — discussion stayed within phase scope
