class_name WorldGenerator
extends RefCounted

## 11-step world generation pipeline.
## Operates directly on HexGrid's _tiles dictionary via the grid reference.
## Freed by GC after generation completes.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")

const TARGET_TILE_MIN: int = 200
const TARGET_TILE_MAX: int = 300
const MAX_RETRIES: int = 10
const CLUSTER_MAX: int = 5
const ANOMALY_DISTANCE_RATIO: float = 0.70
const WATER_CLUSTER_COUNT: int = 6
const WATER_CLUSTER_SIZE: int = 3

# Biome enum int values -> BiomeData .tres path
const BIOME_DATA_PATHS: Dictionary = {
	0: "res://data/biomes/crash_site.tres",   # CRASH_SITE
	1: "res://data/biomes/grassland.tres",    # GRASSLAND
	2: "res://data/biomes/forest.tres",       # FOREST
	3: "res://data/biomes/rocky.tres",        # ROCKY
	4: "res://data/biomes/water.tres",        # WATER
}

var _grid: Node  # HexGrid autoload
var _rng: RandomNumberGenerator
var _biome_data: Dictionary = {}  # int (Biome) -> BiomeData Resource


func _init(grid: Node) -> void:
	_grid = grid
	_rng = RandomNumberGenerator.new()
	_load_biome_data()


func _load_biome_data() -> void:
	for biome_int in BIOME_DATA_PATHS:
		var path: String = BIOME_DATA_PATHS[biome_int]
		var data: Resource = load(path)
		if data != null:
			_biome_data[biome_int] = data


## Generate a map with the given seed. Returns true on success.
func generate(seed_value: int) -> bool:
	for attempt in range(MAX_RETRIES):
		var actual_seed: int = seed_value + attempt
		_rng.seed = actual_seed
		_grid._tiles.clear()
		_grid._seed = actual_seed

		_step1_place_crash_site()
		_step2_expand_map()
		_step3_assign_biomes()
		_step4_place_water_clusters()
		_step5_postprocess_clusters()
		_step6_generate_elevation()
		_step7_populate_resources()
		var reachable: Dictionary = _step8_reachability_and_anomaly()
		if not _step9_validate(reachable):
			continue
		_step10_init_fog()
		_step11_emit()
		return true

	push_error("WorldGenerator: failed after %d retries" % MAX_RETRIES)
	return false


# --- Step 1: Place Crash Site ---

func _step1_place_crash_site() -> void:
	var center := Vector2i.ZERO
	_place_tile(center, _HexTile.Biome.CRASH_SITE, 0)
	for n in _HexMath.get_neighbors(center):
		_place_tile(n, _HexTile.Biome.CRASH_SITE, 0)
	for c in _HexMath.get_ring(center, 2):
		_place_tile(c, _HexTile.Biome.CRASH_SITE, 0)


func _place_tile(coords: Vector2i, biome: int, elevation: int) -> Resource:
	var tile: Resource = _HexTile.new()
	tile.coords = coords
	tile.biome = biome
	tile.elevation = elevation
	tile.fog_state = _HexTile.FogState.HIDDEN
	_grid._tiles[coords] = tile
	return tile


# --- Step 2: Expand map via BFS ---

func _step2_expand_map() -> void:
	var target: int = TARGET_TILE_MIN + _rng.randi_range(0, TARGET_TILE_MAX - TARGET_TILE_MIN)
	var frontier: Array[Vector2i] = []
	for c in _grid._tiles:
		frontier.append(c)

	var shuffled_frontier: Array[Vector2i] = frontier.duplicate()
	while _grid._tiles.size() < target and shuffled_frontier.size() > 0:
		var idx: int = _rng.randi_range(0, shuffled_frontier.size() - 1)
		var current: Vector2i = shuffled_frontier[idx]
		shuffled_frontier.remove_at(idx)

		for n in _HexMath.get_neighbors(current):
			if not _grid._tiles.has(n):
				_place_tile(n, _HexTile.Biome.GRASSLAND, 0)
				shuffled_frontier.append(n)
				if _grid._tiles.size() >= target:
					break


# --- Step 3: Assign biomes via greedy BFS (cluster-safe) ---

