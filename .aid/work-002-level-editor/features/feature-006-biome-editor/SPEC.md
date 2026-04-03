# Biome Editor

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F11, F12; §9 AC2, AC5 | /aid-interview |
| 2026-04-03 | Updated resource_table field names to match biome_data.gd; added F15/AC9 references | /aid-interview (cross-reference) |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: uid in generated header, ProjectContext naming, cancel color revert event | /aid-specify review |

## Source

- REQUIREMENTS.md §5 F11 (Biome Editor), F12 (.tres Parser), F15 (Import Validation), §9 AC2, AC5, AC9

## Description

The Biome Editor tab for managing `data/biomes/*.tres` BiomeData files. Provides a list view with color swatches and resource summaries, create/edit/delete operations, color picker for base color and variations, resource table editor, and deletion validation (warns if any map tile uses the biome). Editing biome color updates the Map Editor canvas in real-time.

**Editable fields** (from `biome_data.gd`): `biome_name` (String), `elevation_range` (Vector2i), `color` (Color — with color picker), `color_variations` (Array[Color]).

**Resource table editor:** Each entry has `type` (String — dropdown from Resource Editor), `chance` (float), `min_amount` (int), `max_amount` (int), `tool_required` (String). Add/remove rows.

## User Stories

- As Andre, I want to see all biomes in a list with color swatches so that I can browse definitions visually
- As Andre, I want to edit biome colors with a color picker and see the map update live so that I can tune the look in real-time
- As Andre, I want to edit biome resource tables so that I can define what resources spawn in each biome
- As Andre, I want deletion to warn me if map tiles use the biome so that I don't break existing maps

## Priority

Must

## Acceptance Criteria

- [ ] Given a biome .tres loaded and saved with no changes, then the file preserves uid, ext_resource, and script lines exactly (AC2)
- [ ] Given a biome color changed in the editor, when switching to Map Editor, then all hexes of that biome show the new color immediately (AC5)
- [ ] Given a biome in use by map tiles, when attempting to delete, then a warning dialog shows the tile count
- [ ] Given a resource table edit, when saved, then the .tres file contains the correct resource_table array
- [ ] Given a malformed .tres file in data/biomes/, when loaded, then the editor shows a clear error message and skips the file without crashing (AC9)

---

## Technical Specification

### Data Model

**BiomeDataModel** — JS representation of a single BiomeData .tres file:
```js
{
  // Round-trip metadata (not user-editable)
  _handle: FileSystemFileHandle|null,  // for direct save
  _headerLines: string[],             // preserved [gd_resource ...] and [ext_resource ...] lines
  _dirty: boolean,                    // true if modified since last save

  // Editable fields
  biome_name: string,          // e.g. "Forest"
  elevation_range: { min: number, max: number },  // Vector2i, integers 0-9
  color: { r: number, g: number, b: number, a: number },  // Color
  color_variations: [          // Array[Color]
    { r: number, g: number, b: number, a: number }
  ],
  resource_table: [            // Array of resource spawn entries
    {
      type: string,            // resource id, e.g. "wood"
      chance: number,          // float 0.0-1.0
      min_amount: number,      // int >= 0
      max_amount: number,      // int >= min_amount
      tool_required: string    // StringName, "" for none
    }
  ]
}
```

**In-memory store:** `Map<string, BiomeDataModel>` keyed by `biome_name` (lowercase). Exposed as `ProjectContext.files.biomes` (see feature-007 for `ProjectContext` definition).

**Biome name as key:** The `biome_name` field is used as the biome identifier in map tiles (lowercased, e.g. tile `biome: "forest"` references biome with `biome_name: "Forest"`). The key in the store is the lowercased `biome_name`.

**Default values for new biome:**
```js
{
  biome_name: "",              // user must set
  elevation_range: { min: 0, max: 9 },
  color: { r: 0.5, g: 0.5, b: 0.5, a: 1.0 },
  color_variations: [],
  resource_table: []
}
```

### Feature Flow

