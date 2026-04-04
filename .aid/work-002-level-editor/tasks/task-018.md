# task-018: Import/Export UI and New Map Dialog

**Type:** IMPLEMENT

**Source:** feature-004-import-export -> delivery-004

**Depends on:** task-017, task-005

**Scope:**
- Implement `ImportExportUI` DOM layer:
  - Toolbar buttons: "New Map", "Save" (with Ctrl+S indicator), "Save As"
  - Map file selector: dropdown or list of discovered maps from ProjectContext.files.maps; clicking loads the selected map
- Implement import flow:
  - Select map from discovered files -> `MapSerializer.fromJSON()` -> populate HexGrid + MapMeta -> fire `map-loaded` event -> HexCanvas.repaint()
  - On validation failure: show modal error dialog listing all errors with field names and hex coordinates; reject import entirely
  - On success: clear CommandHistory, mark map clean via DirtyTracker
- Implement export flow:
  - Triggered by Ctrl+S or Save button
  - Run `MapValidator.validate()` first
  - If invalid: show validation error dialog listing all issues; block save
  - If valid: `MapSerializer.toJSON()` -> write via `FileDiscovery.saveFile()` -> mark map clean
- Implement "Save As" flow:
  - Use `showSaveFilePicker()` or fallback download
  - Allow saving to a new filename
- Implement "New Map" flow:
  - Modal dialog with chapter_id (text, required, alphanumeric+underscores) and name (text, required) inputs
  - "Create" and "Cancel" buttons
  - Create empty HexGrid, MapMeta with entered values and spawn [0, 0]
  - Clear canvas to empty state; clear CommandHistory; mark clean
  - No FileSystemFileHandle -- first save uses "Save As" behavior
- Implement validation error dialog: scrollable modal listing all `ValidationResult.errors` with hex coordinates
- Wire `saveAll()` (from task-005) to include map serialization + validation

**Acceptance Criteria:**
- [ ] Loading a discovered map file renders it on the hex canvas
- [ ] Import validation rejects malformed JSON with clear error messages; no partial load (AC9)
- [ ] Export validation catches missing spawn, invalid biome/resource/structure, elevation out of range (AC6)
- [ ] Validation error dialog shows all errors at once (not just the first)
- [ ] Valid map exports JSON that MapLoader would accept (AC3)
- [ ] "New Map" creates empty canvas with entered metadata
- [ ] "Save As" allows picking a new file location
- [ ] Ctrl+S triggers save flow (validation -> serialize -> write)
- [ ] CommandHistory is cleared on map load and new map creation
- [ ] DirtyTracker state is correctly managed across import/export/new operations
