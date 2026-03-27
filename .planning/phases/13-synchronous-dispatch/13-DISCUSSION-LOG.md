# Phase 13: Synchronous Dispatch - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-27
**Phase:** 13-synchronous-dispatch
**Areas discussed:** Dispatch pattern, Parallel execution, Continuation model, Orchestra CLAUDE.md rewrite

---

## Dispatch Pattern

### Q1: How should orchestra invoke `claude -p`?

| Option | Description | Selected |
|--------|-------------|----------|
| Always `--dangerously-skip-permissions` | Orchestra dispatches are autonomous, no human in the loop | ✓ |
| Permission flag configurable per instrument | Some instruments might need tighter control | |
| You decide | Claude's discretion | |

**User's choice:** Always `--dangerously-skip-permissions`
**Notes:** Matches existing one-shot agent pattern already in use.

### Q2: What happens when `claude -p` fails?

| Option | Description | Selected |
|--------|-------------|----------|
| Retry once, then escalate | One automatic retry; if fails again, escalate to user | |
| Escalate immediately | No retries, report failure and move on | |
| Retry with backoff, then escalate | Up to 3 retries with increasing delay | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

### Q3: Output format from `claude -p`?

| Option | Description | Selected |
|--------|-------------|----------|
| Raw text | Parse human-readable GSD output as-is | |
| Structured markers | Instruments emit parseable markers like `[GSD:DONE]` | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

---

## Parallel Execution

### Q1: How to run multiple `claude -p` simultaneously?

| Option | Description | Selected |
|--------|-------------|----------|
| Shell backgrounding (`&` + `wait`) | Native bash pattern, simple | |
| Sequential with non-blocking checks | One at a time but doesn't wait for completion | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

### Q2: Max concurrency limit?

| Option | Description | Selected |
|--------|-------------|----------|
| No limit | Fire as many as there are instruments | ✓ |
| Configurable cap | Set max in env or config | |
| Match instrument count | One per instrument, no artificial cap | |
| You decide | Claude's discretion | |

**User's choice:** No limit
**Notes:** None

### Q3: Handling blocked instruments?

| Option | Description | Selected |
|--------|-------------|----------|
| Continue driving others independently | Park blocked, advance others | |
| Batch escalations | Park blocked, batch user questions | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

---

## Continuation Model

### Q1: When to use `--continue` vs fresh?

| Option | Description | Selected |
|--------|-------------|----------|
| Fresh default, `--continue` for multi-step GSD chains | discuss→plan→execute uses continue, new phases fresh | |
| Always fresh | Every dispatch is clean slate, state in `.planning/` files | |
| `--continue` within plan, fresh between plans | Continuation scoped to individual plans | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

### Q2: How to track instrument state?

| Option | Description | Selected |
|--------|-------------|----------|
| Internal state only | Orchestra working memory, no external file | |
| State file per instrument | Write `.orchestra-state` file for recovery | |
| Rely on `.planning/STATE.md` | Read existing GSD state, no new files | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

---

## Orchestra CLAUDE.md Rewrite

### Q1: Preserve or rewrite?

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve structure, replace mechanics | Keep escalation, anti-patterns, etc. Replace peer messaging | |
| Full rewrite from scratch | Current CLAUDE.md designed around peers, start fresh | ✓ |
| You decide | Claude's discretion | |

**User's choice:** Full rewrite from scratch
**Notes:** None

### Q2: Fleet discovery mechanism?

| Option | Description | Selected |
|--------|-------------|----------|
| `claude-service list` | Use existing tooling | |
| Hardcoded instrument list | Just list known instruments | |
| Both | Hardcoded primary, `claude-service list` fallback | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

### Q3: Escalation protocol format?

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve `[N/name]` format | Works well for phone reading | |
| Simplify | Describe conceptually, let Claude format | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

### Q4: Include concrete examples?

| Option | Description | Selected |
|--------|-------------|----------|
| Include concrete examples | Show exact `claude -p` invocations | |
| Patterns only | Describe dispatch model conceptually | |
| You decide | Claude's discretion | ✓ |

**User's choice:** You decide
**Notes:** None

---

## Claude's Discretion

- Error/retry strategy for failed `claude -p` commands
- Output format (raw text vs structured markers)
- Parallelism mechanism
- Blocked instrument handling
- Continuation strategy (`--continue` vs fresh)
- Instrument state tracking approach
- Fleet discovery method
- Escalation format
- Example verbosity in CLAUDE.md

## Deferred Ideas

None — discussion stayed within phase scope.
