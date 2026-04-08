class_name PropDef extends Resource

## Unique identifier — numeric StringName matching the .tres filename (e.g. &"00010").
## Used as item type in inventory, prop type in maps, and tool id in equipment slots.
@export var id: StringName

## Human-readable name for UI
@export var display_name: String

# --- Gathering ---
@export var gather_time: float = 1.0
@export var gather_amount: int = 1
@export var tool_required: StringName = &""
@export var respawn_time: float = 30.0
## If set, gathering this yields a different item (e.g. loose_rock → stone). Empty = yields self.
@export var yield_type: StringName = &""

# --- Tool speed multipliers (applied when tool equipped) ---
## Key: tool PropDef id (numeric, e.g. &"00201" for axe). Value: multiplier float (0.5 = 2x faster).
@export var tool_speed: Dictionary = {}

# --- Inventory ---
@export var max_stack: int = 99
@export var category: StringName = &"prop"

# --- Catalog ---
@export var catalog_entry: StringName
@export var catalog_category: StringName  # "minerals", "flora", "fauna", "anomalies"

# --- Placement ---
## Prop.Category index (0=Plant..9=Storage). Determines behavior when placed on map.
@export var prop_category: int = 0
## Prop.Origin index (0=Natural..4=Unknown). Determines scan/anomaly state.
@export var origin: int = 0
## Sub-hex offsets this prop occupies relative to anchor. Empty = single cell at anchor.
@export var footprint: Array[Vector2i] = []

# --- Gameplay Properties ---
## Whether this prop emits light (e.g. torches, campfires). Used by day/night visibility.
@export var emits_light: bool = false
## Light radius in sub-hex rings (1=placement cell, 2=first ring, etc). Only used when emits_light is true.
@export var light_radius: int = 0
## Whether this prop serves as a player respawn point (e.g. shelters).
@export var is_respawn_point: bool = false
## Whether crafting recipes can use this prop as a crafting station.
@export var is_crafting_station: bool = false
## Tool slot this item occupies when equipped (e.g. "axe", "pickaxe", "weapon", "scanner").
## Empty = not a tool.
@export var tool_slot: StringName = &""
## Whether this item can be consumed (eaten/drunk/used-up) from the inventory.
@export var is_consumable: bool = false
## Hunger restored when consumed (only used if is_consumable = true).
@export var hunger_restore: float = 0.0
## Thirst restored when consumed (only used if is_consumable = true).
@export var thirst_restore: float = 0.0
## Health restored when consumed. Negative values represent damage (e.g. toxic items).
@export var health_amount: float = 0.0

# --- Visual: Real assets (override placeholders when set) ---
@export var mesh: Mesh
@export var depleted_mesh: Mesh
@export var material: Material

# --- Visual: Placeholders (used when mesh is null) ---
@export var placeholder_mesh_type: StringName = &"cube"  # cube, cylinder, sphere, octahedron, prism, box
@export var placeholder_params: Dictionary = {}  # e.g. {"half_size": 0.35} or {"radius": 0.2, "height": 0.8}
@export var placeholder_color: Color = Color.WHITE
@export var placeholder_depleted_type: StringName = &"cube"
@export var placeholder_depleted_params: Dictionary = {}
@export var placeholder_depleted_color: Color = Color.GRAY
