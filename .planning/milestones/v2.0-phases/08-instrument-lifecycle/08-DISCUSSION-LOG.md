# Phase 8: Instrument Lifecycle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-22
**Phase:** 08-instrument-lifecycle
**Areas discussed:** Tooling location, Manifest design, Add workflow, Remove behavior

---

## Tooling Location

| Option | Description | Selected |
|--------|-------------|----------|
| Extend claude-service | Add subcommands to existing script. One management entry point. Already has instance routing. | ✓ |
| New claude-instrument script | Separate script for lifecycle ops. Two scripts to install/maintain. | |
| Rename to claude-ctl | Replace claude-service with broader tool. Clean slate naming. | |

**User's choice:** Extend claude-service
**Notes:** User asked "what is easier, best practice, intuitive?" — recommended extending claude-service as it follows systemctl/docker one-CLI pattern and minimizes scripts to manage from phone.

---

## Manifest Design

| Option | Description | Selected |
|--------|-------------|----------|
| Filesystem convention | Each subdir in ~/.config/claude-restart/ IS an instrument. No separate manifest file. | ✓ |
| Explicit manifest file | JSON/plain-text file listing instruments. Can drift from actual state. | |
| systemd as source of truth | Use systemctl list-units to discover. Can't store metadata without reading each env file. | |

**User's choice:** Filesystem convention
**Notes:** None — straightforward selection.

---

## Add Workflow

| Option | Description | Selected |
|--------|-------------|----------|
| Name + existing directory | User clones repo first, add just wires up config. | |
| Name + repo URL (clone for user) | Add clones the repo to a standard location, then sets up everything. | ✓ |
| Interactive wizard | Prompts for each setting. | |

**User's choice:** Add clones the repo
**Notes:** Initially presented as name + existing dir (recommended). User asked "how would it work from phone?" — explained phone flow is via Claude remote-control. User then asked "just to make sure, 'add' will clone a repo?" — realized symmetry with remove (full cleanup) means add should do full setup (clone). Revised to `claude-service add <name> <git-url>` with clone to `~/instruments/<name>/`. API key copied from default instance, no prompts.

### Clone Location Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| ~/instruments/<name>/ | Dedicated directory for all instrument repos. | ✓ |
| ~/GitHub/<name>/ | Uses existing GitHub directory convention. | |
| Configurable base path | Default ~/instruments/ with env var override. | |

**User's choice:** ~/instruments/<name>/
**Notes:** None — clean separation preferred.

---

## Remove Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Config only — never touch repo | Stop service, disable units, delete env dir. Repo stays on disk. | |
| Full cleanup (config + repo) | Stop service, disable units, delete env dir AND working directory. | ✓ |
| Config + optional --purge | Default config only, --purge also deletes repo. | |

**User's choice:** Full cleanup
**Notes:** User clarified "remove should delete the entire instrument (folder), which includes claude + folder in VPS (the repo is just cloned, it's still exist in github). I don't want to have dead folders in my VPS." No confirmation prompts, no safety checks — clones are disposable.

---

## Claude's Discretion

- List output format
- Name validation details
- Error messages and edge cases
- Watchdog template unit internals

## Deferred Ideas

None — discussion stayed within phase scope
