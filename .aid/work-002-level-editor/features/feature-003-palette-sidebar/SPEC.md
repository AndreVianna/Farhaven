# Palette & Sidebar

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F3, F4 | /aid-interview |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: biome key clarification, STRUCTURE_LIST source, hasSpawn, spawn read-only note | /aid-specify review |
| 2026-04-06 | Added Hex Inspector panel to right sidebar: map stats (total hexes, q/r range, biome distribution), hex details on hover (coordinates, biome with swatch, elevation), prop editor (editable fields for sq/sr/rotation, delete button). Replaces floating PropDetailPanel from feature-002. | design change |

## Source

- REQUIREMENTS.md §5 F3 (Palette / Sidebar), F4 (Map Properties)

## Description

The sidebar panel showing biome palette (color swatches from .tres files), resource palette (all PropDef types), structure palette, active tool indicator, and biome statistics (tile count per biome, total tiles, resource count). Also includes map properties editing (chapter ID, chapter name, spawn point highlight). Palettes are live — changes in Resource/Biome Editor tabs update the Map Editor palette immediately.

## User Stories

- As Andre, I want to see biome swatches with actual game colors so that I can pick biomes visually
- As Andre, I want to see resource and structure lists populated from game data so that I only place valid types
- As Andre, I want biome statistics so that I can balance the map composition
- As Andre, I want to set the chapter ID and name so that export metadata is correct

## Priority

Must

## Acceptance Criteria

- [ ] Given loaded biome .tres files, when the palette renders, then each biome shows its actual color swatch and name
- [ ] Given a new resource created in the Resource Editor tab, when switching to Map Editor, then the resource appears in the resource palette
- [ ] Given a map with hexes, when viewing statistics, then tile count per biome and total tile/resource counts are accurate
- [ ] Given map properties, when editing chapter ID/name, then the values are included in exported JSON

---

## Technical Specification

### Data Model

**Palette data sources:**

```js
/**
 * BiomeEntry — one entry in the biome palette.
 * Populated from loaded BiomeData .tres files (via feature-007).
 */
const BiomeEntry = {
  name: "",         // string, lowercased biome_name from .tres (e.g. "forest", "crash_site"). This is the KEY used in map tile `biome` fields. The .tres has display name (e.g. "Forest"); the editor lowercases it for the key.
  color: "#000000"  // hex color string, converted from the BiomeData.color in the .tres file.
                    // This is the ONLY color used — both for the palette swatch and the map canvas hex fill.
};

/**
 * ResourceEntry — one entry in the resource palette.
 * Populated from loaded PropDef .tres files (via feature-007).
 */
const ResourceEntry = {
  name: "",         // string, e.g. "wood", "stone", "fiber"
  color: "#000000"  // placeholder color for the palette dot
};

/**
 * StructureEntry — one entry in the structure palette.
 * Must match WALKABLE_STRUCTURES from hex_grid.gd (scripts/hex/hex_grid.gd).
 * Ordered alphabetically for consistent UI display.
 * To add a new structure: add it here and in the game's hex_grid.gd WALKABLE_STRUCTURES const.
 * Future: could be loaded from a config file or parsed from hex_grid.gd.
 */
const STRUCTURE_LIST = [
  "campfire",
  "shelter",
  "storage_chest",
  "torch",
  "workbench"
];

/**
 * MapStatistics — computed summary of the current map.
 */
const MapStatistics = {
  totalTiles: 0,
  totalResources: 0,
  biomeCounts: {},   // Map<string, number> — biome name -> tile count
  structureCounts: {}, // Map<string, number> — structure name -> count
  hasSpawn: false
};
```

### Sidebar Class

Top-level class managing the sidebar DOM and its sub-components.

```js
class Sidebar {
  constructor(containerElement, hexGrid, toolManager) {
    this.container = containerElement;
    this.grid = hexGrid;
    this.toolManager = toolManager;

    this.biomePalette = new BiomePalette(this, toolManager);
    this.resourcePalette = new ResourcePalette(this, toolManager);
    this.structurePalette = new StructurePalette(this, toolManager);
    this.mapProperties = new MapProperties(this, hexGrid);
    this.statistics = new Statistics(this, hexGrid);
  }

  init()               // build DOM structure, init all sub-components
  render()             // re-render all sub-components
  updatePalettes(biomes, resources)  // called when .tres data is loaded/changed
  updateStatistics()   // recompute and re-render statistics
}
```

### Sub-Components

**`BiomePalette`:**

