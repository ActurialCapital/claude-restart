---
status: awaiting_human_verify
trigger: "Claude App remote control - user sends a message to VPS and expects a reply back, but gets no response at all. No error messages. Was working before recent gsd:quick tasks the user triggered (several in a row)."
created: 2026-03-28T00:00:00Z
updated: 2026-03-28T00:10:00Z
---

## Current Focus

hypothesis: CONFIRMED (code-level). TWO compounding issues make the VPS remote-control service unable to recover from any process exit: (1) Restart=on-failure does not restart clean exits. (2) Watchdog skips remote-control mode. (3) Deploy workflow never restarts services after updating scripts. The trigger (multiple quick tasks) likely caused a process exit during or between deploys, and nothing brought it back.
test: Fixes applied to all three issues. Need user to verify VPS state and confirm fix works.
expecting: After pushing fixes, the deploy will restart all services, and future exits will always be recovered.
next_action: CHECKPOINT -- need user to (a) check VPS service status to confirm hypothesis, (b) push fixes to trigger deploy that restarts everything.

## Symptoms

expected: When user sends a message via Claude App remote control, the VPS Claude instance should process it and reply back
actual: No response at all - messages go into the void
errors: No error messages visible
reproduction: Send any message via Claude App remote control to the VPS
started: Was working before. Broke after user ran several gsd:quick tasks in a row recently

## Eliminated

## Evidence

- timestamp: 2026-03-28T00:01:00Z
  checked: Knowledge base for prior related issues
  found: Two entries -- (1) orchestra-peers-invisible (--no-create-session-in-dir fix), (2) peers-message-not-received (peek/ack pattern). Neither directly matches "no response from remote control."
  implication: This is a new issue, not a repeat of known patterns.

- timestamp: 2026-03-28T00:02:00Z
  checked: Recent git history and deploy workflow
  found: |
    Multiple gsd:quick tasks were merged on 2026-03-27, each triggering the deploy workflow.
    The deploy workflow (deploy.yml) does:
    1. git pull origin main
    2. cp bin/claude-wrapper bin/claude-restart bin/claude-service ~/.local/bin/
    3. cp systemd units
    4. systemctl --user daemon-reload
    5. claude-service update --all

    CRITICAL: It does NOT restart any services. The `update --all` function:
    - Re-deploys CLAUDE.md to each instrument
    - Calls deploy_skills() which runs:
      a. npx get-shit-done-cc@latest --global --claude
      b. claude plugins install superpowers@superpowers-marketplace

    The `claude plugins install` command launches a separate claude CLI process.
    Multiple deploys in a row would run this repeatedly.
  implication: Each push to main triggers a deploy that runs `claude plugins install` on the VPS while remote-control sessions are active. This could interfere with running sessions.

- timestamp: 2026-03-28T00:03:00Z
  checked: peers-no-auto-detect-in-remote-control.md debug session
  found: |
    This session (status: awaiting_human_verify) documents a message-watcher sidecar
    that was created directly on the VPS but never committed to the repo.
    files_changed: [bin/message-watcher, bin/claude-wrapper, bin/install.sh]

    The deploy workflow would have overwritten bin/claude-wrapper on the VPS with
    the repo version, potentially destroying VPS-only changes.

    HOWEVER: looking at the wrapper diff, the only recent changes to claude-wrapper
    in the repo are the shell-injection fix (34e67d2) and INT handler fix (69837cf).
    The message-watcher integration was supposedly in the wrapper but is not in the repo.
  implication: If the message-watcher was integrated into the VPS claude-wrapper, the deploy would have overwritten it with the repo version (which has no message-watcher support). BUT -- the user's symptom is about remote-control (Claude App), not peer messaging. Remote control should work independently of the message-watcher.

- timestamp: 2026-03-28T00:05:00Z
  checked: systemd service unit restart policy and watchdog behavior
  found: |
    1. claude@.service has `Restart=on-failure` -- only restarts on NON-ZERO exit
    2. claude-watchdog@.service SKIPS restart for remote-control mode:
       "skipped restart (remote-control mode has built-in reconnection)"
    3. The wrapper exits with the same code as the claude process when no restart file exists

    COMBINED EFFECT: If claude remote-control exits with code 0 for ANY reason
    (auth expiry, clean shutdown, update, etc.), the service dies permanently.
    Neither systemd's Restart policy nor the watchdog will bring it back.
  implication: This is a systemic fragility. Any clean exit = permanent death until manual `claude-service restart default`.

