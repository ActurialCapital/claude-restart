# Phase 8: Instrument Lifecycle - Research

**Researched:** 2026-03-23
**Domain:** Bash CLI tooling + systemd template units (timer/service)
**Confidence:** HIGH

## Summary

Phase 8 extends the existing `claude-service` bash script with three new subcommands (`add`, `remove`, `list`) and templates the watchdog timer/service for per-instance use. All building blocks exist: the `claude@.service` template from Phase 7 establishes the pattern, `env.template` has all placeholders, and `install.sh` has reusable sed/env-manipulation functions. The main engineering challenge is the watchdog timer templating -- systemd timers cannot read environment variables for timing directives, so the interval must be hardcoded in the template (8h default per D-05) rather than dynamically read from per-instance env files.

The `add` command is the most complex subcommand: it must clone a repo, create an env file from template with sed placeholder replacement, copy the API key from the default instance, enable both `claude@<name>.service` and `claude-watchdog@<name>.timer`, and do all of this non-interactively (no prompts -- critical for orchestra automation per D-08's design). The `remove` command reverses everything. The `list` command scans the filesystem convention (D-02) and queries systemd for status.

**Primary recommendation:** Implement as three new `case` branches in `claude-service`, convert `claude-watchdog.service` and `claude-watchdog.timer` to template units (`@.` pattern), and update `install.sh` to deploy the new template units. Keep the timer interval hardcoded at 8h in the template -- per-instance customization is a future concern.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Extend `claude-service` with `add`, `remove`, and `list` subcommands. One management entry point for everything (follows systemctl/docker pattern). No new scripts.
- **D-02:** Filesystem convention -- each subdirectory in `~/.config/claude-restart/` IS an instrument. No separate manifest file. `list` scans dirs, `add` creates one, `remove` deletes one.
- **D-03:** `claude-service add <name> <git-url>` -- clones repo to `~/instruments/<name>/`, creates env dir, populates env from template, enables systemd service + watchdog timer.
- **D-04:** API key copied from `default` instance's env file (no interactive prompts -- must work via `claude -p` from orchestra).
- **D-05:** Defaults: `CLAUDE_MEMORY_MAX=1G`, `CLAUDE_WATCHDOG_HOURS=8`. User edits env file after to customize.
- **D-06:** Clone destination is always `~/instruments/<name>/` -- dedicated directory for all instrument repos.
- **D-07:** `claude-service remove <name>` does full cleanup: stop service, disable systemd units (service + watchdog), delete env dir (`~/.config/claude-restart/<name>/`), AND delete working directory (`~/instruments/<name>/`).
- **D-08:** No confirmation prompts, no safety checks. Clones are disposable -- repos live on GitHub. No dead folders on VPS.
- **D-09:** Template the watchdog timer and service per-instance (`claude-watchdog@.timer`, `claude-watchdog@.service`) so each instrument gets its own watchdog.
- **D-10:** `add` enables the watchdog timer; `remove` disables it (per WDOG-04, WDOG-05).

### Claude's Discretion
- List output format (table, plain text, etc.) -- whatever is readable on a phone terminal
- Validation details (name format checks, path existence, duplicate detection)
- Error messages and edge case handling
- Watchdog template unit internals (how `claude-watchdog@.service` reads per-instance env)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIFE-01 | User can add an instrument with a single command (clone repo, create env file, enable systemd service, register in manifest) | `add` subcommand in claude-service; env.template + sed pattern from install.sh; git clone + systemctl enable |
| LIFE-02 | User can remove an instrument with a single command (stop service, clean up config, deregister from manifest) | `remove` subcommand; systemctl stop/disable + rm -rf for both dirs |
| LIFE-03 | User can list all instruments with their status (running/stopped/failed) | `list` subcommand; scan ~/.config/claude-restart/*/env + systemctl is-active |
| WDOG-04 | Watchdog timer is templated per-instance and paired automatically with instrument lifecycle | Convert claude-watchdog.{timer,service} to claude-watchdog@.{timer,service} template units |
| WDOG-05 | Adding an instrument enables its watchdog timer; removing an instrument disables it | `add` runs systemctl enable/start claude-watchdog@name.timer; `remove` runs stop/disable |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | 5.x | All CLI scripting | Already used for all project scripts |
| systemd | 252+ | Service and timer management | Already the service manager for all instances |
| git | 2.x | Repository cloning for `add` | Standard, already on VPS |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `sed` | Template placeholder replacement | env.template population (existing pattern from install.sh) |
| `systemctl --user` | Instance management | enable/disable/start/stop/is-active queries |
| `grep` | API key extraction from default env | Extracting ANTHROPIC_API_KEY from default instance |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Filesystem convention (D-02) | JSON manifest file | Filesystem is simpler, no parser needed, but no metadata beyond env vars |
| Hardcoded 8h timer | Per-instance timer files via sed | More flexible but breaks clean template pattern; 8h default covers all use cases initially |

## Architecture Patterns

### Recommended Project Structure Changes
```
systemd/
  claude@.service              # (existing) main service template
  claude-watchdog@.service     # (NEW) replaces claude-watchdog.service
  claude-watchdog@.timer       # (NEW) replaces claude-watchdog.timer
  env.template                 # (existing) used by add command
bin/
  claude-service               # (MODIFIED) add/remove/list subcommands
  install.sh                   # (MODIFIED) deploy new template units
```

### Pattern 1: Subcommand Routing in claude-service
**What:** Extend the existing `case` statement with `add|remove|list` branches
**When to use:** All new lifecycle operations go through claude-service
**Example:**
```bash
case "${1:-}" in
    add)
        # $2 = name, $3 = git-url
        do_add "$2" "$3"
        ;;
    remove)
        do_remove "$2"
        ;;
    list)
        do_list
        ;;
    start|stop|restart|status|logs|watchdog|heartbeat)
        # existing instance-aware routing
        ;;
esac
```

### Pattern 2: Non-Interactive Env File Creation
**What:** Copy env.template, sed-replace placeholders, copy API key from default -- zero prompts
**When to use:** The `add` subcommand (D-04: must work via `claude -p`)
**Example:**
```bash
do_add() {
    local name="$1" git_url="$2"
    local env_dir="$HOME/.config/claude-restart/$name"
    local work_dir="$HOME/instruments/$name"

    # Clone repo
    git clone "$git_url" "$work_dir"

    # Create env from template
    mkdir -p "$env_dir"
    cp "$SCRIPT_DIR/../systemd/env.template" "$env_dir/env"

    # Sed-replace all placeholders
    sed_inplace "s|INSTANCE_PLACEHOLDER|$name|g" "$env_dir/env"
    sed_inplace "s|WORKING_DIR_PLACEHOLDER|$work_dir|g" "$env_dir/env"
    sed_inplace "s|HOME_PLACEHOLDER|$HOME|g" "$env_dir/env"

    # Copy API key from default instance (D-04)
    local api_key
    api_key=$(grep '^ANTHROPIC_API_KEY=' "$HOME/.config/claude-restart/default/env" | cut -d= -f2)
    sed_inplace "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$api_key|" "$env_dir/env"

    # Handle node version
    # ... (same pattern as install.sh)

    chmod 600 "$env_dir/env"

    # Enable systemd units
    systemctl --user daemon-reload
    systemctl --user enable --now "claude@${name}.service"
    systemctl --user enable --now "claude-watchdog@${name}.timer"
}
```

### Pattern 3: Watchdog Template Units
**What:** Convert single-instance watchdog to template units using `%i` specifier
**When to use:** The new `claude-watchdog@.service` and `claude-watchdog@.timer`
**Example (claude-watchdog@.service):**
```ini
[Unit]
Description=Claude Watchdog for %i - mode-aware forced restart

[Service]
Type=oneshot
EnvironmentFile=%h/.config/claude-restart/%i/env
ExecStart=/bin/bash -c '\
  if [ "$CLAUDE_CONNECT" = "remote-control" ]; then \
    echo "claude-watchdog[%i]: skipped restart (remote-control mode)"; \
    exit 0; \
  fi; \
  echo "claude-watchdog[%i]: restarting claude@%i (mode=$CLAUDE_CONNECT)"; \
  systemctl --user restart claude@%i.service'
```

**Example (claude-watchdog@.timer):**
```ini
[Unit]
Description=Claude Watchdog Timer for %i

[Timer]
OnBootSec=8h
OnUnitActiveSec=8h
Unit=claude-watchdog@%i.service

[Install]
WantedBy=timers.target
```

### Pattern 4: List Output for Phone Readability
**What:** Simple columnar output with fixed-width name column, one line per instrument
**Example:**
```bash
do_list() {
    local config_dir="$HOME/.config/claude-restart"
    printf "%-20s %-10s\n" "INSTRUMENT" "STATUS"
    printf "%-20s %-10s\n" "----------" "------"
    for dir in "$config_dir"/*/; do
        [ -d "$dir" ] || continue
        local name
        name=$(basename "$dir")
        local status
        status=$(systemctl --user is-active "claude@${name}.service" 2>/dev/null || echo "unknown")
        printf "%-20s %-10s\n" "$name" "$status"
    done
}
```

### Anti-Patterns to Avoid
- **Interactive prompts in add/remove:** Orchestra calls these via `claude -p`. Any `read -rp` breaks automation (D-04, D-08).
- **Separate manifest file:** The filesystem IS the manifest (D-02). Don't create a JSON/YAML registry.
- **Per-instance timer files generated at add-time:** Use systemd template units (`@.timer`), not sed-generated individual timer files. Templates are cleaner and follow the Phase 7 pattern.
- **Protecting remove with confirmations:** Clones are disposable (D-08). No `read -p "Are you sure?"`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Service status queries | Custom PID checks or process scanning | `systemctl --user is-active` | Authoritative, handles all states (active/inactive/failed/activating) |
| Timer management | cron jobs or custom scheduling | systemd template timers | Already the project's scheduling mechanism; timers survive reboots |
| Instance discovery | Manual registration/manifest | Filesystem scan of `~/.config/claude-restart/*/env` | D-02 decision: filesystem IS the manifest |
| API key propagation | Prompt for key or config wizard | `grep` from default instance env | D-04: copy from default, no prompts |

**Key insight:** Every piece of infrastructure already exists from Phase 7. This phase wires them together with CLI commands, not new infrastructure.

## Common Pitfalls

### Pitfall 1: Forgetting daemon-reload After Template Changes
**What goes wrong:** New template units or modified units aren't picked up by systemd
**Why it happens:** systemd caches unit files; changes require explicit reload
**How to avoid:** Always run `systemctl --user daemon-reload` after deploying/modifying unit files, before any enable/start
**Warning signs:** "Unit file changed on disk" warnings in journal

### Pitfall 2: Timer Not Hardcoded -- Using Env Var Placeholder
**What goes wrong:** `OnBootSec=${CLAUDE_WATCHDOG_HOURS}h` does not work in timer units
**Why it happens:** systemd only expands environment variables in `ExecStart=` and related directives, NOT in timer directives (OnBootSec, OnUnitActiveSec, OnCalendar)
**How to avoid:** Hardcode `8h` in the template timer. If per-instance customization is needed later, use systemd drop-in overrides
**Warning signs:** Timer fails to parse or uses literal string

### Pitfall 3: Instance Name Validation
**What goes wrong:** Names with spaces, slashes, or special characters break systemd unit names and file paths
**Why it happens:** User passes arbitrary string to `add`
**How to avoid:** Validate name matches `^[a-zA-Z0-9][a-zA-Z0-9-]*$` before any operations (per Phase 7 D-01 naming convention)
**Warning signs:** `systemctl enable` fails with cryptic errors

### Pitfall 4: SCRIPT_DIR Resolution in Installed claude-service
**What goes wrong:** `claude-service` is installed to `~/.local/bin/` but needs to find `env.template` relative to the repo
**Why it happens:** The script is copied out of the repo by install.sh; relative paths to `systemd/env.template` break
**How to avoid:** Either embed the template path as a variable set during install, OR copy env.template to a known location (e.g., `~/.config/claude-restart/env.template`), OR have install.sh embed the repo path
**Warning signs:** `add` fails with "file not found" for env.template

### Pitfall 5: Node Version Detection for PATH
**What goes wrong:** New instrument env file has `NODEVERSION_PLACEHOLDER` left unresolved in PATH
**Why it happens:** install.sh detects node version interactively; `add` must do the same non-interactively
**How to avoid:** Detect node version the same way install.sh does (`node --version | sed 's/^v//'`) and apply same sed logic. Or copy PATH line from default instance's env (since all instances run on same VPS)
**Warning signs:** Claude CLI not found when service starts

### Pitfall 6: Existing Default Watchdog Must Be Migrated
**What goes wrong:** After templating, old `claude-watchdog.timer` and `claude-watchdog.service` still exist and conflict
**Why it happens:** install.sh currently deploys non-template watchdog units; Phase 8 replaces with template units
**How to avoid:** install.sh must remove old `claude-watchdog.timer`/`claude-watchdog.service` and deploy `claude-watchdog@.timer`/`claude-watchdog@.service`, then enable `claude-watchdog@default.timer` for backward compatibility
**Warning signs:** Two timers firing for the same instance

## Code Examples

### Verified Pattern: API Key Extraction from Default Instance
```bash
# Source: existing install.sh pattern for reading env files
api_key=$(grep '^ANTHROPIC_API_KEY=' "$HOME/.config/claude-restart/default/env" | cut -d= -f2)
```

### Verified Pattern: sed_inplace Cross-Platform
```bash
# Source: bin/install.sh lines 21-27
sed_inplace() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}
```

### Verified Pattern: Instance Enumeration from Filesystem
```bash
# Source: bin/install.sh do_uninstall (lines 236-242) -- iterates env dirs
for env_dir in "$ENV_DIR"/*/; do
    if [[ -d "$env_dir" ]]; then
        inst_name=$(basename "$env_dir")
        # ... operate on instance
    fi
