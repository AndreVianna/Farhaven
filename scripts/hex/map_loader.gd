## MapLoader — loads a JSON level file and populates HexGrid.
## RefCounted — freed by GC after loading completes.
extends RefCounted

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")

const BIOME_NAMES: Dictionary = {
	"crash_site": 0,
	"grassland": 1,
	"forest": 2,
	"rocky": 3,
	"water": 4,
}

const BIOME_DATA_PATHS: Dictionary = {
	0: "res://data/biomes/crash_site.tres",
	1: "res://data/biomes/grassland.tres",
	2: "res://data/biomes/forest.tres",
	3: "res://data/biomes/rocky.tres",
	4: "res://data/biomes/water.tres",
}

const TILE_COUNT_MIN: int = 200
const TILE_COUNT_MAX: int = 300

var _grid: Node
var _biome_data: Dictionary = {}  # int (Biome) -> BiomeData resource


func _init(grid: Node) -> void:
	_grid = grid
	for biome_int in BIOME_DATA_PATHS:
		var res: Resource = load(BIOME_DATA_PATHS[biome_int])
		if res != null:
			_biome_data[biome_int] = res


## Load map from path. Returns true on success.
## Validation failures push_warning but do not prevent loading.
func load_map(path: String) -> bool:
	# Step 1: Parse JSON
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("MapLoader: cannot open '%s'" % path)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_warning("MapLoader: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return false

	var root = json.get_data()
	if not root is Dictionary:
		push_warning("MapLoader: root is not a Dictionary in '%s'" % path)
		return false

	if not root.has("tiles") or not root["tiles"] is Dictionary:
		push_warning("MapLoader: missing 'tiles' dictionary in '%s'" % path)
		return false

	var spawn_arr: Array = root.get("spawn", [0, 0])
	var spawn := Vector2i(int(spawn_arr[0]), int(spawn_arr[1]))

	# Step 2 & 3: Create HexTile objects and register in HexGrid._tiles
	_grid._tiles.clear()
	var tiles_dict: Dictionary = root["tiles"]

	for key in tiles_dict:
		var parts := str(key).split(",")
		if parts.size() != 2:
			push_warning("MapLoader: bad tile key '%s' — skipping" % str(key))
			continue
		var coords := Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
		var td: Dictionary = tiles_dict[key]

		var biome_str: String = td.get("biome", "grassland")
		var biome_int: int = BIOME_NAMES.get(biome_str, _HexTile.Biome.GRASSLAND)

		var tile: Resource = _HexTile.new()
		tile.coords = coords
		tile.biome = biome_int
		tile.elevation = clampi(int(td.get("elevation", 0)), 0, 9)
		tile.fog_state = _HexTile.FogState.HIDDEN
		tile.structure = StringName(td.get("structure", ""))
		tile.anomaly = StringName(td.get("anomaly", ""))

		var rn_list: Array = []
		for res_entry in td.get("resources", []):
			if res_entry is String:
				rn_list.append(_make_resource_node(StringName(str(res_entry)), biome_int))
			elif res_entry is Dictionary:
				var rn = _make_resource_node(StringName(str(res_entry.get("type", ""))), biome_int)
				rn.offset = Vector2(float(res_entry.get("x", 0.0)), float(res_entry.get("y", 0.0)))
				rn.rotation_deg = float(res_entry.get("rotation", 0.0))
				rn_list.append(rn)
		tile.resource_nodes = rn_list

		_grid._tiles[coords] = tile

	# Step 4: Validate (logs warnings on failure, does not abort)
	_validate(spawn)

	# Step 5: Initialize fog — all HIDDEN, spawn + radius 1 VISIBLE
	for c in _grid._tiles:
		_grid._tiles[c].fog_state = _HexTile.FogState.HIDDEN
	for coords in _HexMath.get_tiles_in_range(spawn, 1):
		var t: Resource = _grid._tiles.get(coords, null)
		if t != null:
			t.fog_state = _HexTile.FogState.VISIBLE

	# Step 6: Emit map_generated
	_grid.map_generated.emit()
	return true


# Default respawn times (seconds). 0 = no respawn.
const RESPAWN_TIMES: Dictionary = {
	&"wood": 30.0,
	&"stone": 30.0,
	&"fiber": 30.0,
	&"berries": 30.0,
	&"toxic_berries": 30.0,
	&"ore": 60.0,
	&"crystal": 60.0,
	&"anomaly_fragment": 0.0,
}


func _make_resource_node(type: StringName, biome_int: int) -> Resource:
	var rn: Resource = _ResourceNode.new()
	rn.type = type
	rn.remaining = 3
	rn.max_amount = 3
	rn.tool_required = &""
	rn.respawn_time = RESPAWN_TIMES.get(type, 0.0)

	var bd: Resource = _biome_data.get(biome_int, null)
	if bd != null:
		for entry in bd.resource_table:
			if StringName(entry.get("type", "")) == type:
				rn.max_amount = int(entry.get("max_amount", 3))
				rn.remaining = rn.max_amount
				rn.tool_required = StringName(entry.get("tool_required", ""))
				break
	return rn


func _validate(spawn: Vector2i) -> void:
	var count: int = _grid._tiles.size()
	if count < TILE_COUNT_MIN or count > TILE_COUNT_MAX:
		push_warning("MapLoader: tile count %d not in [%d,%d]" % [count, TILE_COUNT_MIN, TILE_COUNT_MAX])

	var spawn_tile: Resource = _grid._tiles.get(spawn, null)
	if spawn_tile == null:
		push_warning("MapLoader: spawn tile %s does not exist" % str(spawn))
	elif spawn_tile.biome != _HexTile.Biome.CRASH_SITE:
		push_warning("MapLoader: spawn tile at %s is not CRASH_SITE" % str(spawn))

	var biomes: Dictionary = {}
	var has_anomaly: bool = false
	for c in _grid._tiles:
		var t: Resource = _grid._tiles[c]
		biomes[t.biome] = true
		if t.anomaly != &"":
			has_anomaly = true
		if t.elevation < 0 or t.elevation > 9:
			push_warning("MapLoader: tile %s has invalid elevation %d" % [str(c), t.elevation])

	for b: int in [_HexTile.Biome.CRASH_SITE, _HexTile.Biome.GRASSLAND,
			_HexTile.Biome.FOREST, _HexTile.Biome.ROCKY]:
		if not biomes.has(b):
			push_warning("MapLoader: required biome %d absent from map" % b)

	if not has_anomaly:
		push_warning("MapLoader: no anomaly tile present in map")

	_validate_reachability(spawn)


func _validate_reachability(spawn: Vector2i) -> void:
	if not _grid._tiles.has(spawn):
		return

	var reachable: Dictionary = {spawn: true}
	var queue: Array[Vector2i] = [spawn]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		for n in _HexMath.get_neighbors(cur):
			if reachable.has(n) or not _grid._tiles.has(n):
				continue
			if _grid.is_passable(cur, n):
				reachable[n] = true
				queue.append(n)

	for c in _grid._tiles:
		var coords: Vector2i = c
		var t: Resource = _grid._tiles[coords]
		if t.biome != _HexTile.Biome.WATER and not reachable.has(coords):
			push_warning("MapLoader: tile %s (biome=%d elev=%d) unreachable from spawn" % [
				str(coords), t.biome, t.elevation
			])
