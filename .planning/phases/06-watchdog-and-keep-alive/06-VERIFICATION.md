---
phase: 06-watchdog-and-keep-alive
verified: 2026-03-22T06:00:00Z
status: passed
score: 11/11 must-haves verified
re_verification: false
---

# Phase 06: Watchdog and Keep-Alive Verification Report

**Phase Goal:** Watchdog timer for periodic forced restarts + keep-alive heartbeat for telegram mode
**Verified:** 2026-03-22T06:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

Combined must-haves from Plan 01 and Plan 02:

| #  | Truth                                                                              | Status     | Evidence                                                                       |
|----|------------------------------------------------------------------------------------|------------|--------------------------------------------------------------------------------|
| 1  | A systemd timer unit exists that fires every N hours (default 8)                  | VERIFIED   | systemd/claude-watchdog.timer has OnBootSec + OnUnitActiveSec with placeholder |
| 2  | A systemd oneshot service restarts claude in telegram mode, skips in rc mode       | VERIFIED   | claude-watchdog.service: CLAUDE_CONNECT=remote-control guard, restarts for any other value |
| 3  | The wrapper sends periodic input to claude stdin every 5 minutes in telegram mode  | VERIFIED   | bin/claude-wrapper: FIFO + heartbeat subshell writes newline every HEARTBEAT_INTERVAL |
| 4  | Heartbeat activity is logged to journald with a timestamp                          | VERIFIED   | bin/claude-wrapper line 73: `echo "claude-wrapper: heartbeat sent $(date -u ...)` to stderr |
| 5  | No heartbeat runs in remote-control or interactive mode                            | VERIFIED   | Heartbeat block gated on `CLAUDE_CONNECT == "telegram"` (line 55), else branch runs plain claude |
| 6  | Installer deploys watchdog timer and oneshot service files to systemd user dir     | VERIFIED   | install.sh lines 87-88: cp both files to SYSTEMD_USER_DIR                     |
| 7  | Installer enables and starts the watchdog timer                                    | VERIFIED   | install.sh lines 105-106: systemctl --user enable + start claude-watchdog.timer |
| 8  | Installer replaces CLAUDE_WATCHDOG_HOURS placeholder in timer file                 | VERIFIED   | install.sh lines 91-92: WATCHDOG_HOURS var + sed_inplace replacement           |
| 9  | claude-service has a watchdog subcommand showing timer status                      | VERIFIED   | bin/claude-service lines 39-41: watchdog) case runs systemctl --user status claude-watchdog.timer |
| 10 | claude-service has a heartbeat subcommand showing recent heartbeat log entries     | VERIFIED   | bin/claude-service lines 42-44: heartbeat) case runs journalctl --grep="heartbeat sent" |
| 11 | Uninstaller removes watchdog timer and oneshot files                               | VERIFIED   | install.sh lines 167-170: stop, disable, rm -f both watchdog files             |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact                          | Expected                                         | Status     | Details                                                                 |
|-----------------------------------|--------------------------------------------------|------------|-------------------------------------------------------------------------|
| `systemd/claude-watchdog.timer`   | Periodic timer that triggers watchdog oneshot    | VERIFIED   | Contains OnUnitActiveSec, OnBootSec (with placeholder), Unit=claude-watchdog.service, WantedBy=timers.target |
| `systemd/claude-watchdog.service` | Mode-aware oneshot that restarts claude or skips | VERIFIED   | Type=oneshot, EnvironmentFile, remote-control guard, systemctl --user restart |
| `systemd/env.template`            | CLAUDE_WATCHDOG_HOURS default                    | VERIFIED   | Line 12: CLAUDE_WATCHDOG_HOURS=8 with descriptive comment               |
| `bin/claude-wrapper`              | Heartbeat loop for telegram mode                 | VERIFIED   | heartbeat_pid, HEARTBEAT_FIFO, mkfifo, HEARTBEAT_INTERVAL, "heartbeat sent" log |
| `bin/install.sh`                  | Timer/oneshot deployment in do_install_linux()   | VERIFIED   | Deploys both files, sed placeholder replacement, enable+start timer     |
| `bin/claude-service`              | watchdog and heartbeat subcommands               | VERIFIED   | Both cases present with correct systemctl/journalctl commands            |

