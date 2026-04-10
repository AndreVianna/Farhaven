extends Node

## Manages transient fauna entities during nighttime.
## Child of Player. Fauna spawn at night (Day 4+), move toward player,
## deal contact damage, and despawn at dawn.
## task-037: FaunaManager — spawn, AI, contact, despawn

const _Prop = preload("res://scripts/hex/prop.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

# --- Config ---
const FAUNA_CONFIG: Dictionary = {
	"hp": 20,
	"contact_damage": 10,
	"move_cooldown": 1.0,
	"detection_range": 2,
	"spawn_min": 1,
	"spawn_max": 3,
	"first_spawn_day": 4,
	"spawn_min_distance": 3,
}

const CHAPTER1_SPECIES: Array[StringName] = [&"thornback"]

# --- Signals ---
signal fauna_spawned(id: int, coords: Vector2i, species_type: StringName)
signal fauna_moved(id: int, old_coords: Vector2i, new_coords: Vector2i, species_type: StringName)
signal fauna_attacked_player(id: int, damage: int, species_type: StringName)
signal fauna_killed(id: int, coords: Vector2i, species_type: StringName)
signal fauna_despawned(id: int, coords: Vector2i, species_type: StringName)
signal fauna_surprise_encounter(id: int, coords: Vector2i, species_type: StringName)

# --- Injectable dependencies (set before _ready for testing) ---
var _grid: Node = null       # HexGrid autoload or mock
var _dnc: Node = null        # DayNightCycle autoload or mock
var _lighting: Node = null   # LightingManager autoload or mock
var _registry: Node = null   # PropRegistry autoload or mock

# --- State ---
var _fauna: Array[Dictionary] = []
var _next_id: int = 0

# --- Player reference ---
var _player: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = _get_autoload(&"HexGrid")
	if _dnc == null:
		_dnc = _get_autoload(&"DayNightCycle")
	if _lighting == null:
		_lighting = _get_autoload(&"LightingManager")
	if _registry == null:
		_registry = _get_autoload(&"PropRegistry")
	_connect_signals()


func _connect_signals() -> void:
	if _dnc:
		if _dnc.has_signal("night"):
			_dnc.night.connect(_on_night)
		if _dnc.has_signal("dawn"):
			_dnc.dawn.connect(_on_dawn)


func _process(delta: float) -> void:
	if _dnc == null:
		return
	# Only process during NIGHT phase (phase == 2)
	if _dnc.current_phase != 2:
		return
	if _fauna.is_empty():
		return
	_update_cooldowns_and_move(delta)


# --- Spawn ---

func _on_night() -> void:
	if _dnc == null:
		return
	if _dnc.day_count < FAUNA_CONFIG["first_spawn_day"]:
		return
	_spawn_fauna()


func _spawn_fauna() -> void:
	var player_coords := _get_player_coords()
	var candidates := _get_spawn_candidates(player_coords)
	if candidates.is_empty():
		return

	var count: int = randi_range(FAUNA_CONFIG["spawn_min"], FAUNA_CONFIG["spawn_max"])
	count = mini(count, candidates.size())
	candidates.shuffle()

	for i in count:
		var coords: Vector2i = candidates[i]
		var species: StringName = CHAPTER1_SPECIES[0]
		var fauna_entry: Dictionary = {
			"id": _next_id,
			"species_type": species,
			"coords": coords,
			"hp": FAUNA_CONFIG["hp"],
			"move_cooldown": FAUNA_CONFIG["move_cooldown"],
			"cooldown_remaining": 0.0,
			"was_in_light": false,
		}
		_fauna.append(fauna_entry)
		fauna_spawned.emit(_next_id, coords, species)
		_next_id += 1


func _get_spawn_candidates(player_coords: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	if _grid == null:
		return candidates
	var all_tiles: Dictionary = _grid.get_all_tiles() if _grid.has_method("get_all_tiles") else {}
	var active_lights: Array[Dictionary] = _get_active_lights()

	for coords: Vector2i in all_tiles:
		if not _is_valid_spawn_tile(coords, player_coords, all_tiles, active_lights):
			continue
		candidates.append(coords)
	return candidates


func _is_valid_spawn_tile(coords: Vector2i, player_coords: Vector2i,
		all_tiles: Dictionary, active_lights: Array[Dictionary]) -> bool:
	var tile: Resource = all_tiles.get(coords, null)
	if tile == null:
		return false

	# Must be passable from itself (not water, not blocked)
	if _grid.has_method("get_traversal"):
		var traversal: int = _grid.get_traversal(coords, coords)
		if traversal == 3:  # BLOCKED
			return false
	# Check biome (no water)
	if "biome" in tile and tile.biome == 4:  # WATER
		return false

	# No structure props on tile
	if _has_structure_on_tile(tile):
		return false

	# Distance >= spawn_min_distance from player
	var dist: int = _HexMath.distance(coords, player_coords)
	if dist < FAUNA_CONFIG["spawn_min_distance"]:
		return false

	# Not within any active light radius
	if _is_tile_lit(coords, active_lights):
		return false

	return true


func _is_tile_lit(coords: Vector2i, active_lights: Array[Dictionary]) -> bool:
	var tile_world: Vector2 = _HexMath.axial_to_world(coords)
	for light: Dictionary in active_lights:
		var light_pos: Vector2 = light.get("position", Vector2.ZERO)
		var light_radius: float = light.get("radius", 0.0)
		if tile_world.distance_to(light_pos) <= light_radius:
			return true
	return false


# --- AI Movement ---

func _update_cooldowns_and_move(delta: float) -> void:
	var player_coords := _get_player_coords()
	var active_lights: Array[Dictionary] = _get_active_lights()
	var active_fauna_ids: Array[int] = []

	for fauna: Dictionary in _fauna:
		fauna["cooldown_remaining"] -= delta
		if fauna["cooldown_remaining"] > 0.0:
			continue
		fauna["cooldown_remaining"] = fauna["move_cooldown"]
		active_fauna_ids.append(fauna["id"])

		var fauna_coords: Vector2i = fauna["coords"]
		var dist_to_player: int = _HexMath.distance(fauna_coords, player_coords)

		# Only move if within detection range
		if dist_to_player > FAUNA_CONFIG["detection_range"]:
			continue

		var best_neighbor := _find_best_move(fauna, player_coords, active_lights)
		if best_neighbor != Vector2i(-99999, -99999):
			var old_coords: Vector2i = fauna["coords"]
			# Check surprise encounter: fauna was outside light, now entering player adjacency
			var was_in_light: bool = fauna.get("was_in_light", false)
			fauna["coords"] = best_neighbor
			var now_in_light: bool = _is_tile_lit(best_neighbor, active_lights)
			var is_now_adjacent: bool = _HexMath.distance(best_neighbor, player_coords) <= 1
			if not was_in_light and is_now_adjacent:
				fauna_surprise_encounter.emit(fauna["id"], best_neighbor, fauna["species_type"])
			fauna["was_in_light"] = now_in_light
			fauna_moved.emit(fauna["id"], old_coords, best_neighbor, fauna["species_type"])

	# Contact damage check (only for fauna whose cooldown expired this frame)
	_check_contact_damage(player_coords, active_fauna_ids)


func _find_best_move(fauna: Dictionary, player_coords: Vector2i,
		active_lights: Array[Dictionary]) -> Vector2i:
	var fauna_coords: Vector2i = fauna["coords"]
	var neighbors: Array[Vector2i] = _HexMath.get_neighbors(fauna_coords)
	var best_coords := Vector2i(-99999, -99999)
	var best_dist: int = _HexMath.distance(fauna_coords, player_coords)

	for neighbor: Vector2i in neighbors:
		# Check tile exists
		if _grid == null or not _grid.has_tile(neighbor):
			continue
		# Check passability with fauna-specific rules
		if not _is_fauna_passable(fauna_coords, neighbor, 1):
			continue
		# Avoid lit tiles
		if _is_tile_lit(neighbor, active_lights):
			continue
		# No stacking (one fauna per tile)
		if _is_fauna_at(neighbor):
			continue
		var dist: int = _HexMath.distance(neighbor, player_coords)
		if dist < best_dist:
			best_dist = dist
			best_coords = neighbor

	return best_coords


func _is_fauna_passable(from: Vector2i, to: Vector2i, max_jump: int) -> bool:
	if _grid == null:
		return false
	if not _grid.has_tile(to):
		return false
	# Get tile to check biome and blocking props
	var tile_to: Resource = _grid.get_tile(to)
	if tile_to == null:
		return false
	# Water blocked
	if "biome" in tile_to and tile_to.biome == 4:
		return false
	# Check blocking props (data-driven via BLOCKS_MOVEMENT tag).
	for prop in tile_to.props:
		if PropRegistry.has_def(prop.type):
			var def = PropRegistry.get_def(prop.type)
			if def.has_tag(&"BLOCKS_MOVEMENT"):
				return false
	# Check elevation difference (max_jump for thornback = 1)
	if _grid.has_method("get_elevation_diff"):
		var elev_diff: int = _grid.get_elevation_diff(from, to)
		if elev_diff > max_jump:
			return false
	return true


func _is_fauna_at(coords: Vector2i) -> bool:
	for fauna: Dictionary in _fauna:
		if fauna["coords"] == coords:
			return true
	return false


# --- Contact Damage ---

func _check_contact_damage(player_coords: Vector2i, active_ids: Array[int] = []) -> void:
	for fauna: Dictionary in _fauna:
		# Only fauna that processed a turn this frame can deal contact damage
		if not active_ids.has(fauna["id"]):
			continue
		var dist: int = _HexMath.distance(fauna["coords"], player_coords)
		if dist > 1:
			continue
		# Adjacent or on same tile — check shelter
		var damage: int = FAUNA_CONFIG["contact_damage"]
		if _is_player_sheltered(player_coords):
			damage = 0
		fauna_attacked_player.emit(fauna["id"], damage, fauna["species_type"])


func _is_player_sheltered(player_coords: Vector2i) -> bool:
	if _grid == null:
		return false
	var tile: Resource = _grid.get_tile(player_coords)
	if tile == null:
		return false
	if _registry == null:
		return false
	# Check for STATION with respawn tag (shelter)
	for prop in tile.props:
		var prop_type: StringName = prop.type if "type" in prop else &""
		if prop_type == &"":
			continue
		var has_def: bool = _registry.has_def(prop_type) if _registry.has_method("has_def") else false
		if not has_def:
			continue
		var def = _registry.get_def(prop_type)
		if def != null and def.station != null and def.station.station_tags.has(&"respawn"):
			return true
	return false


# --- Apply Damage ---

func apply_damage(fauna_id: int, damage: int) -> void:
	var fauna := _find_fauna(fauna_id)
	if fauna.is_empty():
		return
	fauna["hp"] -= damage
	if fauna["hp"] <= 0:
		_on_fauna_death(fauna)


func _on_fauna_death(fauna: Dictionary) -> void:
	var coords: Vector2i = fauna["coords"]
	var species: StringName = fauna["species_type"]
	var fauna_id: int = fauna["id"]

	# Place corpse prop on tile
	_place_corpse(coords, species)

	# Remove from fauna list
	_fauna.erase(fauna)

	# Emit signal
	fauna_killed.emit(fauna_id, coords, species)


func _place_corpse(coords: Vector2i, species_type: StringName) -> void:
	if _grid == null:
		return
	var tile: Resource = _grid.get_tile(coords)
	if tile == null:
		return
	var corpse_type: StringName = _get_corpse_type(species_type)
	var corpse := _Prop.create_prop(corpse_type, 1, 1)
	tile.props.append(corpse)


func _get_corpse_type(species_type: StringName) -> StringName:
	match species_type:
		&"thornback":
			return &"P00107"
	return &"P00107"  # Default fallback


# --- Despawn ---

func _on_dawn() -> void:
	for fauna: Dictionary in _fauna.duplicate():
		fauna_despawned.emit(fauna["id"], fauna["coords"], fauna["species_type"])
	_fauna.clear()


# --- Public API ---

func get_fauna_at(coords: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fauna: Dictionary in _fauna:
		if fauna["coords"] == coords:
			result.append(fauna.duplicate())
	return result


func get_fauna_adjacent_to(coords: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fauna: Dictionary in _fauna:
		var dist: int = _HexMath.distance(fauna["coords"], coords)
		if dist == 1:
			result.append(fauna.duplicate())
	return result


func get_all_fauna() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fauna: Dictionary in _fauna:
		result.append(fauna.duplicate())
	return result


# --- Helpers ---

func _get_player_coords() -> Vector2i:
	if _player == null:
		_player = get_parent()
	if _player != null and "current_tile" in _player:
		return _player.current_tile
	return Vector2i.ZERO


func _get_active_lights() -> Array[Dictionary]:
	if _lighting == null:
		return []
	if _lighting.has_method("get_active_lights"):
		return _lighting.get_active_lights()
	return []


func _find_fauna(fauna_id: int) -> Dictionary:
	for fauna: Dictionary in _fauna:
		if fauna["id"] == fauna_id:
			return fauna
	return {}


func _has_structure_on_tile(tile: Resource) -> bool:
	if tile == null:
		return false
	# Try tag-based lookup (uses PropRegistry internally)
	if tile.has_method("get_props_with_tag"):
		var structures: Array = tile.get_props_with_tag(&"STRUCTURE")
		if not structures.is_empty():
			return true
	# Fallback: check props directly for structure category or blocking
	for prop in tile.props:
		if "category" in prop and prop.category == 6:  # STRUCTURE category
			return true
	return false


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
