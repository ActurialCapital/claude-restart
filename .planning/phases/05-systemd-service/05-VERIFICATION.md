---
phase: 05-systemd-service
verified: 2026-03-21T00:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 05: systemd Service Verification Report

**Phase Goal:** Provide a systemd service and installer path so claude-restart runs as a persistent user-level service on Linux VPS hosts.
**Verified:** 2026-03-21
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                       | Status     | Evidence                                                                                  |
| --- | ------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------- |
| 1   | A systemd unit file exists that runs claude-wrapper with Restart=on-failure                 | VERIFIED   | `systemd/claude.service` line 13: `Restart=on-failure`                                   |
| 2   | An env file template exists with placeholders for API key, PATH, and CLAUDE_CONNECT         | VERIFIED   | `systemd/env.template` contains ANTHROPIC_API_KEY, CLAUDE_CONNECT, PATH w/ placeholders  |
| 3   | A claude-service helper script provides start/stop/restart/status/logs subcommands          | VERIFIED   | `bin/claude-service` has all 5 subcommands; executable (`-rwxr-xr-x`)                    |
| 4   | Running install.sh on Linux deploys the unit file, env file, and claude-service helper      | VERIFIED   | `do_install_linux()` copies all three; Tests 11, 12, 13 confirm with 37/37 pass           |
| 5   | Running install.sh on Linux enables linger and starts the service immediately               | VERIFIED   | `loginctl enable-linger` + `systemctl --user enable/start` in `do_install_linux()`; Test 14, 15 confirm |
| 6   | Running install.sh on macOS still does zshrc-only setup with no systemd involvement         | VERIFIED   | `PLATFORM` branch gates Linux path; Test 16 confirms no systemd dir created on Darwin     |
| 7   | Installer prompts for working directory and API key during setup                            | VERIFIED   | `read -rp "Working directory..."` and `read -rp "Anthropic API key:"` in `do_install_linux()` |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact                  | Expected                                          | Status     | Details                                                                 |
| ------------------------- | ------------------------------------------------- | ---------- | ----------------------------------------------------------------------- |
| `systemd/claude.service`  | systemd user service unit file                    | VERIFIED   | Exists; contains `Restart=on-failure`, `EnvironmentFile`, `ExecStart=%h/.local/bin/claude-wrapper`; no `Environment=` lines |
| `systemd/env.template`    | Environment file template for installer           | VERIFIED   | Exists; contains `ANTHROPIC_API_KEY=`, `CLAUDE_CONNECT=remote-control`, `PATH=` with placeholders |
| `bin/claude-service`      | Service management helper                         | VERIFIED   | Exists; executable; contains `journalctl --user -u claude -f` for logs subcommand |
| `bin/install.sh`          | Platform-aware installer with Linux systemd branch | VERIFIED  | Contains `do_install_linux()`, `do_install_macos()`, `PLATFORM` detection, `loginctl enable-linger`, `sed_inplace` helper |
| `test/test-install.sh`    | Tests covering Linux install path                 | VERIFIED   | 7 new test cases (Tests 11-17); all 37 assertions pass                  |

---

### Key Link Verification

| From                     | To                       | Via                               | Status   | Details                                                                            |
| ------------------------ | ------------------------ | --------------------------------- | -------- | ---------------------------------------------------------------------------------- |
| `systemd/claude.service` | `systemd/env.template`   | `EnvironmentFile` directive       | WIRED    | Line 11: `EnvironmentFile=%h/.config/claude-restart/env` — points to installed env file path |
| `systemd/claude.service` | `bin/claude-wrapper`     | `ExecStart` directive             | WIRED    | Line 10: `ExecStart=%h/.local/bin/claude-wrapper --dangerously-skip-permissions`  |
| `bin/install.sh`         | `systemd/claude.service` | copies unit file to systemd dir   | WIRED    | Line 82: `cp "$SCRIPT_DIR/../systemd/claude.service" "$SYSTEMD_USER_DIR/claude.service"` |
| `bin/install.sh`         | `systemd/env.template`   | populates and installs env file   | WIRED    | Line 56: `cp "$SCRIPT_DIR/../systemd/env.template" "$ENV_FILE"` then sed replaces placeholders |
| `bin/install.sh`         | `bin/claude-service`     | copies to INSTALL_DIR             | WIRED    | Line 38: `cp "$SCRIPT_DIR/claude-service" "$INSTALL_DIR/claude-service"` |

