# Data Model

> **Source:** discovery-analyst
> **Status:** Active
> **Last Updated:** 2026-04-08 (updated for delivery-005a: Props & Recipes engine)

> **Authoritative design spec for Props & Recipes:** `.aid/work-001-core/delivery-005a/DESIGN.md`

## Entities / Schemas

### HexTile (scripts/hex/hex_tile.gd)
Godot Resource representing a single hex tile in the game world.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| coords | Vector2i | (0,0) | Axial coordinates (q, r) | Primary key in HexGrid._tiles dictionary |
| biome | Biome enum (int) | GRASSLAND (1) | 0-4 | CRASH_SITE=0, GRASSLAND=1, FOREST=2, ROCKY=3, WATER=4 |
| elevation | int | 0 | -32000..32000 (clamped in MapLoader) | World Y = elevation * 0.5 |
| props | Array | [] | Array of prop Dictionaries | Unified: resources, structures, anomalies, spawn markers. Each prop has type, category, sub-hex coords (sq, sr), and optional footprint. Replaces former `structure`, `prop_nodes`, `anomaly` fields. |

**Deprecated fields (replaced by props[]):**
- ~~`structure`~~ — now a prop with `category=STRUCTURE` (6) in `props[]`
- ~~`prop_nodes`~~ — now props with natural categories (PLANT=0..OOZE=5) in `props[]`
- ~~`anomaly`~~ — now a derived state via `prop.is_anomaly()` (origin is not NATURAL or CRAFTED)

**Helper methods (updated 2026-04-08):**
- `get_props()` — all props
- `get_structures()` — props with category == STRUCTURE
- `get_anomalies()` — props where `is_anomaly()` is true
- `get_props_with_tag(tag: StringName) -> Array` — props whose PropDef has the given tag (added delivery-005a)
- `get_props_with_capability(cap_name: StringName) -> Array` — props whose PropDef has the given capability (added delivery-005a)
- `get_props_by_category(category: int) -> Array` — DEPRECATED: use get_props_with_tag/get_props_with_capability instead

Source: `scripts/hex/hex_tile.gd`

### Prop (scripts/hex/prop.gd)
Godot Resource representing any game object placed in a hex tile. Replaces the former separate PropNode, structure, and anomaly fields with a unified model.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| type | StringName | &"" | Must match a registry id | e.g. &"wood", &"workbench", &"anomaly_ch1_001" |
| category | Category enum (int) | PLANT (0) | 0-9 | PLANT=0, MINERAL=1, ANIMAL=2, FUNGI=3, LIQUID=4, OOZE=5, STRUCTURE=6, VEHICLE=7, EQUIPMENT=8, STORAGE=9 |
| origin | Origin enum (int) | NATURAL (0) | 0-4 | NATURAL=0, CRAFTED=1, HUMAN=2, NATIVE_ALIEN=3, UNKNOWN=4 |
| sub_hex | Vector2i | (0,0) | Distance from origin <= 2 | Pointy-top axial coords within parent hex (19 valid positions) |
| remaining | int | 0 | 0 to max_amount | Resource only: decremented on gather; 0 = depleted |
| max_amount | int | 0 | Set from BiomeData | Resource only: reset to max on respawn |
| tool_required | StringName | &"" | Empty = bare hands | Resource only: e.g. &"stone_pickaxe" |
| respawn_time | float | 0.0 | Seconds; 0 = no respawn | Resource only: 30.0 common, 60.0 rare |
| rotation_deg | float | 0.0 | Degrees | Visual rotation of prop mesh |
| footprint | Array[Vector2i] | [] | Sub-hex coords | Structure only: multi-sub-hex occupancy (future, F-009) |
| blocks_movement | bool | false | | Structure only: true for walls |

**Factory methods:** `Prop.create_resource()`, `Prop.create_structure()`, `Prop.create_anomaly()`
**Helper methods:** `prop.is_anomaly()` (derived state: origin is not NATURAL or CRAFTED), `prop.is_natural_category()` (category in PLANT..OOZE range)
**Note:** ANOMALY is now a derived state (via `is_anomaly()`), not a category. SPAWN was removed (level metadata).

Source: `scripts/hex/prop.gd`

### ~~PropNode (scripts/hex/prop_node.gd)~~ — DEPRECATED
Replaced by Prop with `category=RESOURCE`. File may still exist as orphan.

### PropDef (scripts/data/prop_def.gd)
Godot Resource defining a prop type's static properties. Loaded from `data/props/*.tres`.

> **Updated 2026-04-08 (delivery-005a).** PropDef now uses composable capabilities + tags instead of the old `Category` enum. The authoritative design spec is `.aid/work-001-core/delivery-005a/DESIGN.md`.

