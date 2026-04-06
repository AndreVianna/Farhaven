# task-012b: Tool Selector and Map List

**Type:** IMPLEMENT

**Source:** feature-003-palette-sidebar (partial) -> delivery-003

**Depends on:** task-008 (HexCanvas), task-009 (ToolManager), task-010 (placement tools)

**Scope:**

### Tool Selector Sidebar
- Implement a sidebar panel in the Map Editor tab with:
  - **Tool buttons** — one per tool type (Biome, Elevation, Resource, Structure, Anomaly, Spawn, Eraser, Delete Hex, Flood Fill). Active tool highlighted. Click to activate. Matches keyboard shortcuts (B, E, R, S, A, P, X, D, F).
  - **Biome palette** — grid of swatches showing each biome's color + name, populated from `ProjectContext.files.biomes`. Click a swatch to activate biome brush with that value.
  - **Resource palette** — list of resource types from `ProjectContext.files.resources`. Click to activate resource placer with that type.
  - **Structure palette** — list of structure types from `STRUCTURE_FOOTPRINTS` keys. Click to activate structure placer with that type. Show footprint size (e.g., "2 cells").
  - **Elevation controls** — mode toggle (SET / INCREMENT), value selector (0-9 for SET, +1/-1 for INCREMENT).
  - **Active tool indicator** — shows current tool name and selected value.
- Wire palette clicks to `toolManager.setTool(type, value)`.
- Palettes update dynamically when resources/biomes are added/removed.

### Map List
- Implement a map dropdown at the top of the sidebar or toolbar:
  - Lists all maps in `ProjectContext.files.maps` by filename.
  - Shows currently active map name.
  - Selecting a different map loads it into `hexGrid` via `loadMapIntoGrid()`.
  - Confirms if there are unsaved changes before switching.
- If only one map exists, show it as a label instead of dropdown.

### HTML Structure
- Add sidebar markup to `index.html` inside the `#tab-map` panel.
- Sidebar CSS: fixed width (~250px), scrollable, dark theme consistent with existing styles.

**Acceptance Criteria:**
- [ ] Tool buttons visible in sidebar, active tool highlighted
- [ ] Clicking a biome swatch activates biome brush with that biome value
- [ ] Clicking a resource type activates resource placer with that type
- [ ] Clicking a structure type activates structure placer with that type
- [ ] Elevation mode toggle and value selector work correctly
- [ ] Active tool indicator updates on tool change (click or keyboard)
- [ ] Palette entries populated from ProjectContext data (biomes show colors, resources show names)
- [ ] Map dropdown lists all discovered maps
- [ ] Selecting a map switches the active map on canvas
- [ ] Unsaved changes prompt appears when switching maps with dirty state
- [ ] Keyboard shortcuts (B, E, R, S, etc.) still work and update sidebar highlight
