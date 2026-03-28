---
phase: quick
plan: 260327-qnl
type: execute
wave: 1
depends_on: []
files_modified:
  - bin/install.sh
  - test/test-install.sh
  - test/test-phase14-validation.sh
  - skills/README.md      # DELETE
  - commands/README.md     # DELETE
autonomous: true
requirements: []

must_haves:
  truths:
    - "deploy_skills uses npx get-shit-done-cc@latest --global --claude for GSD"
    - "deploy_skills uses claude plugins install superpowers@superpowers-marketplace for superpowers"
    - "deploy_skills gracefully handles missing npx or claude CLI"
    - "GSD_REPO and SUPERPOWERS_REPO env var overrides are removed"
    - "skills/ and commands/ directories no longer exist in repo"
    - "All tests pass with updated mocks and assertions"
  artifacts:
    - path: "bin/install.sh"
      provides: "deploy_skills using official installers"
      contains: "npx get-shit-done-cc@latest"
    - path: "test/test-install.sh"
      provides: "Tests with npx/claude mocks instead of git mocks"
    - path: "test/test-phase14-validation.sh"
      provides: "Validation assertions matching new installer patterns"
  key_links:
    - from: "bin/install.sh"
      to: "npx get-shit-done-cc@latest --global --claude"
      via: "deploy_skills function"
      pattern: "npx get-shit-done-cc@latest"
    - from: "bin/install.sh"
      to: "claude plugins install superpowers@superpowers-marketplace"
      via: "deploy_skills function"
      pattern: "claude plugins install"
---

<objective>
Replace git clone deployment in deploy_skills() with official package installers, remove
now-unnecessary skills/ and commands/ directories, and update all tests.

Purpose: GSD and superpowers both have official install commands now. Using them means
we get proper version management, dependency handling, and no git dependency for skills.

Output: Updated install.sh, updated tests, removed skills/ and commands/ dirs.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@bin/install.sh
@test/test-install.sh
@test/test-phase14-validation.sh
</context>

<tasks>

<task type="auto">
  <name>Task 1: Rewrite deploy_skills() and remove repo dirs</name>
  <files>bin/install.sh, skills/README.md, commands/README.md</files>
  <action>
In bin/install.sh:

1. Remove the GSD_REPO and SUPERPOWERS_REPO variables (lines 84-85) entirely. These env var
   overrides are no longer relevant since we use package installers, not git URLs.

2. Rewrite deploy_skills() (lines 87-119) to use official installers:

```bash
deploy_skills() {
    # Deploy GSD skills via official installer
    if command -v npx &>/dev/null; then
        echo "Installing GSD skills via npx..."
        if ! npx get-shit-done-cc@latest --global --claude 2>&1; then
            echo "Warning: GSD install failed (skipping)"
        else
            echo "Deployed GSD skills via official installer"
        fi
    else
        echo "Warning: npx not found, skipping GSD skills install (install Node.js to enable)"
    fi

    # Deploy superpowers commands via claude plugins
    if command -v claude &>/dev/null; then
        echo "Installing superpowers via claude plugins..."
        if ! claude plugins install superpowers@superpowers-marketplace 2>&1; then
            echo "Warning: superpowers install failed (skipping)"
        else
            echo "Deployed superpowers via claude plugins"
        fi
    else
        echo "Warning: claude CLI not found, skipping superpowers install"
    fi
}
```

Key changes from the old version:
- No more git clone/pull logic
- No more checking for .git directories
- No more GSD_REPO/SUPERPOWERS_REPO env vars
- Graceful fallback if npx or claude CLI not found (command -v check)
- Graceful fallback if the install command itself fails
- Each installer is independent (GSD failure does not skip superpowers)

3. Delete skills/README.md and commands/README.md files entirely.

4. Delete the skills/ and commands/ directories (they should be empty after README removal):
   `rm -rf skills/ commands/`
  </action>
  <verify>
    <automated>grep -c "git clone" bin/install.sh | grep -q "^0$" && grep -q "npx get-shit-done-cc@latest" bin/install.sh && grep -q "claude plugins install" bin/install.sh && ! test -d skills && ! test -d commands && echo "PASS" || echo "FAIL"</automated>
  </verify>
  <done>
    - deploy_skills() uses npx for GSD and claude plugins for superpowers
    - GSD_REPO and SUPERPOWERS_REPO variables removed
    - skills/ and commands/ directories deleted from repo
    - No git references remain in deploy_skills
  </done>
</task>

<task type="auto">
  <name>Task 2: Update test-install.sh mocks and assertions</name>
  <files>test/test-install.sh</files>
  <action>
Update test/test-install.sh to replace git-based mocking with npx/claude mocking.