**Core fields:**

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| id | StringName | - | Primary key in PropRegistry (numeric, e.g. &"00010") |
| display_name | String | - | Human-readable name for UI |
| tags | Array[StringName] | [] | Free-form labels (e.g. &"BURNABLE.log", &"CONSUMABLE.edible", &"WOOD") |
| catalog_entry | StringName | - | Links to CatalogEntry.entry_id |
| catalog_category | StringName | - | UI-only grouping label ("flora", "minerals", etc.). This is what DESIGN.md calls "category_tag". Never controls behavior. |
| origin | int | 0 | Prop.Origin index (0=Natural..4=Unknown) |
| tool_slot | StringName | &"" | Tool slot this item occupies (e.g. "axe", "pickaxe"). Empty = not a tool. |
| max_stack | int | 99 | Inventory stack limit (kept during transition) |
| footprint | Array[Vector2i] | [] | DEPRECATED: use PlaceableCap.footprint instead. Kept for backward compat. |

**Capability fields (each is a small inner Resource, null when not present):**

| Field | Type (class) | Inner Fields | Notes |
|-------|-------------|-------------|-------|
| portable | PortableCap | `weight: float = 1.0` | Prop can be carried. Weight determines inventory capacity consumed. |
| placeable | PlaceableCap | `footprint: Array[Vector2i] = []`, `blocks_movement: bool = false`, `rotation_snap: int = 0` | Prop can be placed in world at sub-hex position. |
| container | ContainerCap | `capacity_weight: float = 0.0`, `accepts_filter: Array[StringName] = []` | Prop holds other props inside it. |
| light | LightCap | `radius: float = 0.0`, `color: Color = warm_orange`, `flicker: bool = false` | Prop emits light while active (used by LightingManager). |
| movable | MovableCap | `push_cost: float = 1.0` | Prop can be pushed across tiles. |
| station | StationCap | `station_tags: Array[StringName] = []` | Prop is a crafting/cooking station. Tags list roles (e.g. ["cook", "fire"]). |
| catalogable | CatalogableCap | `scan_time: float = 1.0`, `display_tag: StringName = &""` | Prop can be cataloged by ScannerSystem. |

**Helper methods:**
- `has_capability(cap_name: StringName) -> bool` — checks if a capability is non-null
- `has_tag(tag: StringName) -> bool` — checks if tags array contains the given tag

**Deprecated fields (kept for backward compat, replaced by capabilities/recipes):**

| Field | Replaced By |
|-------|------------|
| gather_time, gather_amount, tool_required, respawn_time, yield_type, tool_speed | Recipe system (gather_*.tres, regrow_*.tres) |
| is_consumable, hunger_restore, thirst_restore, health_restore | Recipe system (eat_*.tres with stat_delta effects) |
| category (StringName) | Capabilities + tags |
| prop_category (int) | Capabilities |
| emits_light, light_radius | LightCap capability |
| is_respawn_point, is_crafting_station | StationCap capability with appropriate tags |

**Visual fields (unchanged):** mesh, depleted_mesh, material, placeholder_mesh_type, placeholder_params, placeholder_color, placeholder_depleted_type, placeholder_depleted_params, placeholder_depleted_color.

**Capability Resource classes** live in `scripts/data/capabilities/`: `portable_cap.gd`, `placeable_cap.gd`, `container_cap.gd`, `light_cap.gd`, `movable_cap.gd`, `station_cap.gd`, `catalogable_cap.gd`.

Source: `scripts/data/prop_def.gd`, `scripts/data/capabilities/*.gd`, `data/props/*.tres`

### Recipe (scripts/recipes/recipe.gd)
Godot Resource defining a transformation — any gameplay action that converts props, produces effects, or both. Loaded from `data/recipes/*.tres`. Added in delivery-005a.

> **Authoritative spec:** `.aid/work-001-core/delivery-005a/DESIGN.md` §4.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| id | StringName | - | Unique, e.g. &"eat_berry", &"chop_small_tree" |
| kind | Recipe.Kind enum | - | ASSEMBLE, TRANSFORM, BREAKDOWN, COMBINE |
| inputs | Array[RecipeInput] | [] | Props consumed on resolve |
| outputs | Array[RecipeOutput] | [] | Props produced on resolve (each rolls independently) |
| effects | Array[RecipeEffect] | [] | Non-prop consequences (stat_delta, sound, etc.) |
| conditions | Array[RecipeCondition] | [] | Gate + sustain predicates |
| actions | Array[StringName] | [] | Player verbs that trigger. Empty = passive recipe. |
| time | float | 0.0 | Seconds between trigger and resolution. 0 = instant. |
| unlock_when | Array[Predicate] | [] | Discovery predicates. Empty = known from start. |

Source: `scripts/recipes/recipe.gd`, `data/recipes/*.tres`

### RecipeInput (scripts/recipes/recipe_input.gd)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| ref_or_tag | StringName | - | Prop ref or tag. Tag inputs are fungible. |
| count | int | 1 | How many consumed |
| source | StringName | &"player_inventory" | Where drawn from: player_inventory, container, world_tile, world_anywhere |
| is_tag | bool | false | True if ref_or_tag is a tag |

### RecipeOutput (scripts/recipes/recipe_output.gd)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| prop_ref | StringName | - | PropDef id of produced prop |
| count | int | 1 | How many produced |
| prob | float | 1.0 | Independent probability (0.0-1.0) |

### RecipeEffect (scripts/recipes/recipe_effect.gd)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| kind | StringName | - | stat_delta, sound, fx, emit_light, spawn_heat, world_change, grant_recipe |
| params | Dictionary | {} | Kind-specific parameters |

