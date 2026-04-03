# task-006: Delivery-001 Integration Test

**Type:** TEST

**Source:** feature-007-file-discovery, feature-008-command-infrastructure, feature-009-unsaved-changes -> delivery-001

**Depends on:** task-002, task-003, task-004, task-005

**Scope:**
- Manual integration testing of the complete delivery-001 feature set
- Test the full startup flow: open index.html -> welcome screen -> Open Project -> select Farhaven root -> files discovered -> workspace visible
- Test TresParser round-trip: load all existing .tres files, verify `serialize(parse(text)) === text`
- Test tab switching with dirty indicators: make changes, verify indicators appear, save, verify indicators clear
- Test keyboard shortcuts: Ctrl+Z/Ctrl+Shift+Z with test commands, Ctrl+S save flow
- Test error paths: cancel folder picker, select wrong folder, malformed files
- Test beforeunload protection: make changes, attempt refresh, verify browser warning
- Test fallback path behavior (if testable in the development browser)
- Document test results in a test report

**Acceptance Criteria:**
- [ ] All acceptance criteria from feature-007 SPEC verified (folder picker, discovery, validation, error handling)
- [ ] All acceptance criteria from feature-008 SPEC verified (undo/redo stack, keyboard shortcuts, input suppression)
- [ ] All acceptance criteria from feature-009 SPEC verified (dirty indicators, beforeunload, save clears state)
- [ ] TresParser round-trip passes for all .tres files in `data/resources/` and `data/biomes/`
- [ ] No console errors during normal operation
- [ ] Test results documented
