# Environmental Biomes & Hazard System — Implementation Plan

> Branch: `feature/environmental-biomes`
> Generated 2026-04-22 by Plan agent.

## Design overview

We are replacing binary traversability (water = blocked, elevation diff > 4 = blocked) with data-driven rules based on three per-tile numeric fields, two of which are new. The map generator's "promote unreachable to Rocky / smooth unreachable elevation" step is removed — inaccessible high tiles just stay authored as-is, and the new Region Brush takes over the job of shaping the playable area. Three new biomes add Volcanic, Alpine, and Shoreline. A new `hazard_type` field on `BiomeData` tells the engine what the per-tile `temperature` value means on a given biome (heat/cold/none). Water gets a real submersion rule (`waterLevel - elevation > 3` blocks entry) which finally lets shallow water be walkable.

## File-by-file changes, grouped by layer

### 1. Biome data (`.tres` + GDScript)

- `/home/andre/projects/Farhaven/scripts/hex/biome_data.gd`
  - Add `@export var hazard_type: StringName = &"none"` (values: `&"none"`, `&"heat"`, `&"cold"`).
  - Add constant group doc describing semantics. Keep `color`, `terrain_textures`, `natural_props` as-is. No migration of existing resource files needed because missing-field defaults to `"none"`.

- `/home/andre/projects/Farhaven/scripts/hex/hex_tile.gd`
  - Extend `Biome` enum: append `VOLCANIC`, `ALPINE`, `SHORELINE` (new enum ints land at the end so existing ints keep their value — but order of `_biome_id_to_int` is driven by alphabetized filenames in `MapLoader`, so the enum is effectively just a name table; the real mapping is discovery-order). Keep the enum purely as an informational label and audit every `tile.biome == _HexTile.Biome.WATER` compare — those compare against int values assigned at load time by `MapLoader._biome_id_to_int`, not against the enum values. Document this trap in the file header.
  - Add `@export var temperature: int = 0` (0 = normal, 4 = instadeath). Clamp on set by the loader. Leave the field absent in JSON by default.

- `/home/andre/projects/Farhaven/data/biomes/B00006.tres` (new)
  - `id = &"B00006"`, `display_name = "Volcanic"`, `color = Color(0.18, 0.12, 0.14)` (dark basalt), `hazard_type = &"heat"`, `terrain_textures = [...]` pointing at the 5 Volcanic PNGs, empty `natural_props` initially.

- `/home/andre/projects/Farhaven/data/biomes/B00007.tres` (new)
  - `id = &"B00007"`, `display_name = "Alpine"`, `color = Color(0.85, 0.88, 0.92)`, `hazard_type = &"cold"`, 5 Alpine textures.

- `/home/andre/projects/Farhaven/data/biomes/B00008.tres` (new)
  - `id = &"B00008"`, `display_name = "Shoreline"`, `color = Color(0.87, 0.82, 0.67)` (sand), `hazard_type = &"none"`, 5 Shoreline textures.

- `/home/andre/projects/Farhaven/scripts/hex/map_loader.gd`
  - In the tile-parse loop after `tile.elevation = ...`: `if td.has("temperature"): tile.temperature = clampi(int(td["temperature"]), 0, 4)`. Default 0 when missing.
  - Remove the auto-promote-to-Rocky step (nothing to remove here — it lives in the JS generator, not the loader).
  - Update the shoreline-wall auto-rule (lines 200–211): instead of `t_water != (n_t.biome == WATER)` generating a wall, change to "wall only when `waterLevel - neighbor.elevation > 3` OR elevation diff > 4" — i.e. a wall is only forced where the player physically can't cross. Keep water-land biome transitions wall-free otherwise so Shoreline tiles sit flush with Water surfaces.

### 2. Engine traversal + hazards (GDScript)

