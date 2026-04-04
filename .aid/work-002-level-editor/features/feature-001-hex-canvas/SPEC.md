# Hex Canvas

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F1 | /aid-interview |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: hexCorners formula, biome type note, rotation type, zoom sign, color_variations note, grid toggle AC | /aid-specify review |
| 2026-04-04 | Added ghost grid rendering and empty-cell hover/interaction | code review |

## Source

- REQUIREMENTS.md §5 F1 (Hex Canvas)

## Description

The core hex grid canvas for the Map Editor tab. Renders a flat-top hex grid using axial coordinates (q, r) matching Farhaven's coordinate system. Each hex is colored by its biome using actual biome colors from loaded .tres files. Elevation is shown as a number overlay and brightness gradient. Cliff indicators highlight edges between hexes with elevation difference ≥ 2. Supports click-to-select, click-drag-to-paint, hover tooltips with hex data (coordinates, biome, elevation, resources, structure), zoom (scroll wheel), pan (middle-click or space+drag), and grid coordinate labels toggle.

**Note:** Undo/redo and keyboard shortcuts are in feature-008 (Command Infrastructure) — this feature depends on that foundation.

## User Stories

- As Andre, I want to see a visual hex grid colored by biome so that I can understand the map's shape and layout at a glance
- As Andre, I want to zoom and pan the canvas so that I can work on maps of any size
- As Andre, I want hover tooltips showing hex data so that I can inspect tiles without switching tools

## Priority

Must

## Acceptance Criteria

- [ ] Given a loaded map, when hexes are rendered, then each hex displays the correct biome color from the loaded .tres files
- [ ] Given a hex with elevation > 0, when rendered, then the elevation value is shown as an overlay and brightness is adjusted
- [ ] Given two adjacent hexes with elevation difference ≥ 2, when rendered, then the edge between them is highlighted as a cliff indicator
- [ ] Given a canvas with hexes, when scrolling the mouse wheel, then the canvas zooms in/out smoothly
- [ ] Given a canvas, when middle-click-dragging or space+dragging, then the canvas pans
- [ ] Given a hex on the canvas, when hovering over it, then a tooltip displays coordinates (q,r), biome name, elevation, resource list, and structure (if any)
- [ ] Given the coordinate labels toggle enabled, when viewing the canvas, then each hex displays its "q,r" label at center
- [ ] Given a loaded map, when rendered, then all empty hex positions adjacent to existing tiles are shown as faint ghost outlines
- [ ] Given a ghost hex, when hovering over it, then it highlights and shows a tooltip with coordinates
- [ ] Given a ghost hex, when a painting tool is used on it, then a new tile is created and the ghost grid updates to include the new tile's empty neighbors

---

## Technical Specification

### Data Model

```js
/**
 * MapMeta — top-level map metadata, maps to ch1.json root fields.
 */
const MapMeta = {
  chapter_id: "",   // string, e.g. "ch1"
  name: "",         // string, e.g. "Crash Landing"
  spawn: [0, 0]     // [q, r] axial coordinates
};

/**
 * TileData — per-hex data, stored as value in HexGrid.tiles.
 */
const TileData = {
  biome: "",        // string key, e.g. "forest", "crash_site" — matches map JSON format. (Game's HexTile uses Biome enum int internally; MapLoader translates string↔enum.)
  elevation: 0,     // integer 0-9
  structure: null,   // string | null, e.g. "workbench", "shelter"
  anomaly: null,     // string | null, e.g. "anomaly_ch1_001"
  resources: []      // Array<ResourceInstance>
};

/**
 * ResourceInstance — a single resource placed on a hex.
 * x, y are offsets within the hex. Valid range: -1.0 to 1.0 (storage). Random placement uses -0.8 to 0.8 (margin from hex edge).
 */
const ResourceInstance = {
  type: "",         // string, e.g. "wood", "stone"
  x: 0.0,          // float, position offset within hex
  y: 0.0,          // float, position offset within hex
  rotation: 0.0     // float, degrees (0-359). Matches map JSON "rotation" field; MapLoader reads as float.
};

/**
 * Camera — viewport state for pan and zoom.
 */
const Camera = {
  offsetX: 0,       // float, pixel offset for panning
  offsetY: 0,       // float, pixel offset for panning
  zoom: 1.0         // float, clamped to [0.2, 3.0]
};
```

**`HexGrid` class** — the in-memory map model.

```js
class HexGrid {
  constructor() {
    this.meta = { chapter_id: "", name: "", spawn: [0, 0] };
    this.tiles = new Map();  // Map<string, TileData>, key = "q,r"
  }

  getKey(q, r)          // returns `${q},${r}`
  getTile(q, r)         // returns TileData | undefined
  setTile(q, r, data)   // sets tile, fires onChange
  deleteTile(q, r)      // removes tile entirely, fires onChange
  hasTile(q, r)         // returns boolean
  getAllTiles()          // returns iterator of [key, TileData] entries
  clear()               // removes all tiles

  // Event hook — called on any mutation. HexCanvas subscribes to this.
  onChange = null;       // callback: () => void
}
```

### HexMath Module

