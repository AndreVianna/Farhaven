# Import / Export

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F6, F7; §9 AC1, AC3, AC6 | /aid-interview |
| 2026-04-03 | Technical specification written | /aid-specify |

## Source

- REQUIREMENTS.md §5 F6 (Import/Export), F7 (Export Validation), F15 (Import Validation), §9 AC1, AC3, AC6, AC9

## Description

Map JSON import, export, and new map creation. Import loads existing chapter JSON files and renders the full map on canvas — with validation on import (reject malformed data with clear error, never crash or load partial data). Export saves to JSON in the exact format MapLoader expects, with validation before save. New Map starts from a blank canvas. Export validation checks: exactly one spawn point, no duplicate coordinates, all biome/resource/structure names valid, elevation 0-9, resource positions within range.

## User Stories

- As Andre, I want to load ch1.json and see it rendered so that I can edit existing maps
- As Andre, I want to export valid JSON that MapLoader accepts so that I can test maps immediately in-game
- As Andre, I want export validation to catch errors before save so that I don't ship broken data
- As Andre, I want to start a new blank map so that I can create chapters from scratch

## Priority

Must

## Acceptance Criteria

- [ ] Given ch1.json loaded then exported with no changes, then the output is semantically equivalent to the input (AC1)
- [ ] Given a new map with 50+ hexes, biomes, elevations, resources, structures, and spawn, when exported, then MapLoader loads it without errors (AC3)
- [ ] Given a map with no spawn point, when exporting, then a clear error message is shown and save is blocked (AC6)
- [ ] Given a map with duplicate coordinates, when exporting, then validation catches and reports the duplicates
- [ ] Given a map with an invalid biome name, when exporting, then validation catches and reports the invalid name
- [ ] Given a new blank map started, when painting hexes and exporting, then a valid JSON is produced
- [ ] Given a malformed JSON file (missing tiles, invalid structure), when importing, then the editor shows a clear error message and does not crash or load partial data (AC9)

---

## Technical Specification

### Data Model

**MapMeta** — top-level map metadata:
```js
{
  chapter_id: string,   // e.g. "ch1"
  name: string,         // e.g. "Crash Landing"
  spawn: [number, number]  // [q, r] axial coords
}
```

**HexTile** — single tile in the hex grid (mirrors JSON `tiles["q,r"]`):
```js
{
  q: number,            // axial coordinate
  r: number,            // axial coordinate
  biome: string,        // biome_name key, e.g. "forest"
  elevation: number,    // integer 0-9
  structure: string|null,   // structure id or null
  anomaly: string|null,     // anomaly id or null
  resources: [          // array of placed resources
    { type: string, x: number, y: number, rotation: number }
  ]
}
```

**HexGrid** — in-memory map as `Map<string, HexTile>` keyed by `"q,r"` string.

**ValidationResult** — returned by MapValidator:
```js
{
  valid: boolean,
  errors: [
    { field: string, message: string, hex: string|null }
    // hex is "q,r" string when error is tile-specific, null for map-level errors
  ]
}
```

### Feature Flow

**Import:**
1. User selects a JSON file via the discovered file list (feature-007) or a file picker button.
2. `MapSerializer.fromJSON(jsonString, knownBiomes, knownResources, knownStructures)` is called:
   - Parse JSON with `JSON.parse()` inside try/catch. On `SyntaxError`, return validation error: `"Invalid JSON: {error.message}"`.
   - Validate required top-level fields: `chapter_id` (string), `name` (string), `spawn` (array of 2 numbers), `tiles` (object). Missing field returns: `"Missing required field: {field}"`.
   - Validate `spawn` references an existing tile key. Warning (not error) if spawn tile not in tiles.
3. For each tile entry in `tiles`:
   - Parse key as `"q,r"` — reject if not two integers separated by comma.
   - Validate `biome` exists in `knownBiomes`. Error: `"Tile (q,r): unknown biome '{value}'"`.
   - Validate `elevation` is integer 0-9. Error: `"Tile (q,r): elevation {value} out of range 0-9"`.
   - Validate `structure` (if present) exists in `knownStructures`. Error: `"Tile (q,r): unknown structure '{value}'"`.
   - Validate each resource in `resources[]`: `type` exists in `knownResources`. Error: `"Tile (q,r): unknown resource type '{value}'"`.
4. If `valid === true`: populate `HexGrid` map and `MapMeta`, fire `map-loaded` event, `HexCanvas.repaint()`.
5. If `valid === false`: show error dialog listing all errors. Reject import entirely — no partial load. The previous map state (if any) remains unchanged.