1. In setup_linux_mocks() (line 140-178): Remove the mock git script. Add mock npx and mock
   claude scripts instead:

   Mock npx (in mock_bin):
   ```bash
   cat > "$mock_bin/npx" << 'MOCKEOF'
   #!/bin/bash
   echo "npx $*" >> "$MOCK_LOG"
   MOCKEOF
   chmod +x "$mock_bin/npx"
   ```

   Mock claude (in mock_bin):
   ```bash
   cat > "$mock_bin/claude" << 'MOCKEOF'
   #!/bin/bash
   echo "claude $*" >> "$MOCK_LOG"
   MOCKEOF
   chmod +x "$mock_bin/claude"
   ```

2. Remove setup_linux_mocks_with_git() helper entirely (lines 404-453). It is no longer needed.

3. Replace Test 21 (lines 455-482) "Linux install clones GSD skills via git":
   Rename to "Linux install deploys skills via official installers".
   Set up with standard setup_linux_mocks (which now includes npx/claude mocks).
   After install, check mock log for:
   - `npx get-shit-done-cc@latest --global --claude`
   - `claude plugins install superpowers@superpowers-marketplace`

4. Replace Test 22 (lines 484-509) "Linux install handles git clone failure gracefully":
   Rename to "Linux install handles missing npx/claude gracefully".
   Remove npx and claude from mock_bin PATH so command -v fails.
   Verify install still succeeds (exit 0) and outputs warnings about missing tools.

5. Replace Test 23 (lines 511-544) "Linux install updates existing repos via git pull":
   Remove this test entirely. There is no "update" concept with official installers --
   the installer is idempotent by design. The existing Test 21 replacement covers the
   install path.

6. Remove ORIG_HOME variable (line 401) and `export HOME="$ORIG_HOME"` (line 546) -- these
   are no longer needed since we removed the git-specific test helpers. The run_linux_install
   helper already saves/restores HOME.

7. Update the section comment banner from "Skills Deployment Tests (Phase 14) - git clone/pull
   based" to "Skills Deployment Tests (Phase 14) - official installers".
  </action>
  <verify>
    <automated>cd /Users/jmr/GitHub/JJB/AgenticWorkflow/claude-restart && bash test/test-install.sh 2>&1 | tail -5</automated>
  </verify>
  <done>
    - All tests pass (23 -> ~21-22 tests, renumbered as needed)
    - No git mocks remain in skills deployment section
    - Mock npx and claude verify correct installer commands called
    - Missing-tool graceful fallback is tested
  </done>
</task>

<task type="auto">
  <name>Task 3: Update test-phase14-validation.sh assertions</name>
  <files>test/test-phase14-validation.sh</files>
  <action>
Update test/test-phase14-validation.sh to validate the new installer patterns instead of git.

1. DEPL-01 section (lines 53-66): Change assertions to verify:
   - deploy_skills function still defined: assert_contains "deploy_skills()"
   - Uses npx for GSD: assert_contains "npx get-shit-done-cc@latest" "$install_content"
   - No longer uses git clone: assert that "git clone" does NOT appear in deploy_skills
     (use assert_not_contains for "git clone")
   - Remove the assertion checking for skills/README.md existence (line 67) since the
     directory is deleted

2. DEPL-02 section (lines 73-77): Change assertions to verify:
   - Uses claude plugins for superpowers: assert_contains "claude plugins install superpowers@superpowers-marketplace" "$install_content"
   - Remove assertion checking for commands/README.md existence (line 77) since deleted

3. DEPL-01/02 edge case section (lines 131-137): Update to verify new graceful fallback:
   - assert_contains "npx not found warning" "npx not found" "$install_content"
   - assert_contains "claude CLI not found warning" "claude CLI not found" "$install_content"
   - Remove old git-specific assertions (pull failed, pull --ff-only)
  </action>
  <verify>
    <automated>cd /Users/jmr/GitHub/JJB/AgenticWorkflow/claude-restart && bash test/test-phase14-validation.sh 2>&1 | tail -5</automated>
  </verify>
  <done>
    - All phase 14 validation tests pass
    - Assertions match new npx/claude installer patterns
    - No references to git clone in deployment assertions
    - No references to skills/README.md or commands/README.md
  </done>
</task>

</tasks>

<verification>
Run both test suites to confirm everything passes:
```bash
bash test/test-install.sh && bash test/test-phase14-validation.sh
```
</verification>

<success_criteria>
- deploy_skills() in install.sh uses `npx get-shit-done-cc@latest --global --claude` and `claude plugins install superpowers@superpowers-marketplace`
- No git clone/pull logic remains in deploy_skills
- GSD_REPO and SUPERPOWERS_REPO env var overrides removed
- skills/ and commands/ directories deleted from repo
- test-install.sh passes with npx/claude mocks
- test-phase14-validation.sh passes with updated assertions
</success_criteria>

<output>
After completion, create `.planning/quick/260327-qnl-use-official-installers-for-gsd-and-supe/260327-qnl-SUMMARY.md`
</output>
