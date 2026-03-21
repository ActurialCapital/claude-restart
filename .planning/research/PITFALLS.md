# Pitfalls Research

**Domain:** VPS reliability — systemd + watchdog + keep-alive for a bash-based CLI restart wrapper
**Researched:** 2026-03-20
**Confidence:** HIGH (core pitfalls verified via official systemd docs, Claude Code official docs, and multiple community sources)

---

## Critical Pitfalls

### Pitfall 1: Double-Restart Loop — Wrapper and systemd Both React to an Exit

**What goes wrong:**
The existing `claude-wrapper` loop already restarts Claude when a restart file appears. If systemd also watches the same process with `Restart=always`, both layers will try to restart on the same exit event. This produces conflicting PID tracking, orphaned processes, and a race between the wrapper loop and systemd's restart logic. In the worst case, you get two Claude instances running simultaneously or the wrapper exits (because no restart file was present) and systemd immediately launches a fresh wrapper that has no context about the original session args.

**Why it happens:**
The natural instinct is to wrap `claude-wrapper` in a systemd service and set `Restart=always` "just in case." The problem is that `claude-wrapper` already IS the restart logic — systemd should only act when the wrapper itself dies unexpectedly, not on every clean wrapper exit.

**How to avoid:**
Set `Restart=on-failure` (not `Restart=always`) so systemd only restarts `claude-wrapper` when it exits with a non-zero code and there is no restart file present. The wrapper already exits 0 when Claude exits normally (no restart file) and exits 1 when max restarts are exceeded. Treat systemd as the "process crashed entirely" layer, not the "session restart" layer. The division of responsibilities must be explicit:
- **claude-wrapper loop**: handles intentional restarts (restart file present)
- **systemd**: handles wrapper crashes or unexpected exits (exit code non-zero, no restart file)

**Warning signs:**
- `journalctl -u claude` showing rapid restart entries not triggered by the restart file
- Two `claude` processes visible in `ps aux` simultaneously
- `~/.claude-restart` file appearing when you didn't trigger a restart

**Phase to address:**
Phase: systemd service setup — must be designed first before watchdog or keep-alive are added, since they interact with this restart layer.

---

### Pitfall 2: systemd Enters "Failed" State and Stops Restarting

**What goes wrong:**
systemd's `StartLimitBurst` and `StartLimitIntervalSec` defaults (or misconfigured values) cause the service to enter a permanent `failed` state after N restarts within a time window. On an unattended VPS, this means Claude silently stops running and nothing restarts it. The Telegram plugin goes unresponsive — which is already the symptom you're trying to fix — and now even a crash won't cause a recovery.

**Why it happens:**
The defaults are conservative. `StartLimitBurst=5` within `StartLimitIntervalSec=10s` is a common default. If Claude crashes (or is killed by the watchdog) several times during a bad session, the burst limit is hit and systemd stops. A common misconfiguration compounds this: `StartLimitIntervalSec` and `StartLimitBurst` must go in the `[Unit]` section, not `[Service]` — if placed in `[Service]`, they are silently ignored and the hardcoded defaults apply.

**How to avoid:**
Explicitly configure in `[Unit]`:
```ini
[Unit]
StartLimitIntervalSec=300
StartLimitBurst=10
```
Or for indefinite restarts (personal VPS where you always want recovery):
```ini
[Unit]
StartLimitIntervalSec=0
```
Add `OnFailure=notify-failure@%n.service` or at minimum log to a file when the limit is hit, so silence doesn't happen undetected.

**Warning signs:**
- `systemctl status claude` shows `Active: failed (Result: start-limit-hit)`
- Claude stopped responding and SSH shows the process is gone, no auto-recovery
- `journalctl` shows restarts stopping abruptly

**Phase to address:**
Phase: systemd service setup — configure limits explicitly before going unattended.

---

### Pitfall 3: Watchdog Kills a Genuinely Busy (Not Hung) Claude Instance

**What goes wrong:**
A watchdog that probes for responsiveness by checking output, file modification time, or API response uses a fixed timeout. Claude Code can legitimately take 3–5+ minutes on a complex task, producing no output during that time. The watchdog interprets silence as a hung state and sends SIGKILL. This is a false positive: Claude was working, not hung. The result is data loss (mid-task kill), unnecessary restarts, and eroded trust in the reliability system.