Static utility functions mirroring the math from Farhaven's `hex_math.gd` (same axial coordinate system, flat-top orientation, same formulas). API names use JS camelCase; the game uses snake_case (`axial_to_world`/`world_to_axial`). All functions are pure, no side effects.

```js
const HEX_SIZE = 40; // default visual scale in pixels

const HexMath = {
  /**
   * Axial to pixel (flat-top hex).
   * x = HEX_SIZE * (3/2 * q)
   * y = HEX_SIZE * (sqrt(3)/2 * q + sqrt(3) * r)
   */
  axialToPixel(q, r) // returns { x, y }

  /**
   * Pixel to axial (flat-top hex). Uses fractional axial -> cube round.
   * fq = (2/3 * x) / HEX_SIZE
   * fr = (-1/3 * x + sqrt(3)/3 * y) / HEX_SIZE
   * Then cube round to nearest integer hex.
   */
  pixelToAxial(x, y) // returns { q, r }

  /**
   * Cube rounding for pixel-to-hex snapping.
   */
  cubeRound(fq, fr) // returns { q, r }

  /**
   * Returns the 6 neighbor coordinates of a hex.
   * Flat-top axial directions: [+1,0], [+1,-1], [0,-1], [-1,0], [-1,+1], [0,+1]
   */
  getNeighbors(q, r) // returns Array<{q, r}>

  /**
   * Hex distance (axial).
   */
  distance(q1, r1, q2, r2) // returns integer

  /**
   * Returns the 6 corner points of a flat-top hex at pixel position (cx, cy).
   * Corner i: cx + size * cos(60° * i * π/180), cy + size * sin(60° * i * π/180), for i = 0..5
   * (Angles in degrees converted to radians for Math.cos/Math.sin.)
   */
  hexCorners(cx, cy, size) // returns Array<{x, y}> length 6

  /**
   * Returns the edge index (0-5) between two adjacent hexes.
   * Used for cliff edge rendering.
   */
  getEdgeIndex(q1, r1, q2, r2) // returns 0-5 or -1 if not adjacent
};
```

### HexCanvas Class

Owns the `<canvas>` element, handles all rendering and mouse interaction.

```js
class HexCanvas {
  constructor(canvasElement, hexGrid) {
    this.canvas = canvasElement;
    this.ctx = canvasElement.getContext("2d");
    this.grid = hexGrid;
    this.camera = { offsetX: 0, offsetY: 0, zoom: 1.0 };
    this.selectedHex = null;    // { q, r } | null
    this.hoveredHex = null;     // { q, r } | null
    this.showCoordinates = false; // toggle for "q,r" labels
    this.isPanning = false;
    this.panStart = null;       // { x, y } pixel at pan start
    this.toolManager = null;    // set externally by ToolManager
  }

  // --- Lifecycle ---
  init()              // attach event listeners, subscribe to grid.onChange, initial render
  destroy()           // detach event listeners

  // --- Rendering ---
  render()            // full redraw: clear -> drawAllHexes -> drawOverlays -> drawTooltip
  requestRender()     // debounced render via requestAnimationFrame (coalesces multiple calls)

  // --- Drawing subroutines (called by render) ---
  drawHex(q, r, tile)           // draw hex polygon filled with biome color, adjusted for elevation
  drawElevationOverlay(q, r, tile)  // draw elevation number at hex center if elevation > 0
  drawCliffEdges(q, r, tile)    // for each neighbor, if |elevation diff| >= 2, draw thick edge
  drawSelection(q, r)           // draw highlight border on selected hex
  drawHoverHighlight(q, r)      // draw subtle highlight on hovered hex
  drawCoordinateLabel(q, r)     // draw "q,r" text at hex center (when showCoordinates enabled)
  drawGhostHex(q, r)            // draw faint outline for empty adjacent position
  drawSpawnMarker(q, r)         // draw spawn indicator icon/marker
  drawResourceIndicator(q, r, count) // draw resource count badge on hex
  drawStructureIcon(q, r, type) // draw structure indicator on hex

  // --- Coordinate transforms (account for camera) ---
  worldToScreen(wx, wy)   // applies camera offset + zoom: sx = wx * zoom + offsetX, ...
  screenToWorld(sx, sy)    // inverse of worldToScreen
  screenToHex(sx, sy)      // screenToWorld -> pixelToAxial

  // --- Mouse event handlers ---
  onMouseDown(event)       // left: select/tool, middle: start pan
  onMouseMove(event)       // update hoveredHex, forward to tool, handle pan drag
  onMouseUp(event)         // end pan, forward to tool
  onWheel(event)           // adjust camera.zoom by event.deltaY * -0.001, clamp [0.2, 3.0], re-render

  // --- Resize ---
  onResize()               // update canvas dimensions to fill parent, re-render
}
```

### Renderer Details

**Biome color mapping:** Biome colors come from loaded BiomeData (feature-007 loads .tres files). A lookup `Map<string, string>` maps biome name to hex color string. Fallback color for unknown biomes: `#888888`.

