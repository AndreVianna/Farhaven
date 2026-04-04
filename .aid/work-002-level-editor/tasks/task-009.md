# task-009: ToolManager and Basic Painting Tools

**Type:** IMPLEMENT

**Source:** feature-002-painting-tools -> delivery-002

**Depends on:** task-008, task-004

**Scope:**
- Implement `ToolType` enum and `ElevationMode` enum
- Implement `BaseTool` interface with `onMouseDown(hex)`, `onMouseMove(hex)`, `onMouseUp(hex)`
- Implement `ToolManager` class:
  - `setTool(toolType, value)` -- creates appropriate tool instance
  - Mouse event delegation to active tool
  - `activeToolType`, `activeValue`, `elevationMode`, `elevationValue`, `elevationDelta`
- Implement `BiomeBrush` tool:
  - Click-and-drag painting with `paintedHexes` Set to avoid repainting
  - Individual `SetBiomeCommand` per hex during drag
  - `BatchCommand` wrapping on mouse-up for single undo unit
- Implement `ElevationBrush` tool:
  - SET mode: set elevation to target value, clamp [0, 9]
  - INCREMENT mode: +1/-1 from current, clamp [0, 9]
  - Drag support with `paintedHexes` tracking
  - `SetElevationCommand` per hex, `BatchCommand` on mouse-up
- Implement `FloodFillTool`:
  - BFS from clicked hex, same-biome expansion
  - Safety limit: 10,000 tiles max
  - Single `BatchCommand` with all `SetBiomeCommand`s
- Implement `EraserTool`:
  - Click to clear resources, structure, anomaly (hex remains)
  - `EraseContentCommand` with full tile snapshot for undo
  - Drag support with `erasedHexes` tracking
- Implement all Command classes: `SetBiomeCommand`, `SetElevationCommand`, `EraseContentCommand`, `BatchCommand`
- Wire `selectTool()` function (replacing stub from task-004) to `toolManager.setTool()`

**Acceptance Criteria:**
- [ ] Biome brush paints hexes on click and drag; all touched hexes update to selected biome
- [ ] Ctrl+Z after a drag stroke undoes the entire stroke (not one hex at a time)
- [ ] Elevation brush SET mode sets exact value; INCREMENT mode adds/subtracts 1
- [ ] Elevation clamped to [0, 9] in both modes
- [ ] Flood fill changes all contiguous same-biome hexes to target biome
- [ ] Flood fill respects 10,000 tile safety limit
- [ ] Eraser removes resources/structure/anomaly but preserves hex and biome/elevation
- [ ] All operations produce Commands that undo/redo correctly
- [ ] `BatchCommand.undo()` reverses in correct order
- [ ] ToolManager correctly delegates mouse events to active tool