**Why it happens:**
Developers use simple "no output in N seconds" or "no file touched in N seconds" heuristics because the Telegram plugin's hung symptom looks identical to a long-running task. Both produce silence. The key difference is that a truly hung Claude does not consume CPU and does not make API calls, while a busy Claude does both.

**How to avoid:**
Use CPU activity as a liveness signal, not output silence. A process with >0% CPU usage over a rolling window is not hung. Combine:
1. `ps -o %cpu= -p $PID` — non-zero CPU over 60s window = alive
2. Presence of outbound HTTPS connections from the PID (via `ss -tp` or `/proc/$PID/net/tcp`) — active API call = alive
3. Only declare "hung" if: process exists AND cpu% is ~0 AND no network activity AND last_output_time > threshold (e.g., 10 minutes)

The threshold must be much longer than any plausible task duration. 10 minutes is a reasonable floor for a VPS use case where the Telegram plugin was observed to go unresponsive indefinitely.

**Warning signs:**
- Claude restarts in the middle of complex tasks
- Watchdog log shows "no output in Ns" killing a process that had recent API cost logged
- Users report "Claude was working then disappeared"

**Phase to address:**
Phase: watchdog implementation — liveness criteria must be defined and tested with actual hung vs. busy scenarios before deployment.

---

### Pitfall 4: Signal Handling — Wrapper Does Not Forward SIGTERM to Claude

**What goes wrong:**
When systemd stops the service (e.g., `systemctl stop claude`), it sends SIGTERM to the `claude-wrapper` process. Bash does not automatically forward signals to child processes. The current `claude-wrapper` only traps `SIGINT`. If `SIGTERM` arrives while `claude` is running in the foreground, bash's default behavior is to wait for the foreground child, then handle the signal after the child exits — or in some versions, handle it immediately and leave `claude` running as an orphan. The result: `systemctl stop` hangs, times out, and then sends SIGKILL — a hard kill with no cleanup.

**Why it happens:**
The bash wrapper pattern (run child in foreground, wait for it) works fine interactively. It doesn't handle the service management signal lifecycle. Most tutorials show `exec claude` as the solution (replace the shell with the child), but `exec` can't be used here because the wrapper needs to loop.

**How to avoid:**
Add explicit SIGTERM forwarding to the wrapper:
```bash
trap 'kill -TERM $claude_pid 2>/dev/null; wait $claude_pid' TERM

claude "${current_args[@]}" &
claude_pid=$!
wait $claude_pid
exit_code=$?
```
Running Claude in the background with `&` and using `wait` allows signals to be trapped and forwarded during the wait. The current wrapper uses foreground execution (`claude "${current_args[@]}"` without `&`), which means signals received during the wait are deferred until after the child exits in bash's default mode.

**Warning signs:**
- `systemctl stop claude` hangs for 90 seconds before completing (the default TimeoutStopSec)
- `journalctl` shows `Sent SIGKILL` after a stop command
- Claude does not perform any shutdown behavior (e.g., saving state) on service stop

**Phase to address:**
Phase: systemd service setup — wrapper must be updated before wrapping in a service.

---

### Pitfall 5: tmux and systemd Fight Over Process Ownership

**What goes wrong:**
Running `claude-wrapper` inside a tmux session that is itself managed by systemd (or started during SSH login) creates a cgroup ownership conflict. When the SSH session ends, systemd may kill the entire cgroup (including tmux and everything inside it) even if `tmux` is intended to persist. Two specific failure modes:

1. **KillUserProcesses=yes** (the default on many distributions since systemd 230): all user processes — including tmux — are killed on logout regardless of tmux's "detached" state.
2. **systemd-oomd cgroup pressure**: if Claude consumes high memory, systemd-oomd kills the entire cgroup scope, taking down tmux and all other windows.

Adding a systemd service that runs `claude-wrapper` directly (not inside tmux) solves the first problem but creates a new UX problem: there is no terminal to attach to for interactive monitoring.

**Why it happens:**
Developers assume "tmux detaches so the process survives logout." This was true before systemd's cgroup-based session management became default. The assumption is no longer valid on modern Linux distributions.

