# Phase 14: Skills Deployment and Identity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 14-skills-deployment-and-identity
**Areas discussed:** Skills deployment mechanism, Instrument CLAUDE.md template, Session deduplication, Deployment automation

---

## Skills Deployment Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Add to `install.sh` | New subcommand (e.g., `deploy-skills`) that rsync's from `~/.claude/` to VPS | |
| Git clone on VPS | Clone GSD/superpowers repos directly on VPS into `~/.claude/` | |
| rsync/scp one-liner | No installer changes, documented manual command | |
| You decide | Claude's discretion on mechanism | ✓ |

**User's choice:** You decide
**Notes:** Verification needed that `claude -p` inherits skills from `~/.claude/`. This is a research task for downstream agents.

### Follow-up: Update sync strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Manual push | Run a command when you want to sync updates to VPS | |
| Auto-sync | Some mechanism keeps VPS skills in sync with local | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide

---

## Instrument CLAUDE.md Template

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal identity snippet | Deploy small CLAUDE.md with just instance name + restart hint, append/prepend to existing | |
| Full instrument template | A `templates/instrument-CLAUDE.md` with identity, conventions, GSD hints | |
| Env var injection | Skip CLAUDE.md, inject identity via env var | |
| You decide | Claude researches CLAUDE.md sourcing mechanics | ✓ |

**User's choice:** You decide — research CLAUDE.md sourcing mechanics
**Notes:** User raised that repos will likely have their own CLAUDE.md. Must NOT overwrite it. Claude to research what additional CLAUDE.md locations Claude Code supports and pick the cleanest approach for identity injection.

---

## Session Deduplication

| Option | Description | Selected |
|--------|-------------|----------|
| Known root cause | User describes when duplicates appear | |
| Investigation-first | Claude researches how remote-control sessions are created/named | ✓ |
| Known workaround | User has a theory or prior attempt | |

**User's choice:** Investigation-first
**Notes:** Pure research task. No assumptions — investigate root cause of duplicate "General coding session" on phone, then propose fix.

---

## Deployment Automation

| Option | Description | Selected |
|--------|-------------|----------|
| Repeatable installer subcommand | `install.sh deploy-skills` or similar, idempotent | |
| One-time setup script | Separate script, run once and move on | |
| Fold into `install.sh install` | Skills deployment as part of normal install flow | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide

---

## Claude's Discretion

- Skills deployment mechanism (D-01)
- Update sync strategy (D-02)
- CLAUDE.md identity injection approach (D-03)
- Session deduplication fix after research (D-04)
- Deployment automation model (D-05)

## Deferred Ideas

None — discussion stayed within phase scope.
