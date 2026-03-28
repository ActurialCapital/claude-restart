# VPS Deployment Verification Checklist

**Project:** claude-restart
**Date:** _______________
**Operator:** _______________

> Manual verification checklist for first VPS deployment of claude-restart.
> Follow each section in order -- the sequence matches a real deployment.
> Every check has a command to run and expected output to compare against.

## Prerequisites

- Ubuntu 22.04+ or Debian 12+ (systemd with user sessions)
- A user account with sudo access (needed for `loginctl enable-linger`)
- An Anthropic API key ready to provide during install
- SSH access to the VPS

---

## 1. Pre-Deploy Checks

Verify the VPS has the required tools before running install.sh.

- [ ] **Node.js version**

  ```bash
  node --version
  ```

  Expected: `v18.x` or `v20.x` or later

- [ ] **npm/npx available**

  ```bash
  npx --version
  ```

  Expected: Version number (e.g., `10.x.x`)

- [ ] **Claude CLI installed**

  ```bash
  claude --version
  ```

  Expected: Version string (e.g., `1.x.x`)

- [ ] **Git installed**

  ```bash
  git --version
  ```

  Expected: `git version 2.x.x`

- [ ] **systemd user session works**

  ```bash
  systemctl --user status
  ```

  Expected: No errors; shows active state and loaded units

- [ ] **loginctl linger enabled**

  ```bash
  loginctl show-user $USER | grep Linger
  ```

  Expected: `Linger=yes` (if not, run `sudo loginctl enable-linger $USER`)

- [ ] **ANTHROPIC_API_KEY ready**

  ```bash
  echo "API key ready: ${ANTHROPIC_API_KEY:+yes}"
  ```

  Expected: Have the key available to paste during install (or already exported)

- [ ] **jq installed for config manipulation**

  ```bash
  jq --version
  ```

  Expected: `jq-1.x` (used by install.sh to set remoteDialogSeen)

- [ ] **python3 available for ensure_remote_config**

  ```bash
  python3 --version
  ```

  Expected: `Python 3.x.x` (used by claude-wrapper to configure workspace trust)

---

## 2. install.sh Execution

Clone the repo and run the installer.

- [ ] **Clone repo to VPS**

  ```bash
  git clone https://github.com/<your-org>/claude-restart.git
  cd claude-restart
  ```

  Expected: Repo cloned successfully, you are inside the repo directory

- [ ] **Run install.sh**

  ```bash
  bin/install.sh --install
  ```

  Expected: Prompts for working directory, API key, and connection mode; prints success messages for each step

- [ ] **Verify scripts installed to ~/.local/bin**

  ```bash
  ls -la ~/.local/bin/claude-wrapper ~/.local/bin/claude-restart ~/.local/bin/claude-service
  ```

  Expected: All three files exist and are executable (`-rwxr-xr-x` or `-rwx------`)

- [ ] **Verify env.template installed**

  ```bash
  ls ~/.config/claude-restart/env.template
  ```

  Expected: File exists

- [ ] **Verify systemd units installed**

  ```bash
  ls ~/.config/systemd/user/claude@.service ~/.config/systemd/user/claude-watchdog@.service ~/.config/systemd/user/claude-watchdog@.timer
  ```

  Expected: All three template unit files exist

- [ ] **Verify env file created with correct permissions**

  ```bash
  stat -c %a ~/.config/claude-restart/default/env
  ```

  Expected: `600` (read/write for owner only -- contains API key)

- [ ] **Verify PATH in env file includes node binary path**

  ```bash
  grep ^PATH ~/.config/claude-restart/default/env
  ```

  Expected: PATH line includes the node binary directory (e.g., `~/.nvm/versions/node/v20.x.x/bin`)

---

## 3. Default Instance Smoke Test

Verify the default instance started correctly.

- [ ] **Service is enabled**

  ```bash
  systemctl --user is-enabled claude@default.service
  ```

  Expected: `enabled`

- [ ] **Service is running**

  ```bash
  systemctl --user is-active claude@default.service
  ```

  Expected: `active`

- [ ] **Service status shows no errors**

  ```bash
  systemctl --user status claude@default.service
  ```

  Expected: Active (running), no error lines in recent logs

- [ ] **Journal shows claude started**

  ```bash
  journalctl --user -u claude@default -n 20 --no-pager
  ```

  Expected: Log entries showing claude-wrapper launching claude; no crash loops

- [ ] **Remote control URL available (if CLAUDE_CONNECT=remote-control)**

  ```bash
  journalctl --user -u claude@default --no-pager -n 50 | grep -i "remote\|url\|http"
  ```

  Expected: A remote control URL is logged (for remote-control mode)

