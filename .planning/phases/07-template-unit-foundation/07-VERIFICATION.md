---
phase: 07-template-unit-foundation
verified: 2026-03-22T23:30:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 7: Template Unit Foundation Verification Report

**Phase Goal:** Any instrument can run as an isolated systemd instance with its own config, restart file, and memory limit -- and the wrapper/restart scripts know which instance they belong to
**Verified:** 2026-03-22T23:30:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can start an instrument by name with `systemctl --user start claude@myproject` and it reads from `~/.config/claude-restart/myproject/env` | VERIFIED | `systemd/claude@.service` line 10: `EnvironmentFile=%h/.config/claude-restart/%i/env`; installer deploys unit to systemd user dir |
| 2 | Two instruments running simultaneously use separate restart files and do not interfere with each other | VERIFIED | `env.template` sets `CLAUDE_RESTART_FILE=HOME_PLACEHOLDER/.config/claude-restart/INSTANCE_PLACEHOLDER/restart`; installer substitutes per instance; `claude-wrapper` reads `$CLAUDE_RESTART_FILE` |
| 3 | Each instrument is cgroup-limited by MemoryMax so one runaway instance cannot OOM the VPS | VERIFIED | `systemd/claude@.service` line 11: `ExecStartPre=/bin/bash -c 'systemctl --user set-property claude@%i.service MemoryMax=${CLAUDE_MEMORY_MAX:-1G} 2>/dev/null || true'`; default 1G in `env.template` |
| 4 | Running scripts without an instance name behaves identically to v1.1 single-instance mode | VERIFIED | `claude-wrapper`: no `--name` flag when `CLAUDE_INSTANCE_NAME` unset or "default"; `claude-restart`: falls back to PPID walk; `claude-service`: `INSTANCE="${2:-default}"` routes to `claude@default.service` |
| 5 | Wrapper passes `--name <instance>` to `claude remote-control` and `claude-restart --instance <name>` targets the correct instrument | VERIFIED | `bin/claude-wrapper` lines 24-26: `mode_args+=("--name" "$CLAUDE_INSTANCE_NAME")` in remote-control case; `bin/claude-restart` lines 65-70: `systemctl --user restart "claude@${INSTANCE}.service"` |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `systemd/claude@.service` | Template unit for multi-instance Claude | VERIFIED | 20 lines; contains `%i` specifier (3 occurrences), `EnvironmentFile=%h/.config/claude-restart/%i/env`, `ExecStartPre` with dynamic `MemoryMax` |
| `systemd/env.template` | Per-instance env template with new variables | VERIFIED | 27 lines; contains `CLAUDE_INSTANCE_NAME`, `WORKING_DIRECTORY`, `CLAUDE_RESTART_FILE`, `CLAUDE_MEMORY_MAX` with installer placeholders |
| `bin/claude-wrapper` | Instance-aware wrapper with --name passthrough | VERIFIED | 140 lines; `CLAUDE_INSTANCE_NAME` check in remote-control case; `WORKING_DIRECTORY` cd at startup; all original functionality preserved |
| `bin/claude-restart` | Instance-targeted restart via systemctl | VERIFIED | 97 lines; `--instance` flag parsing; instance-aware restart file path; `systemctl --user restart "claude@${INSTANCE}.service"`; PPID walk fallback |
| `bin/claude-service` | Instance-aware service management | VERIFIED | 63 lines; `SERVICE="claude@${INSTANCE}.service"`; `INSTANCE="${2:-default}"`; journalctl filters by instance |
| `bin/install.sh` | Instance-aware installer with migration | VERIFIED | 278 lines; `migrate_v1_env()` function; `claude@.service` deployment; per-instance env at `$INSTANCE_DIR/env`; old `claude.service` removal; template-aware uninstall |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `systemd/claude@.service` | `~/.config/claude-restart/%i/env` | `EnvironmentFile` directive with `%i` specifier | WIRED | Line 10: `EnvironmentFile=%h/.config/claude-restart/%i/env` |
| `systemd/claude@.service` | `MemoryMax` cgroup limit | `ExecStartPre` + `systemctl set-property` | WIRED | Line 11: reads `${CLAUDE_MEMORY_MAX:-1G}` from env; falls back to 1G |
| `bin/claude-wrapper` | `claude remote-control --name` | `CLAUDE_INSTANCE_NAME` env var | WIRED | Lines 24-26: `mode_args+=("--name" "$CLAUDE_INSTANCE_NAME")` only when non-empty and non-"default" |
| `bin/claude-restart` | `systemctl --user restart claude@` | `--instance` flag | WIRED | Lines 65-70: routes to `claude@${INSTANCE}.service` when instance provided |
| `bin/claude-service` | `claude@.service` | instance argument | WIRED | Lines 8-9: `INSTANCE="${2:-default}"; SERVICE="claude@${INSTANCE}.service"` |
| `bin/install.sh` | `systemd/claude@.service` | `cp` to systemd user dir | WIRED | Line 141: `cp "$SCRIPT_DIR/../systemd/claude@.service" "$SYSTEMD_USER_DIR/claude@.service"` |
| `bin/install.sh` | `~/.config/claude-restart/default/env` | env file creation in instance subdirectory | WIRED | Lines 15-17: `DEFAULT_INSTANCE="default"; INSTANCE_DIR="$ENV_DIR/$DEFAULT_INSTANCE"; ENV_FILE="$INSTANCE_DIR/env"` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INST-01 | 07-01, 07-03 | systemd template unit `claude@.service` runs any instrument by name with per-instance EnvironmentFile | SATISFIED | `systemd/claude@.service` uses `%i` specifier; installer deploys it |
| INST-02 | 07-01, 07-03 | Each instrument has isolated env file at `~/.config/claude-restart/<name>/env` | SATISFIED | `env.template` includes API key, `CLAUDE_CONNECT`, `WORKING_DIRECTORY`; installer creates at `$INSTANCE_DIR/env` |
| INST-03 | 07-01, 07-03 | Each instrument has isolated restart file via per-instance `CLAUDE_RESTART_FILE` | SATISFIED | `env.template` sets `CLAUDE_RESTART_FILE=HOME_PLACEHOLDER/.config/claude-restart/INSTANCE_PLACEHOLDER/restart`; `claude-restart` uses it |
| INST-04 | 07-01 | Each instrument has `MemoryMax` cgroup limit | SATISFIED | `ExecStartPre` in `claude@.service` applies `CLAUDE_MEMORY_MAX` dynamically; `env.template` defaults to `1G` |
| INST-05 | 07-02, 07-03 | No instance name = identical v1.1 behavior | SATISFIED | All three scripts default to backward-compatible behavior; `claude-service` defaults to "default" instance; wrapper skips `--name` when unset |
| WRAP-05 | 07-02 | Wrapper reads `CLAUDE_INSTANCE_NAME` and passes as `--name` to `claude remote-control` | SATISFIED | `bin/claude-wrapper` lines 22-27: conditional `--name` passthrough in remote-control mode |
| WRAP-06 | 07-02 | `claude-restart` accepts `--instance <name>` to restart specific instrument | SATISFIED | `bin/claude-restart` lines 8-27: full `--instance` flag parsing with validation |

