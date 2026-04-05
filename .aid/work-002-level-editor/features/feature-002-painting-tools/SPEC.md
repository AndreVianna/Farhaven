# Painting Tools

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F2, F5 | /aid-interview |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: rotation type, AC range, prompt→modal, undo index, WALKABLE_STRUCTURES ref, JSON field clarification | /aid-specify review |
| 2026-04-04 | Tools now work on ghost (empty) cells — BiomeBrush, ElevationBrush, FloodFill create new tiles | code review |
| 2026-04-04 | Sub-hex grid system: AddResourceCommand uses (sq, sr), SetStructureCommand uses footprint model, ResourceDetailPanel updated for sub-hex fields, ResourcePlacer and StructurePlacer rewritten for sub-hex placement | design change |
| 2026-04-04 | Unified props model: AddResource/EditResource/DeleteResource/SetStructure/SetAnomaly commands replaced with AddPropCommand/EditPropCommand/DeletePropCommand. ResourceDetailPanel renamed to PropDetailPanel. EraserTool targets props at sub-hex. EraseContentCommand clears all props. | design change |

## Source

- REQUIREMENTS.md §5 F2 (Painting Tools), F5 (Resource Placement Detail)

## Description

The set of painting and placement tools for the Map Editor. Includes biome brush, elevation brush (+/- increment mode), resource placer (with auto-randomized position/rotation and manual adjustment via detail panel), structure placer, anomaly marker, spawn marker (exactly one per map), eraser, delete hex, and flood fill for contiguous same-biome regions.

## User Stories

- As Andre, I want to paint biomes by clicking and dragging so that I can quickly define terrain areas
- As Andre, I want to flood-fill a biome region so that I can paint large areas efficiently
- As Andre, I want to place resources on hexes with auto-randomized positions so that placements look natural
- As Andre, I want to fine-tune resource position/rotation via a detail panel so that I can adjust specific placements
- As Andre, I want to set exactly one spawn point so that the map has a valid player start

## Priority

Must

## Acceptance Criteria

- [ ] Given biome brush selected, when clicking and dragging across hexes, then all touched hexes update to the selected biome
- [ ] Given flood fill tool, when clicking a hex, then all contiguous hexes of the same biome change to the selected biome
- [ ] Given elevation brush in increment mode, when clicking a hex, then elevation increases/decreases by 1 (clamped 0-9)
- [ ] Given elevation brush in set mode, when clicking a hex, then elevation is set to the selected value
- [ ] Given resource placer, when clicking a hex, then a resource is added with auto-randomized x, y (within -0.8 to 0.8 margin; valid storage range is -1.0 to 1.0) and rotation (0-359)
- [ ] Given a placed resource, when clicking it, then a detail panel shows x, y, rotation fields for manual editing
- [ ] Given a hex with multiple resources, when viewed on canvas, then a count badge or visual indicator shows the number of resources
- [ ] Given spawn marker tool, when placing a second spawn, then the first spawn is removed (exactly one enforced)
- [ ] Given anomaly marker tool, when clicking a hex, then an anomaly is placed with a string ID input
- [ ] Given eraser tool, when clicking a hex with resources/structures, then they are removed but the hex remains
- [ ] Given delete hex tool, when clicking a hex, then the hex is removed entirely from the map
- [ ] Given biome brush, when painting on an empty (ghost) cell, then a new tile is created with the selected biome
- [ ] Given elevation brush, when painting on an empty (ghost) cell, then a new tile is created with the target elevation

---

## Technical Specification

### Data Model

**Tool types enum:**

```js
const ToolType = {
  BIOME: "biome",
  ELEVATION: "elevation",
  RESOURCE: "resource",
  STRUCTURE: "structure",
  ANOMALY: "anomaly",
  SPAWN: "spawn",
  ERASER: "eraser",
  DELETE_HEX: "delete_hex",
  FLOOD_FILL: "flood_fill"
};
```

**Elevation brush modes:**

```js
const ElevationMode = {
  SET: "set",           // set elevation to a specific value
  INCREMENT: "increment" // +1 or -1 from current
};
```

**`ToolManager` class** — singleton that tracks active tool and delegates canvas mouse events.

```js
class ToolManager {
  constructor(hexGrid, commandHistory) {
    this.grid = hexGrid;
    this.commandHistory = commandHistory;
    this.activeTool = null;       // BaseTool instance
    this.activeToolType = null;   // ToolType value
    this.activeValue = null;      // string — the selected biome/resource/structure name
    this.elevationMode = ElevationMode.SET;
    this.elevationValue = 0;      // target value for SET mode
    this.elevationDelta = 1;      // +1 or -1 for INCREMENT mode
  }

  setTool(toolType, value)    // creates and activates the appropriate tool instance
  getActiveTool()             // returns current BaseTool
  onMouseDown(hex)            // delegates to activeTool.onMouseDown(hex)
  onMouseMove(hex)            // delegates to activeTool.onMouseMove(hex)
  onMouseUp(hex)              // delegates to activeTool.onMouseUp(hex)
}
```