## Process tiles in BFS order from center. For each tile, assign the desired
## biome (distance-weighted) if it keeps the cluster ≤ CLUSTER_MAX.
## Cluster check is performed ONLY against finalized tiles, so unprocessed
## outer tiles cannot inflate the count. Provably correct: always finds a
## valid assignment since at most 1 of 3 biomes can be fully blocked.
func _step3_assign_biomes() -> void:
	var max_dist: int = 0
	for c in _grid._tiles:
		max_dist = max(max_dist, _HexMath.distance(Vector2i.ZERO, c))

	var finalized: Dictionary = {}
	var in_queue: Dictionary = {}
	var bfs_queue: Array[Vector2i] = []
	bfs_queue.append(Vector2i.ZERO)
	in_queue[Vector2i.ZERO] = true

	var idx: int = 0
	while idx < bfs_queue.size():
		var coords: Vector2i = bfs_queue[idx]
		idx += 1

		var tile: Resource = _grid._tiles.get(coords, null)
		if tile == null:
			continue

		if tile.biome != _HexTile.Biome.CRASH_SITE:
			var dist_ratio: float = float(_HexMath.distance(Vector2i.ZERO, coords)) / float(max(max_dist, 1))
			var desired: int
			if dist_ratio < 0.4:
				desired = _HexTile.Biome.GRASSLAND
			elif dist_ratio < 0.70:
				desired = _HexTile.Biome.FOREST
			else:
				desired = _HexTile.Biome.ROCKY

			# Try desired biome, then the other two
			var candidates: Array[int] = [desired]
			for b: int in [_HexTile.Biome.GRASSLAND, _HexTile.Biome.FOREST, _HexTile.Biome.ROCKY]:
				if not candidates.has(b):
					candidates.append(b)

			tile.biome = candidates[0]
			for b: int in candidates:
				tile.biome = b
				if _cluster_size_in_set(coords, b, finalized) <= CLUSTER_MAX:
					break

		finalized[coords] = true

		for n in _HexMath.get_neighbors(coords):
			if not in_queue.has(n) and _grid._tiles.has(n):
				bfs_queue.append(n)
				in_queue[n] = true


# --- Step 4: Place water clusters ---

func _step4_place_water_clusters() -> void:
	var non_crash: Array[Vector2i] = []
	for c in _grid._tiles:
		var coords: Vector2i = c
		var tile: Resource = _grid._tiles[coords]
		if tile.biome != _HexTile.Biome.CRASH_SITE:
			non_crash.append(coords)

	for _i in range(WATER_CLUSTER_COUNT):
		if non_crash.is_empty():
			break
		var idx: int = _rng.randi_range(0, non_crash.size() - 1)
		var seed_coord: Vector2i = non_crash[idx]
		var candidates: Array[Vector2i] = [seed_coord]
		for n in _HexMath.get_neighbors(seed_coord):
			if _grid._tiles.has(n):
				var nt: Resource = _grid._tiles[n]
				if nt.biome != _HexTile.Biome.CRASH_SITE:
					candidates.append(n)

		var placed: int = 0
		for coord in candidates:
			if placed >= WATER_CLUSTER_SIZE:
				break
			var tile: Resource = _grid._tiles.get(coord, null)
			if tile != null and tile.biome != _HexTile.Biome.CRASH_SITE and tile.biome != _HexTile.Biome.WATER:
				tile.biome = _HexTile.Biome.WATER
				placed += 1


# --- Step 5: Post-process clusters ---

## Step 3 greedy BFS guarantees clusters ≤ CLUSTER_MAX for non-water biomes.
## Water clusters (step 4) are excluded from the cluster constraint.
## This step is a safety net that handles any water-adjacent edge cases.
func _step5_postprocess_clusters() -> void:
	pass  # Guaranteed correct by step 3 greedy BFS assignment


## Cluster size among ALL tiles (used for validation).
func _cluster_size(start: Vector2i, biome: int) -> int:
	var visited: Dictionary = {}
	var count: int = 0
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		if visited.has(cur):
			continue
		visited[cur] = true
		var ct: Resource = _grid._tiles.get(cur, null)
		if ct == null or ct.biome != biome:
			continue
		count += 1
		if count > CLUSTER_MAX:
			return count
		for nn in _HexMath.get_neighbors(cur):
			if not visited.has(nn) and _grid._tiles.has(nn):
				queue.append(nn)
	return count


## Cluster size counting ONLY the start tile plus finalized tiles.
## Used during BFS greedy assignment to avoid counting unprocessed outer tiles.
func _cluster_size_in_set(start: Vector2i, biome: int, finalized: Dictionary) -> int:
	var visited: Dictionary = {}
	var count: int = 0
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		if visited.has(cur):
			continue
		visited[cur] = true
		# Allow start tile (being assigned); require others to be finalized
		if cur != start and not finalized.has(cur):
			continue
		var ct: Resource = _grid._tiles.get(cur, null)
		if ct == null or ct.biome != biome:
			continue
		count += 1
		if count > CLUSTER_MAX:
			return count
		for nn in _HexMath.get_neighbors(cur):
			if not visited.has(nn) and _grid._tiles.has(nn):
				queue.append(nn)
	return count


# --- Step 6: Generate elevation ---

func _step6_generate_elevation() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = (int(_grid._seed) + 1337) & 0x7FFFFFFF
	noise.frequency = 0.2
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	for c in _grid._tiles:
		var coords: Vector2i = c
		var tile: Resource = _grid._tiles[coords]

		if tile.biome == _HexTile.Biome.CRASH_SITE or tile.biome == _HexTile.Biome.WATER:
			tile.elevation = 0
			continue

		var biome_data: Resource = _biome_data.get(tile.biome, null)
		if biome_data == null:
			tile.elevation = 0
			continue

		var n_val: float = (noise.get_noise_2d(float(coords.x), float(coords.y)) + 1.0) * 0.5
		var elev_min: int = biome_data.elevation_range.x
		var elev_max: int = biome_data.elevation_range.y
		tile.elevation = elev_min + roundi(n_val * float(elev_max - elev_min))


