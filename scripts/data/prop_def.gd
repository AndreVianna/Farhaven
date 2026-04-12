class_name PropDef extends Gear

# --- Tags ---
## Free-form labels (e.g. &"SOURCE", &"WOOD", &"BURNABLE.log", &"CONSUMABLE.edible").
@export var tags: Array[StringName] = []

# --- Capabilities ---
## Each capability is a small inner Resource, null when not present.
@export var portable: PortableCap = null
@export var placeable: PlaceableCap = null
@export var container: ContainerCap = null
@export var light: LightCap = null
@export var station: StationCap = null
@export var catalogable: CatalogableCap = null
@export var endurance: EnduranceCap = null
@export var movement: MovementCap = null
@export var combat: CombatCap = null
@export var behavior: BehaviorCap = null
@export var spawnable: SpawnableCap = null

# --- Inventory ---
## Temporary — kept during transition, will be replaced by PORTABLE.weight in task-049.
@export var max_stack: int = 99

# --- Placement ---
## Prop.Origin index (0=Natural..4=Unknown). Determines scan/anomaly state.
@export var origin: int = 0
## DEPRECATED in task-053: use placeable.footprint instead. Kept for backward compat.
## Sub-hex offsets this prop occupies relative to anchor. Empty = single cell at anchor.
@export var footprint: Array[Vector2i] = []  # DEPRECATED: use placeable.footprint

# --- Tool ---
## Tool slot this item occupies when equipped (e.g. "axe", "pickaxe", "weapon", "scanner").
## Empty = not a tool. Kept per design decision (Open Question §11.6).
@export var tool_slot: StringName = &""

## Actions this prop can perform when used as a tool (e.g., [&"chop"], [&"mine"], [&"attack_melee"]).
## Used by Inventory.find_best_tool_for_action() to locate the right tool in the grid.
## Empty for non-tool props. Authored per PropDef in task-095 (content migration).
@export var supports_actions: Array[StringName] = []

# --- Gathering (DEPRECATED — replaced by Recipe system; kept for legacy fallback) ---
# DEPRECATED in task-053: remove when legacy gather fallback in AutoInteractionSystem is removed.
@export var gather_time: float = 1.0   # DEPRECATED: use Recipe.duration
@export var gather_amount: int = 1     # DEPRECATED: use RecipeOutput.count
@export var tool_required: StringName = &""  # DEPRECATED: use Recipe condition has_tool
@export var respawn_time: float = 30.0  # DEPRECATED: use Recipe system
@export var yield_type: StringName = &""  # DEPRECATED: use RecipeOutput.prop_ref
@export var tool_speed: Dictionary = {}  # DEPRECATED: use Recipe.duration per tool

# --- Consumable (DEPRECATED — replaced by eat_*/drink_* recipes; kept for legacy fallback) ---
# DEPRECATED in task-053: remove when eat_*/drink_* recipes fully replace consumable fields.
@export var is_consumable: bool = false   # DEPRECATED: use Recipe with stat_delta effect
@export var hunger_restore: float = 0.0   # DEPRECATED: use stat_delta effect params
@export var thirst_restore: float = 0.0   # DEPRECATED: use stat_delta effect params
@export var health_restore: float = 0.0   # DEPRECATED: use stat_delta effect params

# --- Legacy fields (DEPRECATED — replaced by capabilities/tags; kept for backward compat) ---
# DEPRECATED in task-053: remove when all callers migrate to capabilities/tags.
@export var category: StringName = &"prop"  # DEPRECATED: use capabilities + tags
@export var prop_category: int = 0  # DEPRECATED: use capabilities
@export var emits_light: bool = false  # DEPRECATED: use light != null (LightCap)
@export var light_radius: int = 0  # DEPRECATED: use light.radius (LightCap)
@export var is_respawn_point: bool = false  # DEPRECATED: use station cap with "respawn" tag
@export var is_crafting_station: bool = false  # DEPRECATED: use station cap with "craft" tag

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


## Returns true if the named capability is present (non-null) on this PropDef.
func has_capability(cap_name: StringName) -> bool:
	match cap_name:
		&"portable": return portable != null
		&"placeable": return placeable != null
		&"container": return container != null
		&"light": return light != null
		&"station": return station != null
		&"catalogable": return catalogable != null
		&"endurance": return endurance != null
		&"movement": return movement != null
		&"combat": return combat != null
		&"behavior": return behavior != null
		&"spawnable": return spawnable != null
	return false


## Returns true if this PropDef's tags array contains the given tag.
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
