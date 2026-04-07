## MapLoader — loads a JSON level file and populates HexGrid.
## RefCounted — freed by GC after loading completes.
extends RefCounted

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

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

# Legacy walkable structures — used when converting old "structure" field to Prop.blocks_movement
const _WALKABLE_STRUCTURES: Array[StringName] = [&"shelter", &"torch", &"workbench", &"storage_chest", &"campfire"]

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
		tile.elevation = clampi(int(td.get("elevation", 0)), -32000, 32000)
		tile.fog_state = _HexTile.FogState.VISIBLE

		# --- Props: support BOTH new format ("props") and legacy ("resources" + "structure" + "anomaly") ---
		if td.has("props"):
			# New format: props array with full Prop data
			for pd in td["props"]:
				var prop: Resource = _Prop.new()
				prop.type = StringName(pd.get("type", ""))
				prop.category = int(pd.get("category", _Prop.Category.PLANT))
				prop.origin = int(pd.get("origin", _Prop.Origin.NATURAL))
				prop.sub_hex = Vector2i(int(pd.get("sub_hex_q", 0)), int(pd.get("sub_hex_r", 0)))
				if pd.has("tool_required") and pd["tool_required"] != "":
					prop.tool_required = StringName(pd["tool_required"])
				elif ResourceRegistry.has_def(prop.type):
					prop.tool_required = ResourceRegistry.get_def(prop.type).tool_required
				if pd.has("respawn_time"):
					prop.respawn_time = float(pd["respawn_time"])
				elif ResourceRegistry.has_def(prop.type):
					prop.respawn_time = ResourceRegistry.get_def(prop.type).respawn_time
				prop.rotation_deg = float(pd.get("rotation", 0.0))
				prop.blocks_movement = bool(pd.get("blocks_movement", false))
				# Resource props: default remaining/max_amount independently from biome data
				if prop.is_natural_category():
					var defaults: Array = _get_resource_defaults(prop.type, biome_int)
					prop.remaining = int(pd.get("remaining", defaults[0]))
					prop.max_amount = int(pd.get("max_amount", defaults[1]))
				else:
					prop.remaining = int(pd.get("remaining", 0))
					prop.max_amount = int(pd.get("max_amount", 0))
				tile.props.append(prop)
		else:
			# Legacy format: "resources" + "structure" + "anomaly"
			for res_entry in td.get("resources", []):
				if res_entry is String:
					tile.props.append(_make_resource_prop(StringName(str(res_entry)), biome_int))
				elif res_entry is Dictionary:
					var prop: Resource = _make_resource_prop(StringName(str(res_entry.get("type", ""))), biome_int)
					var offset := Vector2(float(res_entry.get("x", 0.0)), float(res_entry.get("y", 0.0)))
					prop.sub_hex = _HexMath.world_to_sub_axial(offset * _HexMath.HEX_SIZE * 0.4)
					prop.rotation_deg = float(res_entry.get("rotation", 0.0))
					tile.props.append(prop)

			var structure_str: String = td.get("structure", "")
			if structure_str != "":
				tile.props.append(_Prop.create_structure(
					StringName(structure_str),
					not (StringName(structure_str) in _WALKABLE_STRUCTURES),
				))

			var anomaly_str: String = td.get("anomaly", "")
			if anomaly_str != "":
				tile.props.append(_Prop.create_anomaly(StringName(anomaly_str)))

		_grid._tiles[coords] = tile

	# Step 4: Store spawn position on the grid.
	_grid.spawn_tile = spawn

	# Step 5: Validate (logs warnings on failure, does not abort)
	_validate(spawn)

	# Step 6: Initialize fog — all tiles VISIBLE (darkness handled by shader)
	for c in _grid._tiles:
		_grid._tiles[c].fog_state = _HexTile.FogState.VISIBLE

	# Step 7: Emit map_generated
	_grid.map_generated.emit()
	return true



## Get default [remaining, max_amount] for a resource type from biome data.
func _get_resource_defaults(type: StringName, biome_int: int) -> Array:
	var remaining: int = 3
	var max_amount: int = 3
	var bd: Resource = _biome_data.get(biome_int, null)
	if bd != null:
		for entry_data in bd.resource_table:
			if StringName(entry_data.get("type", "")) == type:
				max_amount = int(entry_data.get("max_amount", 3))
				remaining = max_amount
				break
	return [remaining, max_amount]


func _make_resource_prop(type: StringName, biome_int: int) -> Resource:
	var tool_req: StringName = ResourceRegistry.get_def(type).tool_required if ResourceRegistry.has_def(type) else &""
	var respawn: float = ResourceRegistry.get_def(type).respawn_time if ResourceRegistry.has_def(type) else 0.0
	var remaining: int = 3
	var max_amount: int = 3

	var bd: Resource = _biome_data.get(biome_int, null)
	if bd != null:
		for entry_data in bd.resource_table:
			if StringName(entry_data.get("type", "")) == type:
				max_amount = int(entry_data.get("max_amount", 3))
				remaining = max_amount
				break

	return _Prop.create_resource(type, remaining, max_amount, tool_req, respawn)


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
		for p in t.props:
			if p.is_anomaly():
				has_anomaly = true
				break
		if t.elevation < -32000 or t.elevation > 32000:
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