**How to avoid:**
Pick one ownership model and do not mix them:
- **Option A (recommended):** systemd user service owns `claude-wrapper` directly. Use `loginctl enable-linger $USER` so the user service survives logout. Monitor via `journalctl` instead of a tmux pane.
- **Option B:** systemd system service owns `claude-wrapper`. No tmux involvement. Requires root for service installation.
- **Never:** tmux inside systemd service inside another tmux. The layering creates ambiguous cgroup membership.

If interactive access is needed (e.g., for initial setup), that is a separate concern from the service lifecycle.

**Warning signs:**
- Claude stops running after SSH logout despite tmux being detached
- `systemctl status claude` shows running but process is not found in `ps`
- systemd-oomd kill events in `journalctl` affecting tmux

**Phase to address:**
Phase: systemd service setup — choose ownership model before implementing. Document explicitly which model is in use.

---

### Pitfall 6: Building Keep-Alive That Duplicates remote-control's Reconnection

**What goes wrong:**
`claude remote-control` already handles network interruptions: "if your laptop sleeps or your network drops, the session reconnects automatically when your machine comes back online." Building a separate keep-alive mechanism that also sends periodic pings or reconnects duplicates this behavior and can interfere with remote-control's own reconnection logic.

**Why it happens:**
The remote-control reconnect behavior is not prominently documented. Developers see "process alive but no response" and build their own keep-alive without checking what remote-control already provides.

**How to avoid:**
Before building any keep-alive:
1. Verify whether the specific mode (`remote-control` vs `--channels plugin:telegram@...`) has built-in reconnection.
2. `claude remote-control` has built-in reconnect — do not add keep-alive for this mode.
3. `claude --channels plugin:telegram@...` (the Telegram plugin) is the confirmed-unresponsive mode with no documented auto-reconnect — this IS the keep-alive target.

The keep-alive (if needed) should be mode-aware: only activate for Telegram channel mode, not for remote-control mode.

**Warning signs:**
- Keep-alive script trying to maintain a connection that remote-control is already maintaining
- Log showing double reconnect attempts after a network drop
- remote-control session becoming confused about connection state

**Phase to address:**
Phase: remote-control compatibility investigation — must happen before keep-alive implementation to know what gap actually exists.

---

### Pitfall 7: remote-control 10-Minute Network Timeout Causing Phantom Crashes

**What goes wrong:**
`claude remote-control` has an explicit documented behavior: "if your machine is awake but unable to reach the network for more than roughly 10 minutes, the session times out and the process exits." On a VPS with intermittent connectivity, this produces a process exit that looks like a crash to systemd, triggering restart logic. The restarted session has no memory of the previous conversation. If the watchdog is also active, it may see the exit and double-report it.

**Why it happens:**
The 10-minute timeout is an intentional safety valve in remote-control, not a bug. It is not configurable. VPS connectivity blips that last >10 minutes trigger it.

**How to avoid:**
Treat the remote-control timeout exit as a distinct exit code or log pattern, not a crash. In the systemd service:
- Use `Restart=always` for remote-control mode (since exit after timeout is expected and recovery via restart is correct)
- Distinguish it from the Telegram plugin mode which has different failure patterns
- Log the restart reason to distinguish "network timeout restart" from "crash restart" for debugging

**Warning signs:**
- remote-control restarts correlating with network events in VPS logs
- Conversation history lost after a network blip
- Watchdog and systemd both logging the same exit event

