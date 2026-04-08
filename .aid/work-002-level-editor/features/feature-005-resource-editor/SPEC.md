# Resource Editor

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F10, F12; §9 AC2, AC4 | /aid-interview |
| 2026-04-03 | Updated field list to match actual resource_def.gd; added F15/AC9 references | /aid-interview (cross-reference) |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: default mesh types cube not cylinder, explicit catalog defaults, alpha handling, delete scan dual format, ProjectContext naming | /aid-specify review |

## Source

- REQUIREMENTS.md §5 F10 (Resource Editor), F12 (.tres Parser), F15 (Import Validation), §9 AC2, AC4, AC9

## Description

The Resource Editor tab for managing `data/props/*.tres` ResourceDef files. Provides a list view of all resources with key properties, create/edit/delete operations with form UI, and deletion validation (warns if any map references the resource). Reads and writes .tres files with round-trip safety — preserving uid, ext_resource, and script lines.

**Editable fields** (from `resource_def.gd`): `id` (StringName), `display_name` (String), `gather_time` (float), `gather_amount` (int), `tool_required` (StringName), `respawn_time` (float), `yield_type` (StringName), `tool_speed` (Dictionary), `max_stack` (int), `category` (StringName), `catalog_entry` (StringName), `catalog_category` (StringName), `placeholder_mesh_type` (StringName), `placeholder_params` (Dictionary), `placeholder_color` (Color — with color picker + swatch preview), `placeholder_depleted_type` (StringName), `placeholder_depleted_params` (Dictionary), `placeholder_depleted_color` (Color).

**Read-only fields:** `mesh`, `depleted_mesh`, `material` (Godot resource references — displayed as path or "not set", cannot be authored in a web editor).

## User Stories

- As Andre, I want to see all resource definitions in a list so that I can browse and manage them
- As Andre, I want to create new resources with a form so that I don't have to write .tres files by hand
- As Andre, I want to edit resource properties and see a color preview so that I can tune visual appearance
- As Andre, I want deletion to warn me if a map uses the resource so that I don't break existing maps

## Priority

Must

## Acceptance Criteria

- [ ] Given a resource .tres loaded and saved with no changes, then the file preserves uid, ext_resource, and script lines exactly (AC2)
- [ ] Given a new resource created, when saved, then a valid .tres file appears in data/props/ and the resource shows in the Map Editor palette (AC4)
- [ ] Given a resource in use by a map, when attempting to delete, then a warning dialog shows which map references it
- [ ] Given a resource edit, when saved, then re-parsing the written file matches the in-memory model
- [ ] Given a malformed .tres file in data/props/, when loaded, then the editor shows a clear error message and skips the file without crashing (AC9)

---

## Technical Specification

### Data Model

**ResourceDefModel** — JS representation of a single ResourceDef .tres file:
```js
{
  // Round-trip metadata (not user-editable)
  _handle: FileSystemFileHandle|null,  // for direct save
  _headerLines: string[],             // preserved [gd_resource ...] and [ext_resource ...] lines
  _dirty: boolean,                    // true if modified since last save

  // Editable fields
  id: string,                  // StringName, e.g. "wood"
  display_name: string,        // e.g. "Wood"
  gather_time: number,         // float, e.g. 1.0
  gather_amount: number,       // int, e.g. 1
  tool_required: string,       // StringName, e.g. "stone_axe" or "" for none
  respawn_time: number,        // float, e.g. 30.0
  yield_type: string,          // StringName, e.g. "" (empty if same as self)
  tool_speed: Map<string, number>,  // e.g. { "stone_axe": 0.5 }
  max_stack: number,           // int, e.g. 99
  category: string,            // StringName, e.g. "resource"
  catalog_entry: string,       // StringName, e.g. "wood_tree"
  catalog_category: string,    // StringName, e.g. "flora"
  placeholder_mesh_type: string,       // StringName, e.g. "cylinder"
  placeholder_params: Object,          // e.g. { radius: 0.2, height: 0.8 }
  placeholder_color: { r: number, g: number, b: number, a: number },  // Color
  placeholder_depleted_type: string,
  placeholder_depleted_params: Object,
  placeholder_depleted_color: { r: number, g: number, b: number, a: number },

  // Read-only fields (displayed but not editable)
  mesh: string|null,           // resource path or null
  depleted_mesh: string|null,
  material: string|null
}
```

