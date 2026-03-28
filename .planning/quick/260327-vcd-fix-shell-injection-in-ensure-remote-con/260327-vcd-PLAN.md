---
phase: quick
plan: 260327-vcd
type: execute
wave: 1
depends_on: []
files_modified:
  - bin/claude-wrapper
  - test/test-wrapper.sh
autonomous: true
requirements: []
must_haves:
  truths:
    - "Working directory paths containing single quotes do not break ensure_remote_config"
    - "Working directory paths containing double quotes do not break ensure_remote_config"
    - "No shell variables are interpolated into Python source code strings"
  artifacts:
    - path: "bin/claude-wrapper"
      provides: "ensure_remote_config with safe argument passing"
  key_links:
    - from: "bin/claude-wrapper (bash)"
      to: "python3 inline script"
      via: "sys.argv or environment variable"
      pattern: "sys\\.argv|os\\.environ"
---

<objective>
Fix shell injection vulnerability in ensure_remote_config where $cwd and $config_file are interpolated directly into Python string literals via bash variable expansion. A path containing single quotes breaks the function; a crafted path could execute arbitrary Python.

Purpose: Security fix — eliminate code injection vector in a function that runs on every wrapper invocation.
Output: Patched ensure_remote_config passing values via sys.argv instead of string interpolation.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@bin/claude-wrapper (lines 56-99: ensure_remote_config function)
@test/test-wrapper.sh (lines 467-498: Test 23 for ensure_remote_config)
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Fix python3 paths in ensure_remote_config to use sys.argv</name>
  <files>bin/claude-wrapper, test/test-wrapper.sh</files>
  <behavior>
    - Test: ensure_remote_config works when cwd contains a single quote (e.g., /tmp/it's a test)
    - Test: ensure_remote_config works when cwd contains double quotes
    - Test: ensure_remote_config creates correct JSON with special-character paths
    - Test: existing Test 23 still passes (basic config creation + trust fields)
  </behavior>
  <action>
In bin/claude-wrapper, refactor BOTH python3 code blocks in ensure_remote_config (lines 62-78 and lines 93-97) to pass $config_file and $cwd as command-line arguments instead of interpolating them into Python source:

1. For the "config exists" python3 block (line 62-78):
   - Change invocation to: python3 -c "..." "$config_file" "$cwd"
   - In the Python code, use sys.argv[1] and sys.argv[2] instead of '$config_file' and '$cwd'
   - Add "import sys" to the imports

2. For the "create minimal config" python3 block (lines 93-97):
   - Same pattern: python3 -c "..." "$config_file" "$cwd"
   - Use sys.argv[1] and sys.argv[2]

3. The jq path (lines 81-87) is already safe — it uses --arg which handles quoting properly. No changes needed there.

4. Add a new test (Test 23b) in test/test-wrapper.sh right after the existing Test 23 block (after line 498). The test should:
   - Create a fake HOME
   - cd to a directory whose name contains a single quote (e.g., mkdir -p "$TMPDIR/it's a dir" && cd to it)
   - Run the wrapper with CLAUDE_CONNECT=remote-control
   - Verify ~/.claude.json was created
   - Verify the JSON contains the single-quoted path as a key in the projects object
   - Clean up the directory afterward
  </action>
  <verify>
    <automated>cd /Users/jmr/GitHub/JJB/AgenticWorkflow/claude-restart && bash test/test-wrapper.sh 2>&1 | tail -20</automated>
  </verify>
  <done>
    - No bash variables ($config_file, $cwd) appear inside Python string literals in ensure_remote_config
    - sys.argv used for all Python value passing
    - All existing tests pass
    - New test proves single-quote paths work correctly
  </done>
</task>

</tasks>

<verification>
1. grep for '$cwd' and '$config_file' inside python3 -c blocks — should find ZERO matches
2. All tests pass: bash test/test-wrapper.sh
3. Manual smoke test: cd to a directory with a quote in its name, source the function, run it
</verification>

<success_criteria>
- ensure_remote_config passes all values to Python via sys.argv, not string interpolation
- Single-quote and double-quote paths do not break the function
- All existing wrapper tests pass
- New test validates special-character path handling
</success_criteria>

<output>
After completion, create `.planning/quick/260327-vcd-fix-shell-injection-in-ensure-remote-con/260327-vcd-SUMMARY.md`
</output>
