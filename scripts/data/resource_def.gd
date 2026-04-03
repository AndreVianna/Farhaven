class_name ResourceDef extends Resource

## Unique identifier — must match the StringName used in map data (e.g. &"wood")
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
## Key: tool StringName, Value: multiplier float. E.g. {"stone_axe": 0.5}
@export var tool_speed: Dictionary = {}

# --- Inventory ---
@export var max_stack: int = 99
@export var category: StringName = &"resource"

# --- Catalog ---
@export var catalog_entry: StringName
@export var catalog_category: StringName  # "minerals", "flora", "fauna", "anomalies"

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
