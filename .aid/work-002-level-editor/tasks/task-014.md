# task-014: Biome Editor -- List View and Data Model

**Type:** IMPLEMENT

**Source:** feature-006-biome-editor -> delivery-003

**Depends on:** task-003, task-004, task-012

**Scope:**
- Implement `BiomeDataModel` data class:
  - All editable fields per SPEC: biome_name, elevation_range ({min, max}), color (RGBA), color_variations (Array of RGBA), resource_table (Array of {type, chance, min_amount, max_amount, tool_required})
  - Round-trip metadata: _handle, _headerLines, _dirty
  - `fromTres(tresString, handle)` -- parse via TresParser, map TresValue fields to typed JS fields
  - `toTres()` -- serialize via TresParser with correct field order (script, biome_name, elevation_range, resource_table, color, color_variations)
  - `clone()` -- deep copy for command snapshots
  - `equals(other)` -- field-by-field comparison
- Implement default values for new biome per SPEC
- Implement biome name -> store key mapping (lowercase)
- Implement Biome Editor list view in the Biomes tab panel:
  - HTML `<table>` with columns: biome name (with 16x16 color swatch), elevation range ("min - max"), resource count
  - Sorted alphabetically by biome_name
  - Click row to open edit form
  - "New Biome" button at top
- Implement hardcoded biome warning: badge on biomes not in `[crash_site, grassland, forest, rocky, water]`
- Wire list rendering to `ProjectContext.files.biomes` data
- Re-render list when biome store changes

**Acceptance Criteria:**
- [ ] `BiomeDataModel.fromTres()` correctly parses all fields from existing .tres files
- [ ] `BiomeDataModel.toTres()` produces valid .tres output that round-trips correctly
- [ ] resource_table serializes with alphabetically sorted dict keys and plain string keys (not StringName)
- [ ] Biome list displays all discovered biomes sorted by name
- [ ] Color swatches render with correct biome color
- [ ] Hardcoded biome warning badge appears on custom biomes not in the known set
- [ ] Clicking a row navigates to edit form (built in task-015)
- [ ] "New Biome" button triggers new biome flow
- [ ] List re-renders when biomes are added or removed