**List View:**
- Rendered as an HTML `<table>` inside the Biome Editor tab panel.
- Columns:
  - Biome Name: text with a 16x16 color swatch (using `color`) to the left of the name.
  - Elevation Range: displayed as `"min - max"`, e.g. `"0 - 9"`.
  - Resources: count of entries in `resource_table`, e.g. `"3 resources"`.
- Rows sorted alphabetically by `biome_name`.
- Clicking a row opens the edit form for that biome.
- "New Biome" button at top opens the edit form with defaults.

**Edit Form:**

**biome_name:** Text input. Validated: non-empty, unique across all biomes (case-insensitive). Disabled when editing existing biome (name is immutable after creation — renaming would require updating all map tile references, which is too risky for a simple edit).

**Hardcoded biome warning:** MapLoader's `BIOME_NAMES` dict only recognizes 5 biomes: `crash_site`, `grassland`, `forest`, `rocky`, `water`. Creating a new biome is valid in the editor, but maps using it will silently fall back to GRASSLAND at game runtime until MapLoader is updated. The editor should show a warning badge on custom biomes (not in the hardcoded set) to alert the author.

**elevation_range:** Two number inputs side by side, labeled "Min" and "Max". Both integers, constrained to 0-9. Validation: min <= max.

**color:** HTML `<input type="color">` with a 32x32 swatch preview div. Changing the picker:
1. Updates the swatch live.
2. Updates the in-memory model immediately.
3. Fires a `biome-color-changed` event with `{ biomeName, newColor }`.
4. The Map Editor's `HexCanvas` listens for this event and calls `repaint()` to update all tiles of that biome with the new color.

**color_variations:** A vertical list of color entries. Each entry has:
- HTML `<input type="color">` with a 16x16 swatch.
- "X" (remove) button.
- "Add Variation" button at bottom appends a new entry defaulting to the current base `color`.
- Maximum 10 variations (UI disables "Add" button at limit).

**resource_table:** Editable table with columns:
- Type: `<select>` dropdown populated from `ProjectContext.files.resources` keys (loaded resource ids). If a type references an unknown resource, show it as red text with "(unknown)" suffix.
- Chance: number input, step 0.05, min 0.0, max 1.0.
- Min Amount: number input, step 1, min 0, integer.
- Max Amount: number input, step 1, min 0, integer. Validated: >= min_amount.
- Tool Required: text input (StringName, empty means no tool).
- "X" (remove) button per row.
- "Add Resource" button appends empty row with defaults: `{ type: "", chance: 0.5, min_amount: 1, max_amount: 1, tool_required: "" }`.

**Form Actions:**
- "Save" button: validates form, creates a `BiomeEditCommand`, serializes to .tres via `TresParser.serializeBiome(model)`, writes via File System Access API. On success, updates in-memory store, returns to list view.
- "Cancel" button: discards changes, restores biome color if it was changed during editing by firing a `biome-color-changed` event with the original color (so the Map Editor canvas reverts), then returns to list view. Confirm dialog if dirty.
- "Back to List" link at top.

**All edits wrapped in Commands (feature-008):**
- `BiomeCreateCommand` — execute: add to store + write file. Undo: remove from store + delete file.
- `BiomeEditCommand` — execute: apply new values + write file + fire color-changed event. Undo: restore previous values + write file + fire color-changed event.
- `BiomeDeleteCommand` — execute: remove from store + delete file. Undo: re-add to store + write file.

**Delete:**
1. User clicks "Delete" button on the edit form.
2. System scans all loaded maps' tiles for any `biome` field matching this biome_name (case-insensitive).
3. If references found: show warning dialog: "This biome is used by {count} tile(s) across {mapCount} map(s). Deleting it will make those tiles invalid. Continue?" with "Delete Anyway" and "Cancel".
4. If confirmed: create `BiomeDeleteCommand`, execute it.