All 7 requirements claimed for Phase 7 are verified. No orphaned requirements found.

### Anti-Patterns Found

None. No TODOs, FIXMEs, stub implementations, or unconnected code paths found in any modified file.

Notable: `env.template` contains `INSTANCE_PLACEHOLDER`, `HOME_PLACEHOLDER`, `WORKING_DIR_PLACEHOLDER` -- these are intentional installer substitution markers, not anti-patterns.

### Notable Implementation Details

**WorkingDirectory resolution (fix commit `5b5e14f`):** The original plan specified `WorkingDirectory=${WORKING_DIRECTORY}` in the systemd unit, but systemd cannot expand environment variables in `WorkingDirectory=` directives (only in `Exec*` directives). The fix correctly uses `WorkingDirectory=%h` in the unit and adds a `cd "$WORKING_DIRECTORY"` at the top of `bin/claude-wrapper` instead. This achieves the same functional outcome: the wrapper process changes to the per-instance working directory before launching claude. This fix was committed after the SUMMARY documents were written, which is why SUMMARYs still describe the original intent -- the actual codebase reflects the corrected implementation.

**MemoryMax dynamic application:** systemd cannot expand environment variables in resource control directives (`MemoryMax=`). The workaround via `ExecStartPre` + `systemctl --user set-property` is the correct solution for this constraint.

### Human Verification Required

#### 1. Live systemd instantiation

**Test:** On a Linux VPS with systemd user services, run `systemctl --user start claude@myproject.service` after placing an env file at `~/.config/claude-restart/myproject/env`.
**Expected:** Service starts, reads env file, wrapper launches with `--name myproject`, and `journalctl --user -u "claude@myproject"` shows output.
**Why human:** Requires a running Linux systemd environment; cannot verify systemd unit parsing and instantiation programmatically.

#### 2. MemoryMax application via ExecStartPre

**Test:** After starting `claude@myproject.service`, run `systemctl --user show claude@myproject.service --property=MemoryMax`.
**Expected:** Shows the value from `CLAUDE_MEMORY_MAX` in the instance's env file (e.g., `1073741824` for `1G`).
**Why human:** `systemctl set-property` behavior requires a live systemd session to verify.

#### 3. v1.1 migration flow

**Test:** On a system with an existing flat `~/.config/claude-restart/env` from v1.1, run `bash bin/install.sh`.
**Expected:** `migrate_v1_env()` moves env to `~/.config/claude-restart/default/env`, creates backup at `env.v1-backup`, adds missing variables, and the new service starts correctly.
**Why human:** Requires an existing v1.1 installation; migration logic cannot be fully exercised without it.

#### 4. Two-instance non-interference

**Test:** Start `claude@project-a` and `claude@project-b` simultaneously; trigger `claude-restart --instance project-a`.
**Expected:** Only project-a restarts; project-b continues running uninterrupted with its own restart file.
**Why human:** Requires two live claude processes with distinct systemd instances.

---

_Verified: 2026-03-22T23:30:00Z_
_Verifier: Claude (gsd-verifier)_
