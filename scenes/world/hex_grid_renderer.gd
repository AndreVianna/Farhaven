extends Node3D

## HexGridRenderer — single ArrayMesh with per-vertex color blending.
## One draw call for the entire hex grid. Signal-driven, no _process.
##
## Architecture:
##   - On map_generated: build full ArrayMesh from HexGrid tile data.
##   - 7 vertices per hex (1 center + 6 corners), 6 triangles (fan from center).
##   - Center vertex color = biome color variation (hash-selected from BiomeData).
##   - Corner vertex color = average of all tiles sharing that corner at SAME elevation.
##   - Different elevation = each hex owns its own corner vertices → hard cliff edge.
##   - Y position = elevation * ELEVATION_STEP.
##   - HIDDEN tiles: excluded from mesh (no geometry).
##   - VISIBLE tiles: full vertex colors. Darkness handled by shader.
##   - Highlights: vertex color override, cleared on clear_highlights().

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

	# Step 4: Assemble triangles with SurfaceTool.
	# Each hex has 13 vertices: center + 6 inner ring (85% radius) + 6 corners.
	# Inner ring vertices = pure tile color. Only corners blend with neighbors.
	# This creates a narrow 15% transition band at hex edges.
	const INNER_RING: float = 0.85  # inner ring at 85% of hex radius

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y
		var elevation_y: float = float(tile.elevation) * ELEVATION_STEP
		var center_color: Color = tile_colors[coords]

		# Compute per-corner Y by directly averaging the elevations of all 3 hexes
		# that share each corner. CRITICAL for cross-hex consistency: each of the
		# 3 hexes sharing a corner must compute the SAME Y value for it.
		#
		# Corner-to-neighbor mapping for flat-top hexes (verified empirically):
		# DIRECTIONS array order is [E, SE, S, SW, NW, N].
		# Corner i is at angle i*60°. The 2 neighbors sharing corner i:
		var corner_neighbor_dirs: Array = [
			[0, 1],  # corner 0 (0°)   ← E + SE
			[0, 5],  # corner 1 (60°)  ← E + N
			[5, 4],  # corner 2 (120°) ← N + NW
			[4, 3],  # corner 3 (180°) ← NW + SW
			[3, 2],  # corner 4 (240°) ← SW + S
			[2, 1],  # corner 5 (300°) ← S + SE
		]
		var corner_y: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for ci: int in range(6):
			# Gather all elevations sharing this corner.
			var elevs: Array[int] = [tile.elevation]
			var dir_pair: Array = corner_neighbor_dirs[ci]
			for d: int in dir_pair:
				var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
				var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
				if n_tile != null:
					elevs.append(n_tile.elevation)
			# Only average if ALL pairwise diffs are within slope range.
			var max_diff: int = 0
			for a: int in range(elevs.size()):
				for b: int in range(a + 1, elevs.size()):
					max_diff = maxi(max_diff, absi(elevs[a] - elevs[b]))
			if max_diff <= 3:
				var sum_elev: float = 0.0
				for e: int in elevs:
					sum_elev += float(e)
				corner_y[ci] = (sum_elev / float(elevs.size())) * ELEVATION_STEP
			else:
				corner_y[ci] = elevation_y

		for i: int in range(6):
			var angle_i: float = deg_to_rad(60.0 * float(i))
			var angle_j: float = deg_to_rad(60.0 * float((i + 1) % 6))

			# Outer corners (blended with neighbors)
			var ci_x: float = cx + cos(angle_i) * HexMath.HEX_SIZE
			var ci_z: float = cz + sin(angle_i) * HexMath.HEX_SIZE
			var cj_x: float = cx + cos(angle_j) * HexMath.HEX_SIZE
			var cj_z: float = cz + sin(angle_j) * HexMath.HEX_SIZE

			# Inner ring (pure tile color)
			var ii_x: float = cx + cos(angle_i) * HexMath.HEX_SIZE * INNER_RING
			var ii_z: float = cz + sin(angle_i) * HexMath.HEX_SIZE * INNER_RING
			var ij_x: float = cx + cos(angle_j) * HexMath.HEX_SIZE * INNER_RING
			var ij_z: float = cz + sin(angle_j) * HexMath.HEX_SIZE * INNER_RING

			var key_i := Vector3i(roundi(ci_x * 1000.0), tile.elevation, roundi(ci_z * 1000.0))
			var key_j := Vector3i(roundi(cj_x * 1000.0), tile.elevation, roundi(cj_z * 1000.0))

			var color_i: Color = corner_colors.get(key_i, center_color)
			var color_j: Color = corner_colors.get(key_j, center_color)

			# Outer corner Y: sloped or flat depending on neighbor elevation
			var cy_i: float = corner_y[i]
			var cy_j: float = corner_y[(i + 1) % 6]

			# Inner triangle: center → inner_i → inner_j (pure tile color, flat)
			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(Vector3(cx, elevation_y, cz))

			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(Vector3(ii_x, elevation_y, ii_z))

			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(Vector3(ij_x, elevation_y, ij_z))

			# Outer quad: inner_i → corner_i → corner_j → inner_j (transition band)
			# Corner vertices use sloped Y; inner ring stays at tile elevation.
			# Triangle A: inner_i → corner_i → inner_j
			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(Vector3(ii_x, elevation_y, ii_z))

			st.set_normal(Vector3.UP)
			st.set_color(color_i)
			st.add_vertex(Vector3(ci_x, cy_i, ci_z))

			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(Vector3(ij_x, elevation_y, ij_z))

			# Triangle B: corner_i → corner_j → inner_j
			st.set_normal(Vector3.UP)
			st.set_color(color_i)
			st.add_vertex(Vector3(ci_x, cy_i, ci_z))

			st.set_normal(Vector3.UP)
			st.set_color(color_j)
			st.add_vertex(Vector3(cj_x, cy_j, cj_z))

			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(Vector3(ij_x, elevation_y, ij_z))

	# Step 5: Generate cliff faces ONLY for elevation diff >= 4 (BLOCKED).
	# Diff 1-3 uses slopes (corner Y interpolation above). No cliff face needed.
	#
	# Edge-to-corner mapping: DIRECTIONS[d] neighbors share these corner pairs.
	# Derived from corner_neighbor_dirs (verified empirically).
	# Corner angle = corner_index * 60°.
	var edge_corners: Array = [
		[0, 1],  # dir 0 (E)  → corners at 0° and 60°
		[5, 0],  # dir 1 (SE) → corners at 300° and 0°
		[4, 5],  # dir 2 (S)  → corners at 240° and 300°
		[3, 4],  # dir 3 (SW) → corners at 180° and 240°
		[2, 3],  # dir 4 (NW) → corners at 120° and 180°
		[1, 2],  # dir 5 (N)  → corners at 60° and 120°
	]

	for coords: Variant in tile_colors:
		var tile: Resource = HexGrid._tiles[coords]
		var world_2d: Vector2 = HexMath.axial_to_world(coords)
		var cx: float = world_2d.x
		var cz: float = world_2d.y
		var high_y: float = float(tile.elevation) * ELEVATION_STEP

		for i: int in range(6):
			var neighbor_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[i] as Vector2i)
			var neighbor_tile: Resource = HexGrid._tiles.get(neighbor_coords, null)
			if neighbor_tile == null:
				continue
			if neighbor_tile.elevation >= tile.elevation:
				continue
			# Only generate cliff face for large elevation differences (BLOCKED traversal).
			var diff: int = tile.elevation - neighbor_tile.elevation
			if diff < 4:
				continue

			var low_y: float = float(neighbor_tile.elevation) * ELEVATION_STEP
			var cliff_color: Color = tile_colors[coords] * 0.6

			# Use correct corner positions for this direction (not i*60°).
			var ec: Array = edge_corners[i]
			var angle_a: float = deg_to_rad(60.0 * float(ec[0]))
			var angle_b: float = deg_to_rad(60.0 * float(ec[1]))
			var ca_x: float = cx + cos(angle_a) * HexMath.HEX_SIZE
			var ca_z: float = cz + sin(angle_a) * HexMath.HEX_SIZE
			var cb_x: float = cx + cos(angle_b) * HexMath.HEX_SIZE
			var cb_z: float = cz + sin(angle_b) * HexMath.HEX_SIZE

			# Normal: direction from hex center toward neighbor center.
			var n_world: Vector2 = HexMath.axial_to_world(neighbor_coords)
			var dir_x: float = n_world.x - cx
			var dir_z: float = n_world.y - cz
			var dir_len: float = sqrt(dir_x * dir_x + dir_z * dir_z)
			var cliff_normal: Vector3 = Vector3(dir_x / dir_len, 0.0, dir_z / dir_len)

			var v0 := Vector3(ca_x, high_y, ca_z)   # left-top
			var v1 := Vector3(cb_x, high_y, cb_z)   # right-top
			var v2 := Vector3(ca_x, low_y, ca_z)    # left-bottom
			var v3 := Vector3(cb_x, low_y, cb_z)    # right-bottom

			# Triangle 1: v0, v2, v3 — outward-facing CCW (visible from neighbor side)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v0)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v2)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v3)

			# Triangle 2: v0, v3, v1 — outward-facing CCW
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v0)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v3)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v1)

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