**Save format** — .tres file output (via TresParser from feature-007):
- Preserve original `_headerLines` exactly.
- For new files, generate standard header with uid (see feature-007 `generateTresUid()`):
  ```
  [gd_resource type="Resource" script_class="BiomeData" load_steps=2 format=3 uid="uid://c<13-char-random>"]
  [ext_resource type="Script" path="res://scripts/hex/biome_data.gd" id="1_biome"]
  ```
- `[resource]` section field order: `script`, `biome_name`, `elevation_range`, `resource_table`, `color`, `color_variations`.
- `biome_name`: quoted string, e.g. `"Forest"`.
- `elevation_range`: `Vector2i(min, max)`.
- `resource_table`: array of dictionaries, e.g. `[{"chance": 0.7, "max_amount": 5, "min_amount": 2, "type": "wood"}]`. Dictionary keys sorted alphabetically to match Godot's serialization.
- `color`: `Color(r, g, b, a)`.
- `color_variations`: `[Color(r, g, b, a), Color(r, g, b, a)]`.

### Layers & Components

**BiomeEditor** (DOM layer):
- Manages the Biome Editor tab content: switches between list view and edit form.
- `renderList()` — builds the biome table from `EditorState.biomes`.
- `renderEditForm(biomeName|null)` — builds the edit form. `null` means new biome.
- `collectFormData() -> BiomeDataModel` — reads current form inputs into a model.
- `validateForm(model) -> ValidationResult` — checks required fields, name uniqueness, elevation range, resource table consistency (max >= min, chance in range).

**BiomeDataModel** (data class, no DOM):
- Static `fromTres(tresString, handle) -> BiomeDataModel` — delegates to TresParser for parsing.
- `toTres() -> string` — delegates to TresParser for serialization.
- `clone() -> BiomeDataModel` — deep copy for command undo snapshots.
- `equals(other) -> boolean` — field-by-field comparison for dirty checking.

**Cross-tab integration (AC5 — live preview):**
- `BiomeEditor` dispatches a custom event `biome-color-changed` on the document whenever the color picker value changes (on `input` event, not just `change`, for real-time feedback).
- `HexCanvas` (from feature-001/002) listens for `biome-color-changed` and calls its `repaint()` method.
- During repaint, `HexCanvas` reads tile biome names, looks up current color from `EditorState.biomes`, and fills hex polygons accordingly.
- This means color changes are visible on the Map Editor tab instantly — even before saving. If the user cancels the edit, the `BiomeEditCommand` undo restores the old color and fires the event again to revert the canvas.

**Integration with Resource Editor:**
- The resource_table type dropdown is populated from `EditorState.resources`. When resources are added/removed, the dropdown options update on next form render.
- If a biome references a resource type that no longer exists, it is displayed with a visual warning but not auto-removed (the user decides what to do).

### Import Validation (F15/AC9)

During file discovery (feature-007), each `.tres` file in `data/biomes/` is parsed:

| Condition | Behavior |
|-----------|----------|
| File cannot be read | Skip, log warning: `"Skipped {filename}: unable to read file"` |
| Not valid .tres (no `[gd_resource ...]` header) | Skip, show warning: `"Skipped {filename}: not a valid .tres file"` |
| Missing `[resource]` section | Skip, show warning: `"Skipped {filename}: missing [resource] section"` |
| `script_class` is not `"BiomeData"` | Skip silently (different resource type) |
| Missing `biome_name` field | Skip, show warning: `"Skipped {filename}: missing 'biome_name' field"` |
| Duplicate `biome_name` (case-insensitive) | Skip, show warning: `"Skipped {filename}: duplicate biome '{name}' (already loaded from {other})"` |
| Malformed `resource_table` | Use empty array, show warning: `"Biome '{name}': could not parse resource_table, using empty"` |
| Malformed `color` | Use default grey, show warning: `"Biome '{name}': could not parse color, using default"` |
| Malformed `elevation_range` | Use `(0, 9)`, show warning: `"Biome '{name}': could not parse elevation_range, using default 0-9"` |

Warnings are collected and displayed in a non-blocking notification area (toast or status bar). The editor never crashes on malformed .tres input.