```js
class BiomePalette {
  constructor(sidebar, toolManager) {
    this.sidebar = sidebar;
    this.toolManager = toolManager;
    this.biomes = [];       // Array<BiomeEntry>
    this.selectedBiome = null;  // string, biome name
  }

  setBiomes(biomeEntries)  // update biome list, re-render
  render(container)         // render biome swatches into container element
  onBiomeClick(biomeName)  // sets toolManager.setTool(ToolType.BIOME, biomeName)
  getSelectedBiome()       // returns selectedBiome string
}
```

**`ResourcePalette`:**

```js
class ResourcePalette {
  constructor(sidebar, toolManager) {
    this.sidebar = sidebar;
    this.toolManager = toolManager;
    this.resources = [];      // Array<ResourceEntry>
    this.selectedResource = null;
  }

  setResources(resourceEntries)  // update resource list, re-render
  render(container)
  onResourceClick(resourceName)  // sets toolManager.setTool(ToolType.RESOURCE, resourceName)
}
```

**`StructurePalette`:**

```js
class StructurePalette {
  constructor(sidebar, toolManager) {
    this.sidebar = sidebar;
    this.toolManager = toolManager;
    this.structures = [...STRUCTURE_LIST];
    this.selectedStructure = null;
  }

  render(container)
  onStructureClick(structureName) // sets toolManager.setTool(ToolType.STRUCTURE, structureName)
}
```

**`MapProperties`:**

```js
class MapProperties {
  constructor(sidebar, hexGrid) {
    this.sidebar = sidebar;
    this.grid = hexGrid;
  }

  render(container)     // render chapter_id input, name input, spawn display
  onChapterIdChange(value)   // grid.meta.chapter_id = value
  onNameChange(value)        // grid.meta.name = value
  getSpawnDisplay()          // returns formatted spawn coordinates string (read-only display; spawn is set via Spawn Marker tool in feature-002, not via text input)
}
```

**`Statistics`:**

```js
class Statistics {
  constructor(sidebar, hexGrid) {
    this.sidebar = sidebar;
    this.grid = hexGrid;
    this.stats = { totalTiles: 0, totalResources: 0, biomeCounts: {}, structureCounts: {}, hasSpawn: false };
  }

  compute()   // iterate grid.getAllTiles(), populate this.stats
  render(container)  // render stats table into container
}
```

### Feature Flow

1. **On project load** (feature-007 completes loading .tres files): `sidebar.updatePalettes(biomes, resources)` is called. `BiomePalette.setBiomes()` receives the array of `BiomeEntry` objects parsed from BiomeData .tres files. `ResourcePalette.setResources()` receives `ResourceEntry` objects parsed from PropDef .tres files. Both palettes re-render.

2. **Clicking a palette item:**
   - User clicks a biome swatch (e.g., "forest"): `BiomePalette.onBiomeClick("forest")` calls `toolManager.setTool(ToolType.BIOME, "forest")`. The swatch gets a highlight border. Other palette selections (resource, structure) are deselected.
   - User clicks a resource (e.g., "wood"): `ResourcePalette.onResourceClick("wood")` calls `toolManager.setTool(ToolType.RESOURCE, "wood")`. Resource item highlighted, biome/structure deselected.
   - User clicks a structure (e.g., "workbench"): `StructurePalette.onStructureClick("workbench")` calls `toolManager.setTool(ToolType.STRUCTURE, "workbench")`.
   - Only one item across all palettes is selected at a time.

3. **Active tool indicator:** The sidebar section header for the active tool's category gets a highlight style (e.g., "Biomes" header highlighted when biome brush is active). A small tool icon or label shows the current tool type.

4. **Statistics update:** `sidebar.updateStatistics()` is called whenever `hexGrid.onChange` fires. `Statistics.compute()` iterates all tiles:
   - `totalTiles`: count of entries in `grid.tiles`.
   - `totalResources`: sum of `tile.resources.length` for all tiles.
   - `biomeCounts`: for each tile, increment `biomeCounts[tile.biome]`.
   - `structureCounts`: for each tile with a non-null structure, increment `structureCounts[tile.structure]`.
   - `hasSpawn`: `grid.meta.spawn !== null && grid.meta.spawn[0] !== undefined` — spawn is `[q, r]` when set, `null` when no spawn has been placed on a new empty map.
   Then `Statistics.render()` updates the DOM table.

5. **Map properties:** `MapProperties.render()` creates two text inputs bound to `grid.meta.chapter_id` and `grid.meta.name`. On `input` event, the values are updated directly on `grid.meta`. A read-only display shows the current spawn coordinates. Changes to map properties mark the file as unsaved (feature-009).