**Export:**
1. User triggers export via Ctrl+S or toolbar "Save" button.
2. `MapValidator.validate(hexGrid, mapMeta, knownBiomes, knownResources, knownStructures)` runs all checks:
   - `spawn` must reference a tile that exists in the grid. Error: `"Spawn point ({q},{r}) does not exist as a tile"`.
   - No duplicate coordinate keys (guaranteed by Map, but validated during serialize).
   - All tile `biome` values exist in `knownBiomes`.
   - All tile `elevation` values are integers 0-9.
   - All tile `structure` values (when non-null) exist in `knownStructures`.
   - All resource `type` values exist in `knownResources`.
   - Resource positions `x` and `y` are within range [-0.5, 0.5] (hex-local coords). Warning if outside.
   - Resource `rotation` is a number. Warning if outside [0, 360).
3. If valid: `MapSerializer.toJSON(hexGrid, mapMeta)` produces a JSON string. Write via File System Access API (`FileSystemFileHandle.createWritable()`). If no handle (fallback browser), trigger download via Blob + anchor click.
4. If invalid: show validation error dialog with all issues. Block save.

**Serialization format** — `MapSerializer.toJSON()` output matches the exact schema MapLoader expects:
```js
{
  "chapter_id": mapMeta.chapter_id,
  "name": mapMeta.name,
  "spawn": mapMeta.spawn,
  "tiles": {
    "q,r": {
      "biome": tile.biome,
      "elevation": tile.elevation,
      // "structure" key omitted if null
      // "anomaly" key omitted if null
      // "resources" key omitted if empty array
      "resources": [
        { "type": "wood", "x": 0.35, "y": -0.45, "rotation": 18 }
      ]
    }
  }
}
```
Optional fields (`structure`, `anomaly`, `resources`) are omitted from output when empty/null to keep JSON clean. On import, missing optional fields default to `null` / `[]`.

**New Map:**
1. User clicks "New Map" in toolbar.
2. Prompt dialog asks for `chapter_id` (text input, required, validated as non-empty alphanumeric + underscores) and `name` (text input, required, non-empty).
3. Create empty `HexGrid` (no tiles), `MapMeta` with the entered values and `spawn: [0, 0]`.
4. Clear canvas to empty state. The user paints hexes from scratch.
5. The new map has no `FileSystemFileHandle` — first save uses "Save As" behavior (pick location or download).

### Layers & Components

**MapSerializer** (pure functions, no DOM):
- `toJSON(hexGrid, mapMeta) -> string` — serialize HexGrid + MapMeta to JSON string. Keys sorted alphabetically for stable output. Tiles sorted by "q,r" key for diffability.
- `fromJSON(jsonString, knownBiomes, knownResources, knownStructures) -> { mapMeta, hexGrid, validation }` — parse and validate. Returns populated data only when `validation.valid === true`.

**MapValidator** (pure functions, no DOM):
- `validate(hexGrid, mapMeta, knownBiomes, knownResources, knownStructures) -> ValidationResult` — full validation pass. Used before export and also available for on-demand "check map" action.
- `validateTile(tile, knownBiomes, knownResources, knownStructures) -> ValidationResult` — single tile validation, used during import iteration.

**ImportExportUI** (DOM layer):
- Renders toolbar buttons: "New Map", "Open", "Save" (Ctrl+S), "Save As".
- `showValidationErrors(errors)` — modal dialog listing all validation errors with field names and hex coordinates. Scrollable if many errors.
- `showNewMapDialog()` — modal with chapter_id and name inputs, "Create" and "Cancel" buttons.
- Listens for `Ctrl+S` keydown (delegated from feature-008 keyboard shortcut system).

**Round-trip guarantee (AC1):** `MapSerializer.toJSON(MapSerializer.fromJSON(original).hexGrid, ...)` produces output semantically equivalent to the original — same tile data, same spawn, same metadata. Key ordering and whitespace may differ (JSON.stringify with 2-space indent is canonical). Acceptance test: load ch1.json, export, diff.

### Import Validation Rules (F15/AC9)

All validation errors are collected (not fail-fast) so the user sees every issue at once.

| Condition | Error Message |
|-----------|---------------|
| JSON parse failure | `"Invalid JSON: {SyntaxError.message}"` |
| Missing `chapter_id` | `"Missing required field: chapter_id"` |
| Missing `name` | `"Missing required field: name"` |
| Missing `spawn` | `"Missing required field: spawn"` |
| Missing `tiles` | `"Missing required field: tiles"` |
| `spawn` not array of 2 numbers | `"Invalid spawn: expected [q, r] array"` |
| Tile key not "int,int" | `"Invalid tile key: '{key}'"` |
| Unknown biome | `"Tile ({q},{r}): unknown biome '{value}'"` |
| Elevation out of range | `"Tile ({q},{r}): elevation {value} out of range 0-9"` |
| Elevation not integer | `"Tile ({q},{r}): elevation must be an integer"` |
| Unknown structure | `"Tile ({q},{r}): unknown structure '{value}'"` |
| Unknown resource type | `"Tile ({q},{r}): unknown resource type '{value}'"` |
| Resource missing type | `"Tile ({q},{r}): resource entry missing 'type' field"` |

The editor never crashes on bad input. The editor never loads partial data.
