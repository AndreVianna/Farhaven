# Import / Export

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F6, F7; §9 AC1, AC3, AC6 | /aid-interview |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: string resource normalization, MapLoader validation scope, spawn checks, anomaly null handling, .tres scope note | /aid-specify review |
| 2026-04-04 | Sub-hex grid system: resource serialization uses (sq, sr) instead of (x, y), structure uses footprint model, legacy format migration, sub-hex validation rules | design change |
| 2026-04-04 | Unified props model: tile format uses props[] instead of separate resources/structure/anomaly fields. Legacy import detects old format and converts. Export writes props[] format. Validation updated for unified model. | design change |
| 2026-04-06 | Engine JSON schema alignment: categories serialize as integers (0=resource, 1=structure, 2=anomaly, 3=spawn), field names sub_hex_q/sub_hex_r replace sq/sr at serialization boundary, footprint is internal-only (not serialized), new optional fields per category (remaining, max_amount, tool_required, respawn_time for resources; blocks_movement for structures), root-level format is { spawn, tiles } with chapter_id/name optional | schema change |

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
  props: [              // array of props (resources, structures, anomalies)
    {
      type: string,       // e.g. "wood", "workbench", "anomaly_ch1_001"
      sq: int,            // sub-hex axial q
      sr: int,            // sub-hex axial r
      category: string,   // "resource" | "structure" | "anomaly"
      rotation: number,   // 0-359, resources only
      footprint: [{q,r}]  // structures only, sub-hex offsets they occupy
    }
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
   - Validate `spawn` references an existing tile key. Warning if spawn tile not in tiles (import still proceeds — the user can fix it before export).
3. For each tile entry in `tiles`:
   - Parse key as `"q,r"` — reject if not two integers separated by comma.
   - Validate `biome` exists in `knownBiomes`. Error: `"Tile (q,r): unknown biome '{value}'"`.
   - Validate `elevation` is integer 0-9. Error: `"Tile (q,r): elevation {value} out of range 0-9"`.
   - **Legacy format detection:** If the tile has `resources`, `structure`, or `anomaly` keys (old format) instead of `props`, convert to unified props[] format:
     - For each resource in `resources[]`: if the entry is a plain string (e.g. `"wood"`), normalize to `{ type: "wood", sq: 0, sr: 0, category: "resource", rotation: random(0, 359) }`. If it's a dict with `x` and `y` fields, convert to nearest sub-hex via `pixelToSubHex()`. If it's a dict with `sq` and `sr` fields, add `category: "resource"`. Push to props[].
     - If `structure` is a plain string (legacy), convert to `{ type: string, sq: 0, sr: 0, category: "structure", footprint: [{q:0,r:0}] }`. If it's a dict with `type` and `sub_hexes`, convert `sub_hexes` to `footprint` and add `category: "structure"`. Push to props[].
     - If `anomaly` is a non-null string, convert to `{ type: anomalyId, sq: 0, sr: 0, category: "anomaly" }`. Push to props[].
   - **New format:** If the tile has `props[]`, use as-is.
   - Validate all props: `type` exists in known definitions for its category. Error: `"Tile (q,r): unknown {category} type '{value}'"`. (MapLoader supports both forms — see `map_loader.gd` lines 93-100.)
4. If `valid === true`: populate `HexGrid` map and `MapMeta`, fire `map-loaded` event, `HexCanvas.repaint()`.
5. If `valid === false`: show error dialog listing all errors. Reject import entirely — no partial load. The previous map state (if any) remains unchanged.

**Export:**
1. User triggers export via Ctrl+S or toolbar "Save" button.
2. `MapValidator.validate(hexGrid, mapMeta, knownBiomes, knownResources, knownStructures)` runs all checks:
   - Spawn must exist: `spawn` must reference a tile that exists in the grid. Error: `"Spawn point ({q},{r}) does not exist as a tile"`. (This enforces REQUIREMENTS F7's "exactly one spawn point" — the data model guarantees at most one since `MapMeta.spawn` is a single `[q, r]` value.)
   - No duplicate coordinate keys (guaranteed by Map, but validated during serialize).
   - All tile `biome` values exist in `knownBiomes`.
   - All tile `elevation` values are integers 0-9.
   - All prop types must exist in known definitions for their category.
   - Prop sub-hex positions (sq, sr) must be valid (distance ≤ 2). Error if invalid.
   - No overlapping props on same sub-hex within a tile (all categories share the sub-hex space). Error if duplicates found.
   - Structure footprints must reference valid sub-hex positions. Error if invalid.
   - Resource `rotation` is a number. Warning if outside [0, 360).
**MapLoader-level validation (advisory):** MapLoader (`scripts/hex/map_loader.gd`) performs additional checks that are logged as warnings but do not block loading: tile count in [200, 300], required biomes (CRASH_SITE, GRASSLAND, FOREST, ROCKY) all present, at least one anomaly tile, all non-water tiles reachable from spawn via BFS, spawn tile is CRASH_SITE. These are **not** enforced as hard errors in the editor's export validator — they are game-design constraints that may not apply during early authoring. Instead, the editor could surface them as warnings in a future "Validate Map" action.

**Hardcoded biome warning:** MapLoader's `BIOME_NAMES` dict is hardcoded to exactly 5 biomes: `crash_site`, `grassland`, `forest`, `rocky`, `water`. Any custom biome created in the Biome Editor will be accepted by the editor's validator (it checks against loaded .tres files) but will **silently fall back to GRASSLAND** at runtime in MapLoader. Until MapLoader is updated to dynamically load biome names, the export validator should warn if a tile references a biome not in the hardcoded set.

3. If valid: `MapSerializer.toJSON(hexGrid, mapMeta)` produces a JSON string. Write via File System Access API (`FileSystemFileHandle.createWritable()`). If no handle (fallback browser), trigger download via Blob + anchor click.
4. If invalid: show validation error dialog with all issues. Block save.

**Serialization format** — `MapSerializer.toJSON()` output uses the engine JSON schema with integer categories:
```js
{
  "spawn": [q, r],
  "tiles": {
    "q,r": {
      "biome": "forest",
      "elevation": 2,
      // "props" key omitted if empty array
      "props": [
        {"type": "wood", "category": 0, "sub_hex_q": 1, "sub_hex_r": 0, "rotation": 18, "remaining": 5, "max_amount": 10, "tool_required": "axe", "respawn_time": 300},
        {"type": "workbench", "category": 1, "blocks_movement": true},
        {"type": "anomaly_ch1_001", "category": 2, "sub_hex_q": 0, "sub_hex_r": -1}
      ]
    }
  },
  // Optional — included only if non-empty (editor metadata, not consumed by engine)
  "chapter_id": "ch1",
  "name": "Crash Landing"
}
```

**Category integer enum:** `{ resource: 0, structure: 1, anomaly: 2, spawn: 3 }`. Defined as `CATEGORY_TO_INT` / `INT_TO_CATEGORY` in `hex-grid.js`.

**Field name mapping at serialization boundary:**
- Internal `sq`/`sr` serialize as `sub_hex_q`/`sub_hex_r` (omitted when both are 0)
- Internal string `category` serializes as integer
- `rotation` is omitted when 0
- `footprint` is internal-only and never serialized

**Optional fields per category:**
- Resource: `remaining` (number), `max_amount` (number), `tool_required` (string), `respawn_time` (number, omitted if 0)
- Structure: `blocks_movement` (boolean, only serialized when true)

The `props` key is omitted from output when the array is empty to keep JSON clean. On import, a missing `props` field defaults to `[]`.

**Import compatibility:** The deserializer accepts both engine format (integer categories, sub_hex_q/sub_hex_r) and legacy editor format (string categories, sq/sr), as well as the oldest format with separate resources/structure/anomaly fields.

**Legacy format support:** On import, detect old format (tile has `resources`, `structure`, or `anomaly` keys instead of `props`). Convert to unified props[]:
- Resource entries: plain strings normalize to `{ type, sq: 0, sr: 0, category: "resource", rotation: random }`. Dicts with `x`/`y` fields convert via `pixelToSubHex()`. Dicts with `sq`/`sr` get `category: "resource"` added.
- Structure: plain strings become `{ type, sq: 0, sr: 0, category: "structure", footprint: [{q:0,r:0}] }`. Dicts with `sub_hexes` convert to footprint format.
- Anomaly: non-null strings become `{ type: anomalyId, sq: 0, sr: 0, category: "anomaly" }`.
This provides backwards compatibility with ch1.json. Export always writes the new props[] format.

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
| Unknown prop type | `"Tile ({q},{r}): unknown {category} type '{value}'"` |
| Prop missing type | `"Tile ({q},{r}): prop entry missing 'type' field"` |
| Prop missing category | `"Tile ({q},{r}): prop entry missing 'category' field"` |
| Invalid category | `"Tile ({q},{r}): invalid prop category '{value}'"` |

| Legacy tile (has resources/structure/anomaly keys) | Convert to unified props[] format (see Legacy format support) |
| Prop sub-hex position invalid | `"Tile ({q},{r}): prop sub-hex ({sq},{sr}) is not a valid position (distance > 2)"` |
| Structure footprint has invalid sub-hex | `"Tile ({q},{r}): structure footprint contains invalid sub-hex ({sq},{sr})"` |
| Duplicate sub-hex occupancy | `"Tile ({q},{r}): sub-hex ({sq},{sr}) is occupied by multiple props"` |

The editor never crashes on bad input. The editor never loads partial data.

**Scope note:** .tres file parsing and round-trip safety (F12/AC2) are handled by feature-007 (File Discovery — TresParser) and consumed by feature-005 (Resource Editor) and feature-006 (Biome Editor). This feature covers only map JSON import/export.
