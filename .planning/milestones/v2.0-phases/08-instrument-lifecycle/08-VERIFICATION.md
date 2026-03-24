---
phase: 08-instrument-lifecycle
verified: 2026-03-23T15:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 8: Instrument Lifecycle Verification Report

**Phase Goal:** User manages the full instrument fleet with single commands, and every instrument automatically gets a watchdog timer
**Verified:** 2026-03-23
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Watchdog template units exist and use %i for per-instance targeting | VERIFIED | `systemd/claude-watchdog@.service` and `systemd/claude-watchdog@.timer` present; `%i` used in EnvironmentFile, ExecStart, Unit= directive, and log messages |
| 2 | install.sh deploys template watchdog units and migrates old non-template units | VERIFIED | Lines 157-168 of `bin/install.sh` copy both `@` units and contain a migration block that stops, disables, and removes old `claude-watchdog.timer`/`claude-watchdog.service` |
| 3 | Default instance gets claude-watchdog@default.timer enabled after migration | VERIFIED | Lines 179-181 of `bin/install.sh` call `systemctl --user enable "claude-watchdog@${DEFAULT_INSTANCE}.timer"` and start it |
| 4 | User can add an instrument with `claude-service add <name> <git-url>` | VERIFIED | `do_add()` fully wired: clones repo, creates env from template, replaces placeholders, copies API key and PATH from default instance, enables `claude@${name}.service` and `claude-watchdog@${name}.timer` |
| 5 | User can remove an instrument with `claude-service remove <name>` | VERIFIED | `do_remove()` fully wired: stops and disables both service and watchdog timer, `rm -rf` on config dir and working dir |
| 6 | User can list all instruments with `claude-service list` | VERIFIED | `do_list()` iterates `$CONFIG_DIR/*/` and emits columnar `printf` output with name and `systemctl is-active` status |
| 7 | Adding enables claude-watchdog@<name>.timer; removing disables it | VERIFIED | `do_add` line 106: `systemctl --user enable --now "claude-watchdog@${name}.timer"` / `do_remove` line 135-136: stop + disable watchdog timer; test suite asserts both paths (26/26 pass) |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `systemd/claude-watchdog@.service` | Per-instance watchdog oneshot service | VERIFIED | Exists, 13 lines; contains `%h/.config/claude-restart/%i/env`, `systemctl --user restart claude@%i.service`, mode-aware skip for remote-control |
| `systemd/claude-watchdog@.timer` | Per-instance watchdog timer (8h hardcoded) | VERIFIED | Exists, 10 lines; `OnBootSec=8h`, `OnUnitActiveSec=8h`, `Unit=claude-watchdog@%i.service`, `[Install]` with `WantedBy=timers.target` |
| `bin/install.sh` | Template unit deployment and old unit migration | VERIFIED | Contains `cp "$SCRIPT_DIR/../systemd/claude-watchdog@.timer"`, migration block, `claude-watchdog@${DEFAULT_INSTANCE}.timer` enable, uninstall loops through env dirs |
| `bin/claude-service` | add, remove, list subcommands | VERIFIED | Contains `do_add`, `do_remove`, `do_list`, `sed_inplace`; all subcommands routed in case statement; no `read -rp` (non-interactive) |
| `test/test-service-lifecycle.sh` | Lifecycle test suite | VERIFIED | 26 assertions; mocks systemctl and git; all 26 pass on macOS |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `systemd/claude-watchdog@.timer` | `systemd/claude-watchdog@.service` | `Unit=` directive | WIRED | Line 7: `Unit=claude-watchdog@%i.service` |
| `bin/install.sh` | `systemd/claude-watchdog@.timer` | `cp` to systemd user dir | WIRED | Lines 158-159 copy both `@` units |
| `bin/claude-service (add)` | `systemd/claude-watchdog@.timer` | `systemctl --user enable --now` | WIRED | Line 106: `systemctl --user enable --now "claude-watchdog@${name}.timer"` |
| `bin/claude-service (add)` | `~/.config/claude-restart/<name>/env` | `cp` + `sed_inplace` from env.template | WIRED | Lines 82-99; template copied, three placeholders replaced, API key and PATH populated from default instance |
| `bin/claude-service (remove)` | systemd units | `systemctl --user stop/disable` | WIRED | Lines 133-136; both service and watchdog timer stopped and disabled |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| WDOG-04 | 08-01-PLAN | Watchdog timer templated per-instance and paired automatically | SATISFIED | `claude-watchdog@.service` and `claude-watchdog@.timer` exist with `%i` parameterization; `install.sh` deploys and migrates |
| WDOG-05 | 08-02-PLAN | Adding an instrument enables its watchdog; removing disables it | SATISFIED | `do_add` calls `systemctl --user enable --now claude-watchdog@${name}.timer`; `do_remove` calls stop + disable on the same unit |
| LIFE-01 | 08-02-PLAN | User can add instrument with single command | SATISFIED | `claude-service add <name> <git-url>` is one command; clones repo, creates env, enables service + watchdog |
| LIFE-02 | 08-02-PLAN | User can remove instrument with single command | SATISFIED | `claude-service remove <name>` is one command; stops service + watchdog, deletes config and working dir |
| LIFE-03 | 08-02-PLAN | User can list instruments with status | SATISFIED | `claude-service list` shows columnar INSTRUMENT / STATUS output with live `systemctl is-active` per instrument |

