extends Node3D

## HexGridRenderer — single ArrayMesh with per-vertex color blending.
## One draw call for the entire hex grid. Signal-driven, no _process.
##
## Architecture:
##   - On map_generated: build full ArrayMesh from HexGrid tile data.
##   - Concentric ring subdivision: 1 center + 12 vertices × 4 rings = 49 vertices per hex.
##   - 12 inner-fan triangles + 72 ring-strip triangles = 84 triangles per hex.
##   - Ring radii: 0, 25%, 50%, 75%, 100% of HEX_SIZE.
##   - 12 vertices per ring: 6 at corners (0°,60°,...) + 6 at edge midpoints (30°,90°,...).
##   - Quintic smoothstep interpolation; corners target corner_y, edge mids target edge_y.
##   - edge_y: avg of 2 hexes if slope (diff ≤ 2), own elevation if cliff (diff ≥ 3).
##   - corner_y: avg of this hex + neighbors with diff ≤ 2.
##   - Center vertex color = biome color variation (hash-selected from BiomeData).
##   - Corner vertex color = average of all tiles sharing that corner at SAME elevation.
##   - Different elevation = different corner key → no color sharing → cliff edge.
##   - Y position = elevation * ELEVATION_STEP, with corner Y averaged for slopes (diff 1-2).
##   - Water tiles stay flat regardless of neighbor elevation (no curvature).
##   - HIDDEN tiles: excluded from mesh (no geometry).
##   - VISIBLE tiles: full vertex colors. Darkness handled by shader.
##   - Highlights: vertex color override, cleared on clear_highlights().
##   - Cliff faces generated only for elevation diff >= 3 (BLOCKED traversal).

const _HexTile = preload("res://scripts/hex/hex_tile.gd")

const ELEVATION_STEP: float = 0.5

## BiomeData .tres paths indexed by HexTile.Biome enum value.
const BIOME_PATHS: Array[String] = [
	"res://data/biomes/crash_site.tres",
	"res://data/biomes/grassland.tres",
	"res://data/biomes/forest.tres",
	"res://data/biomes/rocky.tres",
	"res://data/biomes/water.tres",
]

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial

## Loaded BiomeData resources indexed by Biome enum value.
var _biome_data: Array = []

## coords (Vector2i) → {base_color: Color, fog_state: int, highlight: Color}
## base_color: elevation-tinted biome color, no fog applied.
## fog_state: current HexTile.FogState value.
## highlight: Color.TRANSPARENT = inactive.
var _tile_data: Dictionary = {}

## Currently highlighted tile coords → true.
var _highlights: Dictionary = {}


func _ready() -> void:
	_mesh_instance = $MeshInstance3D

	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/hex_tile.gdshader")
	_mesh_instance.material_override = _material
	DayNightCycle.register_hex_material(_material)

	_biome_data.resize(5)
	for i: int in range(5):
		_biome_data[i] = load(BIOME_PATHS[i])

	HexGrid.map_generated.connect(_on_map_generated)
	HexGrid.tile_revealed.connect(_on_tile_revealed)
	HexGrid.tile_visibility_changed.connect(_on_tile_visibility_changed)


# --- Signal handlers ---

func _on_map_generated() -> void:
	_tile_data.clear()
	_highlights.clear()
	_build_tile_data()
	_rebuild_mesh()


func _on_tile_revealed(coords: Vector2i) -> void:
	if not _tile_data.has(coords):
		return
	var tile = HexGrid._tiles.get(coords, null)
	if tile == null:
		return
	_tile_data[coords].fog_state = tile.fog_state
	_rebuild_mesh()


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	if not _tile_data.has(coords):
		return
	_tile_data[coords].fog_state = state
	_rebuild_mesh()


# --- Public API ---

## Temporarily override vertex colors for specified tiles (building placement preview).
## Replaces any existing highlights.
func highlight_tiles(coords: Array[Vector2i], color: Color) -> void:
	clear_highlights()
	for coord: Vector2i in coords:
		if _tile_data.has(coord):
			_tile_data[coord].highlight = color
			_highlights[coord] = true
	_rebuild_mesh()


## Remove all active highlights, restoring fog-based appearance.
func clear_highlights() -> void:
	for coord: Vector2i in _highlights:
		if _tile_data.has(coord):
			_tile_data[coord].highlight = Color.TRANSPARENT
	_highlights.clear()
	_rebuild_mesh()


# --- Internal helpers ---

## Populate _tile_data from all current HexGrid tiles.
func _build_tile_data() -> void:
	for coords: Variant in HexGrid._tiles:
		var tile: Resource = HexGrid._tiles[coords]
		var bd: BiomeData = _biome_data[tile.biome]
		var base_color: Color = _pick_color(bd, coords, tile.elevation)
		_tile_data[coords] = {
			base_color = base_color,
			fog_state = tile.fog_state,
			highlight = Color.TRANSPARENT,
		}