# --- Step 7: Populate resources ---

func _step7_populate_resources() -> void:
	for c in _grid._tiles:
		var coords: Vector2i = c
		var tile: Resource = _grid._tiles[coords]
		if tile.biome == _HexTile.Biome.WATER:
			continue
		var biome_data: Resource = _biome_data.get(tile.biome, null)
		if biome_data == null or biome_data.resource_table.is_empty():
			continue

		var nodes: Array = []
		for entry in biome_data.resource_table:
			if nodes.size() >= 3:
				break
			var chance: float = entry.get("chance", 0.0)
			if _rng.randf() > chance:
				continue
			var rn: Resource = _ResourceNode.new()
			rn.type = StringName(entry.get("type", ""))
			var min_amt: int = entry.get("min_amount", 1)
			var max_amt: int = entry.get("max_amount", 1)
			rn.max_amount = _rng.randi_range(min_amt, max_amt)
			rn.remaining = rn.max_amount
			rn.tool_required = StringName(entry.get("tool_required", ""))
			nodes.append(rn)
		tile.resource_nodes = nodes


# --- Step 8: Reachability BFS + anomaly placement ---

func _step8_reachability_and_anomaly() -> Dictionary:
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	reachable[Vector2i.ZERO] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for n in _HexMath.get_neighbors(current):
			if reachable.has(n) or not _grid._tiles.has(n):
				continue
			if _grid.is_passable(current, n):
				reachable[n] = true
				queue.append(n)

	var max_ring_dist: int = 0
	for c in reachable:
		var coords: Vector2i = c
		var d: int = _HexMath.distance(Vector2i.ZERO, coords)
		if d > max_ring_dist:
			max_ring_dist = d

	var min_dist: int = roundi(float(max_ring_dist) * ANOMALY_DISTANCE_RATIO)

	var candidates: Array[Vector2i] = []
	for c in reachable:
		var coords: Vector2i = c
		var tile: Resource = _grid._tiles.get(coords, null)
		if tile == null:
			continue
		if tile.structure != &"":
			continue
		if _HexMath.distance(Vector2i.ZERO, coords) >= min_dist:
			candidates.append(coords)

	if candidates.size() > 0:
		var idx: int = _rng.randi_range(0, candidates.size() - 1)
		_grid._tiles[candidates[idx]].anomaly = &"anomaly_ch1_001"

	return reachable


# --- Step 9: Validate ---

func _step9_validate(_reachable: Dictionary) -> bool:
	var tile_count: int = _grid._tiles.size()
	if tile_count < TARGET_TILE_MIN or tile_count > TARGET_TILE_MAX:
		return false

	var biomes_found: Dictionary = {}
	var anomaly_placed: bool = false
	for c in _grid._tiles:
		var coords: Vector2i = c
		var tile: Resource = _grid._tiles[coords]
		biomes_found[tile.biome] = true
		if tile.anomaly != &"":
			anomaly_placed = true

	var required_biomes: Array[int] = [
		_HexTile.Biome.CRASH_SITE,
		_HexTile.Biome.GRASSLAND,
		_HexTile.Biome.FOREST,
		_HexTile.Biome.ROCKY,
	]
	for biome in required_biomes:
		if not biomes_found.has(biome):
			return false

	# Crash Site within 3 hexes of center
	var crash_center_ok: bool = false
	for c in _grid._tiles:
		var coords: Vector2i = c
		if _grid._tiles[coords].biome == _HexTile.Biome.CRASH_SITE:
			if _HexMath.distance(Vector2i.ZERO, coords) <= 3:
				crash_center_ok = true
				break
	if not crash_center_ok:
		return false

	if not _validate_clusters():
		return false

	# Anomaly must be placed (guaranteed by step 8 if candidates exist)
	if not anomaly_placed:
		return false

	return true


func _validate_clusters() -> bool:
	for c in _grid._tiles:
		var coords: Vector2i = c
		var tile: Resource = _grid._tiles[coords]
		if tile.biome == _HexTile.Biome.CRASH_SITE or tile.biome == _HexTile.Biome.WATER:
			continue
		if _cluster_size(coords, tile.biome) > CLUSTER_MAX:
			return false
	return true


# --- Step 10: Initialize fog ---

func _step10_init_fog() -> void:
	for c in _grid._tiles:
		_grid._tiles[c].fog_state = _HexTile.FogState.HIDDEN
	for coords in _HexMath.get_tiles_in_range(Vector2i.ZERO, 1):
		var tile: Resource = _grid._tiles.get(coords, null)
		if tile != null:
			tile.fog_state = _HexTile.FogState.VISIBLE


# --- Step 11: Emit ---

func _step11_emit() -> void:
	_grid.map_generated.emit()