**`BaseTool` interface** — all tools implement:

```js
class BaseTool {
  constructor(grid, commandHistory, toolManager) { ... }
  onMouseDown(hex)   // hex = { q, r }
  onMouseMove(hex)   // hex = { q, r }
  onMouseUp(hex)     // hex = { q, r }
}
```

### Command Classes

Each tool produces Command objects that are pushed to the `CommandHistory` (feature-008). Every command implements `execute()` and `undo()`.

```js
class SetBiomeCommand {
  constructor(grid, q, r, oldBiome, newBiome)
  execute()   // grid.getTile(q,r).biome = newBiome; if tile doesn't exist, create it
  undo()      // grid.getTile(q,r).biome = oldBiome
}

class SetElevationCommand {
  constructor(grid, q, r, oldElevation, newElevation)
  execute()   // grid.getTile(q,r).elevation = newElevation
  undo()      // grid.getTile(q,r).elevation = oldElevation
}

class AddPropCommand {
  constructor(grid, q, r, propInstance)
  // propInstance = { type, sq, sr, category, rotation?, footprint? }
  execute()   // tile.props.push(propInstance); this._index = tile.props.length - 1
  undo()      // tile.props.splice(this._index, 1)
}

class EditPropCommand {
  constructor(grid, q, r, propIndex, oldValues, newValues)
  execute()   // Object.assign(tile.props[propIndex], newValues)
  undo()      // Object.assign(tile.props[propIndex], oldValues)
}

class DeletePropCommand {
  constructor(grid, q, r, propIndex, removedProp)
  execute()   // tile.props.splice(propIndex, 1)
  undo()      // tile.props.splice(propIndex, 0, removedProp)
}

class SetSpawnCommand {
  constructor(grid, oldSpawn, newSpawn)  // oldSpawn/newSpawn = [q, r]
  execute()   // grid.meta.spawn = newSpawn
  undo()      // grid.meta.spawn = oldSpawn
}

class EraseContentCommand {
  constructor(grid, q, r, oldProps)   // snapshot of tile.props before erase
  execute()   // tile.props = []
  undo()      // tile.props = deepClone(oldProps)
}

class DeleteHexCommand {
  constructor(grid, q, r, oldTileData)  // full tile snapshot
  execute()   // grid.deleteTile(q, r)
  undo()      // grid.setTile(q, r, deepClone(oldTileData))
}

class BatchCommand {
  constructor(commands)   // Array<Command> — for flood fill and drag operations
  execute()   // commands.forEach(c => c.execute())
  undo()      // commands.reverse().forEach(c => c.undo()), then re-reverse to preserve order
}
```

### Feature Flow Per Tool

**Biome Brush (`BiomeBrush`):**
- `onMouseDown(hex)`: record the hex, create `SetBiomeCommand` for it, execute via `commandHistory`. Track `paintedHexes = new Set()` to avoid repainting the same hex during a drag. Add hex key to set.
- `onMouseMove(hex)`: if mouse is held down and hex not in `paintedHexes`, create and execute `SetBiomeCommand`. Add to set. Each individual command is grouped into a `BatchCommand` on mouse-up for undo purposes.
- `onMouseUp(hex)`: wrap all commands from this drag into a single `BatchCommand` and replace the individual entries in history with it.

**Elevation Brush (`ElevationBrush`):**
- Two modes controlled by `toolManager.elevationMode`:
  - **SET mode:** `onMouseDown(hex)` sets the tile elevation to `toolManager.elevationValue`. Clamp to [0, 9].
  - **INCREMENT mode:** `onMouseDown(hex)` adds `toolManager.elevationDelta` (+1 or -1) to current elevation. Clamp to [0, 9].
- Supports drag painting like Biome Brush (tracks `paintedHexes`).

**Resource Placer (`ResourcePlacer`):**
- `onMouseDown(hex, subHex)`: creates a `PropInstance` with `type = toolManager.activeValue`, `sq = subHex.q`, `sr = subHex.r`, `category = "resource"`, `rotation = random(0, 359)`. If no tile exists at hex, creates one with default biome first. If sub-hex is already occupied (by any prop), no-op. Executes `AddPropCommand`.
- No drag support — click only.

**Structure Placer (`StructurePlacer`):**
- `onMouseDown(hex, subHex)`: gets the active structure type's footprint (list of sub-hex offsets). Checks if all required sub-hexes are available. If yes, creates `AddPropCommand` with `{ type, sq: subHex.q, sr: subHex.r, category: "structure", footprint }`. If any sub-hex is occupied, no-op (show warning).
- No drag support — click only.

