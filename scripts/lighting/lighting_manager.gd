extends Node

## Autoload singleton — tracks active light sources (placed structures + player torch).
## Provides light data to the terrain shader for local lighting at night.
## task-039: Local Lighting System

const _PropDef = preload("res://scripts/data/prop_def.gd")

## Maximum simultaneous lights the shader supports.
const MAX_LIGHTS: int = 8

## Default light color for props that don't specify one (warm orange fire glow).
const DEFAULT_LIGHT_COLOR: Color = Color(1.0, 0.8, 0.4)

## Sub-hex ring to world-unit conversion. Each ring is roughly one hex width.
const RING_TO_WORLD: float = 3.0

# --- Signals ---
signal light_source_registered(position: Vector2, radius: float)
signal light_source_unregistered(position: Vector2)
signal light_source_moved(position: Vector2)

# --- Injectable dependencies (set before _ready for testing) ---
var _grid: Node = null      # HexGrid autoload or mock
var _dnc: Node = null       # DayNightCycle autoload or mock
var _registry: Node = null  # PropRegistry autoload or mock

# --- State ---

## Active structure lights: key = "coords:prop_type" string, value = light dict.
## Light dict: {position: Vector2, radius: float, color: Color}
var _structure_lights: Dictionary = {}

## Player-carried torch light (empty dict when not active).
var _player_light: Dictionary = {}

## Cached player position for torch tracking.
var _player_world_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	if _dnc == null:
		_dnc = DayNightCycle
	if _registry == null:
		_registry = PropRegistry
	_connect_signals()


func _connect_signals() -> void:
	if _grid:
		if _grid.has_signal("structure_placed"):
			_grid.structure_placed.connect(_on_structure_placed)
		if _grid.has_signal("structure_destroyed"):
			_grid.structure_destroyed.connect(_on_structure_destroyed)
		if _grid.has_signal("tile_entered"):
			_grid.tile_entered.connect(_on_tile_entered)


# --- Public API ---

## Returns array of active light dictionaries for shader consumption.
## Each entry: {position: Vector2, radius: float, color: Color}
## During day phases, returns an empty array (sun overrides local lights).
func get_active_lights() -> Array[Dictionary]:
	if _is_day_phase():
		return []
	var lights: Array[Dictionary] = []
	for key: Variant in _structure_lights:
		lights.append(_structure_lights[key])
	if not _player_light.is_empty():
		lights.append(_player_light)
	return lights


## Returns the number of registered structure lights (excludes player torch).
func get_structure_light_count() -> int:
	return _structure_lights.size()


## Returns whether the lighting system should be visually active.
func is_night_active() -> bool:
	return not _is_day_phase()


## Scan all tiles for existing light-emitting props and register them.
## Called after map load or save load to restore lights that were placed
## before the current session (structure_placed signal doesn't fire on load).
func scan_existing_lights() -> void:
	_structure_lights.clear()
	if _grid == null or _registry == null:
		return
	var tiles: Dictionary = _grid.get_all_tiles() if _grid.has_method("get_all_tiles") else {}
	if tiles.is_empty():
		return
	for coords: Vector2i in tiles:
		var tile: Resource = tiles[coords]
		if tile == null:
			continue
		for prop in tile.props:
			var def = _registry.get_def(prop.type) if _registry.has_method("get_def") else null
			if def == null:
				continue
			if def.light == null:
				continue
			var world_pos: Vector2 = HexMath.axial_to_world(coords)
			var radius: float = def.light.radius * RING_TO_WORLD if def.light.radius > 0.0 else 3.0 * RING_TO_WORLD
			var sub_hex: Vector2i = prop.sub_hex if "sub_hex" in prop else Vector2i.ZERO
			var key: String = "%s:%s:%s" % [str(coords), str(prop.type), str(sub_hex)]
			var color: Color = def.light.color if def.light.color != Color() else DEFAULT_LIGHT_COLOR
			_structure_lights[key] = {
				"position": world_pos,
				"radius": radius,
				"color": color,
			}


## Manually register a light source (for testing or dynamic lights).
func register_light(key: String, position: Vector2, radius: float, color: Color = DEFAULT_LIGHT_COLOR) -> void:
	_structure_lights[key] = {
		"position": position,
		"radius": radius,
		"color": color,
	}
	light_source_registered.emit(position, radius)