### RecipeCondition (scripts/recipes/recipe_condition.gd)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| predicate | Predicate | - | The predicate to evaluate |
| must_sustain | bool | false | If true, re-checked every tick; recipe cancels on failure |

### Predicate (scripts/recipes/predicate.gd)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| kind | StringName | - | One of 15 predicate kinds (see Predicate Vocabulary below) |
| params | Dictionary | {} | Kind-specific parameters |

**Predicate Vocabulary (15 kinds):**
`has_tool`, `at_station`, `at_tile_type`, `player_stat`, `player_skill` (stub), `player_knows_recipe`, `time_of_day`, `weather` (stub), `biome`, `adjacent_to`, `prop_state`, `world_flag`, `animal_nearby` (stub), `container_has`, `cataloged`.

### WorldContext (scripts/recipes/world_context.gd)
Lightweight data bag passed to PredicateEvaluator. Callers fill whatever fields they have.

| Field | Type | Notes |
|-------|------|-------|
| player | Node | For inventory, tool, stats |
| tile | Resource (HexTile) | Current tile |
| station | Resource (Prop) | Station prop in scope |
| container | Resource (Prop) | Container prop in scope |
| grid | Node (HexGrid) | For neighbor queries |
| day_night | Node (DayNightCycle) | For time_of_day predicates |
| catalog | RefCounted (Catalog) | For cataloged predicates |
| world_flags | Dictionary | Named world flags |

**Factory:** `WorldContext.create(player, tile, station)` auto-fills grid/day_night from autoloads.

### PendingRecipe (inner class in scripts/recipes/recipe_runtime.gd)
Tracks an in-progress recipe. Not a Resource file — defined as an inner RefCounted class.

| Field | Type | Notes |
|-------|------|-------|
| recipe | Recipe | The recipe being executed |
| start_time | float | When the recipe started (msec/1000) |
| elapsed | float | Time accumulated so far |
| bound_inputs | Array[Dictionary] | Consumed inputs ({type, count, source, is_tag}) for return on cancel |
| context | WorldContext | World state snapshot at start |

Source: `scripts/recipes/recipe_runtime.gd`

### BiomeData (scripts/hex/biome_data.gd)
Godot Resource defining per-biome configuration.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| biome_name | String | "" | Display name | e.g. "Crash Site", "Forest" |
| elevation_range | Vector2i | (0,0) | Min/max elevation | Currently all set to (0,9) |
| prop_table | Array | [] | Array of Dictionaries | Each: {type, chance, min_amount, max_amount, tool_required} |
| color | Color | WHITE | Base biome color | Used for terrain rendering |
| color_variations | Array[Color] | [] | 3 color variants per biome | Hash-selected per tile for visual variety |

Source: `scripts/hex/biome_data.gd`, `data/biomes/*.tres`

### CatalogEntry (scripts/scanner/catalog_entry.gd)
Godot Resource representing a discoverable entity in the scanner catalog.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| entry_id | StringName | &"" | Unique across all categories | Primary key in Catalog._all_entries |
| category | int | 0 | CatalogCategory enum | FLORA=0, FAUNA=1, MINERAL=2, ANOMALY=3 |
| display_name | String | "" | Human-readable name | Shown in catalog panel |
| description | String | "" | Flavor text | Shown when CATALOGED |
| icon | Texture2D | null | Optional icon | Not yet used (placeholder colors instead) |
| properties | Dictionary | {} | Category-specific | See Properties table below |

**Properties by Category:**

| Category | Property | Type | Notes |
|----------|----------|------|-------|
| FLORA | edible | bool | Whether it can be consumed |
| FLORA | toxic | bool | Triggers confirmation dialog |
| FLORA | resource_type | StringName | Links to PropDef |
| FAUNA | hostile | bool | Determines auto-defend behavior |
| FAUNA | damage | int | Attack damage value |
| FAUNA | hp | int | Health points |
| MINERAL | resource_type | StringName | Links to PropDef |
| MINERAL | tool_required | StringName | Display info for catalog |
| ANOMALY | journal_entry_id | StringName | Links to journal system (future) |
| ANOMALY | cutscene_id | StringName | Links to cutscene system (future) |

Source: `scripts/scanner/catalog_entry.gd`, `data/catalog/*.tres`

### CatalogData (scripts/scanner/catalog_data.gd)
Container resource wrapping an array of CatalogEntry resources.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| entries | Array | [] | Array of CatalogEntry sub-resources |

Source: `scripts/scanner/catalog_data.gd`

### Inventory (scripts/inventory/inventory.gd -- in-memory)

> **Updated 2026-04-08 (delivery-005a).** Inventory is now weight-based. The primary constraint is weight capacity, not slot count. Items are still stored in slots with max_stack limits, but total weight is the binding limit.

**Weight model:**

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| capacity_weight | float | 50.0 | Maximum total weight. Expandable. |
| _current_weight | float | 0.0 | Cached, updated incrementally on add/remove. Recomputed on load. |

**Slot structure (unchanged):**

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| type | StringName | &"" | Empty = unused slot |
| quantity | int | 0 | Current stack count |

