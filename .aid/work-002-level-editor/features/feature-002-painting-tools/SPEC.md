# Painting Tools

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F2, F5 | /aid-interview |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: rotation type, AC range, prompt→modal, undo index, WALKABLE_STRUCTURES ref, JSON field clarification | /aid-specify review |
| 2026-04-04 | Tools now work on ghost (empty) cells — BiomeBrush, ElevationBrush, FloodFill create new tiles | code review |
| 2026-04-04 | Sub-hex grid system: AddResourceCommand uses (sq, sr), SetStructureCommand uses footprint model, ResourceDetailPanel updated for sub-hex fields, ResourcePlacer and StructurePlacer rewritten for sub-hex placement | design change |

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

class AddResourceCommand {
  constructor(grid, q, r, resourceInstance)  // resourceInstance now has sq, sr instead of x, y
  execute()   // const tile = grid.getTile(q,r); tile.resources.push(resourceInstance); this._index = tile.resources.length - 1
  undo()      // grid.getTile(q,r).resources.splice(this._index, 1) — removes by tracked index, not .pop()
}

class EditResourceCommand {
  constructor(grid, q, r, resourceIndex, oldValues, newValues)  // values include sq, sr, rotation
  execute()   // Object.assign(grid.getTile(q,r).resources[index], newValues)
  undo()      // Object.assign(grid.getTile(q,r).resources[index], oldValues)
}

class DeleteResourceCommand {
  constructor(grid, q, r, resourceIndex, removedResource)
  execute()   // grid.getTile(q,r).resources.splice(index, 1)
  undo()      // grid.getTile(q,r).resources.splice(index, 0, removedResource)
}

class SetStructureCommand {
  constructor(grid, q, r, oldStructure, newStructure)
  // oldStructure/newStructure = { type: string, sub_hexes: [{sq, sr}, ...] } | null
  execute()   // grid.getTile(q,r).structure = newStructure
  undo()      // grid.getTile(q,r).structure = oldStructure
}

class SetAnomalyCommand {
  constructor(grid, q, r, oldAnomaly, newAnomaly)
  execute()   // grid.getTile(q,r).anomaly = newAnomaly
  undo()      // grid.getTile(q,r).anomaly = oldAnomaly
}

class SetSpawnCommand {
  constructor(grid, oldSpawn, newSpawn)  // oldSpawn/newSpawn = [q, r]
  execute()   // grid.meta.spawn = newSpawn
  undo()      // grid.meta.spawn = oldSpawn
}

