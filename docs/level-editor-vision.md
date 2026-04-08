# Farhaven Level Editor — Vision Document

*Draft for AID Interview input — work-002*

---

## What Is This

A **web-based game data editor** for Farhaven. Runs in a browser, zero install. Reads and writes the actual game data files directly — map JSON, resource `.tres`, biome `.tres`. Not just a map painter: it's the **single tool for authoring all game content data**.

**Inspired by:** The Iterate level editor we built in February 2026 — a self-contained HTML/JS editor that exported CSV for a Godot isometric game. Same philosophy: lightweight, visual, fast iteration. Different geometry (hex vs rectangular grid).

---

## Why We Need It

The current ch1.json was hand-written and patched with Python scripts. It has 61 tiles. A real chapter map will have 200-300+ tiles with varied biomes, elevations, resources, structures, anomalies, and spawn points. Editing JSON by hand is:

- **Error-prone** — wrong coordinates, typos in resource types, duplicate keys
- **Slow** — no visual feedback until you run the game
- **Opaque** — impossible to see the "shape" of the map from raw JSON

The editor gives us a **WYSIWYG canvas** where we paint hexes, set properties, place resources, and save valid game data files directly. It also manages the resource and biome definitions themselves — adding a new resource to the game means opening the editor, not editing 10 files by hand.

---

## Editor Modes

The editor has **three tabs**, each managing a different layer of game data:

1. **Map Editor** — paint hexes, place resources/structures, set elevation
2. **Resource Editor** — define resource types (reads/writes `data/resources/*.tres`)
3. **Biome Editor** — define biomes and their resource tables (reads/writes `data/biomes/*.tres`)

All three are interconnected: creating a resource in the Resource Editor makes it available in the Map Editor palette. Editing a biome's color in the Biome Editor updates the map canvas immediately.

---

## Tab 1: Map Editor

### 1. Hex Canvas (The Map)

- **Flat-top hex grid** matching Farhaven's coordinate system (axial: q,r)
- **Visual rendering** — each hex colored by biome (using the actual biome colors from .tres files)
- **Elevation** shown as a number overlay and/or brightness gradient (higher = lighter)
- **Cliff indicators** — edges between hexes with elevation difference ≥ 2 highlighted (shows JUMP/DROP/BLOCKED thresholds)
- **Click to select**, click-drag to paint (biome brush, elevation brush)
- **Hover tooltip** showing hex coordinates, biome, elevation, resources, structure

### 2. Painting Tools

| Tool | What It Does |
|------|-------------|
| **Biome Brush** | Paint biome type: crash_site, grassland, forest, rocky, water (+ future biomes) |
| **Elevation Brush** | Set elevation 0-9, with +/- increment mode |
| **Resource Placer** | Click hex → add resource (type dropdown, position auto-randomized within hex) |
| **Structure Placer** | Place structures: workbench, storage_chest, campfire, shelter, torch, wall |
| **Anomaly Marker** | Place anomaly points with string ID |
| **Spawn Marker** | Set player spawn hex (exactly one per map) |
| **Eraser** | Remove resources, structures, anomalies from a hex |
| **Delete Hex** | Remove hex entirely from the map |

### 3. Palette / Sidebar

- **Biome palette** — swatches showing each biome's actual color + name (populated from loaded biome .tres files)
- **Resource palette** — list of all resource types (populated from loaded resource .tres files)
- **Structure palette** — all known structures
- **Active tool indicator** — clear visual of what you're painting

Palettes are **live** — adding a resource or biome in their respective editor tabs updates the map palette immediately.

### 4. Map Properties

- **Chapter ID** — string (e.g., "ch1", "ch2")
- **Chapter Name** — display name (e.g., "Crash Landing")
- **Spawn point** — highlighted hex on canvas

### 5. Resource Placement

Each hex can have 0-N resources. Each resource has:
- `type` — from resource palette
- `x`, `y` — offset within hex (-1.0 to 1.0 range), auto-randomized on placement
- `rotation` — 0-359, auto-randomized

