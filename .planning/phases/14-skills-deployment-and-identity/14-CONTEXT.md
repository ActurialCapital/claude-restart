# Phase 14: Skills Deployment and Identity - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Deploy GSD and superpowers skills to VPS so instruments have `/gsd:*` commands, give each instrument self-awareness of its instance name via CLAUDE.md identity injection, and fix the duplicate "General coding session" appearing on phone from remote-control sessions.

Requirements: DEPL-01, DEPL-02, DEPL-03, INST-01, INST-02, SESS-01

</domain>

<decisions>
## Implementation Decisions

### Skills Deployment Mechanism
- **D-01:** Claude's discretion on how GSD (`~/.claude/get-shit-done/`) and superpowers (`~/.claude/commands/`) are deployed to VPS. Options include installer subcommand, git clone on VPS, rsync, or other approach.
- **D-02:** Claude's discretion on update sync strategy — whether VPS skills auto-sync with local updates or require manual push.

### Instrument Identity (CLAUDE.md)
- **D-03:** Claude's discretion on how to inject instance identity into instruments. Must NOT overwrite the repo's own CLAUDE.md. Research what additional CLAUDE.md locations Claude Code supports (e.g., `.claude/CLAUDE.md`, `CLAUDE.local.md`, user-level settings) and pick the cleanest approach.

### Session Deduplication
- **D-04:** Investigation-first approach. Research how remote-control sessions are created/named, what causes duplicate "General coding session" entries on phone, then propose a fix based on findings.

### Deployment Automation
- **D-05:** Claude's discretion on whether Phase 14 deliverables are a repeatable installer subcommand, a one-time setup script, or folded into the existing `install.sh install` flow.

### Claude's Discretion
- Skills deployment mechanism (D-01)
- Update sync strategy (D-02)
- CLAUDE.md identity injection approach (D-03)
- Session deduplication fix (D-04, after research)
- Deployment automation model (D-05)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — DEPL-01, DEPL-02, DEPL-03 (skills deployment), INST-01, INST-02 (instance identity), SESS-01 (session fix)

### Existing Deployment Infrastructure
- `bin/install.sh` — Current installer with install/uninstall/add/remove subcommands. `do_add()` creates per-instance env files with `CLAUDE_INSTANCE_NAME` substitution. Potential home for skills deployment.
- `bin/claude-service` — Fleet management. `add-orchestra` already deploys `orchestra/CLAUDE.md`. Pattern to follow for instrument identity deployment.
- `systemd/env.template` — Already has `CLAUDE_INSTANCE_NAME=INSTANCE_PLACEHOLDER` — identity plumbing partially exists.

### Prior Phase Context
- `.planning/phases/13-synchronous-dispatch/13-CONTEXT.md` — Orchestra CLAUDE.md already rewritten for `claude -p` dispatch (D-09). Instruments are working directories for `claude -p`.

### Skills Source (on dev machine)
- `~/.claude/get-shit-done/` — GSD skills directory to be deployed
- `~/.claude/commands/` — Superpowers skills directory to be deployed

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/claude-service add` — Already creates per-instance env files with `CLAUDE_INSTANCE_NAME` substitution. Could be extended for CLAUDE.md identity injection.
- `bin/claude-service add-orchestra` — Already deploys `orchestra/CLAUDE.md` to orchestra working directory. Pattern for deploying CLAUDE.md files.
- `bin/install.sh` — Has install/uninstall/add/remove subcommands. Could gain a `deploy-skills` subcommand.

### Established Patterns
- Shell scripts are pure bash, no external dependencies beyond systemd
- `env.template` uses `INSTANCE_PLACEHOLDER` for sed substitution during `add`
- Orchestra CLAUDE.md is deployed as a straight file copy by `claude-service add-orchestra`

### Integration Points
- `bin/install.sh` — Primary deployment vehicle for new VPS setup
- `bin/claude-service add` — Per-instrument setup, where identity injection would happen
- `~/.claude/` on VPS — Target directory for skills deployment
- Instrument working directories (`~/instruments/<name>/`) — Where identity CLAUDE.md would be placed

</code_context>

<specifics>
## Specific Ideas

### Key Research Questions for Downstream Agents
1. **Verify `claude -p` skill inheritance:** Does `claude -p` running in an instrument directory automatically pick up skills from `~/.claude/get-shit-done/` and `~/.claude/commands/`? This determines whether deployment to `~/.claude/` is sufficient or per-instrument deployment is needed.
2. **CLAUDE.md sourcing mechanics:** What locations does Claude Code read CLAUDE.md from? Research `.claude/CLAUDE.md`, `CLAUDE.local.md`, user-level settings, or other mechanisms that allow identity injection without overwriting the repo's own CLAUDE.md.
3. **Session duplication root cause:** Investigate how remote-control mode creates/names sessions, and why duplicate "General coding session" entries appear on phone. Is it per-restart? Per-`claude-service add`? Something else?

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 14-skills-deployment-and-identity*
*Context gathered: 2026-03-27*