class EraseContentCommand {
  constructor(grid, q, r, oldTile)   // snapshot of tile before erase
  execute()   // tile.resources = []; tile.structure = null; tile.anomaly = null
  undo()      // restore resources, structure, anomaly from oldTile snapshot
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
- `onMouseDown(hex, subHex)`: creates a `ResourceInstance` with `type = toolManager.activeValue`, `sq = subHex.q`, `sr = subHex.r`, `rotation = random(0, 359)`. If no tile exists at hex, creates one with default biome first. If sub-hex is already occupied (by resource or structure), no-op. Executes `AddResourceCommand`.
- No drag support — click only.

**Structure Placer (`StructurePlacer`):**
- `onMouseDown(hex, subHex)`: gets the active structure type's footprint (list of sub-hex offsets). Checks if all required sub-hexes are available. If yes, creates `SetStructureCommand` with `{ type, sub_hexes }`. If any sub-hex is occupied, no-op (show warning). One structure per hex; replaces any existing structure.
- No drag support — click only.

**Anomaly Marker (`AnomalyMarker`):**
- `onMouseDown(hex)`: shows an inline modal dialog with a text input labeled "Enter anomaly ID:" and "OK"/"Cancel" buttons (consistent with the editor's DOM-based UI — no native browser dialogs). If user enters a non-empty string and clicks OK, creates `SetAnomalyCommand`. If user cancels, no-op.
- No drag support — click only.

**Spawn Marker (`SpawnMarker`):**
- `onMouseDown(hex)`: creates `SetSpawnCommand(grid.meta.spawn, [hex.q, hex.r])`. Exactly one spawn per map; the command replaces the old spawn.
- No drag support — click only.

**Eraser (`EraserTool`):**
- `onMouseDown(hex)`: if tile exists and has any content (resources, structure, or anomaly), snapshot the tile, execute `EraseContentCommand`. The hex and its biome/elevation remain.
- Supports drag (tracks `erasedHexes` set).

**Delete Hex (`DeleteHexTool`):**
- `onMouseDown(hex)`: if tile exists, snapshot entire `TileData`, execute `DeleteHexCommand`. The hex is removed from `HexGrid.tiles` entirely.
- No drag support — click only (destructive operation, intentional friction).

**Flood Fill (`FloodFillTool`):**
- `onMouseDown(hex)`: BFS from clicked hex. Starting biome = current tile's biome. Target biome = `toolManager.activeValue`. If starting biome equals target biome, no-op.
  - Queue: `[startHex]`. Visited: `Set<string>`.
  - For each hex in queue: if tile exists and tile.biome === startingBiome, create `SetBiomeCommand`, add to batch, mark visited, enqueue all 6 neighbors.
  - Safety limit: max 10,000 tiles to prevent runaway fills.
  - Execute all as a single `BatchCommand`.

### Resource Detail Panel

A DOM panel that appears when the user clicks a resource indicator on a hex (or selects a hex that has resources while using the resource tool).

```js
class ResourceDetailPanel {
  constructor(container, hexGrid, commandHistory) {
    this.container = container;   // DOM element for the panel
    this.grid = hexGrid;
    this.commandHistory = commandHistory;
    this.currentHex = null;       // { q, r }
  }

  show(q, r)          // populate and display the panel for the given hex
  hide()              // hide the panel
  renderRows()        // render one row per resource on the hex
  onFieldChange(index, field, value)  // create EditResourceCommand
  onDeleteResource(index)             // create DeleteResourceCommand
}
```

**Panel UI:**
- Positioned as a floating panel or sidebar sub-panel.
- Header: "Resources on (q, r)" with a close button.
- Each resource row:
  - Type label (read-only, e.g., "wood")
  - `sq` input: integer, range [-2, 2]
  - `sr` input: integer, range [-2, 2]
  - Validation: `isValidSubHex(sq, sr)` must be true (distance from center ≤ 2)
  - `rotation` input: number, step 1, range [0, 359]
  - Delete button (red X)
- On input blur or Enter key: if value changed, create `EditResourceCommand` with old and new values.

### Layers & Components

- `ToolManager` — singleton, instantiated by the application. Holds reference to `HexGrid` and `CommandHistory`. Canvas mouse events from `HexCanvas` are forwarded here.
- Tool classes (`BiomeBrush`, `ElevationBrush`, `ResourcePlacer`, `StructurePlacer`, `AnomalyMarker`, `SpawnMarker`, `EraserTool`, `DeleteHexTool`, `FloodFillTool`) — each extends `BaseTool`.
- `ResourceDetailPanel` — DOM-based panel for fine-tuning resource placement.
- `BatchCommand` — groups multiple commands into one undo/redo unit.

### Dependencies

- **feature-001 (Hex Canvas):** Tools receive hex coordinates from canvas mouse events. Canvas renders tool feedback (hover preview, drag trail).
- **feature-003 (Palette & Sidebar):** Palette click sets `toolManager.setTool(type, value)`. Active tool indicator reads from `toolManager.activeToolType`.
- **feature-008 (Command Infrastructure):** All commands are pushed to `CommandHistory`. Undo/redo is handled there.

**Structure list source:** The editor's structure list must match `HexGrid.WALKABLE_STRUCTURES` in `scripts/hex/hex_grid.gd`. Currently: `workbench`, `storage_chest`, `campfire`, `shelter`, `torch`. When the game adds structures, update both the editor config and the game constant.
