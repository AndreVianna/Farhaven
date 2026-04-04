# task-008: HexCanvas Rendering and Interaction

**Type:** IMPLEMENT

**Source:** feature-001-hex-canvas -> delivery-002

**Depends on:** task-007, task-002

**Scope:**
- Implement `HexCanvas` class owning the `<canvas>` element and Canvas2D context
- Implement rendering pipeline:
  - `render()` -- full redraw: clear canvas with `#1a1a2e` background, iterate all tiles, draw each
  - `requestRender()` -- debounced via `requestAnimationFrame`
  - `drawHex(q, r, tile)` -- hex polygon filled with biome color (lookup from loaded BiomeData .tres)
  - `drawElevationOverlay(q, r, tile)` -- elevation number at center if > 0, brightness adjustment `(1 + elevation * 0.05)`
  - `drawCliffEdges(q, r, tile)` -- 3px brown `#8B4513` stroke on edges with neighbor elevation diff >= 2
  - `drawCoordinateLabel(q, r)` -- "q,r" text when `showCoordinates` is true
  - `drawSpawnMarker(q, r)` -- spawn indicator
  - `drawResourceIndicator(q, r, count)` -- resource count badge
  - `drawStructureIcon(q, r, type)` -- structure indicator
  - `drawSelection(q, r)`, `drawHoverHighlight(q, r)` -- visual feedback
- Implement biome color mapping: `Map<string, string>` from biome name to hex color, fallback `#888888`
- Implement coordinate transforms: `worldToScreen()`, `screenToWorld()`, `screenToHex()`
- Implement mouse interaction:
  - `onMouseDown` -- left click: select hex + forward to toolManager; middle/space+left: start pan
  - `onMouseMove` -- update hoveredHex, position tooltip, forward to tool, handle pan drag
  - `onMouseUp` -- end pan, forward to tool
  - `onWheel` -- zoom centered on cursor: record world point, adjust zoom, recompute offsets
- Implement tooltip: `#hex-tooltip` div positioned near cursor, showing coords/biome/elevation/resources/structure/anomaly
- Implement resize handler: update canvas dimensions to fill parent
- Implement `showCoordinates` toggle (checkbox in toolbar)
- Subscribe to `hexGrid.onChange` for automatic re-rendering

**Acceptance Criteria:**
- [ ] Loaded map renders all hexes with correct biome colors from .tres data
- [ ] Elevation > 0 shows as number overlay with brightness adjustment
- [ ] Cliff edges (elevation diff >= 2) render with brown stroke
- [ ] Scroll wheel zooms in/out, clamped to [0.2, 3.0], centered on cursor
- [ ] Middle-click drag and space+left-drag pan the canvas
- [ ] Hovering a hex shows tooltip with coordinates, biome, elevation, resources, structure, anomaly
- [ ] Coordinate labels toggle shows/hides "q,r" text on each hex
- [ ] Canvas fills its container and resizes correctly
- [ ] Spawn marker renders at the spawn hex
- [ ] Resource count badges and structure indicators visible on hexes
