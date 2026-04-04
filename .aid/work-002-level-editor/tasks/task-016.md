# task-016: Delivery-003 Integration Test

**Type:** TEST

**Source:** feature-005-resource-editor, feature-006-biome-editor -> delivery-003

**Depends on:** task-013, task-015

**Scope:**
- Manual integration testing of the complete delivery-003 feature set
- Test Resource Editor full CRUD cycle:
  - Create new resource with all fields filled -> verify .tres file written correctly
  - Edit existing resource -> verify changes saved and round-trip preserved
  - Delete resource not in use -> verify file removed
  - Delete resource in use by map -> verify warning dialog with tile count
  - Undo create/edit/delete -> verify correct restoration
- Test Biome Editor full CRUD cycle:
  - Create new biome -> verify .tres file with generated uid
  - Edit existing biome color -> verify live preview on hex canvas
  - Edit resource_table -> verify .tres serialization with correct dict format
  - Delete biome not in use -> verify file removed
  - Delete biome in use -> verify warning dialog
  - Undo create/edit/delete -> verify correct restoration (including canvas color revert)
- Test .tres round-trip: edit a resource/biome -> save -> reload -> verify file matches
- Test import validation: place malformed .tres files -> verify warnings and skip behavior
- Test cross-tab integration: create resource -> verify it appears in biome resource_table dropdown
- Test hardcoded biome warning badge on custom biomes

**Acceptance Criteria:**
- [ ] All acceptance criteria from feature-005 SPEC verified (round-trip, CRUD, delete validation, import validation)
- [ ] All acceptance criteria from feature-006 SPEC verified (round-trip, live preview, resource_table, delete validation, import validation)
- [ ] Undo/redo works correctly for all resource and biome commands
- [ ] Live biome color preview updates canvas correctly
- [ ] Dirty indicators appear on resource/biome edits and clear on save
- [ ] No console errors during normal operation