Tool slots stored separately: `{&"axe": &"", &"pickaxe": &"", &"weapon": &"00204", &"scanner": &"00205"}`

**Item weight:** Derived from `PropDef.portable.weight`. Items without PORTABLE capability default to 1.0 for backward compat. Items with weight > capacity_weight are rejected entirely (must be transported via MOVABLE + CONTAINER props).

**No hardcoded ITEM_CONFIG.** All items (resources, consumables, tools) are PropDefs loaded from `data/props/*.tres` by PropRegistry. The old hardcoded ITEM_CONFIG is removed.

Source: `scripts/inventory/inventory.gd`

### Player Known Recipes (DiscoveryWatcher state)
Not a Godot Resource; stored as a Dictionary in DiscoveryWatcher autoload.

- Recipes with `unlock_when: []` are known from start (populated at `_ready()`)
- Recipes are granted permanently via `grant_recipe()` or when all `unlock_when` predicates become true
- Persisted via `get_save_data() / load_save_data()` as `Array[StringName]`

Source: `scripts/recipes/discovery_watcher.gd`

### Recipe Data Files (data/recipes/*.tres)
16 recipe .tres files, loaded by RecipeRegistry at startup. Replaces the old hardcoded RECIPE_CONFIG.

| File | Kind | Description |
|------|------|-------------|
| eat_berry.tres | Transform | Consume berry, +hunger |
| eat_toxic_berry.tres | Transform | Consume toxic berry, -health |
| chop_small_tree.tres | Breakdown | Axe + tree -> wood + branches |
| cook_meat.tres | Transform | Raw meat at fire station -> cooked meat |
| craft_trap.tres | Assemble | Branch + fiber -> trap |
| trap_fires.tres | Breakdown | Passive: trap + animal -> trapped_animal + materials |
| meat_rots.tres | Transform | Passive: cooked meat -> rotten meat (24h) |
| burn_log_in_fireplace.tres | Breakdown | Passive: fuel in fireplace -> ash + light/heat |
| gather_tree.tres | Breakdown | Gather from tree -> wood |
| gather_berry_bush.tres | Breakdown | Gather berries |
| gather_toxic_bush.tres | Breakdown | Gather toxic berries |
| gather_tall_grass.tres | Breakdown | Gather fiber |
| gather_loose_rocks.tres | Breakdown | Gather stone from rocks |
| gather_boulder.tres | Breakdown | Gather stone from boulder |
| gather_iron_deposit.tres | Breakdown | Gather ore |
| gather_crystal_cluster.tres | Breakdown | Gather crystal |

Source: `data/recipes/*.tres`

### Map JSON Schema (data/maps/ch1.json)
Hand-designed map file loaded by MapLoader. Supports both new (props) and legacy formats.

**Root:**
```json
{
  "spawn": [tile_col, tile_row, sub_hex_q, sub_hex_r, facing_deg],
  "tiles": {
    "q,r": { ... }
  }
}
```

**Spawn format:** `[col, row, sub_hex_q, sub_hex_r, facing_deg]`
- `col`, `row` — spawn tile axial coords (required; older maps may have only these two fields)
- `sub_hex_q`, `sub_hex_r` — sub-hex offset within the spawn tile (optional, default 0)
- `facing_deg` — initial facing in degrees, canvas convention: 0 = up/north, 90 = east (optional, default 0.0)

Fields after the first two are optional; missing fields default to 0. `HexGrid` exposes them as `spawn_tile`, `spawn_sub_hex`, `spawn_facing_deg`.

**Tile (new format — unified props):**
```json
"0,0": {
  "biome": "crash_site",
  "elevation": 0,
  "props": [
    {"type": "wood", "category": 0, "sub_hex_q": 1, "sub_hex_r": 0, "rotation": 45},
    {"type": "workbench", "category": 6, "sub_hex_q": 0, "sub_hex_r": 0, "blocks_movement": false},
    {"type": "anomaly_ch1_001", "category": 1, "origin": 4, "sub_hex_q": 0, "sub_hex_r": -1}
  ]
}
```

**Props fields:**

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| type | string | yes | - | Must match a PropDef id, structure name, or anomaly id |
| category | int | yes | 0 | 0=PLANT, 1=MINERAL, 2=ANIMAL, 3=FUNGI, 4=LIQUID, 5=OOZE, 6=STRUCTURE, 7=VEHICLE, 8=EQUIPMENT, 9=STORAGE |
| origin | int | no | 0 | 0=NATURAL, 1=CRAFTED, 2=HUMAN, 3=NATIVE_ALIEN, 4=UNKNOWN |
| sub_hex_q | int | no | 0 | Sub-hex axial q (pointy-top layout, range: distance <= 2) |
| sub_hex_r | int | no | 0 | Sub-hex axial r (pointy-top layout, range: distance <= 2) |
| rotation | float | no | 0.0 | Degrees |
| remaining | int | no | biome default | Resource only: current amount. Defaults from BiomeData |
| max_amount | int | no | biome default | Resource only: maximum amount. Defaults from BiomeData |
| tool_required | string | no | "" | Resource only: tool StringName |
| respawn_time | float | no | 0.0 | Resource only: seconds |
| blocks_movement | bool | no | false | Structure only: true for walls |