### Key Link Verification

| From                              | To                             | Via                                              | Status   | Details                                                          |
|-----------------------------------|--------------------------------|--------------------------------------------------|----------|------------------------------------------------------------------|
| systemd/claude-watchdog.timer     | systemd/claude-watchdog.service | Unit=claude-watchdog.service in [Timer] section  | WIRED    | Line 7 of timer file: `Unit=claude-watchdog.service`            |
| systemd/claude-watchdog.service   | systemd/claude.service         | systemctl --user restart claude.service          | WIRED    | Line 13 of service file: `systemctl --user restart claude.service` |
| systemd/claude-watchdog.service   | systemd/env.template           | EnvironmentFile=%h/.config/claude-restart/env    | WIRED    | Line 6: EnvironmentFile reads CLAUDE_CONNECT and CLAUDE_WATCHDOG_HOURS at runtime |
| bin/install.sh                    | systemd/claude-watchdog.timer  | cp + sed placeholder replacement                 | WIRED    | Lines 87, 92 in install.sh                                       |
| bin/install.sh                    | systemd/claude-watchdog.service | cp to systemd user dir                           | WIRED    | Line 88 in install.sh                                            |
| bin/claude-service                | systemd/claude-watchdog.timer  | systemctl --user status claude-watchdog.timer    | WIRED    | Line 40 in claude-service                                        |

### Requirements Coverage

Both plans declare `requirements: [WDOG-01, KALV-01]`. REQUIREMENTS.md maps both exclusively to Phase 6.

| Requirement | Source Plans | Description                                                      | Status    | Evidence                                                                                               |
|-------------|-------------|------------------------------------------------------------------|-----------|--------------------------------------------------------------------------------------------------------|
| WDOG-01     | 06-01, 06-02 | Periodic forced restart via systemd timer every N hours (configurable) | SATISFIED | claude-watchdog.timer + claude-watchdog.service deployed by installer, hours configurable via CLAUDE_WATCHDOG_HOURS |
| KALV-01     | 06-01, 06-02 | Heartbeat mechanism prevents Telegram plugin idle timeout        | SATISFIED | FIFO-based stdin heartbeat in bin/claude-wrapper, telegram-mode only, logs each send to stderr         |

No orphaned requirements: REQUIREMENTS.md maps only WDOG-01 and KALV-01 to Phase 6, and both are claimed by the plans.

### Anti-Patterns Found

None. Scanned all six modified/created files:

- No TODO/FIXME/placeholder comments in implementation files
- No stub return values (`return null`, `return {}`, `return []`)
- `CLAUDE_WATCHDOG_HOURS_PLACEHOLDER` in systemd/claude-watchdog.timer is an intentional installer token, not a code stub — the installer replaces it via sed before the file is used (confirmed by test 18 + test 20)
- `HEARTBEAT_INTERVAL` defaults to 300 seconds with a test-override pattern (`CLAUDE_WRAPPER_HEARTBEAT_INTERVAL`) that mirrors the established `CLAUDE_WRAPPER_DELAY` convention — not a stub

### Test Suite Results

| Test file             | Result        | Relevant tests                                                                    |
|-----------------------|---------------|-----------------------------------------------------------------------------------|
| test/test-wrapper.sh  | 33/33 passed  | Test 17: heartbeat fires in telegram mode; Test 18: no heartbeat in rc mode       |
| test/test-install.sh  | 49/49 passed  | Test 18: timer+oneshot deployed; Test 19: uninstall cleanup; Test 20: custom hours |

All four task commits confirmed in git history: 26b4e3b, 1368f9a, 43e9823, 354c934.

### Human Verification Required

None. All behaviors are covered by automated tests with mocked systemctl/journalctl/claude.

The one runtime behavior that cannot be programmatically verified is the actual idle-timeout prevention on a live VPS — whether a real Telegram plugin session remains responsive after the 5-minute heartbeat cycle. This is a VPS acceptance test, not a gap.

### Gaps Summary

No gaps. All 11 truths verified, all artifacts substantive and wired, both requirements satisfied, both test suites green.

---

_Verified: 2026-03-22T06:00:00Z_
_Verifier: Claude (gsd-verifier)_