---

## 4. Instrument Add/Remove Lifecycle

Test adding and removing a non-default instrument.

- [ ] **Add a test instrument**

  ```bash
  claude-service add test-instrument https://github.com/some/test-repo.git
  ```

  Expected: "Instrument 'test-instrument' added and started"

- [ ] **Verify env file created**

  ```bash
  ls -la ~/.config/claude-restart/test-instrument/env
  ```

  Expected: File exists with permissions `600`

- [ ] **Verify working directory cloned**

  ```bash
  ls ~/instruments/test-instrument/
  ```

  Expected: Directory exists with repo contents

- [ ] **Verify .claude/CLAUDE.md deployed with instance name**

  ```bash
  grep "test-instrument" ~/instruments/test-instrument/.claude/CLAUDE.md
  ```

  Expected: Instance name "test-instrument" appears in the identity file

- [ ] **Verify service running**

  ```bash
  systemctl --user is-active claude@test-instrument.service
  ```

  Expected: `active`

- [ ] **Verify watchdog timer active**

  ```bash
  systemctl --user is-active claude-watchdog@test-instrument.timer
  ```

  Expected: `active`

- [ ] **List instruments**

  ```bash
  claude-service list
  ```

  Expected: Both `default` and `test-instrument` shown with status `active`

- [ ] **Remove test instrument**

  ```bash
  claude-service remove test-instrument
  ```

  Expected: "Instrument 'test-instrument' removed" (confirm with "yes" if prompted)

- [ ] **Verify cleanup: env dir gone**

  ```bash
  ls ~/.config/claude-restart/test-instrument 2>&1
  ```

  Expected: `No such file or directory`

- [ ] **Verify cleanup: work dir gone**

  ```bash
  ls ~/instruments/test-instrument 2>&1
  ```

  Expected: `No such file or directory`

- [ ] **Verify service stopped**

  ```bash
  systemctl --user is-active claude@test-instrument.service 2>&1
  ```

  Expected: `inactive` or `could not be found`

---

## 5. Orchestra Add and Dispatch

Test the orchestra supervisor instrument.

- [ ] **Add orchestra**

  ```bash
  claude-service add-orchestra
  ```

  Expected: "Orchestra instrument registered and started"

- [ ] **Verify orchestra CLAUDE.md deployed**

  ```bash
  head -5 ~/instruments/orchestra/CLAUDE.md
  ```

  Expected: Orchestra behavioral spec header (not empty)

- [ ] **Verify orchestra identity hint**

  ```bash
  cat ~/instruments/orchestra/.claude/CLAUDE.md
  ```

  Expected: Contains "Instrument: orchestra" and "orchestra supervisor instance"

- [ ] **Verify orchestra service running**

  ```bash
  systemctl --user is-active claude@orchestra.service
  ```

  Expected: `active`

- [ ] **Test dispatch: send a simple prompt via claude -p**

  ```bash
  cd ~/instruments/orchestra && claude -p "echo hello" --output-format text
  ```

  Expected: A text response from Claude (confirms dispatch works)

- [ ] **Remove orchestra when done testing**

  ```bash
  claude-service remove orchestra
  ```

  Expected: "Instrument 'orchestra' removed"

---

## 6. Heartbeat and FIFO Verification

Verify the heartbeat mechanism for session keepalive.

- [ ] **For telegram mode: Check heartbeat log entries**

  ```bash
  journalctl --user -u claude@default --grep="heartbeat sent" --no-pager -n 5
  ```

  Expected: Recent "heartbeat sent" entries with timestamps (telegram mode only)

  Alternative using claude-service:

  ```bash
  claude-service heartbeat default
  ```

  Expected: Recent heartbeat entries

- [ ] **For remote-control mode: Verify FIFO exists while service runs**

  ```bash
  ls /tmp/claude-heartbeat.*
  ```

  Expected: At least one FIFO file listed (created by claude-wrapper)

- [ ] **Verify FIFO cleanup after service stop**

  ```bash
  systemctl --user stop claude@default.service && ls /tmp/claude-heartbeat.* 2>&1
  ```

  Expected: `No such file or directory` (FIFO cleaned up on stop)

- [ ] **Restart service after test**

  ```bash
  systemctl --user start claude@default.service
  ```

  Expected: Service starts successfully (verify with `systemctl --user is-active claude@default.service`)

---

## 7. Watchdog Timer Firing

Verify the watchdog performs mode-aware restarts.

- [ ] **Verify watchdog timer is active**

  ```bash
  systemctl --user is-active claude-watchdog@default.timer
  ```

  Expected: `active`