**Biome values:** `"crash_site"`, `"grassland"`, `"forest"`, `"rocky"`, `"water"`
**Elevation:** integer -32000..32000

**Legacy format (still supported, auto-converted on load):**
```json
"0,0": {
  "biome": "forest",
  "elevation": 1,
  "resources": ["wood", {"type": "berries", "x": 0.5, "y": -0.3, "rotation": 18}],
  "structure": "workbench",
  "anomaly": "anomaly_ch1_001"
}
```
Legacy x/y offsets are converted to sub-hex coords via `world_to_sub_axial()`.

Source: `data/maps/ch1.json`, `scripts/hex/map_loader.gd`

## Relationships

### HexGrid -> HexTile (1:many)
- HexGrid._tiles: Dictionary keyed by Vector2i, values are HexTile Resources
- ~250 tiles per chapter map
- Source: `scripts/hex/hex_grid.gd` line 22

### HexTile -> Prop (1:many)
- HexTile.props: Array of Prop Resources
- 0-5 props per tile (resources, structures, anomalies combined)
- Accessed via helper methods: `tile.get_resources()`, `tile.get_structures()`, `tile.get_anomalies()`
- Source: `scripts/hex/hex_tile.gd`

### Prop (RESOURCE) -> PropDef (many:1)
- Prop.type matches PropDef.id via PropRegistry autoload
- PropRegistry.get_def(type) retrieves the definition
- Source: `scripts/hex/prop.gd` (type field), `scripts/data/prop_registry.gd` (lookup)

### PropDef -> CatalogEntry (1:1)
- PropDef.catalog_entry matches CatalogEntry.entry_id
- e.g. wood -> wood_tree, stone -> stone_deposit, berries -> berry_bush
- Source: `scripts/data/prop_def.gd` (catalog_entry field), `data/catalog/*.tres`

### BiomeData -> PropDef (1:many via prop_table)
- BiomeData.prop_table contains {type: string} entries referencing resource types
- Used by MapLoader to set max_amount on PropNodes
- Source: `scripts/hex/biome_data.gd`, `data/biomes/*.tres`

### Catalog -> CatalogEntry (1:many)
- Catalog._all_entries: Dictionary keyed by StringName entry_id
- Loaded from 4 CatalogData .tres files at initialization
- Source: `scripts/scanner/catalog.gd` lines 26-40

### Player -> Inventory (1:1, composition)
- Player owns an Inventory instance (created at declaration time, not a scene node)
- Source: `scripts/player/player.gd` line 26

### Inventory -> PropDef (many:many, via PropRegistry)
- Inventory.add_item() looks up PropDef for max_stack and category
- Source: `scripts/inventory/inventory.gd` lines 47-51

### CraftingSystem -> Inventory (uses)
- CraftingSystem reads/writes Inventory for ingredient checking and tool setting
- Source: `scripts/crafting/crafting_system.gd` lines 42-44

### AutoInteractionSystem -> Catalog (uses)
- Auto-gather requires resource to be CATALOGED before gathering is allowed
- Source: `scripts/auto_interaction/auto_interaction_system.gd` lines 199-203

### ScannerSystem -> Catalog (1:1, ownership)
- ScannerSystem creates and owns a Catalog instance
- Source: `scripts/scanner/scanner_system.gd` line 61

## Migrations

No migration system exists. This is a Godot game project, not a database application.

- **Data format:** Godot .tres Resource files (binary-compatible across Godot 4.x versions) and JSON map files
- **Schema evolution:** Adding fields to Resource scripts is backward-compatible (Godot uses default values for missing fields). Removing or renaming fields requires manual migration.
- **Save data:** Uses Dictionary-based serialization via get_save_data()/load_save_data(). Catalog has backward compatibility for old "discovered" format (`catalog.gd` lines 205-209).
- **No automated migration tooling.**

Source: `scripts/scanner/catalog.gd` (backward compatibility code), `scripts/data/prop_def.gd` (@export defaults)

## Indexes

### In-Memory Indexes (Runtime)

| Index | Structure | Key | Value | Source |
|-------|-----------|-----|-------|--------|
| HexGrid._tiles | Dictionary | Vector2i (axial coords) | HexTile Resource | `hex_grid.gd` line 22 |
| PropRegistry._defs | Dictionary | StringName (resource id) | PropDef Resource | `prop_registry.gd` line 8 |
| Catalog._all_entries | Dictionary | StringName (entry_id) | CatalogEntry Resource | `catalog.gd` line 15 |
| Catalog._knowledge | Dictionary | StringName (entry_id) | KnowledgeState int | `catalog.gd` line 13 |
| ~~PlayerPathfinder._coord_to_id~~ | ~~Dictionary~~ | ~~Vector2i~~ | ~~int~~ | `player_pathfinder.gd` — **ORPHAN:** Player no longer uses A* pathfinding (joystick pivot). File exists but is unreferenced. May be repurposed for FaunaManager (feature-010). |
| ~~PlayerPathfinder._id_to_coord_map~~ | ~~Dictionary~~ | ~~int~~ | ~~Vector2i~~ | See above. |
| PropRenderer._pools | Dictionary | StringName (resource type) | MultiMeshInstance3D | `prop_renderer.gd` line 29 |
| PropRenderer._tile_entries | Dictionary | Vector2i (coords) | Array of instance info | `prop_renderer.gd` line 43 |
| PropLabelRenderer._tile_labels | Dictionary | Vector2i (coords) | Array of label info | `prop_label_renderer.gd` line 44 |

