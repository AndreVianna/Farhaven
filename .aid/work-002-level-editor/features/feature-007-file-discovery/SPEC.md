# File Discovery

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F13; §7 | /aid-interview |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: typed arrays in parser, dict key style clarification, PackedStringArray support | /aid-specify review |

## Source

- REQUIREMENTS.md §5 F13 (File Discovery), §7 (Constraints)

## Description

Project root selection and automatic file discovery on startup. The user selects the Farhaven project root folder (containing `data/`, `scripts/`, `project.godot`). The editor auto-discovers maps (`data/maps/*.json`), resources (`data/props/*.tres`), and biomes (`data/biomes/*.tres`). File handles are retained via File System Access API for direct save (Chrome/Edge). Fallback to standard file download for browsers without File System Access (Firefox/Safari).

## User Stories

- As Andre, I want to select the project folder once and have the editor find all data files so that I don't manually load each file
- As Andre, I want direct save (Ctrl+S) without download dialogs so that iteration is fast
- As Andre, I want a fallback download option so that the editor works in any browser if needed

## Priority

Must

## Acceptance Criteria

- [ ] Given project root selected, when discovery runs, then all .json maps, .tres resources, and .tres biomes are found and loaded
- [ ] Given Chrome/Edge with File System Access API, when saving, then files are written directly without download dialog
- [ ] Given Firefox/Safari, when saving, then files are offered as downloads
- [ ] Given a folder without project.godot, when selected, then the editor shows an error asking for the correct folder
- [ ] Given the user cancels the folder picker dialog, then the editor shows a welcome/landing state (not an error) with a button to try again

---

## Technical Specification

### Data Model

#### `ProjectContext`

Global singleton object holding all project state after discovery.

```js
const ProjectContext = {
  rootHandle: null,          // FileSystemDirectoryHandle — project root
  hasFileSystemAccess: false, // true if showDirectoryPicker is available
  files: {
    maps: new Map(),         // filename -> { handle: FileSystemFileHandle, data: Object }
    resources: new Map(),    // filename -> { handle: FileSystemFileHandle, data: Object, raw: TresFile }
    biomes: new Map(),       // filename -> { handle: FileSystemFileHandle, data: Object, raw: TresFile }
  },
};
```

- `handle` — retained `FileSystemFileHandle` for direct save via `createWritable()`.
- `data` — parsed JS object (map JSON or parsed .tres resource section).
- `raw` — `TresFile` object preserving full .tres structure for round-trip safety.

#### `TresFile`

Intermediate representation preserving the full .tres file structure.

```js
class TresFile {
  constructor() {
    this.headerLine = '';      // e.g. '[gd_resource type="Resource" ...]'
    this.extResources = [];    // array of raw ext_resource lines (strings)
    this.resourceFields = {};  // ordered Map<string, TresValue> of [resource] key-value pairs
    this.uid = null;           // extracted uid string or null
    this.scriptClass = '';     // e.g. 'PropDef', 'BiomeData'
  }
}
```

#### `TresValue`

Wrapper for typed .tres values to enable round-trip serialization.

```js
// TresValue is a tagged union:
// { type: 'string', value: 'Forest' }
// { type: 'stringname', value: 'wood' }
// { type: 'int', value: 1 }
// { type: 'float', value: 1.0 }
// { type: 'bool', value: true }
// { type: 'color', value: { r: 0.2, g: 0.7, b: 0.2, a: 1.0 } }
// { type: 'vector2i', value: { x: 0, y: 9 } }
// { type: 'dict', value: { 'stone_axe': 0.5 } }
// { type: 'array', value: [...], elementType: null }                    -- untyped array [...]
// { type: 'array', value: [...], elementType: 'Color' }                -- typed array Array[Color](...)
// { type: 'packed_string_array', value: ['a', 'b'] }                   -- PackedStringArray("a", "b")
// { type: 'ext_resource', value: 'ExtResource("1_script")' }           -- preserved verbatim
```

### Feature Flow

1. **Startup** — Editor loads and checks `typeof window.showDirectoryPicker === 'function'`. Sets `ProjectContext.hasFileSystemAccess` accordingly. Shows welcome/landing state with "Open Project" button.

2. **Open Project (File System Access API path)**
   - User clicks "Open Project" button.
   - Call `window.showDirectoryPicker()`. If user cancels (throws `AbortError`), remain on welcome state — no error shown.
   - Store returned `FileSystemDirectoryHandle` in `ProjectContext.rootHandle`.

3. **Validate Project Root**
   - Attempt `rootHandle.getFileHandle('project.godot')`.
   - If not found, show error: "Not a Godot project. Please select the folder containing project.godot."
   - Clear `rootHandle`, return to welcome state.

4. **Scan Directories**
   - `FileDiscovery.scanDirectory(rootHandle, 'data/maps', '.json')` — discovers map files.
   - `FileDiscovery.scanDirectory(rootHandle, 'data/props', '.tres')` — discovers resource files.
   - `FileDiscovery.scanDirectory(rootHandle, 'data/biomes', '.tres')` — discovers biome files.
   - Each scan: navigate subdirectories via `getDirectoryHandle()`, iterate entries via `for await (const [name, handle] of dirHandle)`, filter by extension, retain `FileSystemFileHandle`.

