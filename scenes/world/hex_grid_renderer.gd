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
	# Step 0: Drop previous bucket instances + materials (keep _mesh_instance node).
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
				if absi(elev - other.elevation) <= 2:
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

		var cy: Array[float] = [elev_y, elev_y, elev_y, elev_y, elev_y, elev_y]
		for ci: int in range(6):
			var sum_e: float = elev
			var cnt: int = 1
			var dir_pair: Array = corner_neighbor_dirs[ci]
			for d: int in dir_pair:
				# Skip neighbors across a wall edge
				if tile.walls[d]:
					continue
				var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
				var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
				if n_tile == null:
					continue
				if is_water != (n_tile.biome == _HexTile.Biome.WATER):
					continue
				var n_elev: float = float(n_tile.water_level) if n_tile.biome == _HexTile.Biome.WATER else float(n_tile.elevation)
				sum_e += n_elev
				cnt += 1
			cy[ci] = (sum_e / float(cnt)) * ELEVATION_STEP
		all_corner_y[coords] = cy

	# Step 5: Build per-bucket SurfaceTools for tile surfaces.
	# Bucket key = Vector2i(biome_int, variation_idx). Cliff faces go into a
	# single dedicated color-only bucket keyed (-1, -1) so all cliffs of all
	# biomes share one draw.
	const RING_COUNT: int = 4
	const VERTS_PER_RING: int = 12
	var CLIFF_KEY := Vector2i(-1, -1)

	var buckets: Dictionary = {}  # Vector2i → SurfaceTool
	var _get_bucket := func(key: Vector2i) -> SurfaceTool:
		if not buckets.has(key):
			var new_st := SurfaceTool.new()
			new_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			buckets[key] = new_st
		return buckets[key]

	for coords: Variant in tile_colors:
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

				var vy: float
				if is_water:
					vy = elevation_y
				else:
					vy = lerpf(elevation_y, target_y, s)
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

	# Step 6: Wall faces — color-only bucket.
	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y

		for d: int in range(6):
			if not tile.walls[d]:
				continue
			var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
			var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
			# Skip if current tile is water and neighbor is higher land
			# (land tile draws the shoreline cliff from its side).
			if tile.biome == _HexTile.Biome.WATER and n_tile != null \
					and n_tile.biome != _HexTile.Biome.WATER \
					and n_tile.elevation > tile.water_level:
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
			if n_tile != null and n_tile.biome == _HexTile.Biome.WATER:
				var water_y: float = float(n_tile.water_level) * ELEVATION_STEP
				l_ca_y = water_y
				l_mid_y = water_y
				l_cb_y = water_y
			elif n_tile != null and all_corner_y.has(n_coords) and all_edge_y.has(n_coords):
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

	# Step 7: Commit every bucket.
	# - The first bucket goes into the scene's $MeshInstance3D so the existing
	#   test that asserts "mesh != null on the child named MeshInstance3D"
	#   stays happy.
	# - Additional buckets spawn new MeshInstance3D children.
	var first_assigned: bool = false
	for bucket_key: Vector2i in buckets:
		var st: SurfaceTool = buckets[bucket_key]
		var mesh: ArrayMesh = st.commit()
		var mat := _make_bucket_material(bucket_key)
		_materials.append(mat)
		DayNightCycle.register_hex_material(mat)

		if not first_assigned:
			_mesh_instance.mesh = mesh
			_mesh_instance.material_override = mat
			first_assigned = true
		else:
			var inst := MeshInstance3D.new()
			inst.name = _bucket_node_name(bucket_key)
			inst.mesh = mesh
			inst.material_override = mat
			add_child(inst)
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
