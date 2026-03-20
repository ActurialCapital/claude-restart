# Roadmap: Claude Restart

## Overview

Three phases deliver the complete restart mechanism: first the wrapper loop that runs claude and watches for restart signals, then the restart script that Claude executes to trigger the cycle, and finally shell integration that makes it seamless to use. Each phase produces a working, testable artifact.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Wrapper Script** - Loop mechanism that runs claude and relaunches on restart signal
- [ ] **Phase 2: Restart Script** - Script that writes new options and kills the current claude process
- [ ] **Phase 3: Shell Integration** - Alias and install instructions for seamless daily use

## Phase Details

### Phase 1: Wrapper Script
**Goal**: User can launch claude through a wrapper that automatically relaunches it when a restart is signaled
**Depends on**: Nothing (first phase)
**Requirements**: WRAP-01, WRAP-02, WRAP-03, WRAP-04, WRAP-05
**Success Criteria** (what must be TRUE):
  1. Running the wrapper script launches claude with any passed CLI options
  2. When claude exits and `~/.claude-restart` exists, claude relaunches with options from that file after a 2s pause
  3. When claude exits and no restart file exists, the wrapper exits cleanly
  4. Restarts happen in the same terminal and working directory as the original launch
**Plans:** 1 plan

Plans:
- [ ] 01-01-PLAN.md -- Wrapper script with restart loop, signal handling, and automated tests

### Phase 2: Restart Script
**Goal**: Claude can trigger its own restart by executing a script that writes new options and kills the current process
**Depends on**: Phase 1
**Requirements**: REST-01, REST-02, REST-03
**Success Criteria** (what must be TRUE):
  1. Running the restart script with CLI options writes those options to `~/.claude-restart` and kills the claude process
  2. Running the restart script with no arguments restarts claude with the same options it was launched with
  3. The wrapper detects the kill and relaunches claude with the options from the restart file
**Plans:** 1 plan

Plans:
- [ ] 02-01-PLAN.md -- Restart script with PPID walk, option writing, and TDD test suite

### Phase 3: Shell Integration
**Goal**: User can launch claude-with-restart as easily as typing a short alias in any terminal
**Depends on**: Phase 2
**Requirements**: SHEL-01, SHEL-02
**Success Criteria** (what must be TRUE):
  1. A shell alias or function launches claude through the wrapper script with all arguments forwarded
  2. User has clear instructions (or an install script) to add the alias to their `.zshrc` so it persists across terminals
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Wrapper Script | 0/1 | Not started | - |
| 2. Restart Script | 0/1 | Not started | - |
| 3. Shell Integration | 0/? | Not started | - |
