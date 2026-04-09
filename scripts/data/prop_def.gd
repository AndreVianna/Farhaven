class_name PropDef extends Resource

## Unique identifier — numeric StringName matching the .tres filename (e.g. &"00010").
## Used as item type in inventory, prop type in maps, and tool id in equipment slots.
@export var id: StringName

## Human-readable name for UI
@export var display_name: String

# --- Tags ---
## Free-form labels (e.g. &"SOURCE", &"WOOD", &"BURNABLE.log", &"CONSUMABLE.edible").
@export var tags: Array[StringName] = []

# --- Capabilities ---
## Each capability is a small inner Resource, null when not present.
@export var portable: PortableCap = null
@export var placeable: PlaceableCap = null
@export var container: ContainerCap = null
@export var light: LightCap = null
@export var movable: MovableCap = null
@export var station: StationCap = null
@export var catalogable: CatalogableCap = null

# --- Inventory ---
## Temporary — kept during transition, will be replaced by PORTABLE.weight in task-049.
@export var max_stack: int = 99

# --- Placement ---
## Prop.Origin index (0=Natural..4=Unknown). Determines scan/anomaly state.
@export var origin: int = 0
## DEPRECATED: use placeable.footprint instead. Kept for backward compat.
## Sub-hex offsets this prop occupies relative to anchor. Empty = single cell at anchor.
@export var footprint: Array[Vector2i] = []

# --- Tool ---
## Tool slot this item occupies when equipped (e.g. "axe", "pickaxe", "weapon", "scanner").
## Empty = not a tool. Kept per design decision (Open Question §11.6).
@export var tool_slot: StringName = &""

# --- Gathering (DEPRECATED — replaced by Recipe system; kept for legacy fallback) ---
@export var gather_time: float = 1.0
@export var gather_amount: int = 1
@export var tool_required: StringName = &""
@export var respawn_time: float = 30.0
@export var yield_type: StringName = &""
@export var tool_speed: Dictionary = {}

# --- Consumable (DEPRECATED — replaced by eat_*/drink_* recipes; kept for legacy fallback) ---
@export var is_consumable: bool = false
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var health_restore: float = 0.0

# --- Legacy fields (DEPRECATED — replaced by capabilities/tags; kept for backward compat) ---
## Loose typology ("prop"/"resource"/"consumable"/"structure"/"tool") — replaced by capabilities + tags.
@export var category: StringName = &"prop"
## Prop.Category enum index (0=Plant..9=Storage) — replaced by capabilities.
@export var prop_category: int = 0
## Whether this prop emits light — replaced by LightCap capability.
@export var emits_light: bool = false
## Light radius — replaced by LightCap.radius.
@export var light_radius: int = 0
## Whether this prop is a respawn point — replaced by STATION capability with "respawn" tag.
@export var is_respawn_point: bool = false
## Whether this prop is a crafting station — replaced by STATION capability with "craft" tag.
@export var is_crafting_station: bool = false

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
		&"movable": return movable != null
		&"station": return station != null
		&"catalogable": return catalogable != null
	return false


## Returns true if this PropDef's tags array contains the given tag.
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