**Phase to address:**
Phase: mode integration — remote-control and Telegram plugin modes should have distinct systemd service configurations (or a single service with mode-aware restart policy).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `Restart=always` without `StartLimitIntervalSec=0` | Simple config | Service silently enters failed state after N crashes; Claude stops on VPS with no recovery | Never — configure limits explicitly |
| Single systemd service for both remote-control and Telegram modes | Less setup | Different failure modes (network timeout vs. hang) handled identically; incorrect restart behavior for one mode | Never — modes need distinct restart policies |
| CPU=0% as sole hung-detection criterion | Simple check | False positive when Claude is in a brief pause between API calls | Acceptable only if combined with a 10+ minute window |
| Polling watchdog (cron every minute) | No signal handling complexity | 1-minute blind spot between hang and detection; cron does not integrate with systemd watchdog protocol | Acceptable for MVP watchdog; migrate to systemd WatchdogSec later |
| Running wrapper in tmux for "convenience" | Interactive monitoring possible | cgroup conflict with systemd; session killed on logout | Only for development/testing — not production service |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| systemd + claude-wrapper loop | Using `Restart=always` — both layers restart on every exit | Use `Restart=on-failure`; wrapper handles intentional restarts, systemd handles crashes only |
| systemd + SIGTERM | Foreground child in bash does not receive forwarded SIGTERM | Run child with `&`, capture PID, use `wait`, trap SIGTERM to forward to child PID |
| systemd + tmux | Starting tmux inside a service or relying on tmux to outlast SSH sessions | Use `loginctl enable-linger` for user services; do not mix tmux and systemd as dual lifecycle managers |
| Watchdog + remote-control | Building keep-alive that competes with remote-control's built-in reconnection | Keep-alive only for Telegram plugin mode; remote-control handles its own reconnection |
| Watchdog + long tasks | Low timeout kills busy-but-working Claude | Use CPU and network activity signals; set threshold to 10+ minutes minimum |
| StartLimitBurst placement | Placing in `[Service]` section (silently ignored) | Must be in `[Unit]` section per systemd man page |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Watchdog polling at high frequency (every 5s) | CPU overhead, log spam, increased false positives | Poll no faster than every 60s; use exponential backoff on consecutive "suspicious" readings before acting | Always — high frequency polling is never justified for hung detection |
| Watchdog using `pgrep` pattern matching | Wrong process killed if multiple claude instances exist | Use PID stored at wrapper start, verified against `/proc/$PID/comm` | Immediately if multi-instance ever runs |
| RestartSec too low under systemd | Rapid crash-restart loop fills logs, exhausts rate limits | `RestartSec=10s` minimum for interactive CLI tools | Within seconds of a persistent crash condition |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing API keys in systemd `Environment=` directives (visible in `systemctl show`) | Credential exposure via `systemctl show` output which is world-readable | Use `EnvironmentFile=` pointing to a file with `chmod 600`; or rely on `~/.claude` credentials that Claude Code already manages |
| World-readable restart file (`~/.claude-restart`) | Any local user can inject arbitrary CLI args including `--dangerously-skip-permissions` | `chmod 600 ~/.claude-restart` and verify in install script |
| Watchdog script running as root to kill claude | Unnecessary privilege escalation; watchdog can kill wrong process | Run watchdog as same user as Claude; use user-scoped systemd service |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| systemd restart with no session context | After a crash restart, Claude has no memory of what it was doing via Telegram | Log the restart event to a location the user can check; consider a "Claude restarted" message via the Telegram bot if feasible |
| Watchdog kill with no notification | User sends a Telegram message, silence — then Claude responds from a fresh session with no context | Watchdog should log the kill with timestamp; if Telegram plugin supports it, send a restart notification |
| remote-control session lost after 10-min network outage | User loses conversation history | Document this limitation explicitly; systemd restart is the correct recovery but conversation context is lost |
| Mode selection at launch unclear | User starts wrong mode (remote-control when they wanted Telegram plugin) | Mode selection UX (Phase: mode selection) should make the choice explicit and persistent |

---

## "Looks Done But Isn't" Checklist

