# Requirements

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Initial interview started | /aid-interview |
| 2026-04-03 | Vision document ingested — §1-§5, §7, §10 populated | /aid-interview |
| 2026-04-03 | Interview complete — approved | /aid-interview |
| 2026-04-03 | Cross-reference: fixed ResourceDef fields (§4, F10), biome resource_table field names (§4, F11) | /aid-interview (cross-reference) |
| 2026-04-03 | Post-spec review: unified resource position range (-1.0 to 1.0 storage, -0.8 to 0.8 random), biome CRUD confirmed dynamic, app shell added to F007 | /aid-specify review |
| 2026-04-04 | Added ghost grid and empty-cell painting to F1/F2. New AC10 for map expansion. | code review |
| 2026-04-04 | Sub-hex grid system: resources use discrete (sq, sr) positions, structures use footprints, canvas shows sub-hex overlay for placement tools. Updated F1, F2, F5, F7, §9. | design change |

## 1. Objective

Build a **web-based game data editor** for Farhaven that serves as the single tool for authoring all game content data — maps, resource definitions, and biome definitions. It runs in a browser with zero install, reads and writes actual game data files directly (map JSON, resource `.tres`, biome `.tres`), and provides a WYSIWYG hex canvas for visual map authoring.

**Success looks like:** Content authors can create and edit complete chapter maps (200-300+ tiles) with varied biomes, elevations, resources, structures, anomalies, and spawn points — entirely through a visual interface — and save valid game data files that MapLoader consumes without modification.

**Inspired by:** The Iterate level editor (Feb 2026) — a self-contained HTML/JS editor for a Godot isometric game. Same philosophy: lightweight, visual, fast iteration. Different geometry (hex vs rectangular grid).

## 2. Problem Statement

The current ch1.json was hand-written and patched with Python scripts. It has 61 tiles. A real chapter map will have 200-300+ tiles. Editing JSON by hand is:

- **Error-prone** — wrong coordinates, typos in resource types, duplicate keys
- **Slow** — no visual feedback until you run the game
- **Opaque** — impossible to see the "shape" of the map from raw JSON

Adding a new resource to the game currently means editing multiple files by hand. The editor consolidates all game data authoring into one visual tool.

## 3. Users & Stakeholders

- **Andre Vianna** — project lead, primary map author
- **Lola Lovelace (AI agent)** — co-creator, may use editor for map generation/editing tasks

Internal tool only. No external users, no onboarding flow needed. UX can prioritize efficiency over discoverability.

## 4. Scope

### In Scope

**Three editor tabs, each managing a different layer of game data:**

1. **Map Editor** — hex canvas for painting biomes, placing resources/structures, setting elevation, managing spawn/anomaly markers. Import/export JSON in MapLoader format.
2. **Resource Editor** — CRUD for `data/resources/*.tres` ResourceDef files. Editable fields: `id` (StringName), `display_name` (String), `gather_time` (float), `gather_amount` (int), `tool_required` (StringName), `respawn_time` (float), `yield_type` (StringName), `tool_speed` (Dictionary), `max_stack` (int), `category` (StringName), `catalog_entry` (StringName), `catalog_category` (StringName), `placeholder_mesh_type` (StringName), `placeholder_params` (Dictionary), `placeholder_color` (Color), `placeholder_depleted_type` (StringName), `placeholder_depleted_params` (Dictionary), `placeholder_depleted_color` (Color). Read-only fields: `mesh`, `depleted_mesh`, `material` (Godot resource references — cannot be authored in a web editor).
3. **Biome Editor** — CRUD for `data/biomes/*.tres` BiomeData files (`biome_name`: String, `elevation_range`: Vector2i, `resource_table`: Array of `{type: String, chance: float, min_amount: int, max_amount: int, tool_required: String}`, `color`: Color, `color_variations`: Array[Color]).

**Cross-tab integration:** Creating a resource in the Resource Editor makes it available in the Map Editor palette. Editing a biome color updates the map canvas immediately.