5. **Parse Discovered Files**
   - For each map `.json`: read text via `handle.getFile()` then `file.text()`, call `JSON.parse()`. On parse error, log warning and skip file.
   - For each resource `.tres`: read text, call `TresParser.parse(text)`. Validate `scriptClass === 'PropDef'`. On parse error, log warning and skip file.
   - For each biome `.tres`: read text, call `TresParser.parse(text)`. Validate `scriptClass === 'BiomeData'`. On parse error, log warning and skip file.
   - Populate `ProjectContext.files.maps`, `.resources`, `.biomes` with `{ handle, data, raw }`.

6. **Post-Discovery**
   - Emit/call a callback to notify the UI that project data is loaded.
   - Switch from welcome state to the editor workspace (Map Editor tab active, palette populated from loaded biomes/resources).

7. **Fallback Path (no File System Access API)**
   - "Open Project" renders `<input type="file" webkitdirectory>` instead of calling `showDirectoryPicker()`.
   - On `change` event, read `input.files` — a flat `FileList` with `webkitRelativePath` on each entry.
   - Validate: at least one file has a relative path containing `project.godot` at the root level.
   - Filter files by path prefix (`data/maps/`, `data/props/`, `data/biomes/`) and extension.
   - Parse each file via `FileReader.readAsText()`.
   - `ProjectContext.hasFileSystemAccess` remains `false` — save operations will use download (Blob + `<a download>`).
   - No `FileSystemFileHandle` stored; `handle` fields are `null`.

### Layers & Components

#### `FileDiscovery` class

```js
class FileDiscovery {
  // Navigate from root to a subdirectory path like 'data/maps'
  // Returns FileSystemDirectoryHandle or null
  static async getSubdirectory(rootHandle, path)

  // Scan a directory for files matching the given extension
  // Returns Array<{ name: string, handle: FileSystemFileHandle }>
  static async scanDirectory(rootHandle, path, extension)

  // Full discovery flow: validate root, scan all three dirs, parse files
  // Returns { success: boolean, error?: string }
  static async discoverProject(rootHandle)

  // Fallback: process FileList from <input webkitdirectory>
  // Returns { success: boolean, error?: string }
  static async discoverFromFileList(fileList)

  // Save a single file. Uses FileSystemFileHandle if available, else downloads.
  // content: string (serialized JSON or .tres)
  // filename: string (for download fallback)
  // handle: FileSystemFileHandle | null
  static async saveFile(handle, content, filename)
}
```

#### `TresParser` class (shared infrastructure)

Parses and serializes Godot `.tres` resource files. Used by features 005 (Resource Editor), 006 (Biome Editor), and 007 (File Discovery).

```js
class TresParser {
  // Parse a .tres file string into a TresFile object.
  // Throws on malformed input with a descriptive error message.
  static parse(text) -> TresFile

  // Serialize a TresFile back to a .tres string.
  // Preserves header, ext_resource lines, and field order.
  static serialize(tresFile) -> string

  // Parse a single .tres value string into a TresValue.
  // Handles: &"...", "...", int, float, bool,
  //          Color(...), Vector2i(...), ExtResource("..."),
  //          {...} dictionaries, [...] arrays.
  static parseValue(valueStr) -> TresValue

  // Serialize a TresValue back to its .tres string representation.
  static serializeValue(tresValue) -> string
}
```

### .tres Parser Details

#### Parsing Rules

The `[resource]` section is parsed line by line. Each line has the form `key = value`.

| Godot Syntax | Detection | JS Representation |
|---|---|---|
| `&"wood"` | starts with `&"` | `{ type: 'stringname', value: 'wood' }` |
| `"Forest"` | starts with `"`, no `&` prefix | `{ type: 'string', value: 'Forest' }` |
| `1.0` | contains `.`, parseable as float | `{ type: 'float', value: 1.0 }` |
| `1` | integer, no decimal | `{ type: 'int', value: 1 }` |
| `true` / `false` | literal | `{ type: 'bool', value: true }` |
| `Color(0.2, 0.7, 0.2, 1.0)` | starts with `Color(` | `{ type: 'color', value: { r: 0.2, g: 0.7, b: 0.2, a: 1.0 } }` |
| `Vector2i(0, 9)` | starts with `Vector2i(` | `{ type: 'vector2i', value: { x: 0, y: 9 } }` |
| `ExtResource("1_script")` | starts with `ExtResource(` | `{ type: 'ext_resource', value: 'ExtResource("1_script")' }` |
| `{ &"stone_axe": 0.5 }` | starts with `{` | `{ type: 'dict', value: { 'stone_axe': 0.5 } }` |
| `[{...}, ...]` | starts with `[`, no `Array[` prefix | `{ type: 'array', value: [...], elementType: null }` |
| `Array[Color](...)` | starts with `Array[` | `{ type: 'array', value: [...], elementType: 'Color' }` — extract type from brackets, parse inner elements. Godot 4.x typed array syntax. |
| `PackedStringArray(...)` | starts with `PackedStringArray(` | `{ type: 'packed_string_array', value: [...] }` — parse comma-separated quoted strings. |
| `PackedColorArray(...)` | starts with `PackedColorArray(` | `{ type: 'array', value: [...], elementType: 'Color' }` — legacy/alternate syntax, same result. |

