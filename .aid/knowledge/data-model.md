# Data Model

> **Source:** discovery-analyst
> **Status:** Active
> **Last Updated:** 2026-04-06

## Entities / Schemas

### HexTile (scripts/hex/hex_tile.gd)
Godot Resource representing a single hex tile in the game world.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| coords | Vector2i | (0,0) | Axial coordinates (q, r) | Primary key in HexGrid._tiles dictionary |
| biome | Biome enum (int) | GRASSLAND (1) | 0-4 | CRASH_SITE=0, GRASSLAND=1, FOREST=2, ROCKY=3, WATER=4 |
| elevation | int | 0 | -32000..32000 (clamped in MapLoader) | World Y = elevation * 0.5 |
| fog_state | FogState enum (int) | HIDDEN (0) | 0-1 | HIDDEN=0, VISIBLE=1. Darkness handled by shader, not fog state. |
| props | Array | [] | Array of prop Dictionaries | Unified: resources, structures, anomalies, spawn markers. Each prop has type, category, sub-hex coords (sq, sr), and optional footprint. Replaces former `structure`, `resource_nodes`, `anomaly` fields. |

**Deprecated fields (replaced by props[]):**
- ~~`structure`~~ — now a prop with `category="structure"` in `props[]`
- ~~`resource_nodes`~~ — now props with `category="resource"` in `props[]`
- ~~`anomaly`~~ — now a prop with `category="anomaly"` in `props[]`

Source: `scripts/hex/hex_tile.gd`

### Prop (scripts/hex/prop.gd)
Godot Resource representing any game object placed in a hex tile. Replaces the former separate ResourceNode, structure, and anomaly fields with a unified model.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| type | StringName | &"" | Must match a registry id | e.g. &"wood", &"workbench", &"anomaly_ch1_001" |
| category | Category enum (int) | RESOURCE (0) | 0-3 | RESOURCE=0, STRUCTURE=1, ANOMALY=2, SPAWN=3 |
| sub_hex | Vector2i | (0,0) | Distance from origin <= 2 | Pointy-top axial coords within parent hex (19 valid positions) |
| remaining | int | 0 | 0 to max_amount | Resource only: decremented on gather; 0 = depleted |
| max_amount | int | 0 | Set from BiomeData | Resource only: reset to max on respawn |
| tool_required | StringName | &"" | Empty = bare hands | Resource only: e.g. &"stone_pickaxe" |
| respawn_time | float | 0.0 | Seconds; 0 = no respawn | Resource only: 30.0 common, 60.0 rare |
| rotation_deg | float | 0.0 | Degrees | Visual rotation of prop mesh |
| footprint | Array[Vector2i] | [] | Sub-hex coords | Structure only: multi-sub-hex occupancy (future, F-009) |
| blocks_movement | bool | false | | Structure only: true for walls |

**Factory methods:** `Prop.create_resource()`, `Prop.create_structure()`, `Prop.create_anomaly()`, `Prop.create_spawn()`

Source: `scripts/hex/prop.gd`

### ~~ResourceNode (scripts/hex/resource_node.gd)~~ — DEPRECATED
Replaced by Prop with `category=RESOURCE`. File may still exist as orphan.

### ResourceDef (scripts/data/resource_def.gd)
Godot Resource defining a resource type's static properties. Loaded from `data/resources/*.tres`.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| id | StringName | - | Unique, matches map data | Primary key in ResourceRegistry |
| display_name | String | - | Human-readable | Shown in UI |
| gather_time | float | 1.0 | Seconds | Base time before tool multiplier |
| gather_amount | int | 1 | Per gather action | Added to inventory per harvest |
| tool_required | StringName | &"" | Empty = bare hands | Tool needed to gather |
| respawn_time | float | 30.0 | Seconds; 0 = no respawn | Copied to ResourceNode on map load |
| yield_type | StringName | &"" | Empty = yields self | e.g. loose_rock yields &"stone" |
| tool_speed | Dictionary | {} | StringName -> float | Multiplier; e.g. {&"stone_axe": 0.5} = 2x speed |
| max_stack | int | 99 | Inventory stack limit | 20 for berries/toxic_berries, 50 for crystal |
| category | StringName | &"resource" | &"resource" or &"consumable" | Determines inventory behavior |
| catalog_entry | StringName | - | Matches CatalogEntry.entry_id | Links resource to catalog |
| catalog_category | StringName | - | "flora", "minerals", etc. | For catalog grouping |
| mesh | Mesh | null | Optional real 3D model | Overrides placeholder when set |
| depleted_mesh | Mesh | null | Optional depleted variant | Shown when remaining=0 |
| material | Material | null | Optional material | Not yet used |
| placeholder_mesh_type | StringName | &"cube" | cube/cylinder/sphere/octahedron/prism/box | Procedural mesh type |
| placeholder_params | Dictionary | {} | Type-specific params | e.g. {radius: 0.2, height: 0.8} |
| placeholder_color | Color | WHITE | RGB color | Used for unshaded material |
| placeholder_depleted_type | StringName | &"cube" | Same as mesh_type | Depleted variant shape |
| placeholder_depleted_params | Dictionary | {} | Same as params | Depleted variant params |
| placeholder_depleted_color | Color | GRAY | RGB color | Depleted variant color |