**Quality of life:** Undo/redo (50+ steps), zoom/pan, grid coordinate toggle, biome statistics, keyboard shortcuts, flood fill for biome painting, export validation.

**File discovery:** User selects Farhaven project root → editor discovers maps, resources, biomes from standard paths.

### Out of Scope

- **Not a game preview** — no 3D rendering, no elevation meshes, no player movement. 2D top-down hex painter only.
- **Not a world generator** — no procedural generation. Maps are hand-crafted.
- **Not a Godot plugin** — standalone web app, independent of engine version.
- **Stretch goals deferred:** multi-chapter tabs, biome auto-paint, elevation contour lines, resource auto-scatter, template hex stamps, structure editor tab, catalog editor tab, dark mode.

## 5. Functional Requirements

### F1: Hex Canvas (Map Editor)
- Flat-top hex grid matching Farhaven's axial coordinate system (q, r)
- Each hex colored by biome using actual biome colors from .tres files
- Elevation shown as number overlay and/or brightness gradient (higher = lighter)
- Cliff indicators on edges between hexes with elevation difference ≥ 2
- **Ghost grid** — faint hex outlines rendered at all empty positions adjacent to existing tiles, providing visual affordance for map expansion. Ghost hexes respond to hover and tool interactions (painting a ghost cell creates a real tile).
- Click to select hex, click-drag to paint (biome brush, elevation brush)
- Hover tooltip showing hex coordinates, biome, elevation, resources, structure
- Zoom (scroll wheel) + pan (middle-click drag or space+drag)
- Grid coordinates toggle (show q,r labels on hexes)
- **Sub-hex grid overlay:** when a placement tool (resource, structure) is active, the hovered/selected hex shows its 19 sub-hex positions as a fine grid overlay. Occupied sub-hexes are highlighted. Available sub-hexes respond to clicks.

### F2: Painting Tools
- **Biome Brush** — paint biome type from palette. Painting on an empty (ghost) cell creates a new tile with the selected biome.
- **Elevation Brush** — set elevation 0-9, with +/- increment mode. Painting on an empty cell creates a new tile.
- **Resource Placer** — click sub-hex within a hex → add resource at that sub-hex position (sq, sr). Rotation auto-randomized (0-359).
- **Structure Placer** — place structures with footprint — each structure type occupies a defined set of sub-hex positions. The footprint is previewed on hover before placement. Structure list initially matches WALKABLE_STRUCTURES: workbench, storage_chest, campfire, shelter, torch. List defined once in editor config, easy to update as game adds structures.
- **Anomaly Marker** — place anomaly points with string ID
- **Spawn Marker** — set player spawn hex (exactly one per map)
- **Eraser** — remove resources, structures, anomalies from a hex
- **Delete Hex** — remove hex entirely from map
- **Flood Fill** — paint contiguous same-biome hexes (adapted from Iterate)
- **Note:** Biome Brush, Elevation Brush, Flood Fill, Eraser, Delete Hex, Spawn Marker, Anomaly Marker operate on main hexes only — unaffected by sub-hex system.

### F3: Palette / Sidebar
- Biome palette — swatches showing each biome's actual color + name (from loaded .tres files)
- Resource palette — all resource types (from loaded .tres files)
- Structure palette — all known structures
- Active tool indicator
- Biome statistics — tile count per biome, total tiles, resource count
- Palettes are live — changes in Resource/Biome Editor tabs update Map Editor palette immediately

### F4: Map Properties
- Chapter ID (string, e.g., "ch1")
- Chapter Name (display name, e.g., "Crash Landing")
- Spawn point — highlighted hex on canvas

### F5: Resource Placement Detail
- Each hex can have 0-N resources
- Each resource occupies a specific sub-hex position (sq, sr) within the hex. Valid positions: 19 sub-hexes (center + ring-1 + ring-2, distance ≤ 2 from center). Rotation (0-359 degrees) remains for visual orientation.
- Click resource in detail panel → highlight its sub-hex on canvas
- Visual indicator on hexes with multiple resources (count badge or stacked dots) — clicking opens a resource list for selecting/editing individual resources