**Anomaly Marker (`AnomalyMarker`):**
- `onMouseDown(hex, subHex)`: shows an inline modal dialog with a text input labeled "Enter anomaly ID:" and "OK"/"Cancel" buttons (consistent with the editor's DOM-based UI — no native browser dialogs). If user enters a non-empty string and clicks OK, creates `AddPropCommand` with `{ type: anomalyId, sq: subHex.q, sr: subHex.r, category: "anomaly" }`. If user cancels, no-op.
- No drag support — click only.

**Spawn Marker (`SpawnMarker`):**
- `onMouseDown(hex)`: creates `SetSpawnCommand(grid.meta.spawn, [hex.q, hex.r])`. Exactly one spawn per map; the command replaces the old spawn.
- No drag support — click only.

**Eraser (`EraserTool`):**
- `onMouseDown(hex, subHex)`: if sub-hex is specified and a prop exists at that sub-hex position, find the prop index and execute `DeletePropCommand`. If no sub-hex target (click on hex without sub-hex resolution), and tile has any props, snapshot `tile.props` and execute `EraseContentCommand` to clear all props. The hex and its biome/elevation remain.
- Supports drag (tracks `erasedHexes` set) for bulk erase of all props.

**Delete Hex (`DeleteHexTool`):**
- `onMouseDown(hex)`: if tile exists, snapshot entire `TileData`, execute `DeleteHexCommand`. The hex is removed from `HexGrid.tiles` entirely.
- No drag support — click only (destructive operation, intentional friction).

**Flood Fill (`FloodFillTool`):**
- `onMouseDown(hex)`: BFS from clicked hex. Starting biome = current tile's biome. Target biome = `toolManager.activeValue`. If starting biome equals target biome, no-op.
  - Queue: `[startHex]`. Visited: `Set<string>`.
  - For each hex in queue: if tile exists and tile.biome === startingBiome, create `SetBiomeCommand`, add to batch, mark visited, enqueue all 6 neighbors.
  - Safety limit: max 10,000 tiles to prevent runaway fills.
  - Execute all as a single `BatchCommand`.

### Prop Detail Panel

A DOM panel that appears when the user clicks a prop indicator on a hex (or selects a hex that has props).

```js
class PropDetailPanel {
  constructor(container, hexGrid, commandHistory) {
    this.container = container;   // DOM element for the panel
    this.grid = hexGrid;
    this.commandHistory = commandHistory;
    this.currentHex = null;       // { q, r }
  }

  show(q, r)          // populate and display the panel for the given hex
  hide()              // hide the panel
  renderRows()        // render one row per prop on the hex, grouped by category
  onFieldChange(index, field, value)  // create EditPropCommand
  onDeleteProp(index)                 // create DeletePropCommand
}
```

**Panel UI:**
- Positioned as a floating panel or sidebar sub-panel.
- Header: "Props on (q, r)" with a close button.
- Props are grouped by category (Resources, Structures, Anomalies).
- Each prop row:
  - Category badge (blue/orange/purple)
  - Type label (read-only, e.g., "wood", "workbench", "anomaly_ch1_001")
  - `sq` input: integer, range [-2, 2]
  - `sr` input: integer, range [-2, 2]
  - Validation: `isValidSubHex(sq, sr)` must be true (distance from center ≤ 2)
  - For resources: `rotation` input: number, step 1, range [0, 359]
  - For structures: `footprint` display (read-only list of sub-hex offsets)
  - Delete button (red X)
- On input blur or Enter key: if value changed, create `EditPropCommand` with old and new values.

### Layers & Components

- `ToolManager` — singleton, instantiated by the application. Holds reference to `HexGrid` and `CommandHistory`. Canvas mouse events from `HexCanvas` are forwarded here.
- Tool classes (`BiomeBrush`, `ElevationBrush`, `ResourcePlacer`, `StructurePlacer`, `AnomalyMarker`, `SpawnMarker`, `EraserTool`, `DeleteHexTool`, `FloodFillTool`) — each extends `BaseTool`. Resource/Structure/Anomaly placers all produce `AddPropCommand` with appropriate category.
- `PropDetailPanel` — DOM-based panel for viewing and editing all props on a hex, grouped by category.
- `BatchCommand` — groups multiple commands into one undo/redo unit.

### Dependencies

- **feature-001 (Hex Canvas):** Tools receive hex coordinates from canvas mouse events. Canvas renders tool feedback (hover preview, drag trail).
- **feature-003 (Palette & Sidebar):** Palette click sets `toolManager.setTool(type, value)`. Active tool indicator reads from `toolManager.activeToolType`.
- **feature-008 (Command Infrastructure):** All commands are pushed to `CommandHistory`. Undo/redo is handled there.

**Structure list source:** The editor's structure list must match `HexGrid.WALKABLE_STRUCTURES` in `scripts/hex/hex_grid.gd`. Currently: `workbench`, `storage_chest`, `campfire`, `shelter`, `torch`. When the game adds structures, update both the editor config and the game constant.
