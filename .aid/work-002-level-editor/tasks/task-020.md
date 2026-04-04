# task-020: Delivery-004 Final Integration Test

**Type:** TEST

**Source:** feature-004-import-export, feature-003-palette-sidebar -> delivery-004

**Depends on:** task-018, task-019

**Scope:**
- Manual integration testing of the complete delivery-004 feature set and the full editor end-to-end
- Test full workflow: open project -> load ch1.json -> verify rendering -> paint hexes -> save -> reload -> verify round-trip (AC1)
- Test new map creation: New Map -> paint 50+ hexes with varied biomes, elevations, resources, structures -> set spawn -> export -> verify valid JSON (AC3)
- Test export validation (AC6):
  - Map with no spawn -> error blocks save
  - Map with unknown biome -> error blocks save
  - Map with out-of-range elevation -> error blocks save
  - Hardcoded biome warning for custom biomes
- Test import validation (AC9):
  - Malformed JSON -> error dialog, no crash, no partial load
  - Missing required fields -> specific error messages
- Test sidebar palette integration:
  - Biome swatches from .tres -> click to paint -> verify hex colors
  - Resource palette -> place resources -> verify on canvas
  - Structure palette -> place structures -> verify
  - Statistics update after each operation
- Test cross-tab integration:
  - Create resource in Resource Editor -> appears in map palette immediately
  - Edit biome color in Biome Editor -> map canvas updates live (AC5)
  - Delete resource in use -> warning dialog shows affected tiles (AC4)
- Test undo/redo across full operation set: paint 10 hexes, undo all 10, redo 5 (AC7)
- Test unsaved changes: make edits -> dirty indicators -> Ctrl+S -> indicators clear -> beforeunload protection (AC8)
- Test .tres round-trip: load resource/biome -> save unchanged -> verify file identical (AC2)

**Acceptance Criteria:**
- [ ] AC1 verified: ch1.json round-trip produces semantically equivalent output
- [ ] AC2 verified: .tres round-trip preserves uid, ext_resource, script lines exactly
- [ ] AC3 verified: new map with 50+ hexes exports valid JSON
- [ ] AC4 verified: resource CRUD works end-to-end with map palette integration
- [ ] AC5 verified: biome color edit updates canvas in real-time
- [ ] AC6 verified: export validation catches all specified error conditions
- [ ] AC7 verified: undo/redo works correctly for 10+ operations
- [ ] AC8 verified: unsaved changes protection works (indicators + beforeunload)
- [ ] AC9 verified: malformed import shows clear errors, no crash, no partial load
- [ ] All 9 features working together in the single HTML file
- [ ] No console errors during normal operation
- [ ] Editor opens correctly via file:// protocol
