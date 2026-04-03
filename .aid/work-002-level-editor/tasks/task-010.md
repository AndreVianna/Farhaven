# task-010: Placement Tools and Resource Detail Panel

**Type:** IMPLEMENT

**Source:** feature-002-painting-tools -> delivery-002

**Depends on:** task-009

**Scope:**
- Implement `ResourcePlacer` tool:
  - Click to add resource with auto-randomized x, y (within -0.8 to 0.8) and rotation (0-359)
  - `AddResourceCommand` with tracked index for correct undo
  - No drag support (click only)
- Implement `StructurePlacer` tool:
  - Click to set structure (one per hex, replaces existing)
  - `SetStructureCommand` capturing old structure for undo
  - No drag support
- Implement `AnomalyMarker` tool:
  - Click to show inline modal dialog with text input for anomaly ID
  - `SetAnomalyCommand` on confirmation
  - No drag support
- Implement `SpawnMarker` tool:
  - Click to set spawn (exactly one per map -- replaces old)
  - `SetSpawnCommand` capturing old spawn for undo
  - No drag support
- Implement `DeleteHexTool`:
  - Click to remove hex entirely from grid
  - `DeleteHexCommand` with full tile data snapshot for undo
  - No drag support (intentional friction for destructive operation)
- Implement `ResourceDetailPanel` class:
  - Floating DOM panel showing all resources on a hex
  - Per-resource row: type label (read-only), x/y/rotation inputs
  - `EditResourceCommand` on field change (blur or Enter)
  - `DeleteResourceCommand` on delete button click
  - Show/hide logic tied to hex selection when resource tool is active
- Implement remaining Command classes: `AddResourceCommand`, `EditResourceCommand`, `DeleteResourceCommand`, `SetStructureCommand`, `SetAnomalyCommand`, `SetSpawnCommand`, `DeleteHexCommand`
- Implement inline modal dialog component for anomaly ID input

**Acceptance Criteria:**
- [ ] Resource placer adds resource with randomized position within [-0.8, 0.8] and rotation [0, 359]
- [ ] Structure placer sets one structure per hex, replacing any existing
- [ ] Anomaly marker shows modal dialog; placing sets anomaly ID on hex
- [ ] Spawn marker moves spawn point; exactly one spawn enforced (old removed)
- [ ] Delete hex removes tile entirely from grid
- [ ] ResourceDetailPanel shows all resources on selected hex with editable x, y, rotation fields
- [ ] Editing resource fields in detail panel creates undoable commands
- [ ] Deleting a resource from detail panel creates undoable command
- [ ] All placement operations undo/redo correctly
- [ ] Modal dialog has OK/Cancel buttons (no native browser dialogs)