## Manually unregister a light source.
func unregister_light(key: String) -> void:
	if _structure_lights.has(key):
		var pos: Vector2 = _structure_lights[key]["position"]
		_structure_lights.erase(key)
		light_source_unregistered.emit(pos)


## Set player torch light directly (used by external systems or tests).
func set_player_light(position: Vector2, radius: float, color: Color = DEFAULT_LIGHT_COLOR) -> void:
	_player_light = {
		"position": position,
		"radius": radius,
		"color": color,
	}
	light_source_registered.emit(position, radius)


## Clear the player torch light.
func clear_player_light() -> void:
	if not _player_light.is_empty():
		var pos: Vector2 = _player_light.get("position", Vector2.ZERO)
		_player_light = {}
		light_source_unregistered.emit(pos)


## Initialize player torch on game load. Called from main.gd with direct player ref
## because _find_player() uses groups which may not be populated during deferred startup.
func initialize_player_torch(player: Node) -> void:
	if player == null:
		return
	if "current_tile" in player:
		_player_world_pos = HexMath.axial_to_world(player.current_tile)
	_update_torch_from_player(player)


## Update player torch state from current inventory.
## Called when tool equipment changes or on tile enter.
func update_player_torch() -> void:
	var player: Node = _find_player()
	if player == null:
		_clear_player_light_internal()
		return
	if "current_tile" in player:
		_player_world_pos = HexMath.axial_to_world(player.current_tile)
	_update_torch_from_player(player)


func _update_torch_from_player(player: Node) -> void:
	var inv: RefCounted = player.get_inventory() if player.has_method("get_inventory") else null
	if inv == null:
		_clear_player_light_internal()
		return
	# Check all tool slots for an item with light capability
	var found_light: bool = false
	var light_radius: float = 3.0 * RING_TO_WORLD
	for slot: StringName in [&"axe", &"pickaxe", &"weapon", &"scanner", &"firestarter"]:
		var tool_id: StringName = inv.get_tool(slot)
		if tool_id == &"":
			continue
		var def: _PropDef = _registry.get_def(tool_id) if _registry else null
		if def != null and def.light != null:
			found_light = true
			light_radius = def.light.radius * RING_TO_WORLD if def.light.radius > 0.0 else 3.0 * RING_TO_WORLD
			break
	if found_light:
		_player_light = {
			"position": _player_world_pos,
			"radius": light_radius,
			"color": DEFAULT_LIGHT_COLOR,
		}
	else:
		_clear_player_light_internal()


# --- Signal handlers ---

func _on_structure_placed(coords: Vector2i, structure_type: StringName) -> void:
	var def: _PropDef = _registry.get_def(structure_type) if _registry else null
	if def == null or def.light == null:
		return
	var world_pos: Vector2 = HexMath.axial_to_world(coords)
	var radius: float = def.light.radius * RING_TO_WORLD if def.light.radius > 0.0 else 3.0 * RING_TO_WORLD
	var color: Color = def.light.color if def.light.color != Color() else DEFAULT_LIGHT_COLOR
	var key: String = "%s:%s" % [str(coords), str(structure_type)]
	_structure_lights[key] = {
		"position": world_pos,
		"radius": radius,
		"color": color,
	}
	light_source_registered.emit(world_pos, radius)


func _on_structure_destroyed(coords: Vector2i, structure_type: StringName) -> void:
	var key: String = "%s:%s" % [str(coords), str(structure_type)]
	if _structure_lights.has(key):
		var pos: Vector2 = _structure_lights[key]["position"]
		_structure_lights.erase(key)
		light_source_unregistered.emit(pos)


func _on_tile_entered(coords: Vector2i) -> void:
	_player_world_pos = HexMath.axial_to_world(coords)
	if not _player_light.is_empty():
		_player_light["position"] = _player_world_pos
		light_source_moved.emit(_player_world_pos)


# --- Internal helpers ---

func _is_day_phase() -> bool:
	if _dnc == null:
		return true
	var phase: int = _dnc.current_phase
	# DAY and DAWN are "day" phases — no local lighting effect
	return phase == 0 or phase == 3  # TimePhase.DAY == 0, TimePhase.DAWN == 3


func _clear_player_light_internal() -> void:
	if not _player_light.is_empty():
		var pos: Vector2 = _player_light.get("position", Vector2.ZERO)
		_player_light = {}
		light_source_unregistered.emit(pos)


func _find_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var players: Array[Node] = tree.get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
