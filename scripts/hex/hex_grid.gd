extends Node

## Autoload singleton — map container, public API, signals.
## All cross-feature interaction with the hex grid goes through this node.
## Uses preload because autoloads initialize before class_name registration.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

const WALK_MAX_DIFF: int = 2
const JUMP_MAX_DIFF: int = 4

# Legacy alias — existing code may reference this
const MAX_ELEVATION_DIFF: int = WALK_MAX_DIFF

## Elevation scale: world Y per elevation level.
## Shared constant — renderer, player, and terrain queries all use this.
const ELEVATION_STEP: float = 0.5

## Corner-to-neighbor direction mapping for flat-top hexes (verified empirically).
## DIRECTIONS order: [E, NE, NW, W, SW, SE]. Corner i is at angle i*60°.
## Each pair lists the 2 DIRECTIONS indices whose neighbor hexes share that corner.
const _CORNER_NEIGHBOR_DIRS: Array = [
	[0, 1],  # corner 0 (0°)   ← DIRECTIONS[0] + DIRECTIONS[1]
	[0, 5],  # corner 1 (60°)  ← DIRECTIONS[0] + DIRECTIONS[5]
	[5, 4],  # corner 2 (120°) ← DIRECTIONS[5] + DIRECTIONS[4]
	[4, 3],  # corner 3 (180°) ← DIRECTIONS[4] + DIRECTIONS[3]
	[3, 2],  # corner 4 (240°) ← DIRECTIONS[3] + DIRECTIONS[2]
	[2, 1],  # corner 5 (300°) ← DIRECTIONS[2] + DIRECTIONS[1]
]

enum TraversalType { WALK, JUMP, DROP, BLOCKED }


var _tiles: Dictionary = {}  # Vector2i -> HexTile
var _seed: int = 0
var spawn_tile: Vector2i = Vector2i.ZERO

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
	return get_traversal(from, to) != TraversalType.BLOCKED


func get_elevation_diff(from: Vector2i, to: Vector2i) -> int:
	var tile_from: Resource = _tiles.get(from, null)
	var tile_to: Resource = _tiles.get(to, null)
	if tile_from == null or tile_to == null:
		return 999
	return abs(int(tile_to.elevation) - int(tile_from.elevation))


## 3-tier traversal: WALK (0-2), JUMP/DROP (3-4), BLOCKED (5+, water, wall).
func get_traversal(from: Vector2i, to: Vector2i) -> int:
	var tile_to: Resource = _tiles.get(to, null)
	if tile_to == null:
		return TraversalType.BLOCKED
	if tile_to.biome == _HexTile.Biome.WATER:
		return TraversalType.BLOCKED
	# Check if any prop blocks movement
	for prop in tile_to.props:
		if prop.blocks_movement:
			return TraversalType.BLOCKED
	var diff: int = get_elevation_diff(from, to)
	if diff <= WALK_MAX_DIFF:
		return TraversalType.WALK
	if diff <= JUMP_MAX_DIFF:
		var tile_from: Resource = _tiles.get(from, null)
		if tile_from == null:
			return TraversalType.BLOCKED
		if int(tile_to.elevation) > int(tile_from.elevation):
			return TraversalType.JUMP
		else:
			return TraversalType.DROP
	return TraversalType.BLOCKED


# --- Fog of War ---

## Promote HIDDEN tiles within each source radius to VISIBLE.
## Emits tile_revealed and tile_visibility_changed for HIDDEN→VISIBLE transitions.
## sources: Array of {coords: Vector2i, radius: int}
func refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	var VISIBLE: int = _HexTile.FogState.VISIBLE
	var HIDDEN: int = _HexTile.FogState.HIDDEN

	# Promote HIDDEN tiles within each source radius to VISIBLE
	for source in sources:
		var center: Vector2i = source["coords"]
		var radius: int = source["radius"]
		var in_range: Array[Vector2i] = _HexMath.get_tiles_in_range(center, radius)
		for coords in in_range:
			var tile: Resource = _tiles.get(coords, null)
			if tile == null:
				continue
			if tile.fog_state == HIDDEN:
				tile.fog_state = VISIBLE
				tile_revealed.emit(coords)
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


# --- Terrain height ---