The editor auto-randomizes position/rotation on placement but allows manual adjustment via a resource detail panel (click resource → edit x, y, rotation).

### 6. Import / Export

- **Import:** Load existing ch1.json (or any chapter JSON) → renders the full map
- **Export:** Save to JSON in the exact format MapLoader expects — validated before save
- **New Map:** Start from blank canvas

### 7. Validation

On export, check:
- Exactly one spawn point exists
- No duplicate coordinates
- All biome names are valid (match known biome list)
- All resource types are valid (match known resource list)
- All structure types are valid
- Elevation range 0-9
- Resource positions within valid range

### 8. Quality of Life

- **Undo/Redo** (Ctrl+Z / Ctrl+Shift+Z) — at least 50 steps (like Iterate)
- **Zoom** (scroll wheel) + pan (middle-click drag or space+drag)
- **Grid coordinates** toggle — show q,r labels on hexes
- **Biome statistics** — sidebar showing tile count per biome, total tiles, resource count
- **Keyboard shortcuts** — B for biome, E for elevation, R for resource, S for structure, etc.

---

## Tab 2: Resource Editor

Manages `data/resources/*.tres` files. Each resource is a `PropDef` with:

| Field | Type | Example |
|-------|------|---------|
| resource_name | String | "Wood" |
| category | String | "flora" / "mineral" / "fauna" / "anomaly" |
| gather_time | float | 1.5 |
| tool_required | String | "" or "stone_pickaxe" |
| respawn_time | float | 30.0 |
| max_stack | int | 99 |
| mesh_type | String | "cylinder" / "cube" / "sphere" |
| mesh_color | Color | Color(0.55, 0.35, 0.15, 1) |
| label_color | Color | Color(0.2, 0.8, 0.2, 1) |
| catalog_description | String | "A sturdy hardwood..." |
| discovered_by_default | bool | false |

### Features
- **List view** of all resources with key properties
- **Create new** → generates a new .tres file with defaults
- **Edit** → form with all fields, live preview of mesh color swatch
- **Delete** → removes .tres file (with confirmation + validation that no map uses it)
- **Validation** — warns if a resource exists in a map but is missing its .tres definition

---

## Tab 3: Biome Editor

Manages `data/biomes/*.tres` files. Each biome is a `BiomeData` with:

| Field | Type | Example |
|-------|------|---------|
| biome_name | String | "Forest" |
| elevation_range | Vector2i | (0, 9) |
| resource_table | Array | [{type, chance, min, max}] |
| color | Color | Color(0.15, 0.5, 0.15, 1) |
| color_variations | Array[Color] | [...] |

### Features
- **List view** of all biomes with color swatch and resource summary
- **Create new** → generates a new .tres file with defaults
- **Edit** → form with all fields, including:
  - **Color picker** for base color and variations
  - **Resource table editor** — add/remove resource rows, set chance/min/max per resource (dropdown populated from Resource Editor)
- **Delete** → removes .tres file (with confirmation + validation that no map tile uses it)
- **Live preview** — editing biome color updates the Map Editor canvas in real-time

---

## What It Is NOT

- **Not a game preview** — no 3D rendering, no elevation meshes, no player movement. It's a 2D top-down hex painter.
- **Not a world generator** — no procedural generation. Maps are hand-crafted. (The GDD mentions procedural, but our current design uses hand-crafted maps via MapLoader.)
- **Not a Godot plugin** — standalone web app, like the Iterate editor. Keeps the tool independent of engine version.

---

## Technical Approach

### Stack
- **Single HTML file** with embedded CSS + JS (like Iterate — zero dependencies, zero build step)
- **Canvas 2D** for rendering the hex grid (SVG is too slow for 300+ hexes with hover/drag)
- **File System Access API** for direct file read/write (Chrome/Edge — Ctrl+S saves in place, no download dialog)
- **Fallback:** standard download for browsers without File System Access (Firefox/Safari)