**Note on color_variations:** The game's BiomeData has a `color_variations` array (3 Color variants, hash-selected per tile for visual variety). The editor uses only the base `color` for simplicity — the editor canvas will look visually flatter than the in-game rendering. This is a deliberate simplification; implementing per-tile hash-based variation is a stretch goal.

**Elevation brightness adjustment:** For a base biome color RGB, multiply each channel by `(1 + elevation * 0.05)`, clamped to 255. Elevation 0 = base color, elevation 9 = 45% brighter.

**Cliff edge rendering:** For each of the 6 edges of a hex, check the neighbor. If the neighbor exists and `|tile.elevation - neighbor.elevation| >= 2`, draw that edge segment with a 3px wide stroke in `#8B4513` (brown) to indicate a cliff. Edge-to-neighbor mapping for flat-top hexes with corners at 0°,60°,...,300° clockwise: edge `i` → `DIRECTIONS[(6-i) % 6]`, i.e. lookup `[0, 5, 4, 3, 2, 1]`.

**Ghost grid rendering:** After rendering all existing tiles, compute the set of empty positions adjacent to any existing tile. For each ghost position, draw a faint hex outline (`rgba(255,255,255,0.08)` fill with `rgba(255,255,255,0.15)` 1px stroke). Ghost hexes participate in hover detection and tool interactions — painting on a ghost cell creates a real tile. The ghost set is recomputed on each render (it depends on the current tile set, which changes as tiles are added/removed).

**Tooltip:** A `<div>` element positioned near the cursor (offset +15px x, +15px y). Updated on `onMouseMove` when `hoveredHex` changes. Contents:

```
(q, r)
Biome: forest
Elevation: 3
Structure: workbench
Resources: wood ×2, stone ×1 (aggregated by type; if >5 types, show first 5 + "…and N more")
Anomaly: anomaly_ch1_001
```

Hidden when cursor leaves the canvas.

### Feature Flow

1. **Initialization:** `HexCanvas.init()` attaches mouse/wheel/resize listeners to the canvas. Subscribes to `hexGrid.onChange` to call `requestRender()`.
2. **Rendering cycle:** On any grid change or camera change, `requestRender()` schedules a single `render()` via `requestAnimationFrame`. `render()` clears the canvas, then: (a) computes the ghost set — all empty positions adjacent to existing tiles, (b) draws ghost hex outlines for each position in the ghost set, (c) iterates all tiles via `grid.getAllTiles()`, and for each tile calls `drawHex`, `drawElevationOverlay`, `drawCliffEdges`, and optionally `drawCoordinateLabel`, (d) draws selection highlight, spawn marker, hover highlight. Finally draws the tooltip div if a hex is hovered.
3. **Hover:** `onMouseMove` converts screen coordinates to hex via `screenToHex()`. If the result differs from `hoveredHex`, updates `hoveredHex`, positions the tooltip div, populates tooltip content from `grid.getTile(q, r)` (for real tiles) or minimal "(q,r) — empty" for ghost cells, and calls `requestRender()` for hover highlight. Ghost cells also highlight on hover.
4. **Selection:** `onMouseDown` (left button, no space held) converts to hex, sets `selectedHex = { q, r }`, calls `requestRender()`. If a `toolManager` is set, forwards the event to the active tool.
5. **Zoom:** `onWheel` adjusts `camera.zoom += event.deltaY * -0.001`, clamped to `[0.2, 3.0]`. Zoom is centered on the mouse cursor position: before zoom, record the world-space point under the cursor; after zoom, adjust `offsetX/Y` so that same world point stays under the cursor. Calls `requestRender()`.
6. **Pan:** `onMouseDown` (middle button, or left button with space held) sets `isPanning = true`, records `panStart = { x: event.clientX, y: event.clientY }`. `onMouseMove` while panning: `camera.offsetX += dx`, `camera.offsetY += dy`, updates `panStart`, calls `requestRender()`. `onMouseUp` sets `isPanning = false`.

### UI Specs

- The `<canvas>` element fills the main content area (CSS: `flex: 1; width: 100%; height: 100%`). On window resize, `onResize()` updates `canvas.width` and `canvas.height` to match the element's client dimensions.
- Coordinate labels toggle: a checkbox in the toolbar or sidebar. When checked, `showCoordinates = true` and each hex renders its "q,r" text at center in small font (10px, dark gray).
- Tooltip: a `<div id="hex-tooltip">` with `position: absolute; pointer-events: none; z-index: 100; background: rgba(0,0,0,0.85); color: white; padding: 8px; border-radius: 4px; font-size: 12px; white-space: pre-line;`. Hidden by default (`display: none`), shown on hover.
- Canvas background: `#1a1a2e` (dark blue-gray) for empty space outside the hex grid.

### Dependencies

- **feature-008 (Command Infrastructure):** HexCanvas does not create commands directly, but its mouse events are forwarded to the `ToolManager` (feature-002), which creates commands via the `CommandHistory` from feature-008.
- **feature-007 (File Discovery):** Biome color data comes from loaded .tres files. HexCanvas reads from a shared biome color map populated by feature-007.
- **feature-003 (Palette & Sidebar):** Selection events may update sidebar display. HexCanvas exposes `selectedHex` for the sidebar to read.