- `/home/andre/projects/Farhaven/scripts/hex/hex_grid.gd`
  - Replace `get_traversal()` (lines 116–139):
    - Drop the "biome == WATER → BLOCKED" special case.
    - For any target tile, if it has a `water_level`/biome-is-water and `water_level - elevation > 3` → `BLOCKED`.
    - If `tile_to.elevation - tile_from.elevation > 4` → `BLOCKED` (slope rule, directional — going up. Going down is always allowed up to the old DROP cap; decide whether `JUMP_MAX_DIFF` stays at 4 or becomes 99 for drops. Recommendation: slope block applies only on step-up, drops remain governed by existing JUMP/DROP tiers).
    - Keep `BLOCKS_MOVEMENT` prop tag check.
    - Keep WALK (0-2 diff), JUMP (3-4 diff uphill), DROP (3-4 diff downhill).
  - Add `const SUBMERSION_MAX: int = 3` and `const SLOPE_MAX_UP: int = 4` and mark `WALK_MAX_DIFF` / `JUMP_MAX_DIFF` unchanged. Keep `MAX_ELEVATION_DIFF` alias for backward compat.
  - Add helper `func is_instadeath(coords: Vector2i) -> bool` returning `true` when `tile.temperature == 4`. Used by player movement pre-check.

- `/home/andre/projects/Farhaven/scripts/player/player.gd`
  - In `_process_walking()` (the hex-decision block around lines 424-433), after `get_traversal`, call `HexGrid.is_instadeath(candidate_tile)`. If true: apply a lethal damage pulse through `SurvivalSystem` and treat like `BLOCKED` (slide along boundary). The lethal hit is intentional — even bumping into lava kills.
  - Also call `is_instadeath` on the tile the player just landed in after `move_and_slide()` and `_start_jump()` landing, so stepping *onto* temperature 4 without crossing a hex boundary (e.g. painted by a brush under the player) still kills.
  - Extend `tile_entered` hookup so SurvivalSystem sees biome + temperature changes on every tile transition.

- `/home/andre/projects/Farhaven/scripts/survival/survival_system.gd`
  - Add a new per-tile passive drain layer on top of `_tick`:
    ```
    var current_tile_hazard: Dictionary = _current_hazard()
    ```
    where `_current_hazard()` reads the player's current_tile, fetches the tile, looks up its biome's `hazard_type`, and combines with `tile.temperature` to produce a dict: `{ "thirst": x, "hunger": y, "health": z }`.
  - Heat scaling (temperature 0-4 on a biome with `hazard_type = "heat"`): thirst drain +0, +0.4, +0.8, +1.6, INSTADEATH. Health damage: 0, 0, +0.1, +0.3, INSTADEATH. Symmetric for cold but drains hunger.
  - Instadeath is applied once per entry — subscribe to HexGrid.tile_entered and call `take_damage(hp_max)` if the newly entered tile has temperature 4.
  - Emit stat_changed each tick so HUD reflects the accelerated drain.
  - Add new constant block `HAZARD_CONFIG` next to `STAT_CONFIG` with the tables above for easy tuning.
  - Extend `get_save_data()` / `load_save_data()` to persist current hazard application state only if needed (probably not; it re-derives from the tile on load).

- `/home/andre/projects/Farhaven/scripts/hex/biome_prop.gd`
  - No change required unless we want `near_biomes` to accept the new B00006/B00007/B00008 string names (it already does; just keep in mind the biome IDs during prop authoring).

### 3. Level editor — data schema & serialization (JS)

- `/home/andre/projects/Farhaven/tools/level-editor/js/hex-grid.js`
  - `createTileData()`: add `temperature: 0` to the default shape.
  - `loadMapIntoGrid()`: `tile.temperature = typeof tileJson.temperature === 'number' ? tileJson.temperature : 0;` Clamp to `[0, 4]`.
  - `serializeGridToMapJson()`: only emit `temperature` when non-zero to keep existing maps diff-clean.
  - In the shoreline-wall auto-rule at the bottom (lines 475–487): change `tileIsWater !== neighborIsWater → wall=true` to `(waterLevel - neighborElev > 3) || (abs(elev diff) > 4) → wall=true`. Mirrors the engine-side MapLoader change.

