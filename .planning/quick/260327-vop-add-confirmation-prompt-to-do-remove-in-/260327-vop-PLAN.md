---
phase: quick
plan: 260327-vop
type: execute
wave: 1
depends_on: []
files_modified:
  - bin/claude-service
autonomous: true
requirements: [QUICK-260327-vop]
must_haves:
  truths:
    - "Running `claude-service remove <name>` without --force shows what will be deleted and asks for confirmation"
    - "Typing anything other than 'yes' aborts the removal"
    - "Running `claude-service remove --force <name>` or `claude-service remove <name> --force` skips confirmation and removes immediately"
  artifacts:
    - path: "bin/claude-service"
      provides: "do_remove with confirmation prompt and --force flag support"
      contains: "confirm_removal"
  key_links:
    - from: "case statement (line ~293)"
      to: "do_remove function"
      via: "--force flag parsing and passthrough"
      pattern: "--force"
---

<objective>
Add an interactive confirmation prompt to `do_remove` in `bin/claude-service` so that `rm -rf` on config and working directories requires explicit user consent. Add a `--force` flag to skip confirmation for automation use cases.

Purpose: Prevent accidental deletion of entire repos with uncommitted work from a single typo.
Output: Updated `bin/claude-service` with safe remove behavior.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@bin/claude-service
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add confirmation prompt and --force flag to do_remove</name>
  <files>bin/claude-service</files>
  <action>
Make three changes to bin/claude-service:

1. **Update do_remove function (line 234)** to accept a second parameter `force`:
   ```
   do_remove() {
       local name="$1"
       local force="${2:-false}"
   ```

   After the "Check instrument exists" block (after line 249), add a confirmation prompt that is skipped when force=true:
   ```bash
   # Confirm removal (skip with --force)
   if [[ "$force" != "true" ]]; then
       echo "Will permanently delete instrument '$name':"
       echo "  Config:  $env_dir"
       echo "  Working: $work_dir"
       [[ -d "$work_dir" ]] && echo "  WARNING: $work_dir contains $(cd "$work_dir" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ') uncommitted change(s)" || true
       echo ""
       printf "Type 'yes' to confirm: "
       read -r answer
       if [[ "$answer" != "yes" ]]; then
           echo "Aborted."
           exit 1
       fi
   fi
   ```

   The git status warning line should only appear if the work_dir IS a git repo with uncommitted changes. Use `git -C "$work_dir" status --porcelain 2>/dev/null` instead of cd subshell for cleaner implementation. Only print the WARNING line if the count is > 0.

2. **Update the case statement (line 293)** to parse --force from either position and pass it through:
   ```bash
   remove)
       local force=false
       local remove_name=""
       shift  # past 'remove'
       while [[ $# -gt 0 ]]; do
           case "$1" in
               --force) force=true ;;
               *) remove_name="$1" ;;
           esac
           shift
       done
       if [[ -z "$remove_name" ]]; then
           echo "Usage: claude-service remove [--force] <name>" >&2
           exit 1
       fi
       do_remove "$remove_name" "$force"
       ;;
   ```

3. **Update usage text (line 22)** to document the flag:
   Change: `echo "  remove <name>          Remove an instrument"`
   To:     `echo "  remove [--force] <name> Remove an instrument (prompts for confirmation)"`

   Also update the example (line 37):
   After `echo "  claude-service remove myproject"` add:
   `echo "  claude-service remove --force myproject  # skip confirmation"`
  </action>
  <verify>
    <automated>bash -c 'bash -n bin/claude-service && echo "Syntax OK" && grep -q "confirm" bin/claude-service && grep -q "\-\-force" bin/claude-service && echo "All patterns present"'</automated>
  </verify>
  <done>
    - `claude-service remove name` shows config dir, working dir, uncommitted change count, and asks for "yes" confirmation
    - Any answer besides "yes" aborts with exit 1
    - `claude-service remove --force name` and `claude-service remove name --force` both skip confirmation
    - Usage text documents the --force flag
    - Script passes bash -n syntax check
  </done>
</task>

</tasks>

<verification>
- `bash -n bin/claude-service` passes (no syntax errors)
- grep confirms --force flag handling exists
- grep confirms confirmation prompt text exists
- Usage text includes --force documentation
</verification>

<success_criteria>
The remove command is no longer a silent `rm -rf` -- it shows what will be deleted, warns about uncommitted changes, and requires explicit "yes" confirmation. The --force flag provides an escape hatch for scripts and automation.
</success_criteria>

<output>
After completion, create `.planning/quick/260327-vop-add-confirmation-prompt-to-do-remove-in-/260327-vop-SUMMARY.md`
</output>