6. **Live palette updates:** When a biome color is changed in the Biome Editor tab (feature-006) or a new resource is added in the Resource Editor tab (feature-005), the editor fires a custom event or callback. `Sidebar.updatePalettes()` is called with the updated data, and palettes re-render immediately so the Map Editor always shows current data.

### UI Specs

**Sidebar layout** (top to bottom):

```
+---------------------------+
| MAP PROPERTIES            |
| Chapter ID: [___________] |
| Name:       [___________] |
| Spawn:      (0, 0)        |
+---------------------------+
| TOOLS                     |
| [Eraser] [Delete] [Fill]  |
| [Spawn] [Anomaly]         |
+---------------------------+
| BIOMES          [active]  |
| [##] forest               |
| [##] desert               |
| [##] crash_site           |
| ...                       |
+---------------------------+
| ELEVATION                 |
| Mode: [SET|INCREMENT]     |
| Value: [0-9 slider]       |
+---------------------------+
| RESOURCES                 |
| * wood                    |
| * stone                   |
| * fiber                   |
| ...                       |
+---------------------------+
| STRUCTURES                |
| > shelter                 |
| > workbench               |
| > campfire                |
| ...                       |
+---------------------------+
| STATISTICS                |
| Total tiles:    142       |
| Total resources: 87      |
|                           |
| forest:          45 (32%) |
| desert:          30 (21%) |
| crash_site:       3  (2%)|
| ...                       |
+---------------------------+
```

**CSS specs:**
- Sidebar: `width: 300px; height: 100vh; overflow-y: auto; background: #1e1e2e; color: #cdd6f4; border-left: 1px solid #45475a; padding: 12px; box-sizing: border-box;`
- Section headers: `font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: #a6adc8; margin: 16px 0 8px 0; padding-bottom: 4px; border-bottom: 1px solid #313244;`
- Active section header: `color: #89b4fa;` (blue highlight)
- Biome swatches: `display: inline-block; width: 24px; height: 24px; border-radius: 4px; margin: 2px; cursor: pointer; border: 2px solid transparent;`
- Selected swatch: `border-color: #f5c2e7;` (pink highlight border)
- Resource/structure items: `padding: 4px 8px; cursor: pointer; border-radius: 4px;`
- Selected item: `background: #313244;`
- Resource color dot: `display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 6px;`
- Text inputs: `width: 100%; background: #313244; border: 1px solid #45475a; color: #cdd6f4; padding: 4px 8px; border-radius: 4px;`
- Statistics table: `width: 100%; font-size: 12px; font-family: monospace;` — alternating row backgrounds for readability.

### Hex Inspector (Right Sidebar)

The right sidebar (`<aside id="sidebar">`) serves as the Hex Inspector panel with three sections:

**Map Stats (top):** Displays total hex count, q range (min-max), r range (min-max), and biome distribution (sorted by count descending, with color swatches). Updated on map load and map switch.

**Hex Details (middle):** Shows coordinates, biome (with color swatch), and elevation for the currently hovered hex. Updated on every mousemove via `HexCanvas.onHexHover` callback. Shows "Hover a hex to inspect" when no hex is hovered.

**Prop Editor (bottom):** Lists all props on the hovered hex with editable fields (sq, sr, rotation for resources) and delete buttons. Uses `EditPropCommand`/`DeletePropCommand` for undo/redo support. Auto-updates on hover (no click required). Replaces the former floating `PropDetailPanel`.

```js
class HexInspector {
  constructor(container, grid, commandHistory, biomeColorMap)
  updateMapStats()           // recompute and render map-level statistics
  updateHex(hex, subHex)     // update hex info and prop editor for hovered hex
}
```

### Dependencies

- **feature-001 (Hex Canvas):** Sidebar reads `hexCanvas.selectedHex` to show selected hex info. Biome colors from the palette are used by the canvas renderer.
- **feature-002 (Painting Tools):** Palette clicks call `toolManager.setTool()`. The sidebar reflects `toolManager.activeToolType` for the active indicator.
- **feature-005 (Resource Editor):** Resource palette is updated when resources are added/edited in the Resource Editor tab.
- **feature-006 (Biome Editor):** Biome palette is updated when biome colors change in the Biome Editor tab.
- **feature-007 (File Discovery):** Initial palette data comes from loaded .tres files.
- **feature-009 (Unsaved Changes):** Map property edits mark the map as having unsaved changes.