Source: `scripts/data/resource_def.gd`, `data/resources/*.tres`

### BiomeData (scripts/hex/biome_data.gd)
Godot Resource defining per-biome configuration.

| Field | Type | Default | Constraints | Notes |
|-------|------|---------|-------------|-------|
| biome_name | String | "" | Display name | e.g. "Crash Site", "Forest" |
| elevation_range | Vector2i | (0,0) | Min/max elevation | Currently all set to (0,9) |
| resource_table | Array | [] | Array of Dictionaries | Each: {type, chance, min_amount, max_amount, tool_required} |
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
| FLORA | resource_type | StringName | Links to ResourceDef |
| FAUNA | hostile | bool | Determines auto-defend behavior |
| FAUNA | damage | int | Attack damage value |
| FAUNA | hp | int | Health points |
| MINERAL | resource_type | StringName | Links to ResourceDef |
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

### Inventory Slot (scripts/inventory/inventory.gd -- in-memory)
Not a Godot Resource; stored as Dictionary in an Array within the Inventory class.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| type | StringName | &"" | Empty = unused slot |
| quantity | int | 0 | Current stack count |

Tool slots stored separately as Dictionary: `{&"axe": &"", &"pickaxe": &"", &"weapon": &"survival_knife", &"scanner": &"scanner"}`

Source: `scripts/inventory/inventory.gd` lines 24-33

### Item Config (scripts/inventory/inventory.gd -- const)
Hardcoded configuration for non-resource items.

| Item | max_stack | category | tool_slot | Notes |
|------|-----------|----------|-----------|-------|
| meat | 20 | consumable | - | Fauna drop (future) |
| stone_axe | - | tool | axe | Crafted tool |
| stone_pickaxe | - | tool | pickaxe | Crafted tool |
| survival_knife | - | tool | weapon | Starting tool |
| scanner | - | tool | scanner | Starting tool |

Resource items look up max_stack from ResourceRegistry instead of ITEM_CONFIG.

Source: `scripts/inventory/inventory.gd` ITEM_CONFIG

### Recipe Config (scripts/crafting/crafting_system.gd -- const)
Hardcoded recipe definitions.

| Recipe | Ingredients | Output Type | Tool Slot | Discovery Material | Requires Workbench | Pre-discovered |
|--------|-------------|-------------|-----------|--------------------|--------------------|----------------|
| stone_axe | 2 wood + 1 stone | tool | axe | stone | no | yes |
| stone_pickaxe | 3 wood + 2 stone | tool | pickaxe | stone | no | yes |

Source: `scripts/crafting/crafting_system.gd` RECIPE_CONFIG

### Map JSON Schema (data/maps/ch1.json)
Hand-designed map file loaded by MapLoader. Supports both new (props) and legacy formats.

**Root:**
```json
{
  "spawn": [0, 0],
  "tiles": {
    "q,r": { ... }
  }
}
```

**Tile (new format — unified props):**
```json
"0,0": {
  "biome": "crash_site",
  "elevation": 0,
  "props": [
    {"type": "wood", "category": 0, "sub_hex_q": 1, "sub_hex_r": 0, "rotation": 45},
    {"type": "workbench", "category": 1, "sub_hex_q": 0, "sub_hex_r": 0, "blocks_movement": false},
    {"type": "anomaly_ch1_001", "category": 2, "sub_hex_q": 0, "sub_hex_r": -1}
  ]
}
```

**Props fields:**

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| type | string | yes | - | Must match a ResourceDef id, structure name, or anomaly id |
| category | int | yes | 0 | 0=RESOURCE, 1=STRUCTURE, 2=ANOMALY, 3=SPAWN |
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

### Prop (RESOURCE) -> ResourceDef (many:1)
- Prop.type matches ResourceDef.id via ResourceRegistry autoload
- ResourceRegistry.get_def(type) retrieves the definition
- Source: `scripts/hex/prop.gd` (type field), `scripts/data/resource_registry.gd` (lookup)

### ResourceDef -> CatalogEntry (1:1)
- ResourceDef.catalog_entry matches CatalogEntry.entry_id
- e.g. wood -> wood_tree, stone -> stone_deposit, berries -> berry_bush
- Source: `scripts/data/resource_def.gd` (catalog_entry field), `data/catalog/*.tres`