### Hex Math
- **Axial coordinates** (q, r) — same as Farhaven's HexMath
- **Flat-top orientation** — hex_to_pixel: `x = HEX_SIZE * 3/2 * q`, `y = HEX_SIZE * (√3/2 * q + √3 * r)`
- **Pixel-to-hex** for click detection: reverse the formula, cube-round to nearest hex
- **HEX_SIZE** for the editor is just a visual scale (e.g., 40px), not the game's 3.0 units

### Data Model (in-memory)
```javascript
{
  chapter_id: "ch1",
  name: "Crash Landing",
  spawn: [0, 0],
  tiles: {
    "0,0": {
      biome: "crash_site",
      elevation: 0,
      structure: "",        // optional
      anomaly: "",          // optional
      resources: [
        { type: "wood", x: 0.35, y: -0.45, rotation: 18 }
      ]
    }
  }
}
```

Identical to ch1.json — the editor IS the JSON, with a visual skin.

### .tres Parser

Godot .tres files are plain text with a deterministic format:

```
[gd_resource type="Resource" script_class="BiomeData" load_steps=2 format=3 uid="uid://cforest000001"]
[ext_resource type="Script" path="res://scripts/hex/biome_data.gd" id="1_biome"]
[resource]
script = ExtResource("1_biome")
biome_name = "Forest"
elevation_range = Vector2i(0, 9)
color = Color(0.15, 0.5, 0.15, 1)
```

The editor parses these on load and serializes back on save. Key rules:
- Preserve `uid`, `ext_resource`, `script` lines exactly as-is (round-trip safe)
- Only edit the property values under `[resource]`
- New files get a generated `uid` (format: `uid://c` + 13 lowercase alphanumeric chars)
- **Validation:** after every save, re-parse the written file and compare to in-memory model. If mismatch, warn and don't close.

### File Discovery

On startup, the editor asks the user to select the **Farhaven project root** (the folder containing `data/`, `scripts/`, `project.godot`). From there:
- Maps: `data/maps/*.json`
- Resources: `data/resources/*.tres`
- Biomes: `data/biomes/*.tres`

All file handles are retained via File System Access API for direct save.

---

## Iterate Lessons (What Worked, What to Keep)

From the Iterate editor (Feb 14, 2026):

✅ **Single HTML file** — no build, no deps, just open it
✅ **Undo/redo with 50-step history** — essential for painting
✅ **Tabs for different concerns** (terrain/objects/entities → biome/resources/structures)
✅ **Keyboard shortcuts** — fast mode switching
✅ **Visual validation** (red highlight on invalid placement)
✅ **Flood fill** — useful for biome painting (adapt for hex neighbors)
✅ **Grid resize** — add/remove hexes from edges (adapt: grow map by adding ring of hexes)
✅ **Export validation** before save
✅ **Statistics panel** — tile counts, entity counts

🔄 **Adapted:**
- CSV → JSON (Farhaven uses JSON, not CSV)
- Rectangle grid → Hex grid
- 3-layer system → per-hex properties (biome, elevation, resources, structure)
- Isometric view → top-down flat hex view

---

## Stretch Goals (Post-MVP)

- **Multi-chapter** — open multiple map files in tabs
- **Biome auto-paint** — define biome "zones" and auto-assign based on distance from center
- **Elevation contour lines** — connect same-elevation hexes visually
- **Resource auto-scatter** — use biome resource_table probabilities to auto-populate a hex region
- **Template hexes** — save/load hex "stamps" (e.g., a rocky outcrop pattern)
- **Structure editor tab** — manage structure types (currently hardcoded, low priority)
- **Catalog editor tab** — manage catalog entries and descriptions
- **Dark mode** 🌙

---

## File Location

The editor lives in `tools/level-editor/index.html` in the Farhaven repo. Not deployed — opened locally via `file://` or a simple `python3 -m http.server`.

---

*This document is input for the AID Interview phase (work-002). The interview will refine requirements and produce the formal spec.*