## Get the terrain Y height at an arbitrary world XZ position.
## Uses the same edge_y + corner_y logic as the renderer (12-vertex rings).
## Water tiles return flat elevation. Returns 0.0 for missing tiles.
func get_terrain_y(world_x: float, world_z: float) -> float:
	var coords: Vector2i = _HexMath.world_to_axial(Vector2(world_x, world_z))
	var tile: Resource = _tiles.get(coords, null)
	if tile == null:
		return 0.0

	var elev: float = float(tile.elevation)
	var center_y: float = elev * ELEVATION_STEP

	# Water stays flat.
	if tile.biome == _HexTile.Biome.WATER:
		return center_y

	# Compute edge_y (6 values) — don't blend land with water.
	var is_water: bool = tile.biome == _HexTile.Biome.WATER
	var edge_y: Array[float] = [center_y, center_y, center_y, center_y, center_y, center_y]
	for d: int in range(6):
		var n_coords: Vector2i = coords + (_HexMath.DIRECTIONS[d] as Vector2i)
		var n_tile: Resource = _tiles.get(n_coords, null)
		if n_tile == null:
			continue
		if is_water != (n_tile.biome == _HexTile.Biome.WATER):
			continue
		if absi(tile.elevation - n_tile.elevation) <= 2:
			edge_y[d] = ((elev + float(n_tile.elevation)) / 2.0) * ELEVATION_STEP

	# Compute corner_y (6 values) — don't blend land with water.
	var corner_y: Array[float] = [center_y, center_y, center_y, center_y, center_y, center_y]
	for ci: int in range(6):
		var sum_e: float = elev
		var cnt: int = 1
		var dir_pair: Array = _CORNER_NEIGHBOR_DIRS[ci]
		for d: int in dir_pair:
			var n_coords: Vector2i = coords + (_HexMath.DIRECTIONS[d] as Vector2i)
			var n_tile: Resource = _tiles.get(n_coords, null)
			if n_tile == null:
				continue
			if is_water != (n_tile.biome == _HexTile.Biome.WATER):
				continue
			if absi(tile.elevation - n_tile.elevation) <= 2:
				sum_e += float(n_tile.elevation)
				cnt += 1
		corner_y[ci] = (sum_e / float(cnt)) * ELEVATION_STEP

	# Distance and angle from hex center.
	var center_2d: Vector2 = _HexMath.axial_to_world(coords)
	var dx: float = world_x - center_2d.x
	var dz: float = world_z - center_2d.y
	var dist: float = sqrt(dx * dx + dz * dz)

	if dist < 0.001:
		return center_y

	# Find angle — 12 sectors (30° each) matching 12-vertex ring layout.
	# Even sectors (0,2,4,...) = corners, odd sectors (1,3,5,...) = edge midpoints.
	var angle: float = atan2(dz, dx)
	if angle < 0.0:
		angle += TAU

	# Normalized distance (0 at center, 1 at hex edge).
	# Hex boundary radius at this angle (flat-top hex).
	# Each edge midpoint is at 30°+60°*n. Distance to edge = apothem/cos(offset_from_edge).
	var edge_step: float = PI / 3.0  # 60°
	var first_edge: float = PI / 6.0  # 30°
	var edge_index: float = round((angle - first_edge) / edge_step)
	var nearest_edge_angle: float = first_edge + edge_index * edge_step
	var angle_from_edge: float = absf(angle - nearest_edge_angle)
	# Clamp to avoid numerical issues at exact corners (30° from edge = corner).
	angle_from_edge = minf(angle_from_edge, deg_to_rad(29.99))
	var apothem: float = _HexMath.HEX_SIZE * cos(deg_to_rad(30.0))
	var hex_boundary_radius: float = apothem / cos(angle_from_edge)
	var t: float = clampf(dist / hex_boundary_radius, 0.0, 1.0)

	# Interpolation curve — quintic smoothstep: t³(t(6t - 15) + 10)
	var s: float = t * t * t * (t * (6.0 * t - 15.0) + 10.0)

	# Direction-to-edge mapping for odd sectors (edge midpoints at 30°,90°,...).
	var edge_dir_for_midpoint: Array[int] = [0, 5, 4, 3, 2, 1]

	var sector_f: float = angle / (PI / 6.0)  # 30° per sector
	var sector: int = int(sector_f) % 12
	var sector_frac: float = sector_f - floor(sector_f)

	# Get target Y for this sector and the next.
	var target_a: float
	var target_b: float
	if sector % 2 == 0:
		target_a = corner_y[sector / 2]
	else:
		target_a = edge_y[edge_dir_for_midpoint[(sector - 1) / 2]]
	var next_sector: int = (sector + 1) % 12
	if next_sector % 2 == 0:
		target_b = corner_y[next_sector / 2]
	else:
		target_b = edge_y[edge_dir_for_midpoint[(next_sector - 1) / 2]]

	# Blend between adjacent sector targets.
	var target_blend: float = lerpf(target_a, target_b, sector_frac)

	# Interpolate from center Y to blended target using the curve.
	return lerpf(center_y, target_blend, s)