### BiomeData -> ResourceDef (1:many via resource_table)
- BiomeData.resource_table contains {type: string} entries referencing resource types
- Used by MapLoader to set max_amount on ResourceNodes
- Source: `scripts/hex/biome_data.gd`, `data/biomes/*.tres`

### Catalog -> CatalogEntry (1:many)
- Catalog._all_entries: Dictionary keyed by StringName entry_id
- Loaded from 4 CatalogData .tres files at initialization
- Source: `scripts/scanner/catalog.gd` lines 26-40

### Player -> Inventory (1:1, composition)
- Player owns an Inventory instance (created at declaration time, not a scene node)
- Source: `scripts/player/player.gd` line 26

### Inventory -> ResourceDef (many:many, via ResourceRegistry)
- Inventory.add_item() looks up ResourceDef for max_stack and category
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

Source: `scripts/scanner/catalog.gd` (backward compatibility code), `scripts/data/resource_def.gd` (@export defaults)

## Indexes

### In-Memory Indexes (Runtime)

| Index | Structure | Key | Value | Source |
|-------|-----------|-----|-------|--------|
| HexGrid._tiles | Dictionary | Vector2i (axial coords) | HexTile Resource | `hex_grid.gd` line 22 |
| ResourceRegistry._defs | Dictionary | StringName (resource id) | ResourceDef Resource | `resource_registry.gd` line 8 |
| Catalog._all_entries | Dictionary | StringName (entry_id) | CatalogEntry Resource | `catalog.gd` line 15 |
| Catalog._knowledge | Dictionary | StringName (entry_id) | KnowledgeState int | `catalog.gd` line 13 |
| ~~PlayerPathfinder._coord_to_id~~ | ~~Dictionary~~ | ~~Vector2i~~ | ~~int~~ | `player_pathfinder.gd` — **ORPHAN:** Player no longer uses A* pathfinding (joystick pivot). File exists but is unreferenced. May be repurposed for FaunaManager (feature-010). |
| ~~PlayerPathfinder._id_to_coord_map~~ | ~~Dictionary~~ | ~~int~~ | ~~Vector2i~~ | See above. |
| ResourceRenderer._pools | Dictionary | StringName (resource type) | MultiMeshInstance3D | `resource_renderer.gd` line 29 |
| ResourceRenderer._tile_entries | Dictionary | Vector2i (coords) | Array of instance info | `resource_renderer.gd` line 43 |
| PropLabelRenderer._tile_labels | Dictionary | Vector2i (coords) | Array of label info | `prop_label_renderer.gd` line 44 |

### File-Based Indexes

| Index | Mechanism | Source |
|-------|-----------|--------|
| ResourceDef lookup | ResourceRegistry scans data/resources/ directory at startup | `resource_registry.gd` lines 10-21 |
| CatalogEntry lookup | Catalog loads 4 hardcoded .tres file paths | `catalog.gd` lines 28-40 |
| BiomeData lookup | MapLoader and HexGridRenderer use hardcoded path arrays | `map_loader.gd` lines 17-23, `hex_grid_renderer.gd` lines 24-30 |

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

### Inventory Validation
- add_item() validates item type exists in ITEM_CONFIG or ResourceRegistry before adding (`inventory.gd` lines 47-53)
- Tools rejected from resource slots (must use set_tool) (`inventory.gd` lines 53-54)
- Stack overflow tracked; excess returned as int, inventory_full signal emitted (`inventory.gd` lines 82-83)

### Craft Validation (CraftingSystem.craft())
- Recipe must exist in RECIPE_CONFIG (`crafting_system.gd` line 93)
- Workbench proximity required for workbench recipes (`crafting_system.gd` lines 99-101)
- Tool not already owned check (`crafting_system.gd` lines 105-109)
- All ingredients present in inventory (`crafting_system.gd` lines 112-115)
- Emits craft_failed with reason StringName on any validation failure

### Catalog Validation
- encounter_entry() only accepts FAUNA category entries (`catalog.gd` lines 127-129)
- Knowledge state progression: UNKNOWN -> ENCOUNTERED -> CATALOGED (no downgrades) (`catalog.gd` lines 113, 133)
- Duplicate cataloging silently ignored (`catalog.gd` lines 111-112)

### Auto-Gather Gating
- Resource must not be depleted (remaining > 0) (`auto_interaction_system.gd` line 195)
- Resource must have a catalog_entry that is CATALOGED (`auto_interaction_system.gd` lines 199-203)
- Player must have correct tool equipped (`auto_interaction_system.gd` lines 206-207)
- Resource must be within GATHER_RADIUS (0.75 world units) of player position (`auto_interaction_system.gd` lines 218-219)

## Current Resource Definitions

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

Source: `data/resources/*.tres`

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
