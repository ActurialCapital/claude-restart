---
status: awaiting_human_verify
trigger: "VPS Claude services die after period of inactivity, stop responding to remote-control messages"
created: 2026-03-28T00:00:00Z
updated: 2026-03-28T00:00:00Z
---

## Current Focus

hypothesis: Services die for unknown reason during inactivity. Root cause not yet determined, but observability was the primary blocker. Now fixed: comprehensive lifecycle logging and stderr filtering deployed. Restart=always + fixed watchdog ensure recovery. Next occurrence will reveal root cause.
test: Deployed logging + filter to VPS, verified services running with clean journal output
expecting: Next time service dies, journal will show exact exit code, timing, and context
next_action: Awaiting user verification that services are accessible via remote control

## Symptoms

expected: Claude services stay alive and responsive to remote-control messages indefinitely
actual: After some period of inactivity, Claude stops responding to messages
errors: No error messages visible to user
reproduction: Leave the VPS idle for some time, then try to send a message via Claude App remote control
started: Recurring pattern - works after fresh install, dies after inactivity

## Eliminated

## Evidence

- timestamp: 2026-03-28T22:17Z
  checked: Service status on VPS
  found: Both services currently active (7h uptime since 14:32:33 UTC). NRestarts=0 for current run. Memory 298M/1G for claude-restart, 120M/1G for orchestra.
  implication: Services are alive RIGHT NOW, issue is intermittent

- timestamp: 2026-03-28T22:17Z
  checked: Linger, OOM, memory
  found: Linger=yes. No OOM kills in dmesg. 6.6G available RAM. No swap.
  implication: NOT an OOM or session-scope issue

- timestamp: 2026-03-28T22:18Z
  checked: Journal log rate
  found: 28,760 lines/hour (~8 lines/sec) from remote-control mode constantly printing "Capacity: 0/32" status lines. Journal is 1.9GB. All useful lifecycle events are drowned in noise.
  implication: CRITICAL OBSERVABILITY PROBLEM - cannot diagnose failures because real events are hidden in spam

- timestamp: 2026-03-28T22:19Z
  checked: Service lifecycle events (full boot journal)
  found: Multiple stop/start cycles visible via systemd events. Key events:
    - Mar 27 22:29:12 - Stopping (took 11s, timed out at TimeoutStopSec=10, killed bun with SIGKILL, "Failed with result 'timeout'")
    - Mar 27 22:29:23 - Restarted successfully (Restart=always worked)
    - Mar 27 22:51:49 - Stopping (clean stop)
    - Mar 27 22:53:34 - Restarting
    - Mar 28 05:05:46 - Stopping/restarting
    - Mar 28 14:27:05 - Stopping/restarting
    - Mar 28 14:28:53 - Stopping/restarting
    - Mar 28 14:32:33 - Stopping/restarting (latest, current instance)
  implication: Service HAS been restarting multiple times. Restart=always is working. But we cannot tell WHY it's stopping because the wrapper logs nothing about exits.

- timestamp: 2026-03-28T22:20Z
  checked: Watchdog history
  found: OLD watchdog version was SKIPPING restarts with "skipped restart (remote-control mode has built-in reconnection)". New version (deployed at latest install) actually restarts. Most restarts were user-triggered (fresh install at ~14:27-14:32).
  implication: Previous watchdog was broken - never actually restarted services. Now fixed.

- timestamp: 2026-03-28T22:21Z
  checked: Wrapper logging
  found: claude-wrapper has ZERO logging of its own lifecycle. No log when it starts, no log when claude process exits, no log of exit code, no log when it decides to exit vs restart. The only way to see exits is via systemd lifecycle messages.
  implication: ROOT PROBLEM for observability - wrapper is a black box

## Resolution

root_cause: |
  The exact reason services die during inactivity is not yet proven (need to observe next occurrence with new logging). However, three compounding problems were identified and fixed:
  1. ZERO OBSERVABILITY: The wrapper had no lifecycle logging -- no startup message, no exit code logging, no heartbeat. When services died, there was no evidence of WHY because the only available data was systemd lifecycle events which just say "stopped/started" without the wrapper's exit code or context.
  2. JOURNAL SPAM: Claude remote-control mode outputs ~8 lines/second of repetitive status ("Capacity: 0/32", QR code prompts, etc.) which produced 28,760 lines/hour and a 1.9GB journal. Any real diagnostic information was completely drowned.
  3. WATCHDOG BYPASS: The old watchdog service was configured to SKIP restarts for remote-control mode ("skipped restart - remote-control mode has built-in reconnection"). This was fixed in the recent reinstall but the old behavior meant services that died were never automatically recovered by the watchdog.

  Additionally: Restart=always (already deployed) + StartLimitBurst=5/60s ensure systemd-level recovery. TimeoutStopSec increased to 30s to handle bun processes that don't exit promptly (observed SIGKILL at the old 10s timeout).

fix: |
  1. Added comprehensive lifecycle logging to claude-wrapper: startup params, child PID, exit codes with signal names, restart decisions, heartbeat every 10min with RSS memory
  2. Added rate-limiting stderr filter (filter_stderr) using named pipe: passes through errors/warnings/connection events, suppresses repetitive status spam (~360 lines/min -> 1 summary/min)
  3. Increased TimeoutStopSec from 10s to 30s in systemd unit (bun process was hitting timeout)
  4. Added StandardOutput=journal + StandardError=journal explicitly in unit file
  5. Vacuumed journal (needs root for full cleanup, new filter prevents future bloat)

verification: |
  - All 48 existing wrapper tests pass
  - Deployed to VPS, both services running
  - Journal shows clean lifecycle events: startup, pid, SIGTERM, exit
  - Stderr filter working: "suppressed 372 status lines in last 60s"
  - Journal rate reduced from ~28,760 lines/hour to ~60 lines/hour
  - Heartbeat timer visible (sleep 600 process in cgroup)

files_changed:
  - bin/claude-wrapper
  - systemd/claude@.service