- `/home/andre/projects/Farhaven/tools/level-editor/js/commands.js`
  - New `SetTemperatureCommand(grid, q, r, oldTemp, newTemp)`. Supports undo. Used by the brush; also exposed in the inspector numeric spinner.
  - Update `SetBiomeCommand.execute()`: when switching a tile TO a non-hazard biome (hazard_type of target biome = "none"), clamp `tile.temperature = 0`. When switching FROM water to shoreline, clear waterLevel/waterType (already does on non-water). When the new biome is Volcanic or Alpine, leave temperature untouched (so painting a volcanic biome doesn't auto-heat all tiles; the Region Brush preset will set it).

- `/home/andre/projects/Farhaven/tools/level-editor/js/canvas.js`
  - Update `_computeUnreachable()` (lines 465–510):
    - Remove the spawn-on-water short-circuit.
    - Replace `neighbor.biome.startsWith('B00005')` traversal block with `if (neighbor.waterLevel - neighbor.elevation > 3) continue;`.
    - Replace `Math.abs(diff) > JUMP_MAX` with `(neighbor.elevation - tile.elevation) > 4` (directional; downhill never blocks).
    - Also block on `neighbor.temperature === 4`.
  - Add optional overlay for `tile.temperature > 0`: render a translucent red (heat) or cyan (cold) tint proportional to temperature, gated on a sidebar toggle `showTemperatureOverlay` similar to `showElevationNumbers`. Lookup `hazard_type` via `biomeHazardMap` (see below) to pick color.
  - Update the `_drawUnreachableOverlay` call to still respect the new unreachable set — nothing else changes there.

- `/home/andre/projects/Farhaven/tools/level-editor/js/panels.js`
  - In `_renderHexInfo()` (around line 700): after Elevation row, add a Temperature row when `tile.temperature > 0` OR when the biome's `hazard_type !== 'none'`. Render as a spinner (0-4). Changes go through `SetTemperatureCommand`.
  - If `tile.biome` is Water (B00005): keep the existing waterLevel/waterType panel untouched.
  - Pull biome `hazard_type` via a new helper `getBiomeHazardType(biomeId)` that reads the parsed `ProjectContext.files.biomes.get(biomeId+'.tres').data.hazard_type`. Cache in a Map on first use.

- `/home/andre/projects/Farhaven/tools/level-editor/js/biome-editor.js`
  - Add `hazard_type` to the BiomeData model (parse from `.tres`, serialize back). Add a dropdown in the biome edit panel: None / Heat / Cold. The Volcanic and Alpine presets set this automatically; users can edit it manually if desired.

- `/home/andre/projects/Farhaven/tools/level-editor/js/map-generator.js`
  - Remove `passAccessibility` Steps 1 & 2 entirely (lines 473–511). Keep the pass function but gut its body — or delete the pass and stop calling it. Region Brush replaces its role. Keep the waterLevel post-pass.
  - In `passBiomes`, no new biome assignments by default (the generator stays vanilla; Region Brush places Volcanic/Alpine/Shoreline deliberately).
  - Add generator option `allowShorelineAutoCoat: bool` (default true): iterate all Water tiles after `passBiomes`, and for each land neighbor whose `elevation - waterLevel <= 1`, flip its biome to `B00008` (Shoreline). This gives natural beaches on fresh maps. Guarded by a checkbox in the generator dialog.

### 4. Level editor — Region Brush tool (JS)

- `/home/andre/projects/Farhaven/tools/level-editor/js/tools.js`
  - Add `ToolType.REGION` to the enum.
  - New class `RegionBrush extends DragBrushTool` (file-local).
    - State: `radius`, `edgeRoughness`, `preset`, `targetBiome`, `targetElevation`, `targetTemperature`, and optional `noise2D` instance (created per-stroke, seeded by `Date.now()` so repeats look different; or use an editor-shared seed from the generator).
    - Per-stroke "logical region" is painted at each brush position (debounced to one apply per mouse position by the existing `_visited` set keyed on hex).
    - `_applyAt(hex)` iterates all hex coordinates within `radius` of `hex` using the same `hexesInRadius` helper (pulled out of `map-generator.js` into `hex-math.js`). For each candidate `(q, r)`:
      - `d = HexMath.distance(q, r, hex.q, hex.r)`
      - `n = (noise2D(q * 0.18, r * 0.18) + 1) / 2` (range [0, 1])
      - `threshold = d / radius - edgeRoughness + 0.5` (tuned so `edgeRoughness = 0` means circular, `edgeRoughness = 1` means very ragged)
      - Paint when `n > threshold`.
    - Each painted tile generates a `BatchCommand` built from `[SetBiomeCommand, SetElevationCommand, SetTemperatureCommand]` depending on which fields the preset specifies. Existing elevation is overwritten *only* for tiles inside the ragged boundary; tiles already at the target elevation skip the no-op command. Non-existent tiles are created with `createTileData`.
    - `onMouseUp` flushes `_dragCommands` to `commandHistory.batchReplace()` — the whole stroke is one undo step, matching existing `BiomeBrush` behavior.
  - Add class `RegionBrushPresets` (plain data):
    ```
    MOUNTAIN_WALL:  { biome: 'B00004', elevation: +10, temperature: 0, radius: 8,  edgeRoughness: 0.6 }
    SHORELINE:      { biome: 'B00008', elevation:  0, temperature: 0, radius: 4,  edgeRoughness: 0.7 }
    ALPINE_PEAK:    { biome: 'B00007', elevation: +12, temperature: 2, radius: 10, edgeRoughness: 0.5 }
    VOLCANIC_FLOW:  { biome: 'B00006', elevation: +3,  temperature: 3, radius: 12, edgeRoughness: 0.7 }
    ```
    with a `CUSTOM` preset for user-authored values.

- `/home/andre/projects/Farhaven/tools/level-editor/js/hex-math.js`
  - Export `hexesInRadius(radius, center = {q:0, r:0})`; move the helper out of `map-generator.js` so both generator and Region Brush share it.

- `/home/andre/projects/Farhaven/tools/level-editor/js/app.js` (sidebar + palette)
  - Add `{ type: 'region', label: 'Region', shortcut: 'G' }` to `TOOL_GROUPS` under "Hex Tools".
  - New function `_initRegionBrushPanel()` mirroring `_initElevationControls()`: renders a form with Preset dropdown, Radius slider (3-30), Edge Roughness slider (0-1), Biome dropdown, Elevation spinner, Temperature spinner. Selecting a preset prefills the other fields but leaves them editable. Saves to `toolManager.regionConfig` on change; the `RegionBrush` reads that dict when building commands.
  - In `selectTool('region')`, make sure the palette for that tool is visible (reuse existing show/hide logic).

- `/home/andre/projects/Farhaven/tools/level-editor/js/command-palette.js`
  - Add a `regionBrush` entry to the palette so `Ctrl+K` > "region brush" selects the tool.

- `/home/andre/projects/Farhaven/tools/level-editor/js/canvas.js`
  - Cursor preview: while `toolManager.activeToolType === ToolType.REGION`, draw a translucent circle of radius `regionConfig.radius` around the hovered hex to show the splash area. Uses the same noise sample as the paint step so the preview *looks* like what gets painted — do NOT recompute noise every frame, sample once per hover change and cache.

### 5. Textures

- `/home/andre/projects/Farhaven/assets/textures/biomes/B00006_volcanic_{1..5}.png` (new)
  - Generate with `/home/andre/lola/scripts/gen_image.py` using a "dark basalt with glowing lava veins, tileable 512x512, top-down, organic, no lighting" prompt. Then add Godot `.import` files (copy one of the existing `.import` files, change path). Follow existing B00004 structure.
- `/home/andre/projects/Farhaven/assets/textures/biomes/B00007_alpine_{1..5}.png` (new)
  - Prompt: "snow-covered rocky ground with patches of lichen, tileable, top-down".
- `/home/andre/projects/Farhaven/assets/textures/biomes/B00008_shoreline_{1..5}.png` (new)
  - Prompt: "wet and dry sand beach with pebbles, tileable, top-down, muted".

### 6. Tests

- `/home/andre/projects/Farhaven/tests/unit/test_biome_data.gd` — extend `BIOME_PATHS` to include B00006/B00007/B00008; add a test asserting each biome's `hazard_type` is one of `{"none", "heat", "cold"}`.
- `/home/andre/projects/Farhaven/tests/unit/test_hex_grid_traversal.gd` (new) — direct unit coverage of `get_traversal()` matrix:
  - Shallow water (waterLevel-elev=2): WALK. Deep water (diff=4): BLOCKED.
  - Slope up 4: JUMP. Slope up 5: BLOCKED. Drop down 10: DROP (unchanged).
  - Temperature 4 tile: `is_instadeath()` returns true.
- `/home/andre/projects/Farhaven/tests/features/movement.feature` + `/home/andre/projects/Farhaven/tests/steps/movement_steps.gd` — add scenarios mirroring the above.
- `/home/andre/projects/Farhaven/tests/survival/test_hazard_drain.gd` (new) — drive SurvivalSystem for 5 simulated ticks on a Volcanic tile at temperature 2, assert thirst dropped by the expected amount and HP dropped by the expected amount.

### 7. Map migration — `/home/andre/projects/Farhaven/data/maps/ch1.json`

- No authored changes required. `temperature` defaults to 0 and is omitted on serialize when zero. The loader keeps `walls` / `waterLevel` as authored. The changed shoreline-wall rule in `MapLoader` is additive (it creates walls only when the new geometry requires them). Verify by loading ch1 in the editor and checking that the displayed walls/reachability match the prior version — any regression would point at a bug in the new wall rule.
- If the user wants to re-author ch1 with the new biomes, that's a follow-up task using the Region Brush. Not part of this feature's mandatory scope.

## Order of implementation (smallest shippable increments)

1. **Schema plumbing, no UI.** Add `hazard_type` to `BiomeData` and `temperature` to `HexTile` + the loader. Extend `createTileData`/loader/serializer in JS. Verify ch1 still loads in editor and game. Ship as commit 1.
2. **New biome .tres files (no textures yet).** Create B00006/B00007/B00008 with fallback colors only, empty texture arrays. Biome-editor picks them up automatically via `ProjectContext.files.biomes`. Update `test_biome_data.gd`.
3. **Engine rules.** Update `HexGrid.get_traversal()` with submersion + slope rules, add `is_instadeath`. Update `HexCanvas._computeUnreachable()` in the editor to match so unreachability overlays stay honest. Update `movement.feature`.
4. **Hazard drain.** Add `HAZARD_CONFIG` + per-tile hazard drain into `SurvivalSystem`. Wire `HexGrid.tile_entered` → instadeath check in `player.gd`. Unit test.
5. **Texture generation.** Run the Gemini generator for B00006/B00007/B00008 variants, drop PNGs + `.import` into `assets/textures/biomes/`, wire them into each `.tres`.
6. **Editor inspector + temperature brush-less editing.** Add the Temperature spinner to `panels.js` hex inspector. Add `SetTemperatureCommand`. Add overlay toggle in canvas. This already lets us hand-paint small hazard regions for playtesting.
7. **Region Brush.** Build the tool + palette panel + presets. This is the biggest UI chunk; ship last because it depends on all the preceding groundwork (new biomes visible in palette, temperature command exists, region math shared with generator).
8. **Cleanup.** Remove `passAccessibility` Steps 1 & 2 from `map-generator.js`. Add the optional Shoreline auto-coat pass. Update the generator dialog.

## Risks, open questions, decisions deferred

- **Biome int mapping.** `MapLoader._biome_id_to_int` is keyed on alphabetized `.tres` filenames, which means adding B00006–B00008 shifts nothing (they sort after B00005). But any code that stores the int biome in a save and reloads with a different biome set will desync. There is currently no such save path (biomes live on tiles, tiles come from the JSON), so we're safe — but document it.
- **Directional slope rule.** Spec says `elevation - currentTile.elevation > 4` blocks. That implies uphill-only. Confirm drops can still fall any distance (current JUMP/DROP caps are both 4). Recommend: keep downhill drops governed by the existing DROP tier up to 4 (animated jump), but do not allow drops larger than 4 either (consistent with current behavior). Open question: does this feature include changing that? Default: no.
- **Instadeath semantics.** Does bumping into a temperature-4 edge kill you, or only *entering* the tile? Current plan: block entry (slide along boundary) but also instadeath-kill if the player somehow ends up on one (paint-under-player, teleport, spawn). Confirm.
- **Noise library.** `simplex-noise.js` exists; reuse `createNoise2D` for the Region Brush so both the generator and brush stay consistent. Seed choice: per-brush-stroke `Math.random()`. No persistence.
- **Migration warnings.** If a map is authored with old `passAccessibility` smoothing, its elevations are already clamped. Removing the pass won't change those maps. New maps generated after this change will have more varied (and possibly inaccessible) peaks — that's by design.
- **Shoreline walls.** The current auto-rule "water-biome transition always places a wall" exists to prevent the terrain-Y blending across water-land biomes (they render at different heights). Shoreline needs to render flush with water. Strategy: keep the *rendering* rule (water tiles use `water_level`, dry tiles use `elevation`, no blend) but drop the *wall* part of the rule — the wall is a gameplay-blocking concept, and Shoreline must be traversable. Verify the renderer still looks correct when a Shoreline tile sits next to Water with no wall. Risk: may need to special-case Shoreline in `HexGrid.get_terrain_y()` so it blends with water surface. Defer to implementation time.
- **Godot int-enum extension.** Existing GDScript code references `_HexTile.Biome.WATER`. Adding new entries to the enum is fine, but nobody should compare against `Biome.VOLCANIC` etc. via the enum because the int on the tile is a filename-sort index, not the enum value. The existing `.biome == _HexTile.Biome.WATER` checks happen to work today because `WATER` is the 5th alphabetically-sorted file AND the 5th enum value. Adding B00006-B00008 keeps that accidental alignment. Document this as a known landmine and, at some point, replace the enum with a lookup by `biome_id: StringName`. Not in scope here.
- **Temperature 4 = instadeath vs damage-over-time only.** The spec says 4 is instadeath. Confirmed. At temperature 3 it's strong drain but survivable — the hazard drain table has to ladder appropriately.

## Testing approach per step

- Step 1 (schema): load ch1 in editor, diff serialized output vs original — should be byte-identical.
- Step 2 (biome files): `test_biome_data` suite extended.
- Step 3 (engine rules): new GdUnit test + BDD feature scenarios for submerged water and slope > 4 blocks.
- Step 4 (hazard drain): headless SurvivalSystem test — construct a tile with `temperature=2` and `hazard_type="heat"`, tick 10 seconds, assert thirst drop matches HAZARD_CONFIG.
- Step 5 (textures): manual visual QA in editor texture mode and in-game.
- Step 6 (inspector): open a hex in editor, change temperature, undo, redo — should be lossless.
- Step 7 (Region Brush): paint a Volcanic Flow on a test map; save; re-open; assert elevation + biome + temperature round-trip. Playtest walking into temperature 3 (should drain fast) and temperature 4 (should kill).
- Step 8 (generator cleanup): regenerate a procedural map; assert unreachable peaks are rendered with red X (since we removed the automatic fixup). That's the signal the Region Brush is now doing the job.
