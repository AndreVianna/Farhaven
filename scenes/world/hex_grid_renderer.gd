extends Node3D

## HexGridRenderer — multi-MeshInstance3D hex grid with per-biome textures.
##
## Each (biome, variation) pair gets its own MeshInstance3D child with its own
## ShaderMaterial. Biomes that have `terrain_textures` set on their BiomeData
## use `hex_tile_textured.gdshader` (UV-sampled texture × vertex color);
## biomes with an empty texture list fall back to `hex_tile.gdshader`
## (vertex color only). Cliff side faces always use the color shader since
## they have no sensible tile-local UV.
##
## Geometry:
##   - Concentric ring subdivision: 1 center + 12 vertices × 4 rings = 49 vertices per hex.
##   - 12 inner-fan triangles + 72 ring-strip triangles = 84 triangles per hex.
##   - Ring radii: 0, 25%, 50%, 75%, 100% of HEX_SIZE.
##   - 12 vertices per ring: 6 at corners (0°,60°,...) + 6 at edge midpoints (30°,90°,...).
##   - Quintic smoothstep interpolation; corners target corner_y, edge mids target edge_y.
##   - edge_y: avg of 2 hexes if slope (diff ≤ 2), own elevation if cliff (diff ≥ 3).
##   - corner_y: avg of this hex + neighbors with diff ≤ 2.
##   - Center vertex color = biome variation color (hash-selected).
##   - Corner vertex color = average of all tiles sharing that corner at SAME elevation.
##   - Different elevation = different corner key → no color sharing → cliff edge.
##   - Y position = elevation * ELEVATION_STEP, with corner Y averaged for slopes (diff 1-2).
##   - Water tiles stay flat regardless of neighbor elevation (no curvature).
##   - Wall faces on all non-water hex edges where neighbor is same-or-lower, water, or missing.
##
## UV mapping:
##   Each hex samples its texture in its own local [0..1] space so every tile
##   shows one copy of its assigned texture. Center UV = (0.5, 0.5). Ring-vertex
##   UVs use cos/sin around the center and map local radius ∈ [0..HEX_SIZE]
##   into [0..0.5] offset from the centre.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _COLOR_SHADER: Shader = preload("res://shaders/hex_tile.gdshader")
const _TEXTURED_SHADER: Shader = preload("res://shaders/hex_tile_textured.gdshader")

const ELEVATION_STEP: float = 0.5
const CHUNK_SIZE: int = 16

## Sentinel used in the bucket key when a biome has no textures.
const _NO_TEXTURE_VARIATION: int = -1

## Legacy/default child — kept for scene compatibility and tests. Always holds
## a committed ArrayMesh (first bucket built, or empty).
var _mesh_instance: MeshInstance3D

## Every ShaderMaterial we own this build, parallel to the meshes on child
## instances. `_sync_lights_to_shader()` iterates this list.
var _materials: Array[ShaderMaterial] = []

## MeshInstance3D children we spawn per (biome, variation) bucket. These are
## separate from `_mesh_instance` — we queue_free() them on rebuild.
var _bucket_instances: Array[MeshInstance3D] = []

## Loaded BiomeData resources indexed by Biome enum value.
var _biome_data: Array = []

## coords (Vector2i) → {base_color: Color, highlight: Color}
var _tile_data: Dictionary = {}

## Currently highlighted tile coords → true.
var _highlights: Dictionary = {}

## Chunk Node3D containers keyed by Vector2i(chunk_q, chunk_r).
var _chunk_nodes: Dictionary = {}

## Cached light count to avoid redundant shader updates.
var _last_light_count: int = 0


func _ready() -> void:
	_mesh_instance = $MeshInstance3D

	# Discover biome .tres files from data/biomes/ directory.
	var biome_files: Array[String] = []
	var dir := DirAccess.open("res://data/biomes")
	if dir == null:
		push_warning("HexGridRenderer: cannot open 'res://data/biomes' — biome population skipped (error: %d)" % DirAccess.get_open_error())
	else:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				biome_files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
	biome_files.sort()
	_biome_data.resize(biome_files.size())
	for i: int in range(biome_files.size()):
		var bd_res: Resource = load("res://data/biomes/" + biome_files[i])
		if bd_res == null:
			push_warning("HexGridRenderer: failed to load biome '%s' — index %d left null" % [biome_files[i], i])
		_biome_data[i] = bd_res

	HexGrid.map_generated.connect(_on_map_generated)


# --- Light sync (task-039) ---

func _process(_delta: float) -> void:
	_sync_lights_to_shader()


## Push active light sources from LightingManager into every owned material.
func _sync_lights_to_shader() -> void:
	if _materials.is_empty():
		return
	var lights: Array[Dictionary] = LightingManager.get_active_lights()
	var count: int = mini(lights.size(), 8)
	if count == 0 and _last_light_count == 0:
		return
	_last_light_count = count
	if count == 0:
		for m: ShaderMaterial in _materials:
			m.set_shader_parameter("light_count", 0)
		return
	var positions: PackedVector2Array = PackedVector2Array()
	positions.resize(count)
	var radii: PackedFloat32Array = PackedFloat32Array()
	radii.resize(count)
	for i: int in range(count):
		var light: Dictionary = lights[i]
		positions[i] = light["position"]
		radii[i] = light["radius"]
	for m: ShaderMaterial in _materials:
		m.set_shader_parameter("light_count", count)
		m.set_shader_parameter("light_positions", positions)
		m.set_shader_parameter("light_radii", radii)


# --- Signal handlers ---

func _on_map_generated() -> void:
	_tile_data.clear()
	_highlights.clear()
	_build_tile_data()
	_rebuild_mesh()


# --- Public API ---

