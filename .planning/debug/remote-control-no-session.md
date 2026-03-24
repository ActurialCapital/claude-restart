---
status: diagnosed
trigger: "Remote-control mode doesn't spawn a session"
created: 2026-03-23T00:00:00Z
updated: 2026-03-23T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED - Two sequential readline prompts block in non-TTY; the "y" from FIFO may answer the first but a second spawn-mode prompt also reads from stdin and gets a heartbeat empty-line, choosing default. However the PRIMARY issue is likely that remoteDialogSeen is NOT set in the global config on the VPS, so the first prompt fires and may race with the FIFO fd 3 open.
test: Source code analysis of claude CLI binary
expecting: Confirm stdin vs /dev/tty for prompt reading
next_action: Return diagnosis

## Symptoms

expected: claude remote-control spawns a child session (--print --sdk-url ...), registers with broker, starts claude-peers MCP
actual: Process tree shows only `claude remote-control` and heartbeat subshell. No child session, no MCP server, no orchestra peer.
errors: No explicit errors reported - process just sits idle
reproduction: Start orchestra service via systemd; observe process tree
started: Since remote-control mode was implemented

## Eliminated

- hypothesis: "y" is never written to stdin because FIFO blocking prevents the heartbeat subshell from opening fd 3
  evidence: Test 21 in test-wrapper.sh confirms the mock claude receives "y" on stdin. The FIFO mechanism itself works correctly - the subshell opens fd 3 and writes "y" before the heartbeat loop.
  timestamp: 2026-03-23

## Evidence

- timestamp: 2026-03-23
  checked: claude remote-control --help output
  found: No --yes, --auto-accept, or --skip-prompts flag exists. No flag to bypass the "Enable Remote Control?" confirmation prompt.
  implication: The only way to auto-confirm is via stdin (which the wrapper does) or by pre-setting the remoteDialogSeen global config flag.

- timestamp: 2026-03-23
  checked: claude CLI source code (minified JS at /opt/homebrew/bin/claude, v2.1.81)
  found: |
    The "Enable Remote Control? (y/n)" prompt uses Node.js readline:
    ```js
    let r = (await import("readline")).createInterface({input: process.stdin, output: process.stdout});
    let O6 = await new Promise((u6) => { r.question("Enable Remote Control? (y/n) ", u6) });
    r.close();
    ```
    CRITICAL: It reads from `process.stdin`, NOT from `/dev/tty`. This means the FIFO stdin approach SHOULD work.
  implication: The hypothesis that the prompt reads from /dev/tty is WRONG. The "y" from the FIFO should reach the readline interface.

- timestamp: 2026-03-23
  checked: claude CLI source - spawn mode prompt
  found: |
    There is a SECOND interactive prompt after the "Enable Remote Control" confirmation:
    ```js
    if (k && !M6 && K6 && $ === void 0 && !X && process.stdin.isTTY) {
        // "Choose [1/2] (default: 1):" spawn mode prompt
    }
    ```
    This second prompt is GATED by `process.stdin.isTTY`. When stdin is a FIFO (not a TTY), `process.stdin.isTTY` is `undefined`/falsy, so this prompt is SKIPPED.
  implication: The spawn mode prompt is not the blocker - it auto-skips in non-TTY mode.

- timestamp: 2026-03-23
  checked: claude CLI source - remoteDialogSeen config flag
  found: |
    The "Enable Remote Control?" prompt is conditional on `!C().remoteDialogSeen`. This is a global config flag.
    After answering, it sets `remoteDialogSeen: true` in the global config.
    If `remoteDialogSeen` is already `true`, the prompt is completely SKIPPED.
  implication: On a fresh VPS install where claude has never been run interactively, remoteDialogSeen is false, so the prompt fires. On subsequent runs after first successful confirmation, it would be skipped.