**In-memory store:** `Map<string, ResourceDefModel>` keyed by `id`. Exposed as `ProjectContext.files.resources` (see feature-007 for `ProjectContext` definition).

**Color representation:** Colors are stored as `{r, g, b, a}` with values 0.0-1.0 internally. Converted to/from hex string `#rrggbb` for HTML color picker inputs. The HTML color picker does not support alpha, so the UI always shows/sets alpha as 1.0 for new resources. However, the parser must read and preserve alpha from existing .tres files (write it back as-is). The .tres format uses `Color(r, g, b, a)`.

**Default values for new resource:**
```js
{
  id: "",                    // user must set
  display_name: "",          // user must set
  gather_time: 1.0,
  gather_amount: 1,
  tool_required: "",
  respawn_time: 30.0,
  yield_type: "",
  tool_speed: {},
  max_stack: 99,
  category: "resource",
  catalog_entry: "",
  catalog_category: "",
  placeholder_mesh_type: "cube",
  placeholder_params: {},
  placeholder_color: { r: 0.5, g: 0.5, b: 0.5, a: 1.0 },
  placeholder_depleted_type: "cube",
  placeholder_depleted_params: {},
  placeholder_depleted_color: { r: 0.3, g: 0.3, b: 0.3, a: 1.0 }
}
```

### Feature Flow

**List View:**
- Rendered as an HTML `<table>` inside the Resource Editor tab panel.
- Columns: `id`, `display_name`, `category`, color swatch (16x16 div with `placeholder_color` as background), `gather_time`.
- Rows sorted alphabetically by `id`.
- Clicking a row opens the edit form for that resource (replaces list view in the tab panel).
- "New Resource" button at top of list opens the edit form populated with defaults.
- List re-renders when the resource store changes (add/delete/rename).

**Edit Form:**
- Organized into collapsible sections with `<details>` elements, all open by default:

**Section 1 — Identity:**
- `id`: text input. Validated: non-empty, alphanumeric + underscores only, unique across all resources. Disabled when editing existing resource (id is immutable after creation to avoid breaking map references).
- `display_name`: text input. Non-empty.

**Section 2 — Gathering:**
- `gather_time`: number input, step 0.1, min 0.1.
- `gather_amount`: number input, step 1, min 1, integer.
- `tool_required`: text input (StringName, empty means no tool needed).
- `respawn_time`: number input, step 1.0, min 0.
- `yield_type`: text input (StringName, empty means yields self).
- `tool_speed`: key-value pair editor. Table with columns: Tool (text input), Speed Multiplier (number input, step 0.1). "Add Row" button appends empty row. "X" button on each row removes it.

**Section 3 — Inventory:**
- `max_stack`: number input, step 1, min 1, integer.
- `category`: text input (StringName).

**Section 4 — Catalog:**
- `catalog_entry`: text input.
- `catalog_category`: text input.

**Section 5 — Visuals:**
- `placeholder_mesh_type`: text input.
- `placeholder_params`: key-value pair editor (key: text, value: number input).
- `placeholder_color`: HTML `<input type="color">` with a 24x24 swatch preview div beside it. Changing the picker updates the swatch live.
- `placeholder_depleted_type`: text input.
- `placeholder_depleted_params`: key-value pair editor.
- `placeholder_depleted_color`: HTML `<input type="color">` with swatch.

**Section 6 — Read-Only:**
- `mesh`, `depleted_mesh`, `material`: displayed as text labels showing the resource path or "(not set)". No edit controls.

**Form Actions:**
- "Save" button: validates form, creates a `ResourceEditCommand` (for undo/redo), serializes to .tres via `TresParser.serializeResource(model)`, writes via File System Access API. On success, updates the in-memory store and returns to list view.
- "Cancel" button: discards changes, returns to list view. If form is dirty, confirm dialog: "Discard unsaved changes?"
- "Back to List" link at top of form.

**All edits are wrapped in Commands (feature-008):**
- `ResourceCreateCommand` — execute: add to store + write file. Undo: remove from store + delete file.
- `ResourceEditCommand` — execute: apply new field values + write file. Undo: restore previous field values + write file.
- `ResourceDeleteCommand` — execute: remove from store + delete file. Undo: re-add to store + write file.