## Rebuild the entire ArrayMesh from current _tile_data.
## Called on map_generated and on any fog/highlight change.
func _rebuild_mesh() -> void:
	# Step 1: Compute final vertex color per tile (fog + highlight applied).
	var tile_colors: Dictionary = {}
	for coords: Variant in _tile_data:
		var data: Dictionary = _tile_data[coords]
		if data.fog_state == _HexTile.FogState.HIDDEN:
			continue  # Hidden tiles produce no geometry.
		var c: Color = data.base_color
		if (data.highlight as Color).a > 0.0:
			c = data.highlight
		tile_colors[coords] = c

	if tile_colors.is_empty():
		_mesh_instance.mesh = null
		return

	# Step 2: Build corner color map.
	# Key = Vector3i(round(x*1000), elevation, round(z*1000)) → Array[Color].
	# Only tiles visible (non-HIDDEN) contribute their color to shared corners.
	# Different elevations = different keys → no color sharing → hard cliff edge.
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
			var key := Vector3i(
				roundi(corner_x * 1000.0),
				tile.elevation,
				roundi(corner_z * 1000.0)
			)
			if not corner_map.has(key):
				corner_map[key] = []
			(corner_map[key] as Array).append(tile_colors[coords])

	# Step 3: Average corner colors.
	var corner_colors: Dictionary = {}
	for key: Variant in corner_map:
		var colors: Array = corner_map[key]
		var r: float = 0.0
		var g: float = 0.0
		var b: float = 0.0
		var a: float = 0.0
		for c: Color in colors:
			r += c.r
			g += c.g
			b += c.b
			a += c.a
		var n: float = float(colors.size())
		corner_colors[key] = Color(r / n, g / n, b / n, a / n)

	# Step 4: Compute edge_y and corner_y for all visible tiles.
	# edge_y[d]: Y at the midpoint of edge in direction d.
	#   - diff ≤ 2 (slope): avg of both hexes × ELEVATION_STEP
	#   - diff ≥ 3 (cliff): own elevation × ELEVATION_STEP
	# corner_y[i]: Y at corner i (shared by 3 hexes).
	#   - Include each neighbor if diff ≤ 2; avg of included × ELEVATION_STEP
	#
	# Corner-to-neighbor mapping for flat-top hexes (verified empirically):
	var corner_neighbor_dirs: Array = [
		[0, 1],  # corner 0 (0°)   ← E + SE
		[0, 5],  # corner 1 (60°)  ← E + N
		[5, 4],  # corner 2 (120°) ← N + NW
		[4, 3],  # corner 3 (180°) ← NW + SW
		[3, 2],  # corner 4 (240°) ← SW + S
		[2, 1],  # corner 5 (300°) ← S + SE
	]
	# Edge-to-corner mapping: DIRECTIONS[d] → [corner_a, corner_b].
	var edge_corners: Array = [
		[0, 1],  # dir 0 (E)  → 0° and 60°
		[5, 0],  # dir 1 (SE) → 300° and 0°
		[4, 5],  # dir 2 (S)  → 240° and 300°
		[3, 4],  # dir 3 (SW) → 180° and 240°
		[2, 3],  # dir 4 (NW) → 120° and 180°
		[1, 2],  # dir 5 (N)  → 60° and 120°
	]
	# Maps edge midpoint ring-index (0..5 for odd vertices 1,3,5,7,9,11) to direction.
	var edge_dir_for_midpoint: Array[int] = [0, 5, 4, 3, 2, 1]

	var all_edge_y: Dictionary = {}    # coords → Array[float] of 6
	var all_corner_y: Dictionary = {}  # coords → Array[float] of 6

	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var elev: float = float(tile.elevation)
		var elev_y: float = elev * ELEVATION_STEP

		# Edge Y
		var ey: Array[float] = [elev_y, elev_y, elev_y, elev_y, elev_y, elev_y]
		for d: int in range(6):
			var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
			var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
			if n_tile == null:
				continue
			var diff: int = absi(tile.elevation - n_tile.elevation)
			if diff <= 2:
				ey[d] = ((elev + float(n_tile.elevation)) / 2.0) * ELEVATION_STEP
		all_edge_y[coords] = ey

		# Corner Y
		var cy: Array[float] = [elev_y, elev_y, elev_y, elev_y, elev_y, elev_y]
		for ci: int in range(6):
			var sum_e: float = elev
			var cnt: int = 1
			var dir_pair: Array = corner_neighbor_dirs[ci]
			for d: int in dir_pair:
				var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
				var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
				if n_tile == null:
					continue
				if absi(tile.elevation - n_tile.elevation) <= 2:
					sum_e += float(n_tile.elevation)
					cnt += 1
			cy[ci] = (sum_e / float(cnt)) * ELEVATION_STEP
		all_corner_y[coords] = cy

	# Step 5: Assemble hex surface triangles with SurfaceTool.
	# 12 vertices per ring (6 at corners + 6 at edge midpoints).
	# 12 inner-fan tris + 3 strips × 24 tris = 84 tris per hex.
	const RING_COUNT: int = 4
	const VERTS_PER_RING: int = 12

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y
		var elevation_y: float = float(tile.elevation) * ELEVATION_STEP
		var center_color: Color = tile_colors[coords]
		var is_water: bool = tile.biome == _HexTile.Biome.WATER
		var corner_y: Array[float] = all_corner_y[coords]
		var edge_y: Array[float] = all_edge_y[coords]

		# Precompute outer corner colors (at 6 corner positions).
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

		# Build ring vertices: 12 per ring (corners at 0°,60°,... + edge mids at 30°,90°,...).
		var rings_pos: Array = []
		var rings_col: Array = []

		# Ring 0: center.
		rings_pos.append([Vector3(cx, elevation_y, cz)])
		rings_col.append([center_color])

		# Rings 1..4.
		for k: int in range(1, RING_COUNT + 1):
			var t: float = float(k) / float(RING_COUNT)
			var s: float = t * t * t * (t * (6.0 * t - 15.0) + 10.0)  # quintic smoothstep
			var radius: float = HexMath.HEX_SIZE * t

			var ring_pos: Array = []
			var ring_col: Array = []
			for j: int in range(VERTS_PER_RING):
				var angle: float = deg_to_rad(30.0 * float(j))
				# Edge midpoints sit closer to center than corners (hex is flat-sided).
				# Corner radius = full radius. Edge midpoint = radius * cos(30°).
				var r: float = radius if j % 2 == 0 else radius * cos(deg_to_rad(30.0))
				var vx: float = cx + cos(angle) * r
				var vz: float = cz + sin(angle) * r

				var target_y: float
				var target_col: Color
				if j % 2 == 0:
					# Corner vertex.
					var ci: int = j / 2
					target_y = corner_y[ci]
					target_col = corner_colors_at[ci]
				else:
					# Edge midpoint vertex.
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
			rings_pos.append(ring_pos)
			rings_col.append(ring_col)

		# Inner fan: 12 triangles (center → ring1[j] → ring1[j+1]).
		var center_pos: Vector3 = rings_pos[0][0]
		var ring1_pos: Array = rings_pos[1]
		var ring1_col: Array = rings_col[1]
		for j: int in range(VERTS_PER_RING):
			var j_next: int = (j + 1) % VERTS_PER_RING
			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(center_pos)
			st.set_normal(Vector3.UP)
			st.set_color(ring1_col[j])
			st.add_vertex(ring1_pos[j])
			st.set_normal(Vector3.UP)
			st.set_color(ring1_col[j_next])
			st.add_vertex(ring1_pos[j_next])

		# Quad strips: 3 strips × 12 quads × 2 tris = 72 triangles.
		for k: int in range(1, RING_COUNT):
			var rk_pos: Array = rings_pos[k]
			var rk_col: Array = rings_col[k]
			var rk1_pos: Array = rings_pos[k + 1]
			var rk1_col: Array = rings_col[k + 1]
			for j: int in range(VERTS_PER_RING):
				var j_next: int = (j + 1) % VERTS_PER_RING
				st.set_normal(Vector3.UP)
				st.set_color(rk_col[j])
				st.add_vertex(rk_pos[j])
				st.set_normal(Vector3.UP)
				st.set_color(rk1_col[j])
				st.add_vertex(rk1_pos[j])
				st.set_normal(Vector3.UP)
				st.set_color(rk_col[j_next])
				st.add_vertex(rk_pos[j_next])

				st.set_normal(Vector3.UP)
				st.set_color(rk1_col[j])
				st.add_vertex(rk1_pos[j])
				st.set_normal(Vector3.UP)
				st.set_color(rk1_col[j_next])
				st.add_vertex(rk1_pos[j_next])
				st.set_normal(Vector3.UP)
				st.set_color(rk_col[j_next])
				st.add_vertex(rk_pos[j_next])

	# Step 6: Generate wall faces on ALL edges where this hex is higher than neighbor.
	# Walls on every face with elevation > 0 eliminates visual gaps regardless of
	# corner_y averaging asymmetry. Short walls for slopes, tall walls for cliffs.
	# 6-point polygon per wall, following the actual surface profile on both sides.
	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		if tile.elevation == 0:
			continue  # Ground-level hexes need no walls.
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y

		for d: int in range(6):
			var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
			var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
			# Wall if neighbor is lower or missing (map edge).
			if n_tile != null and n_tile.elevation >= tile.elevation:
				continue

			var cliff_color: Color = tile_colors[coords] * 0.6
			var ec: Array = edge_corners[d]
			var ca_idx: int = ec[0]
			var cb_idx: int = ec[1]

			# Corner and edge midpoint world XZ positions.
			var angle_a: float = deg_to_rad(60.0 * float(ca_idx))
			var angle_b: float = deg_to_rad(60.0 * float(cb_idx))
			var ca_x: float = cx + cos(angle_a) * HexMath.HEX_SIZE
			var ca_z: float = cz + sin(angle_a) * HexMath.HEX_SIZE
			var cb_x: float = cx + cos(angle_b) * HexMath.HEX_SIZE
			var cb_z: float = cz + sin(angle_b) * HexMath.HEX_SIZE
			var mid_angle: float = (angle_a + angle_b) / 2.0
			# Handle wrap-around (e.g., corners at 300° and 0° → mid at 330°, not 150°).
			if absf(angle_a - angle_b) > PI:
				mid_angle += PI
			var edge_mid_radius: float = HexMath.HEX_SIZE * cos(deg_to_rad(30.0))
			var mid_x: float = cx + cos(mid_angle) * edge_mid_radius
			var mid_z: float = cz + sin(mid_angle) * edge_mid_radius

			# High hex (tile) Y values at the 3 edge points.
			var h_corner_y: Array[float] = all_corner_y[coords]
			var h_edge_y: Array[float] = all_edge_y[coords]
			var h_ca_y: float = h_corner_y[ca_idx]
			var h_mid_y: float = h_edge_y[d]
			var h_cb_y: float = h_corner_y[cb_idx]

			# Low side Y values at the 3 edge points.
			var l_ca_y: float
			var l_mid_y: float
			var l_cb_y: float
			if n_tile != null and all_corner_y.has(n_coords) and all_edge_y.has(n_coords):
				# Neighbor exists — use its surface profile (corners swapped).
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
					var low_y: float = float(n_tile.elevation) * ELEVATION_STEP
					l_ca_y = low_y
					l_mid_y = low_y
					l_cb_y = low_y
			elif n_tile != null:
				var low_y: float = float(n_tile.elevation) * ELEVATION_STEP
				l_ca_y = low_y
				l_mid_y = low_y
				l_cb_y = low_y
			else:
				# Map edge — wall goes down to ground (Y=0).
				l_ca_y = 0.0
				l_mid_y = 0.0
				l_cb_y = 0.0

			# Normal: direction toward neighbor (or outward for map edges).
			var cliff_normal: Vector3
			if n_tile != null:
				var n_world: Vector2 = HexMath.axial_to_world(n_coords)
				var dir_x: float = n_world.x - cx
				var dir_z: float = n_world.y - cz
				var dir_len: float = sqrt(dir_x * dir_x + dir_z * dir_z)
				cliff_normal = Vector3(dir_x / dir_len, 0.0, dir_z / dir_len)
			else:
				# Map edge: normal points outward from hex center toward edge midpoint.
				cliff_normal = Vector3(cos(mid_angle), 0.0, sin(mid_angle))

			# 6 vertices of the cliff face polygon:
			# Top (high hex):  h0=corner_a, h1=edge_mid, h2=corner_b
			# Bot (low hex):   l2=corner_b, l1=edge_mid, l0=corner_a  (mirrored)
			var h0 := Vector3(ca_x, h_ca_y, ca_z)
			var h1 := Vector3(mid_x, h_mid_y, mid_z)
			var h2 := Vector3(cb_x, h_cb_y, cb_z)
			var l0 := Vector3(ca_x, l_ca_y, ca_z)
			var l1 := Vector3(mid_x, l_mid_y, mid_z)
			var l2 := Vector3(cb_x, l_cb_y, cb_z)

			# 4 triangles (CCW from outside = visible from neighbor side):
			# Tri 1: h0, l0, l1
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(h0)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(l0)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(l1)
			# Tri 2: h0, l1, h1
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(h0)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(l1)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(h1)
			# Tri 3: h1, l1, l2
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(h1)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(l1)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(l2)
			# Tri 4: h1, l2, h2
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(h1)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(l2)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(h2)

	_mesh_instance.mesh = st.commit()


## Select a color variation for a tile deterministically from its coords hash.
## Elevation subtly lightens the color (+5% per level).
func _pick_color(bd: BiomeData, coords: Vector2i, elevation: int) -> Color:
	var base: Color
	if bd.color_variations.is_empty():
		base = bd.color
	else:
		var hash_val: int = (coords.x * 73856093) ^ (coords.y * 19349663)
		var idx: int = absi(hash_val) % bd.color_variations.size()
		base = bd.color_variations[idx]

	var factor: float = 1.0 + float(elevation) * 0.05
	return Color(
		minf(base.r * factor, 1.0),
		minf(base.g * factor, 1.0),
		minf(base.b * factor, 1.0),
		base.a
	)