func highlight_tiles(coords: Array[Vector2i], color: Color) -> void:
	clear_highlights()
	for coord: Vector2i in coords:
		if _tile_data.has(coord):
			_tile_data[coord].highlight = color
			_highlights[coord] = true
	_rebuild_mesh()


func clear_highlights() -> void:
	for coord: Vector2i in _highlights:
		if _tile_data.has(coord):
			_tile_data[coord].highlight = Color.TRANSPARENT
	_highlights.clear()
	_rebuild_mesh()


# --- Internal helpers ---

func _build_tile_data() -> void:
	for coords: Variant in HexGrid._tiles:
		var tile: Resource = HexGrid._tiles[coords]
		var bd: BiomeData = _biome_data[tile.biome]
		var base_color: Color = _pick_color(bd, tile.elevation)
		_tile_data[coords] = {
			base_color = base_color,
			highlight = Color.TRANSPARENT,
		}


## Deterministic per-tile variation index for a given biome.
## Returns 0 when the biome has no textures (the single color bucket uses 0).
func _pick_variation_idx(bd: BiomeData, coords: Vector2i) -> int:
	if bd == null or bd.terrain_textures.is_empty():
		return 0
	return absi(_hash_coords(coords, 0)) % bd.terrain_textures.size()


## Deterministic per-tile UV rotation in radians (one of 0°, 90°, 180°, 270°).
## Multiplies effective variation by 4 with no extra texture assets.
## Uses a different seed from `_pick_variation_idx` so rotation and
## variation aren't correlated along any lattice direction.
func _pick_rotation_radians(coords: Vector2i) -> float:
	return float(absi(_hash_coords(coords, 1)) % 4) * (PI / 2.0)


## PCG-style integer hash that mixes both axes so the bottom bits of
## the result don't correlate with the bottom bits of the inputs.
## The earlier straight `(x * P1) ^ (y * P2)` version produced visible
## diagonal stripes in both variation and rotation because both primes
## happened to be 1 and 3 mod 4 — `hash % 4` was `(q + 3r) % 4` for
## both, making them share the same diagonal pattern.
##
## Changing primes alone wouldn't have broken the correlation BETWEEN
## the two hashes, so `seed` also enters the mix to keep variation
## and rotation statistically independent.
func _hash_coords(coords: Vector2i, seed: int) -> int:
	var h: int = coords.x * 374761393 + coords.y * 668265263 + seed * 2246822519
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h