**Delete:**
1. User clicks "Delete" button on the edit form (not available from list view to prevent accidental deletion).
2. System scans all loaded maps' tiles for any resource referencing this id. Resources in map JSON can be either plain strings (`"wood"`) or dicts (`{ type: "wood", ... }`); the scan must handle both forms: `entry === id` or `entry.type === id`.
3. If references found: show warning dialog: "This resource is used by {count} tile(s) in {mapNames}. Deleting it will make those tiles invalid. Continue?" with "Delete Anyway" and "Cancel" buttons.
4. If no references or user confirms: create `ResourceDeleteCommand`, execute it. File is deleted via `FileSystemFileHandle` (or marked for deletion in fallback mode).

**Save format** — .tres file output (via TresParser from feature-007):
- Preserve original `_headerLines` exactly (the `[gd_resource ...]` and `[ext_resource ...]` lines).
- For new files, generate standard header:
  ```
  [gd_resource type="Resource" script_class="ResourceDef" load_steps=2 format=3]
  [ext_resource type="Script" path="res://scripts/data/resource_def.gd" id="1_script"]
  ```
- `[resource]` section: write `script = ExtResource("1_script")` first, then each field in the order defined in resource_def.gd.
- StringName values: formatted as `&"value"`.
- Float values: always include decimal (e.g. `1.0` not `1`).
- Dictionary values: formatted as `{ &"key": value, ... }` (Godot dictionary syntax).
- Color values: formatted as `Color(r, g, b, a)` with values to 1-3 decimal places.
- Omit read-only fields (`mesh`, `depleted_mesh`, `material`) from output — Godot assigns these at runtime.

### Layers & Components

**ResourceEditor** (DOM layer):
- Manages the Resource Editor tab content: switches between list view and edit form.
- `renderList()` — builds the resource table from `EditorState.resources`.
- `renderEditForm(resourceId|null)` — builds the edit form. `null` means new resource.
- `collectFormData() -> ResourceDefModel` — reads current form inputs into a model.
- `validateForm(model) -> ValidationResult` — checks required fields, id uniqueness, numeric ranges.
- Listens for `resource-store-changed` event to re-render list.

**ResourceDefModel** (data class, no DOM):
- Static `fromTres(tresString, handle) -> ResourceDefModel` — delegates to TresParser for parsing.
- `toTres() -> string` — delegates to TresParser for serialization.
- `clone() -> ResourceDefModel` — deep copy for command undo snapshots.
- `equals(other) -> boolean` — field-by-field comparison for dirty checking.

**Implementation dependency:** Feature-007 (File Discovery + TresParser) must be implemented before this feature, as it provides the shared .tres parsing infrastructure.

**Integration with TresParser (feature-007):**
- `TresParser.parseResource(tresString) -> { headers, fields }` — extracts header lines and key-value pairs from `[resource]` section.
- `TresParser.serializeResource(headers, fields) -> string` — reconstructs the .tres file text.
- The ResourceDefModel maps between the parsed key-value pairs and its typed JS fields (e.g., parsing `Color(0.2, 0.7, 0.2, 1.0)` into `{r: 0.2, g: 0.7, b: 0.2, a: 1.0}`).

**Integration with Map Editor:**
- When a resource is created or renamed, the Map Editor's resource palette is updated (resource type dropdown).
- When a resource is deleted, tiles referencing it in loaded maps will show validation warnings on next export.

### Import Validation (F15/AC9)

During file discovery (feature-007), each `.tres` file in `data/props/` is parsed:

| Condition | Behavior |
|-----------|----------|
| File cannot be read | Skip, log warning: `"Skipped {filename}: unable to read file"` |
| Not valid .tres (no `[gd_resource ...]` header) | Skip, show warning: `"Skipped {filename}: not a valid .tres file"` |
| Missing `[resource]` section | Skip, show warning: `"Skipped {filename}: missing [resource] section"` |
| `script_class` is not `"ResourceDef"` | Skip silently (it is a different resource type) |
| Missing `id` field in `[resource]` | Skip, show warning: `"Skipped {filename}: missing 'id' field"` |
| Duplicate `id` (already loaded) | Skip, show warning: `"Skipped {filename}: duplicate id '{id}' (already loaded from {other_filename})"` |
| Individual field parse error (e.g., malformed Color) | Use default value for that field, show warning: `"Resource '{id}': could not parse field '{field}', using default"` |

Warnings are collected and displayed in a non-blocking notification area (toast or status bar), not as modal dialogs. The editor never crashes on malformed .tres input.
