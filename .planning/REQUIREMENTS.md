# Requirements: Claude Restart

**Defined:** 2026-03-20
**Core Value:** Claude can be restarted with new CLI options from within a session without manual exit-and-retype.

## v1 Requirements

### Wrapper

- [ ] **WRAP-01**: Wrapper runs claude in a loop, relaunching when restart file exists
- [ ] **WRAP-02**: Wrapper sleeps 2s before relaunching claude
- [ ] **WRAP-03**: Wrapper passes through initial CLI options to claude on first launch
- [ ] **WRAP-04**: Wrapper reads new options from restart file on subsequent launches
- [ ] **WRAP-05**: Wrapper stays in same terminal and working directory across restarts

### Restart

- [ ] **REST-01**: Restart script accepts CLI options as arguments and writes them to `~/.claude-restart`
- [ ] **REST-02**: Restart script finds and kills the current claude process via process tree walk
- [ ] **REST-03**: If no args given, restart script writes current session's options (default restart)

### Shell

- [ ] **SHEL-01**: Shell alias/function launches claude via the wrapper script
- [ ] **SHEL-02**: Install script or instructions to auto-source in `.zshrc`

## v2 Requirements

### Slash Command

- **SLSH-01**: `/restart --[options]` triggers restart from within Claude session
- **SLSH-02**: `/restart` with no options restarts with current options

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-instance support | Assumes one claude session at a time |
| Session/context preservation | No automatic resume across restarts |
| Cross-platform (Linux/Windows) | macOS-only for v1 |
| Auto-update detection | Not related to restart functionality |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WRAP-01 | Phase 1 | Pending |
| WRAP-02 | Phase 1 | Pending |
| WRAP-03 | Phase 1 | Pending |
| WRAP-04 | Phase 1 | Pending |
| WRAP-05 | Phase 1 | Pending |
| REST-01 | Phase 2 | Pending |
| REST-02 | Phase 2 | Pending |
| REST-03 | Phase 2 | Pending |
| SHEL-01 | Phase 3 | Pending |
| SHEL-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-03-20*
*Last updated: 2026-03-20 after roadmap creation*