---

### Requirements Coverage

| Requirement | Source Plan     | Description                                                              | Status    | Evidence                                                                                      |
| ----------- | --------------- | ------------------------------------------------------------------------ | --------- | --------------------------------------------------------------------------------------------- |
| SYSD-01     | 05-01, 05-02    | User service unit file runs wrapper with `Restart=on-failure`            | SATISFIED | `systemd/claude.service` line 13 confirmed; no `Environment=` lines; `WantedBy=default.target` |
| SYSD-02     | 05-01, 05-02    | Service starts on boot and survives SSH logout via `loginctl enable-linger` | SATISFIED | `do_install_linux()` calls `loginctl enable-linger "$USER"` + `systemctl --user enable claude.service`; Test 15 confirms |
| SYSD-03     | 05-02           | Install script detects Linux and installs systemd unit file (macOS unchanged) | SATISFIED | `PLATFORM="$(uname -s)"` detection; `do_install_linux` / `do_install_macos` branch; Test 16 confirms macOS isolation |

All 3 required requirement IDs (SYSD-01, SYSD-02, SYSD-03) are satisfied. No orphaned requirements found for Phase 5.

---

### Anti-Patterns Found

None. No TODO/FIXME/placeholder comments in implementation files. Installer placeholders (`WORKING_DIR_PLACEHOLDER`, `HOME_PLACEHOLDER`, `NODEVERSION_PLACEHOLDER`) are intentional design artifacts replaced by the installer at deploy time — not stubs.

---

### Human Verification Required

#### 1. Real VPS deployment

**Test:** Run `bash bin/install.sh` on a Linux VPS where `loginctl` and `systemctl --user` are functional. Answer prompts for working directory, API key, and connection mode.
**Expected:** Unit file deployed to `~/.config/systemd/user/claude.service`, env file at `~/.config/claude-restart/env` (mode 600), `claude-service` in `~/.local/bin/`, `systemctl --user status claude.service` shows active/running after install completes.
**Why human:** Cannot execute `loginctl enable-linger` or `systemctl --user` on the macOS development machine. Test suite mocks these calls.

#### 2. Boot persistence after SSH logout

**Test:** After install, log out of SSH, wait a few seconds, log back in, run `systemctl --user status claude.service`.
**Expected:** Service is still active/running — confirms linger is effective and unit is enabled.
**Why human:** Requires real Linux session lifecycle; cannot simulate SSH logout in automated tests.

#### 3. Crash recovery (Restart=on-failure)

**Test:** `kill $(systemctl --user show -p MainPID --value claude.service)` to simulate a crash. Wait 5 seconds (RestartSec=5). Check `systemctl --user status claude.service`.
**Expected:** Service restarts automatically and shows active/running again.
**Why human:** Requires a live systemd service with a real child process to kill.

---

### Summary

All 7 observable truths are verified. All 5 artifacts exist and are substantive (not stubs). All 5 key links are wired. All 3 requirements (SYSD-01, SYSD-02, SYSD-03) are satisfied by evidence in the actual codebase — not just claimed in summaries.

The test suite (37 assertions across 17 tests) executes end-to-end on macOS with mocked `systemctl`/`loginctl`, confirming the Linux install path produces the correct files and invokes the correct commands. macOS isolation is confirmed by Test 16.

The 3 human verification items all require a live Linux VPS with systemd — they are runtime/behavioral checks that cannot be automated on the development machine.

---

_Verified: 2026-03-21_
_Verifier: Claude (gsd-verifier)_