# --- Serialization ---

func get_save_data() -> Dictionary:
	var tiles_data: Array = []
	for coords in _tiles:
		var tile: Resource = _tiles[coords]
		var props_data: Array = []
		for prop in tile.props:
			props_data.append({
				"type": String(prop.type),
				"category": prop.category,
				"origin": prop.origin,
				"sub_hex_q": prop.sub_hex.x,
				"sub_hex_r": prop.sub_hex.y,
				"remaining": prop.remaining,
				"max_amount": prop.max_amount,
				"tool_required": String(prop.tool_required),
				"respawn_time": prop.respawn_time,
				"rotation": prop.rotation_deg,
				"blocks_movement": prop.blocks_movement,
			})
		tiles_data.append({
			"tile_col": coords.x,
			"tile_row": coords.y,
			"biome": tile.biome,
			"elevation": tile.elevation,
			"fog": tile.fog_state,
			"props": props_data,
		})
	return {
		"seed": _seed,
		"tiles": tiles_data,
	}


func load_map(path: String) -> bool:
	var loader = load("res://scripts/hex/map_loader.gd").new(self)
	return loader.load_map(path)


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

		if td.has("props"):
			# New save format: unified props array
			for pd in td["props"]:
				var prop: Resource = _Prop.new()
				prop.type = StringName(pd["type"])
				prop.category = int(pd.get("category", _Prop.Category.PLANT))
				prop.origin = int(pd.get("origin", _Prop.Origin.NATURAL))
				prop.sub_hex = Vector2i(int(pd.get("sub_hex_q", 0)), int(pd.get("sub_hex_r", 0)))
				prop.remaining = int(pd.get("remaining", 0))
				prop.max_amount = int(pd.get("max_amount", 0))
				prop.tool_required = StringName(pd.get("tool_required", ""))
				prop.respawn_time = float(pd.get("respawn_time", 0.0))
				prop.rotation_deg = float(pd.get("rotation", 0.0))
				prop.blocks_movement = bool(pd.get("blocks_movement", false))
				tile.props.append(prop)
		else:
			# Legacy save format: "resources" + "structure" + "anomaly"
			for rd in td.get("resources", []):
				tile.props.append(_Prop.create_resource(
					StringName(rd["type"]),
					int(rd["remaining"]),
					int(rd["max"]),
					StringName(rd.get("tool", "")),
				))

			var structure_str: String = td.get("structure", "")
			if structure_str != "":
				tile.props.append(_Prop.create_structure(
					StringName(structure_str),
					false,  # Legacy structures default to walkable (blocks_movement from .tres)
				))

			var anomaly_str: String = td.get("anomaly", "")
			if anomaly_str != "":
				tile.props.append(_Prop.create_anomaly(StringName(anomaly_str)))

		_tiles[coords] = tile



# --- Prop helpers ---

## Return all props of a given category on the tile at coords.
func get_props_by_category(coords: Vector2i, category: int) -> Array:
	var tile: Resource = _tiles.get(coords, null)
	if tile == null:
		return []
	return tile.get_props_by_category(category)


## Return true if the tile at coords has a structure prop of the given type.
func has_structure(coords: Vector2i, type: StringName) -> bool:
	var tile: Resource = _tiles.get(coords, null)
	if tile == null:
		return false
	for prop in tile.get_structures():
		if prop.type == type:
			return true
	return false


## Return the first anomaly prop on the tile at coords, or null.
func get_anomaly(coords: Vector2i) -> Resource:
	var tile: Resource = _tiles.get(coords, null)
	if tile == null:
		return null
	var anomalies: Array = tile.get_anomalies()
	if anomalies.is_empty():
		return null
	return anomalies[0]