### Recipe Indexes (Runtime, added delivery-005a)

| Index | Structure | Key | Value | Source |
|-------|-----------|-----|-------|--------|
| RecipeRegistry._by_id | Dictionary | StringName (recipe id) | Recipe Resource | `recipe_registry.gd` |
| RecipeRegistry._by_input_ref | Dictionary | StringName (prop ref) | Array[Recipe] | `recipe_registry.gd` |
| RecipeRegistry._by_input_tag | Dictionary | StringName (tag) | Array[Recipe] | `recipe_registry.gd` |
| RecipeRegistry._by_action | Dictionary | StringName (action) | Array[Recipe] | `recipe_registry.gd` |
| RecipeRegistry._by_station_tag | Dictionary | StringName (station tag) | Array[Recipe] | `recipe_registry.gd` |
| DiscoveryWatcher._known_recipes | Dictionary | StringName (recipe id) | bool (always true) | `discovery_watcher.gd` |

### File-Based Indexes

| Index | Mechanism | Source |
|-------|-----------|--------|
| PropDef lookup | PropRegistry scans data/props/ directory at startup | `prop_registry.gd` |
| Recipe lookup | RecipeRegistry scans data/recipes/ directory at startup | `recipe_registry.gd` |
| CatalogEntry lookup | Catalog loads 4 hardcoded .tres file paths | `catalog.gd` lines 28-40 |
| BiomeData lookup | MapLoader and HexGridRenderer use hardcoded path arrays | `map_loader.gd`, `hex_grid_renderer.gd` |

## Validation

### Map Validation (MapLoader)
Performed at load time. All failures log push_warning but do not prevent map from loading.

| Rule | Source |
|------|--------|
| JSON must parse successfully | `map_loader.gd` lines 53-54 |
| Root must be a Dictionary with "tiles" key | `map_loader.gd` lines 57-64 |
| Tile count must be in [200, 300] | `map_loader.gd` line 143 |
| Spawn tile must exist and be CRASH_SITE biome | `map_loader.gd` lines 145-149 |
| All required biomes present (CRASH_SITE, GRASSLAND, FOREST, ROCKY) | `map_loader.gd` lines 161-164 |
| At least one anomaly tile exists | `map_loader.gd` lines 166-167 |
| Elevation in [-32000, 32000] for all tiles | `map_loader.gd` lines 158-159 |
| All non-water tiles reachable from spawn via BFS | `map_loader.gd` lines 172-192 |

### Inventory Validation (updated delivery-005a)
- add_item() validates item type exists in PropRegistry before adding. Items without a PropDef are rejected (returns 0).
- Tools (PropDef.tool_slot != "") rejected from resource slots (must use set_tool).
- Weight check: `current_weight + (unit_weight * count) <= capacity_weight`. Items exceeding total capacity rejected entirely.
- Stack overflow tracked; excess returned as int, inventory_full signal emitted.

### Recipe Validation (RecipeRuntime.try_start_recipe())
- Recipe must be known (DiscoveryWatcher.is_known())
- All conditions must pass (PredicateEvaluator.evaluate() for each RecipeCondition)
- All inputs must be available from their specified source (player_inventory, world_tile, container)
- If any check fails: returns null, inputs are rolled back
- On success: instant resolve (time==0) or enqueued as PendingRecipe

### Legacy Craft Validation (CraftingSystem.craft() — still present)
- Recipe must exist in RECIPE_CONFIG
- Workbench proximity required for workbench recipes
- Tool not already owned check
- All ingredients present in inventory
- Emits craft_failed with reason StringName on any validation failure

### Catalog Validation
- encounter_entry() only accepts FAUNA category entries (`catalog.gd` lines 127-129)
- Knowledge state progression: UNKNOWN -> ENCOUNTERED -> CATALOGED (no downgrades) (`catalog.gd` lines 113, 133)
- Duplicate cataloging silently ignored (`catalog.gd` lines 111-112)

### Auto-Gather Gating (updated delivery-005a)
- Prop must be within GATHER_RADIUS (0.75 world units) of player position
- RecipeRegistry.find_recipes_for_input(prop.type) must return at least one recipe
- Recipe must be known (DiscoveryWatcher.is_known())
- All recipe conditions must pass (PredicateEvaluator: has_tool, at_station, etc.)
- Legacy fallback (for props without recipe coverage): resource must not be depleted, must be CATALOGED, correct tool equipped

## Current Resource Definitions

> **Note (2026-04-08):** The "Gather Time", "Tool Required", "Respawn", and "Yield" columns below reference deprecated PropDef fields. In the new model, these behaviors are controlled by Recipe .tres files (e.g. `gather_tree.tres`, `gather_berry_bush.tres`). The deprecated fields remain on PropDef for backward compat but are no longer authoritative.

