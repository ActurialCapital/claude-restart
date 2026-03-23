# Project Research Summary

**Project:** claude-restart v2.0 -- Multi-Instance Orchestration
**Domain:** Multi-instance Claude Code management on Linux VPS with autonomous orchestration
**Researched:** 2026-03-22
**Overall confidence:** HIGH

## Executive Summary

This research covers what is needed to evolve the existing v1.1 single-instance restart/service infrastructure into a multi-instance orchestration platform. The core finding is that the existing stack (bash + systemd) extends naturally to multi-instance via systemd template units (`claude@.service`) -- no new languages or frameworks needed. The only new external dependency is `jq` for parsing JSON output from `claude -p` headless mode.

The critical architectural discovery is that Claude Code's `remote-control` mode has NO local programmatic API. Remote Control works via HTTPS polling through Anthropic's relay servers -- there is no way for the orchestra to inject prompts into a running instrument's session from another local process. This means the orchestra's interaction model must be: (1) restart instruments for context reset via `claude-restart`, (2) spawn one-shot `claude -p` tasks in instrument project directories for ad-hoc research, and (3) monitor instrument health via `systemctl`. Direct human-to-instrument interaction happens independently via claude.ai/code or the mobile app.

The main risks are operational, not technical: shared restart files across instances (race condition), memory leaks multiplied by N instances exhausting VPS RAM, API rate limits shared across all instances, and watchdog timers that must be templated alongside the main service units. All have mechanical solutions documented in PITFALLS.md.

The manifest format recommendation is deliberately simple: a plain text file with one instrument name per line. The instrument-to-directory mapping lives in per-instance systemd environment files and drop-in overrides, not in the manifest. This keeps bash parsing trivial and avoids any new parsing dependencies beyond what systemd already provides.

## Key Findings

**Stack:** Pure bash + systemd template units + jq. No Node.js SDK, no Docker, no additional process managers. Only new dependency is `jq` for JSON parsing of `claude -p` output.

**Architecture:** Orchestra is a Claude session (itself an instrument) that dispatches via `claude -p` one-shots, restarts instruments via `claude-restart --instance`, and monitors via `systemctl`. No direct inter-session communication protocol exists.

**Critical pitfall:** Shared mutable state -- the single restart file (`~/.claude-restart`) from v1.0/v1.1 becomes a race condition with multiple instances. Must be per-instance from day one using the already-supported `CLAUDE_RESTART_FILE` env var.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Template Unit Foundation** - Convert single-instance to multi-instance
   - Addresses: `claude@.service` template unit, per-instance env files, per-instance restart files, `MemoryMax` limits
   - Avoids: Pitfalls 1 (shared restart file), 2 (specifier escaping), 3 (env file layering), 5 (memory leak x N), 9 (session naming)
   - This must come first because every subsequent feature depends on isolated instances

2. **Lifecycle Tooling** - Add/remove/list instruments with single commands
   - Addresses: `claude-service add/remove/list`, env file creation, drop-in override for WorkingDirectory, manifest file management
   - Avoids: Pitfall 10 (daemon-reload race), UX pitfall (multi-step manual process)
   - Depends on template unit existing; enables dynamic instrument management

3. **Watchdog Migration** - Template the watchdog timer per-instance
   - Addresses: `claude-watchdog@.timer` and `claude-watchdog@.service` template units
   - Avoids: Pitfall 6 (singleton watchdog targeting nonexistent unit)
   - Depends on template unit; must match 1:1 with instrument instances

4. **claude-wrapper Multi-Instance Adaptation** - Instance-aware wrapper modifications
   - Addresses: `CLAUDE_CONNECT=remote-control` mapping to `claude remote-control --name`, `CLAUDE_INSTANCE_NAME` env var, instance-targeted `claude-restart --instance`
   - This can be developed in parallel with phases 2-3 but must be tested against template units