- timestamp: 2026-03-23
  checked: FIFO write timing in claude-wrapper (lines 104-125)
  found: |
    The wrapper does:
    1. `mkfifo "$HEARTBEAT_FIFO"` (line 106)
    2. `claude ... < "$HEARTBEAT_FIFO" &` (line 107) -- claude blocks waiting for FIFO reader
    3. Subshell starts (line 109)
    4. `exec 3>"$HEARTBEAT_FIFO"` (line 112) -- opens FIFO for writing, unblocks claude's stdin
    5. `echo "y" >&3` (line 114) -- writes "y\n" to FIFO

    There is a RACE CONDITION: claude must have its readline interface set up and be reading
    from stdin BEFORE the "y" arrives. But claude is a Node.js app that needs to:
    - Parse and execute JS
    - Check auth tokens
    - Import readline module
    - Create readline interface
    - Call r.question()

    The subshell writes "y" essentially immediately after opening fd 3. If readline
    isn't listening yet, the "y" sits in the pipe buffer -- which should be fine because
    pipes buffer data. When readline eventually reads, it should find the "y".

    HOWEVER: readline reads line-by-line. The "y\n" should be consumed as one line.
    But if there is ANY other read from stdin before readline sets up (e.g., during
    Node.js startup, or checking isTTY), the data could be consumed before readline
    sees it.
  implication: The pipe buffer should hold the "y" until readline reads it. Timing should NOT be the issue.

- timestamp: 2026-03-23
  checked: What happens after confirmation is accepted
  found: |
    After "y" is accepted:
    1. remoteDialogSeen is set to true in global config
    2. The spawn mode prompt is skipped (stdin is not TTY)
    3. Remote control server starts, creates a session
    4. `process.stdin.setRawMode(true)` is called for keyboard input -- BUT this ONLY runs if `process.stdin.isTTY` is true
    5. The process enters its main event loop

    When stdin is NOT a TTY, setRawMode is skipped (good), and the process should
    run as a server without needing further stdin interaction.
  implication: After confirmation, the server should start and spawn sessions normally.

- timestamp: 2026-03-23
  checked: Possible issue with readline consuming more than just "y"
  found: |
    readline.createInterface({input: process.stdin}) takes over stdin. When readline
    is created, it starts consuming data from stdin. After r.close(), readline stops.
    But the heartbeat subshell continues to write empty lines ("") every 5 minutes.

    If readline is closed properly, subsequent writes to stdin should just buffer.
    But if something else reads stdin after readline closes, those empty heartbeat
    lines could cause issues.

    Looking at the code after readline closes: the process enters its server loop.
    It only reads stdin again if `process.stdin.isTTY` is true (for keypress handling).
    Since FIFO stdin is not a TTY, stdin should be ignored after readline closes.
  implication: Heartbeat empty lines should be harmless after confirmation is consumed.

## Resolution

root_cause: |
  INVESTIGATION POINTS TO A TIMING/BUFFERING ISSUE OR A FIRST-RUN CONFIGURATION ISSUE.

  The source code analysis shows:
  1. The "Enable Remote Control?" prompt DOES read from process.stdin (not /dev/tty) -- so the FIFO approach is architecturally correct
  2. The spawn mode prompt is skipped in non-TTY mode -- not a blocker
  3. The readline should consume the buffered "y" from the pipe

  THREE POSSIBLE ROOT CAUSES (ranked by likelihood):

  **A) (MOST LIKELY) The VPS has `remoteDialogSeen: true` from a previous run, so the prompt is skipped,
  and the "y" goes into stdin as garbage. Meanwhile the REAL problem is something else entirely --
  perhaps auth failure, network issue, or the session just isn't showing in the process tree the way expected.**

  **B) (LIKELY) readline on the specific Node.js version on the VPS has a bug or behavior difference
  with FIFO stdin. Some Node versions handle non-TTY readline differently -- the "y" might be
  consumed but readline might not emit the "line" event correctly from a pipe.**

  **C) (POSSIBLE) There is a pre-readline stdin read somewhere in the Node.js startup path
  that consumes the "y" before readline gets it. This would leave readline hanging forever
  waiting for input that was already consumed.**

  RECOMMENDED FIX APPROACH:
  Rather than relying on piping "y" through stdin, bypass the prompt entirely by:
  1. Pre-setting `remoteDialogSeen: true` in the global config before launching (safest)
  2. OR using `--settings '{"remoteDialogSeen": true}'` if the flag accepts it
  3. OR adding a small delay before writing "y" (fragile, not recommended)

fix: |
  NOT YET APPLIED (diagnosis only mode).

  Recommended fix direction: Pre-set the remoteDialogSeen global config flag
  before launching claude remote-control, eliminating the prompt entirely.
  This is more robust than piping "y" through stdin.

  Implementation options:
  1. Run a one-time `claude` interactive session during install to set the flag
  2. Directly write to claude's global config JSON (fragile, config location may vary)
  3. Check if `--settings` flag can override global config to skip the prompt

verification:
files_changed: []
