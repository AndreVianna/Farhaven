# task-019: Palette and Sidebar -- Palettes, Statistics, Map Properties

**Type:** IMPLEMENT

**Source:** feature-003-palette-sidebar -> delivery-004

**Depends on:** task-008, task-009, task-012, task-014, task-018

**Scope:**
- Implement `Sidebar` class managing the sidebar DOM container and all sub-components
- Implement `BiomePalette`:
  - Render biome swatches (24x24 rounded squares) with biome colors from loaded .tres data
  - Click swatch -> `toolManager.setTool(ToolType.BIOME, biomeName)`
  - Selected swatch highlight (pink border)
  - Mutual exclusion: selecting a biome deselects resource/structure selections
- Implement `ResourcePalette`:
  - Render resource list items with placeholder_color dots (8px circles)
  - Click -> `toolManager.setTool(ToolType.RESOURCE, resourceName)`
  - Selected item highlight
- Implement `StructurePalette`:
  - Render STRUCTURE_LIST items (campfire, shelter, storage_chest, torch, workbench)
  - Click -> `toolManager.setTool(ToolType.STRUCTURE, structureName)`
  - Selected item highlight
- Implement `MapProperties`:
  - chapter_id text input bound to `hexGrid.meta.chapter_id`
  - name text input bound to `hexGrid.meta.name`
  - Spawn display (read-only, formatted coordinates)
  - Input changes mark map as dirty via DirtyTracker
- Implement `Statistics`:
  - `compute()` iterates all tiles: totalTiles, totalResources, biomeCounts, structureCounts, hasSpawn
  - Render stats table with percentages
  - Auto-update on `hexGrid.onChange`
- Implement elevation controls in sidebar: mode toggle (SET/INCREMENT), value slider (0-9), delta toggle (+1/-1)
- Implement tool buttons row: Eraser, Delete Hex, Flood Fill, Spawn, Anomaly
- Implement active tool indicator: highlight section header for active tool category
- Implement live palette updates: listen for resource/biome store changes and re-render affected palettes
- Apply all CSS styles per SPEC: dark theme, section headers, swatches, items, inputs, monospace stats

**Acceptance Criteria:**
- [ ] Biome palette shows swatches with correct colors from loaded .tres files
- [ ] Resource palette lists all loaded resources with color dots
- [ ] Structure palette lists all WALKABLE_STRUCTURES
- [ ] Clicking a palette item activates the correct tool with correct value
- [ ] Only one item across all palettes is selected at a time
- [ ] Active tool indicator highlights the correct section header
- [ ] Statistics show accurate tile count per biome, total tiles, total resources
- [ ] Statistics update automatically when map changes
- [ ] Map properties (chapter_id, name) are editable and mark map as dirty
- [ ] Spawn coordinates display correctly (read-only)
- [ ] Elevation mode toggle and value slider control the elevation brush
- [ ] Live palette updates: new resource/biome in editor tabs appears in palette immediately
- [ ] Sidebar scrolls when content exceeds viewport height