## Rebuild every MeshInstance3D bucket from current _tile_data.
## Called on map_generated and on any highlight change.
func _rebuild_mesh() -> void:
	# Step 0: Drop previous chunk nodes, bucket instances + materials.
	for ck: Variant in _chunk_nodes:
		var node: Node3D = _chunk_nodes[ck]
		if is_instance_valid(node):
			node.queue_free()
	_chunk_nodes.clear()
	for inst: MeshInstance3D in _bucket_instances:
		if is_instance_valid(inst):
			inst.queue_free()
	_bucket_instances.clear()
	_materials.clear()
	DayNightCycle.clear_hex_materials()
	_mesh_instance.mesh = null
	_mesh_instance.material_override = null

	# Step 1: Compute final per-tile vertex color (highlight applied if active).
	var tile_colors: Dictionary = {}
	for coords: Variant in _tile_data:
		var data: Dictionary = _tile_data[coords]
		var c: Color = data.base_color
		if (data.highlight as Color).a > 0.0:
			c = data.highlight
		tile_colors[coords] = c

	if tile_colors.is_empty():
		return

	# Step 2: Corner color map keyed by world position.
	var corner_map: Dictionary = {}
	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y
		for i: int in range(6):
			var angle: float = deg_to_rad(60.0 * float(i))
			var corner_x: float = cx + cos(angle) * HexMath.HEX_SIZE
			var corner_z: float = cz + sin(angle) * HexMath.HEX_SIZE
			var pos_key := Vector2i(
				roundi(corner_x * 1000.0),
				roundi(corner_z * 1000.0)
			)
			if not corner_map.has(pos_key):
				corner_map[pos_key] = []
			# Water tiles use water_level (surface) for corner sharing, not elevation (depth).
			var surface_elev: int = tile.water_level if tile.biome == _HexTile.Biome.WATER else tile.elevation
			(corner_map[pos_key] as Array).append({color = tile_colors[coords], elevation = surface_elev, is_water = (tile.biome == _HexTile.Biome.WATER)})

	# Step 3: Average corner colors per elevation group.
	var corner_colors: Dictionary = {}
	for pos_key: Variant in corner_map:
		var entries: Array = corner_map[pos_key]
		for entry: Dictionary in entries:
			var elev: int = entry.elevation
			var entry_is_water: bool = entry.is_water
			var r: float = 0.0
			var g: float = 0.0
			var b: float = 0.0
			var a: float = 0.0
			var n: float = 0.0
			for other: Dictionary in entries:
				if entry_is_water != other.is_water:
					continue
				# Water is always smooth — skip elevation diff check
				if entry_is_water or absi(elev - other.elevation) <= 2:
					r += (other.color as Color).r
					g += (other.color as Color).g
					b += (other.color as Color).b
					a += (other.color as Color).a
					n += 1.0
			var result_key := Vector3i((pos_key as Vector2i).x, elev, (pos_key as Vector2i).y)
			corner_colors[result_key] = Color(r / n, g / n, b / n, a / n)

	# Step 4: edge_y and corner_y per tile (unchanged from color-only version).
	var corner_neighbor_dirs: Array = [
		[0, 1],  # corner 0 (0°)   ← E + SE
		[0, 5],  # corner 1 (60°)  ← E + N
		[5, 4],  # corner 2 (120°) ← N + NW
		[4, 3],  # corner 3 (180°) ← NW + SW
		[3, 2],  # corner 4 (240°) ← SW + S
		[2, 1],  # corner 5 (300°) ← S + SE
	]
	var edge_corners: Array = [
		[0, 1],  # dir 0 (E)
		[5, 0],  # dir 1 (SE)
		[4, 5],  # dir 2 (S)
		[3, 4],  # dir 3 (SW)
		[2, 3],  # dir 4 (NW)
		[1, 2],  # dir 5 (N)
	]
	var edge_dir_for_midpoint: Array[int] = [0, 5, 4, 3, 2, 1]

	var all_edge_y: Dictionary = {}
	var all_corner_y: Dictionary = {}

	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var is_water: bool = tile.biome == _HexTile.Biome.WATER
		# Water tiles render at water_level (surface), not elevation (depth).
		var elev: float = float(tile.water_level) if is_water else float(tile.elevation)
		var elev_y: float = elev * ELEVATION_STEP

		var ey: Array[float] = [elev_y, elev_y, elev_y, elev_y, elev_y, elev_y]
		for d: int in range(6):
			# If this edge has a wall, keep own elevation (cliff face).
			if tile.walls[d]:
				continue
			var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
			var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
			if n_tile == null:
				continue
			if is_water != (n_tile.biome == _HexTile.Biome.WATER):
				continue
			# No wall → slope: average the two surface elevations.
			# Water tiles use water_level (surface), land tiles use elevation.
			var n_elev: float = float(n_tile.water_level) if n_tile.biome == _HexTile.Biome.WATER else float(n_tile.elevation)
			ey[d] = ((elev + n_elev) / 2.0) * ELEVATION_STEP
		all_edge_y[coords] = ey

		var _init_cy: Array[float] = [elev_y, elev_y, elev_y, elev_y, elev_y, elev_y]
		all_corner_y[coords] = _init_cy

	# Step 4b: corner_y — per-point computation for cross-tile consistency.
	# Each physical corner point is shared by up to 3 tiles. We find connected
	# components based on walls and type (water/land), average within each
	# component, and assign the SAME value to every tile in that component.
	var corner_point_tiles: Dictionary = {}  # Vector2i pos_key → Array[Dictionary]
	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var is_water: bool = tile.biome == _HexTile.Biome.WATER
		var elev: float = float(tile.water_level) if is_water else float(tile.elevation)
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y
		for ci: int in range(6):
			var angle: float = deg_to_rad(60.0 * float(ci))
			var pos_key := Vector2i(
				roundi((cx + cos(angle) * HexMath.HEX_SIZE) * 1000.0),
				roundi((cz + sin(angle) * HexMath.HEX_SIZE) * 1000.0),
			)
			if not corner_point_tiles.has(pos_key):
				corner_point_tiles[pos_key] = []
			(corner_point_tiles[pos_key] as Array).append({
				coords = coords, ci = ci, elev = elev, is_water = is_water,
			})

	for pos_key: Variant in corner_point_tiles:
		var entries: Array = corner_point_tiles[pos_key]
		var n: int = entries.size()
		if n == 1:
			# Single tile — keeps its own elevation (already set above).
			continue

		# Build connectivity: two entries are connected if they are neighbors
		# with no wall on either side and same type (water/land).
		# parent[i] tracks union-find root.
		var parent: Array[int] = []
		parent.resize(n)
		for i: int in range(n):
			parent[i] = i
		for i: int in range(n):
			for j: int in range(i + 1, n):
				var a: Dictionary = entries[i]
				var b: Dictionary = entries[j]
				if a.is_water != b.is_water:
					continue
				# Find direction from a to b.
				var a_coords: Vector2i = a.coords
				var b_coords: Vector2i = b.coords
				var dir_ab: int = -1
				for d: int in range(6):
					if a_coords + (HexMath.DIRECTIONS[d] as Vector2i) == b_coords:
						dir_ab = d
						break
				if dir_ab < 0:
					continue  # not neighbors
				var dir_ba: int = (dir_ab + 3) % 6
				var a_tile: Resource = HexGrid._tiles[a_coords]
				var b_tile: Resource = HexGrid._tiles[b_coords]
				if a_tile.walls[dir_ab] or b_tile.walls[dir_ba]:
					continue  # wall blocks connection
				# Union
				var ra: int = i
				while parent[ra] != ra:
					ra = parent[ra]
				var rb: int = j
				while parent[rb] != rb:
					rb = parent[rb]
				if ra != rb:
					parent[ra] = rb

		# Group by component root and average elevation.
		var components: Dictionary = {}  # root → Array[int]
		for i: int in range(n):
			var r: int = i
			while parent[r] != r:
				r = parent[r]
			if not components.has(r):
				components[r] = []
			(components[r] as Array).append(i)

		for root: Variant in components:
			var indices: Array = components[root]
			var sum_e: float = 0.0
			for idx: int in indices:
				sum_e += (entries[idx] as Dictionary).elev
			var avg_y: float = (sum_e / float(indices.size())) * ELEVATION_STEP
			for idx: int in indices:
				var entry: Dictionary = entries[idx]
				(all_corner_y[entry.coords] as Array)[entry.ci] = avg_y

	# Steps 5-7: Build per-chunk geometry.
	# Each chunk gets its own Node3D with MeshInstance3D children per bucket.
	# Godot frustum-culls each MeshInstance3D by its AABB, so smaller chunks
	# mean only visible terrain is rendered.
	const RING_COUNT: int = 4
	const VERTS_PER_RING: int = 12
	var CLIFF_KEY := Vector2i(-1, -1)

	# Group tiles by chunk key.
	var chunks: Dictionary = {}  # Vector2i → Array[Variant]
	for coords: Variant in tile_colors:
		var ck: Vector2i = _chunk_key_for(coords as Vector2i)
		if not chunks.has(ck):
			chunks[ck] = []
		(chunks[ck] as Array).append(coords)

	# Material cache: reuse the same ShaderMaterial for identical bucket keys
	# across chunks. Avoids material explosion on large maps and reduces
	# DayNightCycle iteration overhead.
	var _material_cache: Dictionary = {}  # Vector2i bucket_key → ShaderMaterial
	var _get_or_create_material := func(key: Vector2i) -> ShaderMaterial:
		if _material_cache.has(key):
			return _material_cache[key]
		var mat := _make_bucket_material(key)
		_material_cache[key] = mat
		_materials.append(mat)
		DayNightCycle.register_hex_material(mat)
		return mat

	# Build each chunk.
	var first_mesh_assigned: bool = false
	for ck: Variant in chunks:
		var chunk_node := Node3D.new()
		chunk_node.name = "Chunk_%d_%d" % [(ck as Vector2i).x, (ck as Vector2i).y]
		add_child(chunk_node)
		_chunk_nodes[ck] = chunk_node

		var chunk_coords: Array = chunks[ck]
		var buckets: Dictionary = {}  # Vector2i → SurfaceTool
		var _get_bucket := func(key: Vector2i) -> SurfaceTool:
			if not buckets.has(key):
				var new_st := SurfaceTool.new()
				new_st.begin(Mesh.PRIMITIVE_TRIANGLES)
				buckets[key] = new_st
			return buckets[key]

		# Step 5: Tile surface geometry for this chunk.
		for coords: Variant in chunk_coords:
			var tile: Resource = HexGrid._tiles[coords]
			var bd: BiomeData = _biome_data[tile.biome]
			var variation_idx: int = _pick_variation_idx(bd, coords)
			var bucket_key: Vector2i
			if bd != null and not bd.terrain_textures.is_empty():
				bucket_key = Vector2i(int(tile.biome), variation_idx)
			else:
				bucket_key = Vector2i(int(tile.biome), _NO_TEXTURE_VARIATION)
			var st: SurfaceTool = _get_bucket.call(bucket_key)

			var world_2d: Vector2 = HexMath.axial_to_world(coords)
			var cx: float = world_2d.x
			var cz: float = world_2d.y
			var is_water: bool = tile.biome == _HexTile.Biome.WATER
			var elevation_y: float = (float(tile.water_level) if is_water else float(tile.elevation)) * ELEVATION_STEP
			var center_color: Color = tile_colors[coords]
			var corner_y: Array[float] = all_corner_y[coords]
			var edge_y: Array[float] = all_edge_y[coords]
			# Per-tile UV rotation (0/90/180/270°) — multiplies effective
			# variation by 4 against the same texture set. Skipped for
			# untextured biomes since they sample no texture anyway.
			var uv_rotation: float = 0.0
			if bd != null and not bd.terrain_textures.is_empty():
				uv_rotation = _pick_rotation_radians(coords)

			var corner_colors_at: Array[Color] = [
				center_color, center_color, center_color,
				center_color, center_color, center_color,
			]
			for i: int in range(6):
				var angle_i: float = deg_to_rad(60.0 * float(i))
				var ci_x: float = cx + cos(angle_i) * HexMath.HEX_SIZE
				var ci_z: float = cz + sin(angle_i) * HexMath.HEX_SIZE
				var key_i := Vector3i(
					roundi(ci_x * 1000.0),
					tile.elevation,
					roundi(ci_z * 1000.0)
				)
				corner_colors_at[i] = corner_colors.get(key_i, center_color)

			var rings_pos: Array = []
			var rings_col: Array = []
			var rings_uv: Array = []

			# Ring 0: center.
			rings_pos.append([Vector3(cx, elevation_y, cz)])
			rings_col.append([center_color])
			rings_uv.append([Vector2(0.5, 0.5)])

			# Rings 1..4.
			for k: int in range(1, RING_COUNT + 1):
				var t: float = float(k) / float(RING_COUNT)
				var s: float = t * t * t * (t * (6.0 * t - 15.0) + 10.0)
				var radius: float = HexMath.HEX_SIZE * t

				var ring_pos: Array = []
				var ring_col: Array = []
				var ring_uv: Array = []
				for j: int in range(VERTS_PER_RING):
					var angle: float = deg_to_rad(30.0 * float(j))
					var r: float = radius if j % 2 == 0 else radius * cos(deg_to_rad(30.0))
					var vx: float = cx + cos(angle) * r
					var vz: float = cz + sin(angle) * r

					var target_y: float
					var target_col: Color
					if j % 2 == 0:
						var ci: int = j / 2
						target_y = corner_y[ci]
						target_col = corner_colors_at[ci]
					else:
						var ei: int = (j - 1) / 2
						var d: int = edge_dir_for_midpoint[ei]
						target_y = edge_y[d]
						var ca: int = ei
						var cb: int = (ei + 1) % 6
						target_col = corner_colors_at[ca].lerp(corner_colors_at[cb], 0.5)

					var vy: float = lerpf(elevation_y, target_y, s)
					ring_pos.append(Vector3(vx, vy, vz))
					ring_col.append(center_color.lerp(target_col, t))
					# UV: hex-local, with per-tile rotation about (0.5, 0.5).
					# Centre stays put; the offset angle gets `uv_rotation`
					# added so each tile shows the same texture rotated by
					# 0/90/180/270°. Edge midpoints ride slightly closer to
					# centre via the r factor.
					var r_uv: float = r / HexMath.HEX_SIZE  # 0..1
					var uv_angle: float = angle + uv_rotation
					ring_uv.append(Vector2(
						0.5 + 0.5 * r_uv * cos(uv_angle),
						0.5 + 0.5 * r_uv * sin(uv_angle)
					))
				rings_pos.append(ring_pos)
				rings_col.append(ring_col)
				rings_uv.append(ring_uv)

			# Inner fan (center → ring1[j] → ring1[j+1]).
			var center_pos: Vector3 = rings_pos[0][0]
			var center_uv: Vector2 = rings_uv[0][0]
			var ring1_pos: Array = rings_pos[1]
			var ring1_col: Array = rings_col[1]
			var ring1_uv: Array = rings_uv[1]
			for j: int in range(VERTS_PER_RING):
				var j_next: int = (j + 1) % VERTS_PER_RING
				st.set_normal(Vector3.UP)
				st.set_color(center_color)
				st.set_uv(center_uv)
				st.add_vertex(center_pos)
				st.set_normal(Vector3.UP)
				st.set_color(ring1_col[j])
				st.set_uv(ring1_uv[j])
				st.add_vertex(ring1_pos[j])
				st.set_normal(Vector3.UP)
				st.set_color(ring1_col[j_next])
				st.set_uv(ring1_uv[j_next])
				st.add_vertex(ring1_pos[j_next])

			# Quad strips (3 × 12 quads × 2 tris).
			for k: int in range(1, RING_COUNT):
				var rk_pos: Array = rings_pos[k]
				var rk_col: Array = rings_col[k]
				var rk_uv: Array = rings_uv[k]
				var rk1_pos: Array = rings_pos[k + 1]
				var rk1_col: Array = rings_col[k + 1]
				var rk1_uv: Array = rings_uv[k + 1]
				for j: int in range(VERTS_PER_RING):
					var j_next: int = (j + 1) % VERTS_PER_RING
					st.set_normal(Vector3.UP)
					st.set_color(rk_col[j])
					st.set_uv(rk_uv[j])
					st.add_vertex(rk_pos[j])
					st.set_normal(Vector3.UP)
					st.set_color(rk1_col[j])
					st.set_uv(rk1_uv[j])
					st.add_vertex(rk1_pos[j])
					st.set_normal(Vector3.UP)
					st.set_color(rk_col[j_next])
					st.set_uv(rk_uv[j_next])
					st.add_vertex(rk_pos[j_next])

					st.set_normal(Vector3.UP)
					st.set_color(rk1_col[j])
					st.set_uv(rk1_uv[j])
					st.add_vertex(rk1_pos[j])
					st.set_normal(Vector3.UP)
					st.set_color(rk1_col[j_next])
					st.set_uv(rk1_uv[j_next])
					st.add_vertex(rk1_pos[j_next])
					st.set_normal(Vector3.UP)
					st.set_color(rk_col[j_next])
					st.set_uv(rk_uv[j_next])
					st.add_vertex(rk_pos[j_next])

		# Step 6: Wall faces for this chunk — color-only bucket.
		for coords: Variant in chunk_coords:
			var tile: Resource = HexGrid._tiles[coords]
			var world_2d: Vector2 = HexMath.axial_to_world(coords)
			var cx: float = world_2d.x
			var cz: float = world_2d.y

			for d: int in range(6):
				if not tile.walls[d]:
					continue
				var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
				var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
				# Skip if current tile is water and neighbor land is at or above
				# water level — land tile draws the shoreline cliff from its side.
				if tile.biome == _HexTile.Biome.WATER and n_tile != null \
						and n_tile.biome != _HexTile.Biome.WATER \
						and n_tile.elevation >= tile.water_level:
					continue

				# Water walls get blue color; land walls get darkened biome color.
				var cliff_color: Color
				var foam_color: Color
				if tile.biome == _HexTile.Biome.WATER:
					cliff_color = Color(0.15, 0.35, 0.7, 1.0)  # water blue
					foam_color = Color(0.85, 0.92, 0.98, 1.0)  # white foam
				else:
					cliff_color = tile_colors[coords] * 0.6
					foam_color = cliff_color  # no foam for land cliffs
				var ec: Array = edge_corners[d]
				var ca_idx: int = ec[0]
				var cb_idx: int = ec[1]

				var angle_a: float = deg_to_rad(60.0 * float(ca_idx))
				var angle_b: float = deg_to_rad(60.0 * float(cb_idx))
				var ca_x: float = cx + cos(angle_a) * HexMath.HEX_SIZE
				var ca_z: float = cz + sin(angle_a) * HexMath.HEX_SIZE
				var cb_x: float = cx + cos(angle_b) * HexMath.HEX_SIZE
				var cb_z: float = cz + sin(angle_b) * HexMath.HEX_SIZE
				var mid_angle: float = (angle_a + angle_b) / 2.0
				if absf(angle_a - angle_b) > PI:
					mid_angle += PI
				var edge_mid_radius: float = HexMath.HEX_SIZE * cos(deg_to_rad(30.0))
				var mid_x: float = cx + cos(mid_angle) * edge_mid_radius
				var mid_z: float = cz + sin(mid_angle) * edge_mid_radius

				var h_corner_y: Array[float] = all_corner_y[coords]
				var h_edge_y: Array[float] = all_edge_y[coords]
				var h_ca_y: float = h_corner_y[ca_idx]
				var h_mid_y: float = h_edge_y[d]
				var h_cb_y: float = h_corner_y[cb_idx]

				var l_ca_y: float
				var l_mid_y: float
				var l_cb_y: float
				if n_tile != null and all_corner_y.has(n_coords) and all_edge_y.has(n_coords):
					var n_cy: Array[float] = all_corner_y[n_coords]
					var n_ey: Array[float] = all_edge_y[n_coords]
					var rev_d: int = -1
					for rd: int in range(6):
						if n_coords + (HexMath.DIRECTIONS[rd] as Vector2i) == (coords as Vector2i):
							rev_d = rd
							break
					if rev_d >= 0:
						var rev_ec: Array = edge_corners[rev_d]
						l_cb_y = n_cy[rev_ec[0]]
						l_mid_y = n_ey[rev_d]
						l_ca_y = n_cy[rev_ec[1]]
					else:
						var n_surface: float = (float(n_tile.water_level) if n_tile.biome == _HexTile.Biome.WATER else float(n_tile.elevation)) * ELEVATION_STEP
						l_ca_y = n_surface
						l_mid_y = n_surface
						l_cb_y = n_surface
				elif n_tile != null:
					var n_surface: float = (float(n_tile.water_level) if n_tile.biome == _HexTile.Biome.WATER else float(n_tile.elevation)) * ELEVATION_STEP
					l_ca_y = n_surface
					l_mid_y = n_surface
					l_cb_y = n_surface
				else:
					l_ca_y = 0.0
					l_mid_y = 0.0
					l_cb_y = 0.0

				# Skip degenerate wall faces (zero height) — walls still block
				# smoothing but no cliff geometry is needed when both sides
				# are at the same level.
				if absf(h_ca_y - l_ca_y) < 0.01 and absf(h_mid_y - l_mid_y) < 0.01 and absf(h_cb_y - l_cb_y) < 0.01:
					continue

				var cliff_normal: Vector3
				if n_tile != null:
					var n_world: Vector2 = HexMath.axial_to_world(n_coords)
					var dir_x: float = n_world.x - cx
					var dir_z: float = n_world.y - cz
					var dir_len: float = sqrt(dir_x * dir_x + dir_z * dir_z)
					cliff_normal = Vector3(dir_x / dir_len, 0.0, dir_z / dir_len)
				else:
					cliff_normal = Vector3(cos(mid_angle), 0.0, sin(mid_angle))

				var h0 := Vector3(ca_x, h_ca_y, ca_z)
				var h1 := Vector3(mid_x, h_mid_y, mid_z)
				var h2 := Vector3(cb_x, h_cb_y, cb_z)
				var l0 := Vector3(ca_x, l_ca_y, ca_z)
				var l1 := Vector3(mid_x, l_mid_y, mid_z)
				var l2 := Vector3(cb_x, l_cb_y, cb_z)

				var cst: SurfaceTool = _get_bucket.call(CLIFF_KEY)
				# Tri 1: h0, l0, l1 — h vertices get cliff_color, l vertices get foam_color
				cst.set_normal(cliff_normal); cst.set_color(cliff_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(h0)
				cst.set_normal(cliff_normal); cst.set_color(foam_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(l0)
				cst.set_normal(cliff_normal); cst.set_color(foam_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(l1)
				# Tri 2: h0, l1, h1
				cst.set_normal(cliff_normal); cst.set_color(cliff_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(h0)
				cst.set_normal(cliff_normal); cst.set_color(foam_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(l1)
				cst.set_normal(cliff_normal); cst.set_color(cliff_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(h1)
				# Tri 3: h1, l1, l2
				cst.set_normal(cliff_normal); cst.set_color(cliff_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(h1)
				cst.set_normal(cliff_normal); cst.set_color(foam_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(l1)
				cst.set_normal(cliff_normal); cst.set_color(foam_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(l2)
				# Tri 4: h1, l2, h2
				cst.set_normal(cliff_normal); cst.set_color(cliff_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(h1)
				cst.set_normal(cliff_normal); cst.set_color(foam_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(l2)
				cst.set_normal(cliff_normal); cst.set_color(cliff_color); cst.set_uv(Vector2.ZERO); cst.add_vertex(h2)

		# Step 7: Commit this chunk's buckets.
		# First mesh overall → legacy $MeshInstance3D (test compatibility).
		# All others → MeshInstance3D children of the chunk Node3D.
		for bucket_key: Vector2i in buckets:
			var st: SurfaceTool = buckets[bucket_key]
			var mesh: ArrayMesh = st.commit()
			var mat: ShaderMaterial = _get_or_create_material.call(bucket_key)

			if not first_mesh_assigned:
				_mesh_instance.mesh = mesh
				_mesh_instance.material_override = mat
				first_mesh_assigned = true
			else:
				var inst := MeshInstance3D.new()
				inst.name = _bucket_node_name(bucket_key)
				inst.mesh = mesh
				inst.material_override = mat
				chunk_node.add_child(inst)
				_bucket_instances.append(inst)


## Build the ShaderMaterial for a bucket key.
## (-1, -1) = cliff bucket (color-only).
## (biome, -1) = no-texture biome (color-only).
## (biome, variation_idx) = textured biome.
func _make_bucket_material(key: Vector2i) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var biome_int: int = key.x
	var variation_idx: int = key.y
	if biome_int >= 0 and variation_idx >= 0:
		var bd: BiomeData = _biome_data[biome_int] if biome_int < _biome_data.size() else null
		if bd != null and variation_idx < bd.terrain_textures.size():
			mat.shader = _TEXTURED_SHADER
			mat.set_shader_parameter("terrain_texture", bd.terrain_textures[variation_idx])
			return mat
	# Fall back to color-only shader (cliffs, or biome without textures).
	mat.shader = _COLOR_SHADER
	return mat


## Map tile axial coords to chunk key using floor division.
func _chunk_key_for(coords: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(coords.x) / float(CHUNK_SIZE)),
		floori(float(coords.y) / float(CHUNK_SIZE)),
	)


func _bucket_node_name(key: Vector2i) -> String:
	if key == Vector2i(-1, -1):
		return "MeshInstance3D_Cliffs"
	return "MeshInstance3D_B%d_V%d" % [key.x, key.y]


## Base color for a tile. The old elevation-tint (factor = 1 + elev*0.05)
## made sense when elevation was clamped to 0..9 but now saturates to
## pure white at +20 and collapses to black at -20, which turns cliff
## tops and pits into colourless blocks. With the shader carrying the
## rest of the lighting, the right default is just the biome color.
func _pick_color(bd: BiomeData, _elevation: int) -> Color:
	return bd.color if bd != null else Color.WHITE


# ---------------------------------------------------------------------------
# Debug tool — call from Godot console:
#   $World/HexGridRenderer.debug_hex(Vector2i(q, r))
# ---------------------------------------------------------------------------

const _DIR_NAMES: Array = ["E", "NE", "NW", "W", "SW", "SE"]

## Compute edge_y[6] and corner_y[6] for a set of tiles using the same
## per-point algorithm as _rebuild_mesh Steps 4 + 4b.
## Returns Dictionary { coords → { edge_y, corner_y, biome, ... } }.
func _compute_geometry_for(tile_coords: Array[Vector2i]) -> Dictionary:
	var results: Dictionary = {}  # Vector2i → Dictionary

	# edge_y: per-tile (same as renderer Step 4).
	for coords: Vector2i in tile_coords:
		var tile: Resource = HexGrid._tiles.get(coords, null)
		if tile == null:
			continue
		var is_water: bool = tile.biome == _HexTile.Biome.WATER
		var elev: float = float(tile.water_level) if is_water else float(tile.elevation)
		var elev_y: float = elev * ELEVATION_STEP

		var ey: Array[float] = [elev_y, elev_y, elev_y, elev_y, elev_y, elev_y]
		for d: int in range(6):
			if tile.walls[d]:
				continue
			var n_coords: Vector2i = coords + (HexMath.DIRECTIONS[d] as Vector2i)
			var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
			if n_tile == null:
				continue
			if is_water != (n_tile.biome == _HexTile.Biome.WATER):
				continue
			var n_elev: float = float(n_tile.water_level) if n_tile.biome == _HexTile.Biome.WATER else float(n_tile.elevation)
			ey[d] = ((elev + n_elev) / 2.0) * ELEVATION_STEP

		results[coords] = {
			biome = tile.biome,
			elevation = tile.elevation,
			water_level = tile.water_level,
			is_water = is_water,
			walls = tile.walls.duplicate(),
			edge_y = ey,
			corner_y = [elev_y, elev_y, elev_y, elev_y, elev_y, elev_y] as Array[float],
		}

	# corner_y: per-point with connected components (same as renderer Step 4b).
	var corner_point_tiles: Dictionary = {}
	for coords: Vector2i in results:
		var data: Dictionary = results[coords]
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y
		for ci: int in range(6):
			var angle: float = deg_to_rad(60.0 * float(ci))
			var pos_key := Vector2i(
				roundi((cx + cos(angle) * HexMath.HEX_SIZE) * 1000.0),
				roundi((cz + sin(angle) * HexMath.HEX_SIZE) * 1000.0),
			)
			if not corner_point_tiles.has(pos_key):
				corner_point_tiles[pos_key] = []
			(corner_point_tiles[pos_key] as Array).append({
				coords = coords, ci = ci,
				elev = float(data.water_level) if data.is_water else float(data.elevation),
				is_water = data.is_water,
			})

	for pos_key: Variant in corner_point_tiles:
		var entries: Array = corner_point_tiles[pos_key]
		var n: int = entries.size()
		if n <= 1:
			continue
		var parent: Array[int] = []
		parent.resize(n)
		for i: int in range(n):
			parent[i] = i
		for i: int in range(n):
			for j: int in range(i + 1, n):
				var a: Dictionary = entries[i]
				var b: Dictionary = entries[j]
				if a.is_water != b.is_water:
					continue
				var dir_ab: int = -1
				for d: int in range(6):
					if (a.coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i) == (b.coords as Vector2i):
						dir_ab = d
						break
				if dir_ab < 0:
					continue
				var dir_ba: int = (dir_ab + 3) % 6
				var a_tile: Resource = HexGrid._tiles[a.coords]
				var b_tile: Resource = HexGrid._tiles[b.coords]
				if a_tile.walls[dir_ab] or b_tile.walls[dir_ba]:
					continue
				var ra: int = i
				while parent[ra] != ra:
					ra = parent[ra]
				var rb: int = j
				while parent[rb] != rb:
					rb = parent[rb]
				if ra != rb:
					parent[ra] = rb
		var components: Dictionary = {}
		for i: int in range(n):
			var r: int = i
			while parent[r] != r:
				r = parent[r]
			if not components.has(r):
				components[r] = []
			(components[r] as Array).append(i)
		for root: Variant in components:
			var indices: Array = components[root]
			var sum_e: float = 0.0
			for idx: int in indices:
				sum_e += (entries[idx] as Dictionary).elev
			var avg_y: float = (sum_e / float(indices.size())) * ELEVATION_STEP
			for idx: int in indices:
				var entry: Dictionary = entries[idx]
				if results.has(entry.coords):
					(results[entry.coords].corner_y as Array)[entry.ci] = avg_y

	return results


## Print edge_y / corner_y for a hex and all neighbors, marking shared-point
## mismatches and wall rendering status.
func debug_hex(coords: Vector2i) -> void:
	var edge_corners: Array = [
		[0, 1], [5, 0], [4, 5], [3, 4], [2, 3], [1, 2],
	]

	if not HexGrid._tiles.has(coords):
		print("debug_hex: tile %s does not exist" % str(coords))
		return

	# Gather center + all neighbors for per-point computation.
	var all_coords: Array[Vector2i] = [coords]
	for d: int in range(6):
		var n: Vector2i = coords + (HexMath.DIRECTIONS[d] as Vector2i)
		if HexGrid._tiles.has(n):
			all_coords.append(n)
		# Also include neighbors-of-neighbors that share corners with center.
		# This ensures the per-point algorithm has full context for all corners.
		for d2: int in range(6):
			var nn: Vector2i = n + (HexMath.DIRECTIONS[d2] as Vector2i)
			if HexGrid._tiles.has(nn) and not all_coords.has(nn):
				all_coords.append(nn)

	var geo: Dictionary = _compute_geometry_for(all_coords)
	var center: Dictionary = geo[coords]

	var walls_str: String = ""
	for w: bool in center.walls:
		walls_str += "T" if w else "F"
	print("=== Hex %s ===" % str(coords))
	print("  Biome: %d  Elev: %d  WaterLvl: %d  Water: %s  Walls: [%s]  Chunk: %s" % [
		center.biome, center.elevation, center.water_level,
		"Y" if center.is_water else "N", walls_str, str(_chunk_key_for(coords))])
	print("  edge_y:   %s" % str(_fmt_floats(center.edge_y)))
	print("  corner_y: %s" % str(_fmt_floats(center.corner_y)))

	var mismatch_count: int = 0
	for d: int in range(6):
		var n_coords: Vector2i = coords + (HexMath.DIRECTIONS[d] as Vector2i)
		var rev_d: int = (d + 3) % 6
		var ec: Array = edge_corners[d]
		var ca_idx: int = ec[0]
		var cb_idx: int = ec[1]

		print("")
		if not geo.has(n_coords):
			print("--- %s (%s) — no tile ---" % [_DIR_NAMES[d], str(n_coords)])
			# Wall analysis: center has wall toward empty → wall face drawn
			if center.walls[d]:
				print("  Wall: center draws cliff face toward void")
			continue

		var n_data: Dictionary = geo[n_coords]
		var n_walls_str: String = ""
		for w: bool in n_data.walls:
			n_walls_str += "T" if w else "F"
		print("--- %s (%s) ---" % [_DIR_NAMES[d], str(n_coords)])
		print("  Biome: %d  Elev: %d  WaterLvl: %d  Water: %s  Walls: [%s]" % [
			n_data.biome, n_data.elevation, n_data.water_level,
			"Y" if n_data.is_water else "N", n_walls_str])
		print("  edge_y:   %s" % str(_fmt_floats(n_data.edge_y)))
		print("  corner_y: %s" % str(_fmt_floats(n_data.corner_y)))

		# Wall rendering analysis
		var c_has_wall: bool = center.walls[d]
		var n_has_wall: bool = n_data.walls[rev_d]
		var c_surface: float = float(center.water_level) if center.is_water else float(center.elevation)
		var n_surface: float = float(n_data.water_level) if n_data.is_water else float(n_data.elevation)
		var same_type: bool = center.is_water == n_data.is_water
		# Water↔land always expects a wall.
		var wall_expected: bool = not same_type
		# Who draws the wall face?
		var c_draws: bool = c_has_wall
		var n_draws: bool = n_has_wall
		if center.is_water and not n_data.is_water and n_data.elevation >= center.water_level:
			c_draws = false  # water skips when neighbor land is at or above water
		if n_data.is_water and not center.is_water and center.elevation >= n_data.water_level:
			n_draws = false

		if c_has_wall or n_has_wall:
			var wall_parts: PackedStringArray = PackedStringArray()
			if c_has_wall:
				wall_parts.append("center.walls[%d]=T" % d)
			if n_has_wall:
				wall_parts.append("neighbor.walls[%d]=T" % rev_d)
			var draw_parts: PackedStringArray = PackedStringArray()
			if c_draws:
				draw_parts.append("center draws")
			if n_draws:
				draw_parts.append("neighbor draws")
			if draw_parts.is_empty():
				draw_parts.append("neither draws (skipped)")
			print("  Wall: %s → %s" % [", ".join(wall_parts), ", ".join(draw_parts)])
		else:
			if wall_expected:
				print("  Wall: MISSING — expected wall between %s and %s" % [
					"water" if center.is_water else "land",
					"water" if n_data.is_water else "land"])
			else:
				print("  Wall: none (smooth edge)")

		# Compare shared edge midpoint
		var rev_ec: Array = edge_corners[rev_d]
		var c_mid: float = center.edge_y[d]
		var n_mid: float = n_data.edge_y[rev_d]
		var mid_ok: String = "OK" if absf(c_mid - n_mid) < 0.001 else "MISMATCH"
		if mid_ok != "OK":
			mismatch_count += 1
		print("  Edge mid  (c.ey[%d]=%.3f  n.ey[%d]=%.3f) %s" % [d, c_mid, rev_d, n_mid, mid_ok])

		# Compare shared corners (cross-mapped)
		var c_ca_y: float = center.corner_y[ca_idx]
		var n_ca_y: float = n_data.corner_y[rev_ec[1]]
		var ca_ok: String = "OK" if absf(c_ca_y - n_ca_y) < 0.001 else "MISMATCH"
		if ca_ok != "OK":
			mismatch_count += 1
		print("  Corner A  (c.cy[%d]=%.3f  n.cy[%d]=%.3f) %s" % [ca_idx, c_ca_y, rev_ec[1], n_ca_y, ca_ok])

		var c_cb_y: float = center.corner_y[cb_idx]
		var n_cb_y: float = n_data.corner_y[rev_ec[0]]
		var cb_ok: String = "OK" if absf(c_cb_y - n_cb_y) < 0.001 else "MISMATCH"
		if cb_ok != "OK":
			mismatch_count += 1
		print("  Corner B  (c.cy[%d]=%.3f  n.cy[%d]=%.3f) %s" % [cb_idx, c_cb_y, rev_ec[0], n_cb_y, cb_ok])

	print("")
	if mismatch_count == 0:
		print("All shared points match.")
	else:
		print("%d MISMATCHES found!" % mismatch_count)


func _fmt_floats(arr: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for v: float in arr:
		parts.append("%.3f" % v)
	return "[%s]" % ", ".join(parts)
