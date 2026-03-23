# Phase 7: Template Unit Foundation - Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Isolated multi-instance systemd infrastructure. Any instrument can run as its own systemd service (`claude@<name>.service`) with separate config, restart file, and memory limit. Existing single-instance behavior migrates to a "default" instance. Wrapper and restart scripts become instance-aware.

Requirements: INST-01, INST-02, INST-03, INST-04, INST-05, WRAP-05, WRAP-06

</domain>

<decisions>
## Implementation Decisions

### Instance Naming & Directory Layout
- **D-01:** Instance names must be alphanumeric + hyphens only (matches systemd unit naming conventions, safe for file paths)
- **D-02:** Per-instance config lives at `~/.config/claude-restart/<name>/env` (subdirectory per instance)
- **D-03:** Per-instance restart file lives at `~/.config/claude-restart/<name>/restart`
- **D-04:** Working directory is stored in the instance env file as `WORKING_DIRECTORY=<path>` (single source of truth, read by systemd template)

### Backward Compatibility
- **D-05:** Replace `claude.service` with `claude@.service` template unit. Single-instance mode becomes `claude@default.service`
- **D-06:** Default instance is named `"default"` — config at `~/.config/claude-restart/default/env`
- **D-07:** When scripts are called without `--instance`, they target the `"default"` instance automatically (seamless v1.1 upgrade)
- **D-08:** Installer migrates existing `~/.config/claude-restart/env` into `~/.config/claude-restart/default/env`

### Memory Limits & Cgroup Config
- **D-09:** `MemoryMax` is configured via `CLAUDE_MEMORY_MAX` env var in the per-instance env file
- **D-10:** Template unit reads `MemoryMax=${CLAUDE_MEMORY_MAX}` — no systemd drop-ins needed
- **D-11:** Default `CLAUDE_MEMORY_MAX=1G` in the env template (user has 8GB VPS, supports 3-4 concurrent instances)

### Instance-Aware Scripts
- **D-12:** Wrapper reads `CLAUDE_INSTANCE_NAME` env var (set in per-instance env file) and passes `--name $CLAUDE_INSTANCE_NAME` to `claude remote-control`
- **D-13:** `claude-restart --instance <name>` uses `systemctl --user restart claude@<name>` (no PID hunting). PPID walk becomes fallback for non-systemd environments (macOS dev)
- **D-14:** `claude-service` becomes instance-aware: `claude-service status [name]` defaults to `"default"` when name omitted

### Claude's Discretion
- Template unit specifier usage (`%i` for instance name, `%h` for home) — implementation detail
- Env file variable ordering and comments
- Installer migration strategy details (backup existing env, create default/ subdirectory)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Infrastructure (v1.1 baseline)
- `systemd/claude.service` — current single-instance unit (being replaced by template)
- `systemd/claude-watchdog.service` — watchdog oneshot (Phase 8 will template this)
- `systemd/claude-watchdog.timer` — watchdog timer (Phase 8 will template this)
- `systemd/env.template` — current env template (needs CLAUDE_INSTANCE_NAME, CLAUDE_MEMORY_MAX, WORKING_DIRECTORY additions)

### Scripts to Modify
- `bin/claude-wrapper` — needs CLAUDE_INSTANCE_NAME → --name passthrough
- `bin/claude-restart` — needs --instance flag with systemctl restart path
- `bin/claude-service` — needs optional instance argument routing
- `bin/install.sh` — needs migration logic and template unit deployment

### Requirements
- `.planning/REQUIREMENTS.md` — INST-01 through INST-05, WRAP-05, WRAP-06

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `claude-wrapper` already reads `CLAUDE_RESTART_FILE` env var — restart file isolation is ready, just needs the per-instance path set in env
- `claude-wrapper` mode selection via `CLAUDE_CONNECT` env var — same pattern for `CLAUDE_INSTANCE_NAME`
- `claude.service` uses `EnvironmentFile=%h/.config/claude-restart/env` — template version uses `%h/.config/claude-restart/%i/env`

### Established Patterns
- Environment variable-driven configuration (CLAUDE_CONNECT, CLAUDE_RESTART_FILE, CLAUDE_WRAPPER_MAX_RESTARTS)
- systemd `%h` specifier for home directory paths
- Installer uses sentinel markers for idempotent modifications

### Integration Points
- Template unit `claude@.service` replaces `claude.service` — installer must handle migration
- `claude-restart --instance` needs to write restart file AND trigger systemctl restart
- `claude-service` routes to `claude@<name>.service` instead of `claude.service`

</code_context>

<specifics>
## Specific Ideas

- VPS has 8GB RAM — 1G per instance default allows 3-4 comfortable concurrent instruments
- User manages VPS from phone — all config should be in env files (no systemd drop-ins or manual editing of unit files)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-template-unit-foundation*
*Context gathered: 2026-03-22*