| ID | Display | Gather Time | Amount | Tool Required | Respawn | Yield | Max Stack | Catalog Entry |
|----|---------|-------------|--------|---------------|---------|-------|-----------|---------------|
| wood | Wood | 1.0s | 1 | - | 30s | self | 99 | wood_tree |
| stone | Stone | 1.5s | 1 | stone_pickaxe | 30s | self | 99 | stone_deposit |
| berries | Berries | 0.5s | 2 | - | 30s | self | 20 | berry_bush |
| toxic_berries | Toxic Berries | 0.5s | 2 | - | 30s | self | 20 | toxic_berry_bush |
| fiber | Fiber | 0.5s | 1 | - | 30s | self | 99 | fiber_grass |
| ore | Ore | 2.0s | 1 | stone_pickaxe | 60s | self | 99 | iron_deposit |
| crystal | Crystal | 2.5s | 1 | stone_pickaxe | 60s | self | 50 | crystal_cluster |
| loose_rock | Loose Rock | 1.0s | 2 | - | 30s | stone | 99 | loose_rocks |
| anomaly_fragment | Anomaly Fragment | 3.0s | 1 | - | 0 (none) | self | 99 | - |

Source: `data/props/*.tres`

## Current Catalog Entries

| Entry ID | Category | Display Name |
|----------|----------|-------------|
| wood_tree | FLORA | Thornwood Tree |
| berry_bush | FLORA | Berry Bush |
| toxic_berry_bush | FLORA | Toxic Berry Bush |
| fiber_grass | FLORA | Fiber Grass |
| thornback | FAUNA | Thornback |
| loose_rocks | MINERAL | Loose Rocks |
| stone_deposit | MINERAL | Stone Deposit |
| iron_deposit | MINERAL | Iron Deposit |
| crystal_cluster | MINERAL | Crystal Cluster |
| anomaly_ch1_001 | ANOMALY | Alien Beacon |

Source: `data/catalog/*.tres`

## Biome Resource Tables

| Biome | Resources |
|-------|-----------|
| Crash Site | wood (60%, max 3), loose_rock (50%, max 5), fiber (40%, max 4) |
| Forest | wood (70%, max 5), berries (40%, max 3), toxic_berries (20%, max 2) |
| Grassland | berries (50%, max 4), fiber (60%, max 4), wood (30%, max 3) |
| Rocky | stone (70%, max 6), ore (30%, max 4), crystal (10%, max 2) |
| Water | (no resources) |

Source: `data/biomes/*.tres`

---

## Gear Hierarchy (delivery-006 target)

> **Status:** Approved design, implementation deferred to delivery-006
> **Created:** 2026-04-09
> **Authors:** Andre Vianna (architecture) + Lola (documentation)

### The Hierarchy

```
Gear (engine root entity)
  id: StringName
  display_name: String
  short_description: String
  long_description: String

  ├── Script (executable game logic)
  │   conditions: [Predicate]
  │   effects: [Effect]
  │   actions: [StringName]     # player trigger (empty = passive)
  │   duration: float           # seconds (was "time")
  │   │
  │   ├── Recipe
  │   │   inputs: [Input]
  │   │   outputs: [Output]
  │   │   # NO unlock_when — discovery handled by Event with grant_script effect
  │   │   # NO kind enum — was purely cosmetic, no runtime behavior
  │   │
  │   └── Event
  │       count: int            # runtime state (persisted in save)
  │       max_count: int        # 0=unlimited, 1=one-shot, N=limited
  │
  ├── Element (world data)
  │   ├── Biome
  │   └── Prop (+ capabilities + tags)
  │
  ├── Cutscene
  │   # display_name = title
  │   # short_description = summary
  │   # long_description = transcript
  │
  └── Journal Entry
      # display_name = title
      # short_description = summary
      # long_description = full entry
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Script (not GameAction) | "Script" = screenplay/instruction. Clear, evocative, not overloaded. |
| duration (not time) | "time" is vague. "duration" says what it is. |
| unlock_when removed from Script | Discovery = Event with max_count=1 and effect grant_script(). Recipe doesn't need to know HOW it's discovered. |
| Recipe.kind removed | No runtime behavior. Purely cosmetic classification. Can be optional editor metadata. |
| max_count (not count_max) | Adjective+noun reads better. |
| World flags = Event counts | A "flag" is an Event that has fired (count >= 1). No separate WorldFlags dict. |
| Milestones = Event (max_count=1) | One-shot events that trigger cutscenes, journal entries, recipe unlocks. |
| Cycles = Event (max_count=0) | Unlimited events (campfire burn cycle, decay, growth). |
| Cutscene + JournalEntry = Gear | First-class entities, not properties buried in dictionaries. |

### What Changes in Existing Code

| Change | Effort | Risk |
|--------|--------|------|
| Create gear.gd + script_base.gd | ~1h | Low (additive) |
| recipe.gd extends script_base | ~1h | Medium (26 .tres + tests) |
| Create event.gd | ~30min | Low (new) |
| Move unlock_when → Event .tres files | ~2h | Medium (10 events + DiscoveryWatcher) |
| Rename time → duration in 26 .tres + code | ~1h | Low (find/replace) |
| PropDef extends gear | ~1h | Medium (28 .tres) |
| Kind → optional/cosmetic | ~30min | Low |
| **Total** | **~7h** | **Medium** |

### Implementation Plan

**When:** First task of delivery-006 (after delivery-005b closes)
**Why not now:** delivery-005b is mid-flight with elfos running. Refactoring the base class mid-delivery risks merge conflicts and regressions.
**Dependencies:** None — purely structural refactor, all behavior preserved.

### Examples After Refactor

#### Recipe (no unlock_when)
```yaml
eat_berry:
  # Gear fields
  id: "00001"
  display_name: "Eat Berry"
  short_description: "Consume a berry for nourishment"
  # Script fields
  conditions: []
  effects: [{ stat_delta: { hunger: 5 } }, { sound: crunch }]
  actions: [eat]
  duration: 0
  # Recipe fields
  inputs: [{ berry, 1 }]
  outputs: []