- [ ] **systemd service restarts:** Verify `Restart=on-failure` not `Restart=always` — test by killing `claude-wrapper` directly vs. triggering a restart file restart
- [ ] **SIGTERM forwarding:** Run `systemctl stop claude` and confirm it completes in <10 seconds without SIGKILL appearing in journalctl
- [ ] **StartLimitBurst placement:** Confirm `StartLimitIntervalSec` and `StartLimitBurst` are in `[Unit]` section — run `systemctl show claude | grep StartLimit` to verify they took effect
- [ ] **Linger enabled:** After `systemctl enable claude` for user service, log out via SSH and verify service is still active with `systemctl --user status claude` from another session
- [ ] **Watchdog false positive test:** Run a long task (5+ minutes), confirm watchdog does not kill the process mid-task
- [ ] **Watchdog true positive test:** Simulate a hung process (kill -STOP $pid), confirm watchdog detects and kills within threshold
- [ ] **Mode-specific behavior:** Verify keep-alive does NOT run when in remote-control mode, DOES run when in Telegram plugin mode
- [ ] **remote-control overlap:** Confirm no keep-alive script is pinging while remote-control's own reconnect logic is active
- [ ] **Restart file permissions:** `ls -la ~/.claude-restart` shows 600 after install

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Service in failed state (hit StartLimitBurst) | LOW | `systemctl reset-failed claude && systemctl start claude` |
| Double-restart loop producing two Claude instances | MEDIUM | `systemctl stop claude`, kill all `claude` processes manually, verify single instance before restart |
| SIGTERM not forwarded — claude orphaned | LOW | `pkill -f claude`; fix wrapper signal handling before next deployment |
| Watchdog false-positive mid-task kill | LOW (for user) | Restart is automatic; adjust threshold; apologize to Telegram user |
| tmux session killed after SSH logout | MEDIUM | Re-enable lingering, switch to pure systemd service ownership, restart |
| remote-control 10-min timeout during network outage | LOW | Systemd restarts automatically; conversation context is lost — this is acceptable |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Double-restart loop (wrapper + systemd) | Phase: systemd service — restart policy design | `systemctl stop claude` should exit wrapper cleanly; `kill -9 <wrapper_pid>` should trigger systemd restart |
| Service enters failed state silently | Phase: systemd service — StartLimit configuration | Crash service 10x rapidly; confirm systemd keeps restarting |
| Watchdog false positive on long tasks | Phase: watchdog implementation — liveness criteria | Run 5-min task; confirm no kill; stop process; confirm kill within threshold |
| SIGTERM not forwarded to Claude | Phase: systemd service — wrapper signal handling update | `systemctl stop claude` completes in <10s with no SIGKILL |
| tmux/systemd cgroup conflict | Phase: systemd service — ownership model decision | SSH logout; confirm service survives |
| Keep-alive duplicating remote-control reconnect | Phase: remote-control compatibility — feature gap audit | Enable both; simulate network drop; confirm single reconnect attempt |
| remote-control 10-min timeout as phantom crash | Phase: mode integration — distinct service configs | Simulate network outage >10min; confirm clean restart without watchdog double-reporting |
| StartLimitBurst in wrong section | Phase: systemd service — config review | `systemctl show claude | grep StartLimit` matches intended values |

---

## Sources

- [systemd.service — Restart, StartLimitBurst, StartLimitIntervalSec documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [Claude Code Remote Control official docs](https://code.claude.com/docs/en/remote-control) — confirmed built-in reconnect behavior, 10-minute timeout, /clear not supported in remote-control server mode
- [How to propagate SIGTERM to a child process in a Bash script — veithen.io](https://veithen.io/2014/11/16/sigterm-propagation.html)
- [Systemd service keeps restarting — ZeonEdge](https://zeonedge.com/blog/systemd-service-keeps-restarting-fix)
- [systemd StartLimitIntervalSec and StartLimitBurst placement issue — copyprogramming.com](https://copyprogramming.com/howto/systemd-s-startlimitintervalsec-and-startlimitburst-never-work)
- [systemd indefinite service restarts — Michael Stapelberg (2024)](https://michael.stapelberg.ch/posts/2024-01-17-systemd-indefinite-service-restarts/)
- [tmux user service exits on detach/logout — Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=162152)
- [KillUserProcesses tmux persistence issue — tmux GitHub issue #438](https://github.com/tmux/tmux/issues/438)
- [Warn/disallow Restart=always without preventing restart loop — systemd GitHub #30804](https://github.com/systemd/systemd/issues/30804)
- [systemd services killed by watchdog on suspend — Red Hat](https://access.redhat.com/solutions/5118401)
- [Bash forward SIGTERM to child processes — dirask.com](https://dirask.com/posts/Bash-forward-SIGTERM-to-child-processes-DkBqq1)
- [Child Process Graceful Shutdown in Shell Scripting — Medium](https://medium.com/@muhammedsaidkaya/child-process-graceful-shutdown-in-shell-scripting-8827ea45982a)
- Personal inspection of `bin/claude-wrapper` v1.0 (55 lines) — confirmed foreground child execution, SIGINT trap only, no SIGTERM forwarding

---
*Pitfalls research for: VPS reliability — systemd + watchdog + keep-alive for bash-based Claude Code restart wrapper*
*Researched: 2026-03-20*