- timestamp: 2026-03-28T00:07:00Z
  checked: deploy workflow's INSTRUMENT.md.template handling
  found: |
    The deploy workflow copies bin/* scripts to ~/.local/bin/ but does NOT copy
    INSTRUMENT.md.template anywhere. The template is only deployed during initial
    install.sh run (to ~/.local/INSTRUMENT.md.template).

    do_update() for non-orchestra instruments does:
      cp "$script_dir/../INSTRUMENT.md.template" "$work_dir/.claude/CLAUDE.md"

    script_dir = ~/.local/bin, so it looks for ~/.local/INSTRUMENT.md.template.

    If this file doesn't exist (never installed, or was deleted), the cp fails.
    Under set -euo pipefail, this kills the entire claude-service process,
    aborting the deploy before deploy_skills() runs.

    If the file DOES exist from initial install, it's the OLD version (deploy
    never updates it). This is a staleness bug but not a crash.
  implication: Deploy workflow has a gap -- INSTRUMENT.md.template is not deployed alongside the scripts.

- timestamp: 2026-03-28T00:09:00Z
  checked: Whether deploy could crash the running remote-control process
  found: |
    The deploy does NOT directly interact with running services (no restart/stop).
    It only updates files on disk and runs deploy_skills.

    deploy_skills runs `claude plugins install superpowers@superpowers-marketplace`.
    This launches a SEPARATE claude CLI process. It modifies ~/.claude/ config
    (plugins list). It should NOT affect the running remote-control server process.

    npx get-shit-done-cc@latest --global --claude modifies ~/.claude/ (hooks/skills).
    Again, a separate process that shouldn't crash the server.

    HOWEVER: if the running claude process has an auto-update mechanism that triggers
    when it detects config changes, or if it watches ~/.claude/ for changes, these
    writes could trigger unexpected behavior.
  implication: The deploy shouldn't directly crash the running process, but indirect effects through shared ~/.claude/ config are possible.

## Resolution

root_cause: |
  Three compounding systemic issues prevent the remote-control service from
  recovering after any process exit:

  1. **Restart=on-failure (should be Restart=always):** If claude remote-control
     exits with code 0 (auth expiry, update, clean shutdown), systemd does NOT
     restart it. Only non-zero exits trigger restart.

  2. **Watchdog skips remote-control mode:** The watchdog oneshot has a conditional
     that skips restart for remote-control mode, claiming "built-in reconnection"
     handles it. This is wrong -- if the process exits, there is no reconnection.

  3. **Deploy workflow never restarts services:** The deploy copies new scripts
     and runs update --all but never restarts the running services. If a service
     died before or during the deploy, the deploy does not bring it back.

  4. **Deploy missing INSTRUMENT.md.template copy:** The deploy copies bin/* but
     not INSTRUMENT.md.template, so `do_update` for non-orchestra instruments
     uses a stale version (or fails if template was never installed).

  5. **Pre-existing bash bug:** `local` used outside function in remove case
     statement, causing `claude-service remove` to always fail.

  The trigger: multiple quick tasks merged on 2026-03-27, each triggering the
  deploy workflow. At some point the claude process exited (likely from
  deploy_skills running `claude plugins install` which may interfere with
  the running session's shared config, or from a natural timeout/restart).
  After the exit, nothing brought the service back.

fix: |
  Applied four fixes:
  1. systemd/claude@.service: Changed Restart=on-failure to Restart=always
  2. systemd/claude-watchdog@.service: Removed remote-control skip logic
  3. .github/workflows/deploy.yml: Added INSTRUMENT.md.template copy + env.template
     copy + service restart loop after update
  4. bin/claude-service: Fixed `local` outside function in remove case statement
  5. test/test-service-lifecycle.sh: Added --force to all remove calls (exposed
     by fix #4 unmasking the confirmation prompt)
  6. test/test-install.sh: Updated assertion for Restart=always

verification: |
  - test-service-lifecycle.sh: 47/47 passed
  - test-install.sh: 51/53 passed (2 pre-existing failures in test 20, unrelated)
  - Awaiting user VPS verification

files_changed:
  - systemd/claude@.service
  - systemd/claude-watchdog@.service
  - .github/workflows/deploy.yml
  - bin/claude-service
  - test/test-service-lifecycle.sh
  - test/test-install.sh