```

#### Event (discovery)
```yaml
discover_eat_berry:
  # Gear fields
  id: "E0001"
  display_name: "Discover Eat Berry"
  short_description: "Learn that berries are edible"
  # Script fields
  conditions: [{ cataloged: berry }]
  effects: [{ grant_script: "00001" }]
  actions: []
  duration: 0
  # Event fields
  count: 0
  max_count: 1
```

#### Event (milestone)
```yaml
milestone_first_shelter:
  id: "E0100"
  display_name: "First Shelter Built"
  short_description: "The crash survivor builds their first shelter"
  conditions: [{ event_count: { event: "shelter_placed", min: 1 } }]
  effects: [{ play_cutscene: "cs_first_shelter" }, { journal_entry: "J0001" }]
  actions: []
  duration: 0
  count: 0
  max_count: 1
```

#### Cutscene
```yaml
cs_first_shelter:
  id: "CS001"
  display_name: "A Roof Over Your Head"
  short_description: "The survivor reflects on building their first shelter"
  long_description: "Camera pans from the hex grid to a cinematic view..."
  # + video_path, duration, skip_allowed, etc. (delivery-006 details)
```

#### Journal Entry
```yaml
journal_first_shelter:
  id: "J0001"
  display_name: "Day 4 — Shelter"
  short_description: "I built something today."
  long_description: "The walls aren't much. Branches and fiber, mostly..."
```

---

## Spatial System — SSH Grid (delivery-006 target)

> **Status:** Approved design, implementation deferred to delivery-006
> **Created:** 2026-04-09
> **Authors:** Andre Vianna (concept) + Lola (math validation + documentation)

### The Change

Replace abstract footprint arrays with mesh-based collision and a 3-level hex grid.

### Three-level grid

```
Hex (H):          diameter = 6.000m    — world tile, biome unit
Sub-hex (SH):     diameter = 1.386m    — prop anchor, current placement unit
Sub-sub-hex (SSH): diameter = 0.320m   — fine placement snap (32cm resolution)

Formula: child_diameter = (parent_diameter / 5) / (√3/2)
```

### What changes

| Before | After |
|---|---|
| `footprint: [Vector2i]` manual cell list | **DELETE** — mesh is the truth |
| `PlaceableCap.footprint` | **DELETE** |
| `blocks_movement: bool` flag | **DELETE** — CollisionShape3D on mesh handles blocking |
| Collision = "cell occupied?" | **Collision = 3D mesh overlap** (Godot physics) |
| Placement snap = sub-hex center | **Placement snap = SSH center** (32cm grid) |
| 2D footprint in editor | **2D top-down silhouette** derived from mesh |

### Decisions (Andre, 2026-04-09)

1. **No footprint field.** Collision is 3D mesh-to-mesh. Godot native (CollisionShape3D, Area3D).
2. **Two representations per prop:** 3D mesh (game world) + 2D top-down (web editor).
3. **SSH is placement snap only.** "Where to position the prop center." Collision is mesh physics.
4. **Prop center of rotation = center of nearest SSH.**
5. **Prop base = ground plane.** Mesh bottom aligns with terrain Y.
6. **No pathfinder yet.** Movement blocking comes from mesh colliders, not grid data.
7. **Performance deferred.** Evaluate when implemented (~18,000 SSHs per 50-hex map is manageable).
8. **Detailed building (shelves, wall mounts) = future.** Current props sit on the ground.

### What this enables

- Props with any shape (box, cylinder, irregular) placed at 32cm precision
- Natural coexistence: torch + chest in same sub-hex if meshes don't overlap
- No manual footprint maintenance — add a mesh, it just works
- Editor shows real prop shapes (2D projected) on the SSH grid
- Level design in both web editor and Godot editor with same snapping

### Implementation scope (delivery-006)

- Add SSH coordinate math to HexMath (trivial — same axial math, smaller scale)
- Remove `footprint` from PlaceableCap and all .tres files
- Remove `blocks_movement` from PlaceableCap
- Add CollisionShape3D to prop meshes (or generate from placeholder mesh params)
- Update BuildingSystem placement to snap to SSH + physics overlap check
- Update web editor to show SSH grid + 2D prop silhouettes
- Update StructureRenderer to position at SSH precision
- ~Estimated 3-4 tasks, ~20h total
