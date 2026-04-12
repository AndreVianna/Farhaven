# BuildingSystem

**Source:** `scripts/building/building_system.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`prop_def.md`](prop_def.md) (for STRUCTURE tag, PlaceableCap lookup), [`recipe.md`](recipe.md), [`recipe_runtime.md`](recipe_runtime.md), [`hex_grid.md`](hex_grid.md), [`hex_tile.md`](hex_tile.md) (for `Biome.WATER` check), [`inventory.md`](inventory.md) (for post-resolve cleanup), [`hud.md`](hud.md) (for placement label). Not an autoload — it is a child Node of Player.

## What this system is

BuildingSystem is a **thin UX wrapper around RecipeRuntime for structure placement**. It
implements the two player-facing verbs "enter placement mode with recipe X" and "tap a tile
to place." Everything economic (material validation, material consumption, recipe resolution,
output delivery) is delegated to RecipeRuntime. BuildingSystem only handles:

1. **Placement mode.** Which recipe is selected, whether placement is active.
2. **Tile validation.** Adjacency to player, not water, not blocked by collision / overlap.
3. **Tap → coordinate conversion.** Raycasting the screen touch to a hex coordinate.
4. **Highlight display.** Telling the renderer which tiles are valid candidates.
5. **Placement label.** Telling the HUD what to show as "TAP TO PLACE X".
6. **Post-resolve prop placement.** When RecipeRuntime finishes a build recipe, actually
   create the structure Prop on the target tile.

## Promises to content

- **Placement mode is modal.** `enter_placement_mode(recipe)` sets a single selected recipe
  and emits `placement_mode_entered(recipe_id)`. Any subsequent tap is either a place or a
  cancel. `exit_placement_mode()` clears it and emits `placement_mode_exited()`.
- **Only one recipe at a time.** Calling `enter_placement_mode` twice replaces the selection
  without resolving the first — the player effectively swaps build targets.
- **Valid tiles are adjacent + walkable + non-water.** `get_valid_placement_tiles()` returns
  the tiles neighbouring the player that are passable and not water. Diagonal / non-adjacent
  tiles are never valid. Distance is hex-distance = 1.
- **Tap on non-valid tile cancels, no materials consumed.** Content can rely on this: mistaps
  are safe. Materials are only drawn from inventory once `try_place_at` successfully hands off
  to RecipeRuntime.
- **Placement snaps to sub-hex SSH centre.** Placement positions are snapped to the nearest
  `HexMath.snap_to_ssh` result, giving 32cm precision for structure alignment. The snapped
  sub-hex is stored in `_pending_builds` and used when the recipe resolves.
- **Pending build info survives instant recipes.** Build info is recorded in `_pending_builds`
  *before* `try_start_recipe` is called, so zero-duration "instant" recipes still find their
  target tile when the resolve callback fires synchronously.
- **Signals are the integration surface.** `structure_build_failed(reason)`,
  `placement_mode_entered(recipe_id)`, `placement_mode_exited()` are what HUD and audio
  subscribe to. Failure reasons are StringName codes: `&"no_recipe_selected"`, `&"no_grid"`,
  `&"invalid_tile"`, `&"water_tile"`, `&"sub_hex_occupied"`, `&"no_runtime"`, `&"recipe_failed"`.
- **Input has highest priority during placement.** `process_priority = -100` ensures
  `_unhandled_input` runs before any scanner or movement handlers, so a tap during placement
  always claims the input.

## Requirements from content

- **Must be child of Player.** Like AutoInteractionSystem, BuildingSystem walks `get_parent()`
  to find the player and reads `player.current_tile`. The camera is located by walking up to
  the world node and fetching the sibling `Camera3D` — if that layout changes, `_find_camera`
  needs updating.
- **Player must expose `current_tile: Vector2i` and `get_inventory()`.** Standard player
  contract.
- **Recipe must have at least one output with a placeable, tagged `&"STRUCTURE"` PropDef.**
  On resolve, BuildingSystem walks the recipe outputs, looks up each `prop_ref` in
  PropRegistry, and places it iff it has a non-null `placeable` cap AND
  `def.has_tag(&"STRUCTURE")`. Outputs that don't match are silently skipped (the
  RecipeRuntime may have given the player an item instead — e.g. a crafted token — which
  BuildingSystem leaves alone).
- **RecipeRuntime must be the HexGrid sibling autoload.** `_ready` looks it up from the
  autoload tree. Tests can inject via `_runtime` before `_ready`.
- **HexGridRenderer must be findable.** `_find_renderer` walks `player → world →
  HexGridRenderer`. If no renderer is found, highlights are silently no-op (headless tests
  work, no visual feedback).
- **HUD must be at `Main/HUD/HUD`.** `_find_hud` looks it up by absolute path. Tests can
  inject via `_hud` before `_ready`.
- **BuildingSystem owns post-resolve inventory cleanup.** RecipeRuntime delivers the structure
  prop to the player's inventory as a "token." BuildingSystem then removes that token from
  inventory (`inv.remove_item(prop_ref, 1)`) and places the real structure prop on the tile.
  This two-step model exists so the recipe resolution path is uniform with crafting recipes.

## Extension points

- **New placement rules.** `_is_valid_placement_tile` is the single gate. Adding "no building
  on blessed tiles" or "no building within 2 hexes of another structure" means adding a check
  in that function. Highlight display follows automatically.
- **Special outputs.** The `if prop_ref == &"P00104"` branch (Storage Chest → `capacity_size
  += 50.0`) is the template for structures that need a side-effect when placed. New ones can
  follow the same pattern in `_on_recipe_resolved`.
- **Renderer integration.** BuildingSystem calls `_renderer.highlight_tiles(tiles, Color.CYAN)`
  and `_renderer.clear_highlights()`. A different renderer with those method signatures can
  be injected without touching BuildingSystem.
- **Cancel paths.** Every validation failure calls `exit_placement_mode()` and returns false.
  Hooks that want to react to specific cancels listen to `structure_build_failed` for the
  reason.

## Genre-specific notes

BuildingSystem is **survival-genre specific** in posture but its core loop is more reusable
than it looks.

- **"Tap to place on hex grid" is survival / builder convention.** Games in this family
  (Minecraft, Don't Starve, Rust) all have a "placement ghost + tap to confirm" flow.
  A turn-based strategy game would often use a similar pattern, just applied to units or
  city tiles rather than world props.
- **Adjacency-only restriction is Farhaven-specific.** The "must be adjacent to player"
  rule is a design choice for hex-grid navigation. A god-game or RTS would allow free-camera
  placement anywhere on the map.
- **Water-tile ban is genre-flavoured.** Survival games typically disallow building on water;
  a seafaring or sailing game would invert this rule.
- **RecipeRuntime delegation is fully genre-agnostic.** The "materials validated and consumed
  via a declarative rule engine" pattern transfers to any game. Anything that wants building
  without inventing its own consumption/validation can reuse RecipeRuntime + a thin wrapper
  like this one.
- **Sub-hex SSH snapping is Farhaven-specific.** Games without the Farhaven sub-hex model
  would snap to different granularity (tile centre, freeform, grid cell).

The split "dumb data class (Recipe) + runtime executor (RecipeRuntime) + UX wrapper
(BuildingSystem)" is a pattern worth preserving across engine versions.

## Known limitations and TODOs

- **Collision helper path is partial.** `_has_collision_overlap` uses Godot's `PhysicsDirectSpaceState3D`
  to check for overlapping physics bodies, but is guarded behind a `null` space state for
  headless test runs. In practice it almost always returns `false` because the collision
  bodies for structures aren't wired up yet. Flagged for the visual-testing pass.
- **Sub-hex overlap is coarse.** `_has_sub_hex_overlap` rejects placement if any prop on the
  tile shares the exact sub-hex. It does NOT check footprint overlap — a 2x1 structure and a
  1x1 structure at neighbouring sub-hexes could still collide visually. Full footprint
  occupancy needs `PlaceableCap.footprint` to be honoured here.
- **Only structure outputs are placed.** Non-structure outputs in the same recipe are handed
  to the inventory by RecipeRuntime but receive no special handling here. Recipes that mix
  items and structures need care in output ordering.
- **Storage Chest capacity bonus is hardcoded.** `prop_ref == &"P00104"` is a literal string
  match. Moving the +50 capacity to a capability (e.g. an "on_placed" effect in the recipe)
  is deferred.
- **No undo.** Once a structure is placed, the only removal path is destruction (which is a
  separate system entirely). Placement is final.
- **No rotation UI.** Structures can be rotated via `rotation_deg` in their prop data, but
  there is no player-facing gesture to rotate a ghost before placing. Everything is placed
  at zero rotation in v1.
