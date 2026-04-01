extends Node

## Autoload singleton — map container, public API, signals.
## All cross-feature interaction with the hex grid goes through this node.
## Uses preload because autoloads initialize before class_name registration.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")

const MAX_ELEVATION_DIFF: int = 1

# Structures that do NOT block movement (walkable)
const WALKABLE_STRUCTURES: Array[StringName] = [&"shelter", &"torch"]

var _tiles: Dictionary = {}  # Vector2i -> HexTile
var _seed: int = 0

# --- Signals ---
signal map_generated()
signal tile_revealed(coords: Vector2i)
signal tile_visibility_changed(coords: Vector2i, state: int)  # int = HexTile.FogState
signal tile_entered(coords: Vector2i)
signal tile_exited(coords: Vector2i)
signal resource_depleted(coords: Vector2i, resource_type: StringName)
signal resource_respawned(coords: Vector2i, resource_type: StringName)
signal tile_contents_changed(coords: Vector2i)
signal structure_placed(coords: Vector2i, structure_type: StringName)
signal structure_destroyed(coords: Vector2i, structure_type: StringName)


# --- Tile queries ---

func get_tile(coords: Vector2i) -> Resource:
	return _tiles.get(coords, null)


func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
	var all_neighbors: Array[Vector2i] = _HexMath.get_neighbors(coords)
	var result: Array[Vector2i] = []
	for n in all_neighbors:
		if _tiles.has(n):
			result.append(n)
	return result


func get_tiles_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var all_coords: Array[Vector2i] = _HexMath.get_tiles_in_range(center, radius)
	var result: Array[Vector2i] = []
	for c in all_coords:
		if _tiles.has(c):
			result.append(c)
	return result


func distance(a: Vector2i, b: Vector2i) -> int:
	return _HexMath.distance(a, b)


# --- Traversability ---

func is_passable(from: Vector2i, to: Vector2i) -> bool:
	var tile: Resource = _tiles.get(to, null)
	if tile == null:
		return false
	if tile.biome == _HexTile.Biome.WATER:
		return false
	if get_elevation_diff(from, to) > MAX_ELEVATION_DIFF:
		return false
	if tile.structure != &"":
		if not (tile.structure as StringName) in WALKABLE_STRUCTURES:
			return false
	return true


func get_elevation_diff(from: Vector2i, to: Vector2i) -> int:
	var tile_from: Resource = _tiles.get(from, null)
	var tile_to: Resource = _tiles.get(to, null)
	if tile_from == null or tile_to == null:
		return 999
	return abs(int(tile_to.elevation) - int(tile_from.elevation))


# --- Fog of War ---

## Demote all VISIBLE→REVEALED, then promote tiles within each source radius
## to VISIBLE. Emits tile_revealed for HIDDEN→non-HIDDEN and
## tile_visibility_changed for all fog state changes.
## sources: Array of {coords: Vector2i, radius: int}
func refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	var VISIBLE: int = _HexTile.FogState.VISIBLE
	var REVEALED: int = _HexTile.FogState.REVEALED
	var HIDDEN: int = _HexTile.FogState.HIDDEN

	# Demote VISIBLE → REVEALED
	for coords in _tiles:
		var tile: Resource = _tiles[coords]
		if tile.fog_state == VISIBLE:
			tile.fog_state = REVEALED
			changed.append(coords)

	# Promote tiles within each source radius
	for source in sources:
		var center: Vector2i = source["coords"]
		var radius: int = source["radius"]
		var in_range: Array[Vector2i] = _HexMath.get_tiles_in_range(center, radius)
		for coords in in_range:
			var tile: Resource = _tiles.get(coords, null)
			if tile == null:
				continue
			var was_hidden: bool = tile.fog_state == HIDDEN
			if tile.fog_state != VISIBLE:
				tile.fog_state = VISIBLE
				if was_hidden:
					tile_revealed.emit(coords)
				if not coords in changed:
					changed.append(coords)

	# Emit visibility changed for all affected tiles
	for coords in changed:
		var tile: Resource = _tiles.get(coords, null)
		if tile != null:
			tile_visibility_changed.emit(coords, tile.fog_state)

	return changed


# --- Coordinate conversions ---

func axial_to_cube(coords: Vector2i) -> Vector3i:
	return _HexMath.axial_to_cube(coords)


func axial_to_world(coords: Vector2i) -> Vector2:
	return _HexMath.axial_to_world(coords)


func world_to_axial(world_pos: Vector2) -> Vector2i:
	return _HexMath.world_to_axial(world_pos)


# --- Serialization ---

func get_save_data() -> Dictionary:
	var tiles_data: Array = []
	for coords in _tiles:
		var tile: Resource = _tiles[coords]
		var resources_data: Array = []
		for rn in tile.resource_nodes:
			resources_data.append({
				"type": String(rn.type),
				"remaining": rn.remaining,
				"max": rn.max_amount,
				"tool": String(rn.tool_required),
			})
		tiles_data.append({
			"tile_col": coords.x,
			"tile_row": coords.y,
			"biome": tile.biome,
			"elevation": tile.elevation,
			"fog": tile.fog_state,
			"structure": String(tile.structure),
			"anomaly": String(tile.anomaly),
			"resources": resources_data,
		})
	return {
		"seed": _seed,
		"tiles": tiles_data,
	}


func load_save_data(data: Dictionary) -> void:
	_tiles.clear()
	_seed = data.get("seed", 0)
	var tiles_array: Array = data.get("tiles", [])
	for td in tiles_array:
		var tile: Resource = _HexTile.new()
		var coords := Vector2i(td["tile_col"], td["tile_row"])
		tile.coords = coords
		tile.biome = td["biome"]
		tile.elevation = td["elevation"]
		tile.fog_state = td["fog"]
		tile.structure = StringName(td.get("structure", ""))
		tile.anomaly = StringName(td.get("anomaly", ""))
		var rn_array: Array = []
		for rd in td.get("resources", []):
			var rn: Resource = _ResourceNode.new()
			rn.type = StringName(rd["type"])
			rn.remaining = rd["remaining"]
			rn.max_amount = rd["max"]
			rn.tool_required = StringName(rd["tool"])
			rn_array.append(rn)
		tile.resource_nodes = rn_array
		_tiles[coords] = tile