No orphaned requirements. All five IDs declared in plan frontmatter are present in REQUIREMENTS.md and mapped to Phase 8 in the traceability table. REQUIREMENTS.md traceability table marks all five complete.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `bin/claude-service` | 85-87 | `INSTANCE_PLACEHOLDER`, `WORKING_DIR_PLACEHOLDER`, `HOME_PLACEHOLDER` | Info | These are sed replacement targets being consumed via `sed_inplace` — not stubs. Matched by the scan but are intentional template variables. |
| `bin/install.sh` | 118-126 | Same placeholder strings | Info | Same as above — these are the sed substitution calls, not leaked placeholders. |

No blockers. No warnings. The PLACEHOLDER strings are used as sed patterns in replacement calls, not as unconsumed leftover values. `CLAUDE_WATCHDOG_HOURS_PLACEHOLDER` is confirmed absent from `install.sh` (0 occurrences). No `read -rp` in `bin/claude-service` (non-interactive requirement met).

### Human Verification Required

None. All goal-critical behaviors are covered by the automated test suite (26/26 assertions passing) or are statically verifiable from file contents.

Items that would require a live VPS to fully exercise (not gaps — the code is correct and wired):

1. **systemd unit activation on Linux** — `claude-watchdog@default.timer` actually fires and restarts the service after 8 hours. The unit file contents are correct; behavior depends on a running systemd user session.
2. **Migration path from v1.1 non-template watchdog units** — the `if [[ -f "$SYSTEMD_USER_DIR/claude-watchdog.timer" ]]` branch in `install.sh` requires an existing v1.1 installation to exercise. Logic is correct; cannot test without the legacy state.

### Gaps Summary

No gaps. All seven observable truths are verified with direct code evidence. All five required artifacts exist, are substantive (no stubs), and are wired to their consumers. All five requirement IDs (LIFE-01, LIFE-02, LIFE-03, WDOG-04, WDOG-05) are satisfied. Commits bbb7143, 647799a, 8524c48, 97fc836, and 752ddc5 are all present in git history. The test suite passes 26/26 on macOS with mocked systemd.

The ROADMAP.md still shows `08-02-PLAN.md` as `[ ]` (not checked) — this is a documentation inconsistency in the roadmap itself, not a code gap. The implementation is complete.

---

_Verified: 2026-03-23_
_Verifier: Claude (gsd-verifier)_