5. **Orchestra Foundation** - Autonomous supervisor session
   - Addresses: Orchestra CLAUDE.md with instrument awareness, dispatch via `claude -p`, status monitoring, `claude-restart --instance` for context reset
   - Avoids: Pitfall 4 (context bleed), Pitfall 7 (discovery race), Pitfall 8 (rate limit contention)
   - Depends on all prior phases; orchestra cannot function without stable multi-instance infrastructure

6. **Dynamic Discovery** - Hot-add/remove while running
   - Addresses: Manifest file watching, orchestra refresh-before-act pattern, eventual consistency model
   - Avoids: Pitfall 7 (race condition on add/remove during operation)
   - Can be deferred to after orchestra is functional with a static instrument list

**Phase ordering rationale:**
- Template units must precede everything because isolated instances are the foundation
- Lifecycle tooling must precede orchestra because the orchestra uses `claude-service` commands
- Watchdog migration must happen early to prevent data loss from unmonitored memory leaks
- Orchestra comes last because it is the consumer of all prior infrastructure
- Dynamic discovery is the least critical -- static instrument lists work for initial deployment

**Research flags for phases:**
- Phase 1: Standard systemd patterns, no additional research needed
- Phase 2: Standard bash tooling, no additional research needed
- Phase 5: May need research on effective orchestra system prompts and dispatch patterns -- this is the most novel aspect of the project
- Phase 6: May need research on file watching patterns in bash (inotifywait vs polling)

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | systemd template units, bash, jq are all mature, well-documented technologies. Claude CLI flags verified against official docs 2026-03-22. |
| Features | HIGH | Feature scope constrained by PROJECT.md. Remote-control limitations verified via official docs. |
| Architecture | HIGH (infrastructure), MEDIUM (orchestra patterns) | systemd template units are well-understood. Orchestra dispatch patterns are novel -- no established best practices for "Claude session orchestrating other Claude sessions." |
| Pitfalls | HIGH | Core pitfalls verified against systemd docs, Claude Code GitHub issues, and inspection of existing v1.1 codebase. |

## Gaps to Address

- **Orchestra dispatch UX**: No established pattern for how a Claude session should structure prompts to `claude -p` for instrument dispatch. This is novel territory that will need iteration.
- **Rate limit behavior under multi-instance**: Theoretical analysis says it will be tight with 3+ active instances, but actual token consumption patterns depend on workload. Needs real-world validation.
- **`claude remote-control` exit codes**: The specific exit code when remote-control exits due to network timeout is not documented. Need to test whether `Restart=on-failure` correctly catches this case or if `Restart=always` is needed for remote-control instances.
- **Memory leak severity in current Claude Code version**: The GitHub issues reference versions from 2025. Current severity needs validation on the target VPS.

## Sources

### Primary (HIGH confidence)
- [Claude Code Remote Control docs](https://code.claude.com/docs/en/remote-control) -- server mode, `--capacity`, `--name`, session lifecycle
- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference) -- all flags including `-p`, `--resume`, `--output-format`, `--bare`
- [Claude Code headless mode](https://code.claude.com/docs/en/headless) -- print mode patterns, session continuation
- [Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) -- SDK capabilities vs CLI
- [systemd template unit files (Fedora Magazine)](https://fedoramagazine.org/systemd-template-unit-files/)
- [systemd.unit man page](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
- [systemd for Administrators Part X (Lennart Poettering)](http://0pointer.de/blog/projects/instances.html)

### Secondary (MEDIUM confidence)
- [Deep dive: Remote Control internals](https://dev.to/chwu1946/deep-dive-how-claude-code-remote-control-actually-works-50p6) -- HTTPS polling, not WebSocket
- [Run multiple instances with systemd (Steven Rombauts)](https://www.stevenrombauts.be/2019/01/run-multiple-instances-of-the-same-systemd-unit/)
- [Claude Code Memory Leak issues (#4953, #21403, #22188)](https://github.com/anthropics/claude-code/issues/4953)

---
*Research completed: 2026-03-22*
*Ready for roadmap: yes*