done
```

### Verified Pattern: systemd Template Unit with %i
```ini
# Source: systemd/claude@.service (existing, working)
EnvironmentFile=%h/.config/claude-restart/%i/env
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `claude-watchdog.service` | `claude-watchdog@.service` template | Phase 8 | Each instrument gets own watchdog |
| Hardcoded env path in watchdog | `%i`-parameterized env path | Phase 8 | Watchdog reads correct instance env |
| Manual instance setup | `claude-service add` | Phase 8 | One-command instrument provisioning |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash test scripts (custom assert functions) |
| Config file | None (scripts in `test/` directory) |
| Quick run command | `bash test/test-install.sh` |
| Full suite command | `for t in test/test-*.sh; do bash "$t"; done` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIFE-01 | `add` creates env, clones repo, enables service+timer | unit | `bash test/test-service-lifecycle.sh` | No -- Wave 0 |
| LIFE-02 | `remove` stops service, disables units, deletes dirs | unit | `bash test/test-service-lifecycle.sh` | No -- Wave 0 |
| LIFE-03 | `list` shows all instruments with status | unit | `bash test/test-service-lifecycle.sh` | No -- Wave 0 |
| WDOG-04 | Watchdog template units deployed and functional | unit | `bash test/test-service-lifecycle.sh` | No -- Wave 0 |
| WDOG-05 | `add` enables watchdog timer; `remove` disables it | unit | `bash test/test-service-lifecycle.sh` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `bash test/test-service-lifecycle.sh`
- **Per wave merge:** `for t in test/test-*.sh; do bash "$t"; done`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/test-service-lifecycle.sh` -- covers LIFE-01, LIFE-02, LIFE-03, WDOG-04, WDOG-05
  - Must mock `systemctl`, `git clone`, filesystem operations (same tmpdir pattern as test-install.sh)
  - Tests run on macOS (dev machine) so systemctl calls must be stubbed

## Open Questions

1. **env.template Location at Runtime**
   - What we know: `claude-service` is installed to `~/.local/bin/`, but `env.template` lives in the repo at `systemd/env.template`
   - What's unclear: How does `add` find `env.template` after installation? The script is copied out of the repo.
   - Recommendation: Have `install.sh` copy `env.template` to `~/.config/claude-restart/env.template` as a known location. The `add` command reads from there.

2. **Old Watchdog Migration Path**
   - What we know: Current install.sh deploys `claude-watchdog.timer` and `claude-watchdog.service` (non-template). Phase 8 replaces with `@.` templates.
   - What's unclear: Should install.sh handle migration (stop old, deploy new, enable default), or is this a separate task?
   - Recommendation: install.sh should handle it -- same pattern as Phase 7's migration of `claude.service` to `claude@.service` (lines 144-150 of install.sh).

3. **Node Version in PATH for New Instruments**
   - What we know: env.template has `NODEVERSION_PLACEHOLDER` in PATH. install.sh detects via `node --version`.
   - What's unclear: Should `add` detect node version, or copy PATH from default instance?
   - Recommendation: Copy the entire PATH line from default instance's env -- all instruments run on the same VPS with the same node version. Simpler and more reliable.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `bin/claude-service`, `bin/install.sh`, `systemd/claude@.service`, `systemd/claude-watchdog.service`, `systemd/claude-watchdog.timer`, `systemd/env.template`
- Phase 7 context: `.planning/phases/07-template-unit-foundation/07-CONTEXT.md`
- Phase 8 context: `.planning/phases/08-instrument-lifecycle/08-CONTEXT.md`

### Secondary (MEDIUM confidence)
- [systemd.unit manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html) - %i specifier behavior, template unit naming
- [systemd-devel mailing list](https://www.mail-archive.com/systemd-devel@lists.freedesktop.org/msg50001.html) - Confirmation that EnvironmentFile variables cannot be used in timer directives

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools already in use in the project
- Architecture: HIGH - extending existing patterns from Phase 7, no new infrastructure
- Pitfalls: HIGH - based on direct code analysis and systemd documentation
- Watchdog timer limitation: HIGH - confirmed by systemd official docs and mailing list

**Research date:** 2026-03-23
**Valid until:** 2026-04-23 (stable domain, bash + systemd)