- [ ] **Check timer schedule**

  ```bash
  systemctl --user list-timers --all | grep claude-watchdog
  ```

  Expected: Shows claude-watchdog@default.timer with ~8h intervals (OnBootSec=8h, OnUnitActiveSec=8h)

- [ ] **For telegram mode: manually trigger watchdog and verify restart**

  ```bash
  systemctl --user start claude-watchdog@default.service
  journalctl --user -u claude-watchdog@default --no-pager -n 5
  ```

  Expected: Log shows "restarting claude@default" and service restarts

- [ ] **For remote-control mode: watchdog should skip restart**

  ```bash
  systemctl --user start claude-watchdog@default.service
  journalctl --user -u claude-watchdog@default --no-pager -n 5
  ```

  Expected: Log shows "skipped restart (remote-control mode has built-in reconnection)"

---

## 8. Update Command

> **Note:** The `update` command is a planned feature. If `claude-service update` is not yet
> implemented, skip this section and revisit after the feature is added.

- [ ] **Run update on default**

  ```bash
  claude-service update default
  ```

  Expected: Re-deploys CLAUDE.md and skills for the default instance

- [ ] **Verify CLAUDE.md was re-deployed**

  ```bash
  stat ~/instruments/default/.claude/CLAUDE.md
  ```

  Expected: Timestamp is recent (updated during this session)

- [ ] **Run update --all**

  ```bash
  claude-service update --all
  ```

  Expected: Updates all instruments; shows GSD and superpowers install output

- [ ] **Verify skills re-deployed**

  ```bash
  ls ~/.claude/get-shit-done/ && ls ~/.claude/plugins/
  ```

  Expected: GSD and superpowers directories exist with current content

---

## 9. Restart Mechanism

Test the restart signal flow (claude-restart -> restart file -> claude-wrapper picks up).

- [ ] **Create restart file and verify restart**

  ```bash
  claude-restart --instance default
  ```

  Expected: "Restarting claude..." and journal shows service restarting

  Verify in journal:

  ```bash
  journalctl --user -u claude@default -n 10 --no-pager
  ```

  Expected: Restart messages visible

- [ ] **Restart with new args**

  ```bash
  claude-restart --instance default -p "test prompt"
  ```

  Expected: "Restarting claude with: -p test prompt" and journal shows new args

  Verify:

  ```bash
  journalctl --user -u claude@default -n 10 --no-pager
  ```

- [ ] **Verify systemctl restart works**

  ```bash
  claude-service restart default
  claude-service status default
  ```

  Expected: "Claude service restarted (default)" followed by active status

- [ ] **Verify max restart protection**

  ```bash
  grep MAX_RESTARTS ~/.local/bin/claude-wrapper
  ```

  Expected: `CLAUDE_WRAPPER_MAX_RESTARTS` defaults to `10`

  Also check env file:

  ```bash
  grep MAX_RESTARTS ~/.config/claude-restart/default/env
  ```

  Expected: Either not set (uses default of 10) or set to a reasonable value

---

## 10. Cleanup and Final State

Verify the system is in a clean, expected state after all testing.

- [ ] **All expected services running**

  ```bash
  claude-service list
  ```

  Expected: `default` shown as `active`; no leftover test instruments

- [ ] **No orphaned FIFOs**

  ```bash
  ls /tmp/claude-heartbeat.* 2>&1
  ```

  Expected: Only FIFOs for currently running instances (or "No such file" if none expected)

- [ ] **No orphaned restart files**

  ```bash
  ls ~/.config/claude-restart/*/restart 2>&1
  ```

  Expected: `No such file or directory` (restart files are consumed and deleted)

- [ ] **Memory limit applied**

  ```bash
  systemctl --user show claude@default.service | grep MemoryMax
  ```

  Expected: `MemoryMax=1073741824` (1G in bytes) or the value set in env file

---

## Results Summary

| Section | Pass | Fail | Skipped | Notes |
|---------|------|------|---------|-------|
| 1. Pre-Deploy Checks | | | | |
| 2. install.sh Execution | | | | |
| 3. Default Instance Smoke Test | | | | |
| 4. Instrument Add/Remove Lifecycle | | | | |
| 5. Orchestra Add and Dispatch | | | | |
| 6. Heartbeat and FIFO Verification | | | | |
| 7. Watchdog Timer Firing | | | | |
| 8. Update Command | | | | |
| 9. Restart Mechanism | | | | |
| 10. Cleanup and Final State | | | | |

**Overall Result:** PASS / FAIL

**Notes:**
