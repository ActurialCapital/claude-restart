---
phase: quick
plan: 260327-w3t
subsystem: ci-cd
tags: [github-actions, deployment, ssh, automation]
dependency_graph:
  requires: []
  provides: [github-actions-deploy-workflow]
  affects: [vps-deployment]
tech_stack:
  added: [github-actions, appleboy-ssh-action]
  patterns: [ssh-deploy, workflow-dispatch]
key_files:
  created:
    - .github/workflows/deploy.yml
  modified: []
decisions:
  - Used appleboy/ssh-action@v1 for SSH connectivity (standard, well-maintained)
  - Copy scripts and systemd units manually instead of running install.sh (avoids interactive prompts)
  - Service restart step commented out by default (safety -- uncomment to auto-restart sessions)
metrics:
  duration: 50s
  completed: 2026-03-28
---

# Quick Task 260327-w3t: Create GitHub Actions Workflow for Auto-Deploy

GitHub Actions workflow that deploys to VPS via SSH on push to main, copying scripts and systemd units, running claude-service update --all, with no interactive prompts.

## What Was Done

### Task 1: Create GitHub Actions deploy workflow
**Commit:** ab86fec

Created `.github/workflows/deploy.yml` with:
- **Triggers:** push to main, workflow_dispatch (manual)
- **Runner:** ubuntu-latest
- **SSH:** appleboy/ssh-action@v1 with 4 secrets (VPS_SSH_KEY, VPS_HOST, VPS_USER, VPS_REPO_PATH)
- **Remote script:** git pull, copy scripts to ~/.local/bin, copy systemd units, daemon-reload, claude-service update --all
- **Safety:** Service restart line present but commented out by default

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Verification

- YAML syntax validated (ruby yaml parser)
- All 4 secrets referenced
- All done criteria verified: triggers, ssh-action, script steps, no install.sh calls, restart commented out

## Self-Check: PASSED
