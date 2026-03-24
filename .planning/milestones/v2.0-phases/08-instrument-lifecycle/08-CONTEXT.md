# Phase 8: Instrument Lifecycle - Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Single-command instrument lifecycle management. User can add, remove, and list instruments. Each instrument automatically gets a per-instance watchdog timer. Add clones a repo and wires up everything; remove tears down everything (config + repo clone). List shows all instruments with status.

Requirements: LIFE-01, LIFE-02, LIFE-03, WDOG-04, WDOG-05

</domain>

<decisions>
## Implementation Decisions

### Tooling Location
- **D-01:** Extend `claude-service` with `add`, `remove`, and `list` subcommands. One management entry point for everything (follows systemctl/docker pattern). No new scripts.

### Manifest / Source of Truth
- **D-02:** Filesystem convention — each subdirectory in `~/.config/claude-restart/` IS an instrument. No separate manifest file. `list` scans dirs, `add` creates one, `remove` deletes one.

### Add Workflow
- **D-03:** `claude-service add <name> <git-url>` — clones repo to `~/instruments/<name>/`, creates env dir, populates env from template, enables systemd service + watchdog timer.
- **D-04:** API key copied from `default` instance's env file (no interactive prompts — must work via `claude -p` from orchestra).
- **D-05:** Defaults: `CLAUDE_MEMORY_MAX=1G`, `CLAUDE_WATCHDOG_HOURS=8`. User edits env file after to customize.
- **D-06:** Clone destination is always `~/instruments/<name>/` — dedicated directory for all instrument repos.

### Remove Workflow
- **D-07:** `claude-service remove <name>` does full cleanup: stop service, disable systemd units (service + watchdog), delete env dir (`~/.config/claude-restart/<name>/`), AND delete working directory (`~/instruments/<name>/`).
- **D-08:** No confirmation prompts, no safety checks. Clones are disposable — repos live on GitHub. No dead folders on VPS.

### Watchdog Templating
- **D-09:** Template the watchdog timer and service per-instance (`claude-watchdog@.timer`, `claude-watchdog@.service`) so each instrument gets its own watchdog.
- **D-10:** `add` enables the watchdog timer; `remove` disables it (per WDOG-04, WDOG-05).

### Claude's Discretion
- List output format (table, plain text, etc.) — whatever is readable on a phone terminal
- Validation details (name format checks, path existence, duplicate detection)
- Error messages and edge case handling
- Watchdog template unit internals (how `claude-watchdog@.service` reads per-instance env)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Scripts to Modify
- `bin/claude-service` — Adding `add`, `remove`, `list` subcommands here
- `bin/install.sh` — May need updates for watchdog template deployment

### Existing systemd Units
- `systemd/claude@.service` — Template unit from Phase 7 (reference for watchdog templating pattern)
- `systemd/claude-watchdog.service` — Current single-instance watchdog (needs templating to `claude-watchdog@.service`)
- `systemd/claude-watchdog.timer` — Current single-instance timer (needs templating to `claude-watchdog@.timer`)
- `systemd/env.template` — Env template with all per-instance vars (used by `add` to populate new instrument env)

### Requirements
- `.planning/REQUIREMENTS.md` — LIFE-01, LIFE-02, LIFE-03, WDOG-04, WDOG-05

### Prior Phase Context
- `.planning/phases/07-template-unit-foundation/07-CONTEXT.md` — Instance naming conventions (D-01), directory layout (D-02, D-03), backward compatibility (D-05 through D-08)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `claude-service` already has instance routing (`INSTANCE="${2:-default}"`, `SERVICE="claude@${INSTANCE}.service"`) — extend with new case branches
- `env.template` has all placeholders (`INSTANCE_PLACEHOLDER`, `WORKING_DIR_PLACEHOLDER`, `HOME_PLACEHOLDER`, `NODEVERSION_PLACEHOLDER`) — `add` command fills these in
- `install.sh` has `sed_inplace()` for cross-platform sed and `migrate_v1_env()` as pattern for env file manipulation

### Established Patterns
- Environment variable-driven config (CLAUDE_CONNECT, CLAUDE_INSTANCE_NAME, CLAUDE_MEMORY_MAX)
- systemd template units with `%i` for instance name, `%h` for home directory
- Installer uses sentinel markers for idempotent modifications

### Integration Points
- `add` creates `~/.config/claude-restart/<name>/env` + `~/instruments/<name>/` (clone)
- `add` enables `claude@<name>.service` + `claude-watchdog@<name>.timer`
- `remove` reverses both: disables units + deletes both directories
- `list` scans `~/.config/claude-restart/*/env` and queries `systemctl --user` for status

</code_context>

<specifics>
## Specific Ideas

- User manages VPS from phone via remote-control — all commands must work non-interactively (no prompts, no confirmations)
- Orchestra will call these commands via `claude -p` — zero-prompt design is critical
- Repos are disposable clones from GitHub — full cleanup on remove is the right default
- `~/instruments/` as dedicated clone directory keeps instrument repos separate from any other files

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-instrument-lifecycle*
*Context gathered: 2026-03-22*