### F6: Import / Export
- **Import:** Load existing chapter JSON → renders the full map
- **Export:** Save to JSON in exact MapLoader format — validated before save
- **New Map:** Start from blank canvas

### F7: Export Validation
- Exactly one spawn point exists
- No duplicate coordinates
- All biome names valid (match known biome list)
- All resource types valid (match known resource list)
- All structure types valid
- Elevation range 0-9
- Resource sub-hex positions (sq, sr) must be valid (hex distance from (0,0) ≤ 2)
- Structure footprints must reference valid sub-hex positions
- No two props may occupy the same sub-hex within a tile (resources and structures share the sub-hex space)

### F8: Undo/Redo
- Ctrl+Z / Ctrl+Shift+Z, at least 50 steps
- Covers all map editing operations

### F9: Keyboard Shortcuts
- B for biome, E for elevation, R for resource, S for structure, etc.

### F10: Resource Editor (Tab 2)
- List view of all resources with key properties
- Create new → generates .tres file with defaults
- Edit → form with all fields, live preview of mesh color swatch
- Delete → removes .tres file (with confirmation + validation no map uses it)
- Validation — warns if resource exists in map but missing .tres definition

### F11: Biome Editor (Tab 3)
- List view of all biomes with color swatch and resource summary
- Create new → generates .tres file with defaults
- Edit → form with all fields, color picker for base color and variations
- Resource table editor — add/remove rows, set `type` (dropdown from Resource Editor), `chance` (float), `min_amount` (int), `max_amount` (int), `tool_required` (StringName) per entry
- Delete → removes .tres file (with confirmation + validation no map tile uses it)
- Live preview — editing biome color updates Map Editor canvas in real-time