#### Serialization Rules

- `stringname` -> `&"value"`
- `string` -> `"value"`
- `int` -> value with no decimal (e.g. `1`)
- `float` -> value with decimal (e.g. `1.0`). If value is whole number, append `.0`.
- `color` -> `Color(r, g, b, a)` — preserve original precision where possible.
- `vector2i` -> `Vector2i(x, y)`
- `ext_resource` -> verbatim string
- `dict` -> key style depends on context:
  - **Top-level resource fields** (e.g. `tool_speed`): `{ &"key1": value1, &"key2": value2 }` — keys are StringName.
  - **Dicts inside arrays** (e.g. `resource_table` entries): `{"key": value}` — keys are plain strings.
  - The `TresValue` dict tracks this via a `keyStyle` field: `'stringname'` or `'string'`. On parse, detect from presence of `&"` prefix on first key. On serialize, use the stored style.
- `array` (untyped, `elementType: null`) -> `[element1, element2, ...]`
- `array` (typed, e.g. `elementType: 'Color'`) -> `Array[Color](element1, element2, ...)` — round-trips Godot 4.x typed array syntax.
- `packed_string_array` -> `PackedStringArray("val1", "val2", ...)`

#### Header Preservation

- The `[gd_resource ...]` line is stored verbatim in `TresFile.headerLine` and written back unchanged.
- All `[ext_resource ...]` lines are stored in `TresFile.extResources` array and written back in order.
- The `uid` attribute is extracted from the header for display/reference but never modified for existing files.
- Blank lines between sections are preserved (one blank line between header, ext_resource block, and resource block).

#### UID Generation (new files only)

When creating a new .tres file (feature 005 or 006), generate a uid:

```js
function generateTresUid() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let id = 'uid://c';
  for (let i = 0; i < 13; i++) {
    id += chars[Math.floor(Math.random() * chars.length)];
  }
  return id;
}
```

#### Round-Trip Safety

The parser is validated by this invariant: for any well-formed .tres file in the project, `TresParser.serialize(TresParser.parse(text))` must produce output identical to the input. This is verified during discovery by comparing parse-then-serialize output against the original file text and logging warnings on mismatch.

### Application Shell

Feature-007 owns the HTML skeleton, tab switching, toolbar, and initialization order — it is the application entry point.

**HTML structure:**
```html
<div id="app">
  <header id="toolbar">
    <!-- Tool buttons, save button, file name display -->
  </header>
  <nav id="tabs">
    <button class="tab active" data-tab="map">Map Editor</button>
    <button class="tab" data-tab="resources">Resource Editor</button>
    <button class="tab" data-tab="biomes">Biome Editor</button>
  </nav>
  <main id="tab-content">
    <div id="tab-map" class="tab-panel active">
      <canvas id="hex-canvas"></canvas>
      <aside id="sidebar"><!-- Palette & Sidebar (feature-003) --></aside>
    </div>
    <div id="tab-resources" class="tab-panel"><!-- Resource Editor (feature-005) --></div>
    <div id="tab-biomes" class="tab-panel"><!-- Biome Editor (feature-006) --></div>
  </main>
  <div id="welcome" class="overlay"><!-- Shown before project is opened --></div>
  <div id="hex-tooltip"></div>
</div>
```

**Tab switching:** Click a tab button → hide all `.tab-panel`, show the target panel, update `active` class. Each tab's content is initialized lazily on first switch (or eagerly after project load).

**Initialization order:**
1. `App.init()` — render welcome screen, register keyboard shortcuts (feature-008)
2. User opens project → `FileDiscovery.discoverProject()` (this feature)
3. On success → initialize `CommandHistory` (feature-008), `DirtyTracker` (feature-009)
4. Initialize `HexCanvas` (feature-001), `Sidebar` (feature-003), `ToolManager` (feature-002)
5. Initialize `ResourceEditor` (feature-005), `BiomeEditor` (feature-006)
6. Load first discovered map (or show empty canvas)
7. Switch from welcome overlay to main app view

### Error Handling

| Scenario | Behavior |
|---|---|
| User cancels folder picker | Stay on welcome state, no error message |
| Selected folder missing `project.godot` | Show error banner: "Not a Godot project. Select the folder containing project.godot." Return to welcome state. |
| `data/maps/` directory missing | Log warning, `ProjectContext.files.maps` stays empty. Editor still loads. |
| `data/props/` directory missing | Log warning, `ProjectContext.files.resources` stays empty. |
| `data/biomes/` directory missing | Log warning, `ProjectContext.files.biomes` stays empty. |
| Individual file parse error | Log warning with filename and error. Skip file. Other files still load. |
| File System Access API unavailable | Fallback to `<input webkitdirectory>`. Save uses download. |
