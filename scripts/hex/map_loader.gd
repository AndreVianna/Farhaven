## MapLoader — loads a JSON level file and populates HexGrid.
## RefCounted — freed by GC after loading completes.
extends RefCounted

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

const TILE_COUNT_MIN: int = 200
const TILE_COUNT_MAX: int = 300

var _grid: Node
var _biome_data: Dictionary = {}    # biome_id (String) -> BiomeData
var _biome_id_to_int: Dictionary = {}  # biome_id (String) -> int (HexTile.Biome enum)


func _init(grid: Node) -> void:
	_grid = grid
	# Discover biome .tres files from data/biomes/ directory.
	# Collect filenames first, then sort for deterministic ordering across
	# platforms/filesystems. Must match HexGridRenderer's sort order.
	var biome_files: Array[String] = []
	var dir := DirAccess.open("res://data/biomes")
	if dir == null:
		push_warning("MapLoader: cannot open 'res://data/biomes' — biome discovery skipped (error: %d)" % DirAccess.get_open_error())
	else:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				biome_files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
	biome_files.sort()
	for i: int in range(biome_files.size()):
		var biome_id: String = biome_files[i].get_basename()
		var res: Resource = load("res://data/biomes/" + biome_files[i])
		if res != null:
			_biome_data[biome_id] = res
			_biome_id_to_int[biome_id] = i


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

	# Spawn format: [tile_col, tile_row, sub_hex_q, sub_hex_r, facing_deg]
	# sub_hex and facing are optional — older maps may have just 2 elements.
	var spawn_arr: Array = root.get("spawn", [0, 0])
	var spawn := Vector2i(
		int(spawn_arr[0]) if spawn_arr.size() > 0 else 0,
		int(spawn_arr[1]) if spawn_arr.size() > 1 else 0,
	)
	var spawn_sub_hex := Vector2i(
		int(spawn_arr[2]) if spawn_arr.size() > 2 else 0,
		int(spawn_arr[3]) if spawn_arr.size() > 3 else 0,
	)
	var spawn_facing_deg: float = float(spawn_arr[4]) if spawn_arr.size() > 4 else 0.0

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

		var biome_str: String = td.get("biome", "001")
		var biome_int: int = _biome_id_to_int.get(biome_str, 0)

		var tile: Resource = _HexTile.new()
		tile.coords = coords
		tile.biome = biome_int
		tile.elevation = clampi(int(td.get("elevation", 0)), -32000, 32000)

		# --- Props: support BOTH new format ("props") and legacy ("resources" + "structure" + "anomaly") ---
		if td.has("props"):
			# New format: props array with full Prop data
			for pd in td["props"]:
				var prop: Resource = _Prop.new()
				prop.type = StringName(pd.get("type", ""))
				prop.origin = int(pd.get("origin", _Prop.Origin.NATURAL))
				prop.sub_hex = Vector2i(int(pd.get("sub_hex_q", 0)), int(pd.get("sub_hex_r", 0)))
				if pd.has("tool_required") and pd["tool_required"] != "":
					prop.tool_required = StringName(pd["tool_required"])
				elif PropRegistry.has_def(prop.type):
					prop.tool_required = PropRegistry.get_def(prop.type).tool_required
				if pd.has("respawn_time"):
					prop.respawn_time = float(pd["respawn_time"])
				elif PropRegistry.has_def(prop.type):
					prop.respawn_time = PropRegistry.get_def(prop.type).respawn_time
				prop.rotation_deg = float(pd.get("rotation", 0.0))
				prop.blocks_movement = bool(pd.get("blocks_movement", false))
				# Resource props: default remaining/max_amount independently from biome data
				if prop.origin == _Prop.Origin.NATURAL:
					var defaults: Array = _get_prop_defaults(prop.type, biome_int)
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
					tile.props.append(_make_prop(StringName(str(res_entry)), biome_int))
				elif res_entry is Dictionary:
					var prop: Resource = _make_prop(StringName(str(res_entry.get("type", ""))), biome_int)
					var offset := Vector2(float(res_entry.get("x", 0.0)), float(res_entry.get("y", 0.0)))
					prop.sub_hex = _HexMath.world_to_sub_axial(offset * _HexMath.HEX_SIZE * 0.4)
					prop.rotation_deg = float(res_entry.get("rotation", 0.0))
					tile.props.append(prop)

			var structure_str: String = td.get("structure", "")
			if structure_str != "":
				tile.props.append(_Prop.create_structure(
					StringName(structure_str),
					false,  # Legacy structures default to walkable; blocks_movement from .tres
				))

			var anomaly_str: String = td.get("anomaly", "")
			if anomaly_str != "":
				tile.props.append(_Prop.create_anomaly(StringName(anomaly_str)))

		_grid._tiles[coords] = tile

	# Step 4: Store spawn position and starting loadout on the grid.
	_grid.spawn_tile = spawn
	_grid.spawn_sub_hex = spawn_sub_hex
	_grid.spawn_facing_deg = spawn_facing_deg
	_grid.starting_loadout = root.get("starting_loadout", {})

	# Step 5: Validate (logs warnings on failure, does not abort)
	_validate(spawn)

	# Emit map_generated
	_grid.map_generated.emit()
	return true



## Get default [remaining, max_amount] for a prop type from biome data.
func _get_prop_defaults(type: StringName, biome_int: int) -> Array:
	var remaining: int = 3
	var max_amount: int = 3
	var bd: Resource = _biome_data.get(biome_int, null)
	if bd != null:
		for entry_data in bd.prop_table:
			if StringName(entry_data.get("type", "")) == type:
				max_amount = int(entry_data.get("max_amount", 3))
				remaining = max_amount
				break
	return [remaining, max_amount]


func _make_prop(type: StringName, biome_int: int) -> Resource:
	var tool_req: StringName = PropRegistry.get_def(type).tool_required if PropRegistry.has_def(type) else &""
	var respawn: float = PropRegistry.get_def(type).respawn_time if PropRegistry.has_def(type) else 0.0
	var remaining: int = 3
	var max_amount: int = 3

	var bd: Resource = _biome_data.get(biome_int, null)
	if bd != null:
		for entry_data in bd.prop_table:
			if StringName(entry_data.get("type", "")) == type:
				max_amount = int(entry_data.get("max_amount", 3))
				remaining = max_amount
				break

	return _Prop.create_prop(type, remaining, max_amount, tool_req, respawn)


func _validate(spawn: Vector2i) -> void:
	var count: int = _grid._tiles.size()
	if count < TILE_COUNT_MIN or count > TILE_COUNT_MAX:
		push_warning("MapLoader: tile count %d not in [%d,%d]" % [count, TILE_COUNT_MIN, TILE_COUNT_MAX])

	var spawn_tile: Resource = _grid._tiles.get(spawn, null)
	if spawn_tile == null:
		push_warning("MapLoader: spawn tile %s does not exist" % str(spawn))
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