### F12: .tres File Parser
- Parse Godot .tres files on load, serialize back on save
- Preserve uid, ext_resource, script lines exactly (round-trip safe)
- Only edit property values under [resource]
- Handle complex Godot types: `Color(r, g, b, a)`, `Vector2i(x, y)`, `Array` (typed and untyped), `PackedStringArray`, nested structures in `resource_table` (array of dicts with type/chance/min/max). Each type needs dedicated parse/serialize logic.
- New files get generated uid (format: uid://c + 13 lowercase alphanumeric chars)
- Post-save validation: re-parse written file and compare to in-memory model

### F13: File Discovery
- User selects Farhaven project root folder on startup
- Auto-discovers: maps from `data/maps/*.json`, resources from `data/resources/*.tres`, biomes from `data/biomes/*.tres`
- Retains file handles via File System Access API for direct save

### F14: Unsaved Changes Protection
- `beforeunload` event warns if there are unsaved changes (any tab: map, resource, biome)
- Visual indicator (asterisk in tab title or dot on tab) when unsaved changes exist
- Optional: periodic auto-save via File System Access API (handle already retained — saving is cheap)

### F15: Import Validation
- On map JSON import: validate structure, check for required fields (tiles array, spawn), reject malformed data with clear error message
- On .tres import: validate format, check for required sections (`[gd_resource]`, `[resource]`), warn on unrecognized properties
- Graceful error handling: malformed files never crash the editor — show actionable error message with line/field info where possible

## 6. Non-Functional Requirements

- **Performance:** No hard tile limit. Map shape and size are defined implicitly by the array of hexes and how they connect — no `map_size` field needed. The editor should remain responsive at any practical map size.
- **Browser support:** Chrome/Edge primary (File System Access API). Firefox/Safari via download fallback.
- **Testing:** Internal tool — manual testing sufficient.
- **Portability:** Single HTML file, zero dependencies. Opens via `file://` or local HTTP server.

## 7. Constraints

- **Single HTML file** — embedded CSS + JS, zero dependencies, zero build step
- **Canvas 2D** for hex grid rendering (SVG too slow for 300+ hexes with hover/drag)
- **File System Access API** for direct file read/write (Chrome/Edge — Ctrl+S saves in place)
- **Fallback:** standard file download for browsers without File System Access (Firefox/Safari)
- **File location:** `tools/level-editor/index.html` in the Farhaven repo
- Not deployed — opened locally via `file://` or `python3 -m http.server`
- Hex math must match Farhaven's: axial coordinates, flat-top orientation, same formulas

## 8. Assumptions & Dependencies

### Assumptions
- Current game data file formats (map JSON, ResourceDef .tres, BiomeData .tres) remain stable
- Godot .tres text format remains stable (text-based, `[resource]` section with key-value pairs)
- Map shape/size is defined implicitly by the hex array — no explicit size field in the schema
- Chrome/Edge will continue supporting File System Access API
- The editor does not need to validate game logic (e.g., pathfinding reachability) — only data format correctness

### Dependencies
- `data/maps/*.json` — must match MapLoader's expected format (`scripts/hex/map_loader.gd`)
- `data/resources/*.tres` — uses ResourceDef script class (`scripts/data/resource_def.gd`)
- `data/biomes/*.tres` — uses BiomeData script class (`scripts/hex/biome_data.gd`)
- Hex math formulas must match `scripts/hex/hex_math.gd` (axial coords, flat-top, HEX_SIZE=3.0 in game units)

## 9. Acceptance Criteria

**AC1: Map round-trip** — Load ch1.json → make no changes → export → output is semantically equivalent to input (same tiles, same data, key order may differ).

**AC2: .tres round-trip** — Load a resource/biome .tres → make no changes → save → file preserves uid, ext_resource, script lines exactly. Property values match original.

**AC3: Map authoring** — Create a new map from blank canvas, paint 50+ hexes with biomes, set elevations, place resources and structures, set spawn → export valid JSON that MapLoader loads without errors.

**AC4: Resource CRUD** — Create a new ResourceDef, edit its fields, see it appear in map palette, place it on a hex, export. Delete a resource → confirmation dialog, in-use validation warns if any map references it.

**AC5: Biome CRUD** — Create a new BiomeData, set color, edit resource table, see map canvas update with new color in real-time. Delete → confirmation dialog, in-use validation warns if any map tile uses it.

**AC6: Export validation** — Attempting to export with missing spawn point, duplicate coordinates, invalid biome/resource/structure names, or out-of-range elevation/positions → shows clear error message, blocks save until fixed.

**AC7: Undo/redo** — Paint 10 hexes, undo all 10, redo 5 → canvas state is correct at each step. Minimum 50-step history.

**AC8: Unsaved changes protection** — Make changes to a map without saving, attempt to close/refresh the browser tab → browser warns about unsaved changes. Visual indicator (e.g., asterisk) visible while changes are pending. Save → indicator clears.

**AC9: Import validation** — Load a malformed JSON file (missing tiles, invalid structure) → editor shows clear error message, does not crash, does not load partial data. Load a malformed .tres file → editor shows clear error, does not crash.

**AC10: Map expansion** — Given an existing map, when hovering the canvas near map edges, then faint ghost hex outlines are visible at empty adjacent positions. When painting (biome brush or any tool) on a ghost cell, a new tile is created at that position and the ghost grid updates to include the new tile's empty neighbors.

**AC11: Sub-hex placement** — Given a resource tool active, when hovering a hex, then the 19 sub-hex positions are shown as a grid overlay. Clicking an available sub-hex places the resource there. Occupied sub-hexes show as blocked. Structure placement previews the footprint before confirming.

## 10. Priority

### Must Have (MVP)
- All F1-F15 functional requirements
- Three-tab editor (Map, Resource, Biome)
- Import/export ch1.json
- Export validation
- Undo/redo
- .tres read/write with round-trip safety

### Stretch Goals (Post-MVP)
- Multi-chapter tabs
- Biome auto-paint (zone-based)
- Elevation contour lines
- Resource auto-scatter (from biome resource_table probabilities)
- Template hex stamps
- Structure editor tab
- Catalog editor tab
- Dark mode
