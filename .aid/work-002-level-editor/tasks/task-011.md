# task-011: Delivery-002 Integration Test

**Type:** TEST

**Source:** feature-001-hex-canvas, feature-002-painting-tools -> delivery-002

**Depends on:** task-008, task-009, task-010

**Scope:**
- Manual integration testing of the complete delivery-002 feature set
- Test hex canvas rendering: load ch1.json via discovery, verify correct biome colors, elevation overlays, cliff indicators
- Test all 9 painting tools with undo/redo for each:
  - Biome brush (click + drag + undo full stroke)
  - Elevation brush (SET mode, INCREMENT mode)
  - Flood fill (contiguous fill + undo)
  - Resource placer (randomized placement + detail panel editing)
  - Structure placer (replacement behavior)
  - Anomaly marker (modal dialog + placement)
  - Spawn marker (single-spawn enforcement)
  - Eraser (content removal, hex preservation)
  - Delete hex (full removal + undo restoration)
- Test canvas interaction: zoom (scroll wheel), pan (middle-click + space+drag), hover tooltips, coordinate labels toggle
- Test keyboard shortcuts for tool switching: B, E, R, S, A, P, X, D, F, Escape
- Test cross-tab undo: perform map operations, switch tab, undo -- verify correct behavior
- Verify all commands integrate correctly with DirtyTracker (dirty indicators appear on edits)

**Acceptance Criteria:**
- [ ] All acceptance criteria from feature-001 SPEC verified (rendering, zoom/pan, tooltip, coordinate labels)
- [ ] All acceptance criteria from feature-002 SPEC verified (all 9 tools, drag painting, detail panel, flood fill, spawn enforcement)
- [ ] Undo/redo works correctly for every tool type
- [ ] Keyboard shortcuts switch tools correctly; suppressed in text inputs
- [ ] Canvas renders correctly after zoom, pan, and resize
- [ ] DirtyTracker marks map tab dirty on any edit
- [ ] No console errors during normal operation
