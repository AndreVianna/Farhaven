extends Node3D

## HexGridRenderer — single ArrayMesh with per-vertex color blending.
## One draw call for the entire hex grid. Signal-driven, no _process.
##
## Architecture:
##   - On map_generated: build full ArrayMesh from HexGrid tile data.
##   - Concentric ring subdivision: 1 center + 6 vertices × 4 rings = 25 vertices per hex.
##   - 6 inner-fan triangles + 36 ring-strip triangles = 42 triangles per hex.
##   - Ring radii: 0, 25%, 50%, 75%, 100% of HEX_SIZE.
##   - Smoothstep interpolation between center and outer corners → curved terrain.
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

	# Step 4: Assemble triangles with SurfaceTool.
	# Concentric ring subdivision: 1 center vertex + 6 vertices × 4 rings = 25 verts per hex.
	# Ring radii: 0, 25%, 50%, 75%, 100% of HEX_SIZE.
	# Y is interpolated via smoothstep between center elevation and per-corner elevation.
	# 6 inner-fan triangles + 3 quad strips × 12 tris each = 42 tris per hex.
	# Water tiles stay flat at center elevation regardless of neighbor heights.
	const RING_COUNT: int = 4

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

		# Compute per-corner Y for slope interpolation.
		# Each corner is influenced by the two edges it belongs to.
		# Edge d spans corners d and (d+1)%6, neighbor = DIRECTIONS[d].
		var corner_slope_sums: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var corner_slope_counts: Array[int] = [0, 0, 0, 0, 0, 0]
		for d: int in range(6):
			var n_coords: Vector2i = (coords as Vector2i) + (HexMath.DIRECTIONS[d] as Vector2i)
			var n_tile: Resource = HexGrid._tiles.get(n_coords, null)
			if n_tile == null:
				continue
			var diff: int = absi(tile.elevation - n_tile.elevation)
			if diff >= 1 and diff <= 2:
				var n_y: float = float(n_tile.elevation) * ELEVATION_STEP
				var slope_y: float = lerpf(elevation_y, n_y, 0.5)
				# Corner d and corner (d+1)%6 both touch this edge.
				corner_slope_sums[d] += slope_y
				corner_slope_counts[d] += 1
				var next: int = (d + 1) % 6
				corner_slope_sums[next] += slope_y
				corner_slope_counts[next] += 1

		var corner_y: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for ci: int in range(6):
			if corner_slope_counts[ci] == 0:
				corner_y[ci] = elevation_y
			else:
				corner_y[ci] = corner_slope_sums[ci] / float(corner_slope_counts[ci])

		# Precompute outer corner colors at each angular direction (i = 0..5).
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

		# Build all ring vertex positions and colors.
		# rings_pos[k] = Array of 6 Vector3 (or 1 element for ring 0)
		# rings_col[k] = Array of 6 Color   (or 1 element for ring 0)
		var rings_pos: Array = []
		var rings_col: Array = []

		# Ring 0: just the center vertex.
		rings_pos.append([Vector3(cx, elevation_y, cz)])
		rings_col.append([center_color])

		# Rings 1..RING_COUNT (k = 1..4): 6 vertices each.
		for k: int in range(1, RING_COUNT + 1):
			var t: float = float(k) / float(RING_COUNT)
			var s: float = t * t * (3.0 - 2.0 * t)  # smoothstep
			var radius: float = HexMath.HEX_SIZE * t

			var ring_pos: Array = []
			var ring_col: Array = []
			for i: int in range(6):
				var angle: float = deg_to_rad(60.0 * float(i))
				var vx: float = cx + cos(angle) * radius
				var vz: float = cz + sin(angle) * radius
				var vy: float
				if is_water:
					vy = elevation_y  # water stays flat
				else:
					vy = lerpf(elevation_y, corner_y[i], s)
				ring_pos.append(Vector3(vx, vy, vz))
				# Color: linear lerp from center to outer corner color at this angle.
				ring_col.append(center_color.lerp(corner_colors_at[i], t))
			rings_pos.append(ring_pos)
			rings_col.append(ring_col)

		# Inner fan: center → ring1[i] → ring1[(i+1)%6]
		var center_pos: Vector3 = rings_pos[0][0]
		var ring1_pos: Array = rings_pos[1]
		var ring1_col: Array = rings_col[1]
		for i: int in range(6):
			var i_next: int = (i + 1) % 6
			st.set_normal(Vector3.UP)
			st.set_color(center_color)
			st.add_vertex(center_pos)

			st.set_normal(Vector3.UP)
			st.set_color(ring1_col[i])
			st.add_vertex(ring1_pos[i])

			st.set_normal(Vector3.UP)
			st.set_color(ring1_col[i_next])
			st.add_vertex(ring1_pos[i_next])

		# Quad strips between ring k and ring k+1, for k in 1..RING_COUNT-1 (1..3).
		# Each strip = 6 quads = 12 triangles. 3 strips × 12 = 36 strip triangles.
		for k: int in range(1, RING_COUNT):
			var rk_pos: Array = rings_pos[k]
			var rk_col: Array = rings_col[k]
			var rk1_pos: Array = rings_pos[k + 1]
			var rk1_col: Array = rings_col[k + 1]
			for i: int in range(6):
				var i_next: int = (i + 1) % 6
				# Triangle A: rk[i] → rk1[i] → rk[i_next]
				st.set_normal(Vector3.UP)
				st.set_color(rk_col[i])
				st.add_vertex(rk_pos[i])

				st.set_normal(Vector3.UP)
				st.set_color(rk1_col[i])
				st.add_vertex(rk1_pos[i])

				st.set_normal(Vector3.UP)
				st.set_color(rk_col[i_next])
				st.add_vertex(rk_pos[i_next])

				# Triangle B: rk1[i] → rk1[i_next] → rk[i_next]
				st.set_normal(Vector3.UP)
				st.set_color(rk1_col[i])
				st.add_vertex(rk1_pos[i])

				st.set_normal(Vector3.UP)
				st.set_color(rk1_col[i_next])
				st.add_vertex(rk1_pos[i_next])

				st.set_normal(Vector3.UP)
				st.set_color(rk_col[i_next])
				st.add_vertex(rk_pos[i_next])

	# Step 5: Generate cliff faces ONLY for elevation diff >= 3 (BLOCKED).
	# Diff 1-2 uses curved slopes (smoothstep ring Y interpolation above). No cliff face needed.
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
			if diff < 3:
				continue

			var low_y: float = float(neighbor_tile.elevation) * ELEVATION_STEP
			var cliff_color: Color = tile_colors[coords] * 0.6

			var angle_i: float = deg_to_rad(60.0 * float(i))
			var angle_j: float = deg_to_rad(60.0 * float(i + 1))
			var ci_x: float = cx + cos(angle_i) * HexMath.HEX_SIZE
			var ci_z: float = cz + sin(angle_i) * HexMath.HEX_SIZE
			var cj_x: float = cx + cos(angle_j) * HexMath.HEX_SIZE
			var cj_z: float = cz + sin(angle_j) * HexMath.HEX_SIZE

			var mid_angle: float = deg_to_rad(60.0 * float(i) + 30.0)
			var cliff_normal: Vector3 = Vector3(cos(mid_angle), 0.0, sin(mid_angle))

			var v0 := Vector3(ci_x, high_y, ci_z)   # left-top
			var v1 := Vector3(cj_x, high_y, cj_z)   # right-top
			var v2 := Vector3(ci_x, low_y, ci_z)    # left-bottom
			var v3 := Vector3(cj_x, low_y, cj_z)    # right-bottom

			# Triangle 1: v0, v3, v2 — outward-facing CCW
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v0)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v3)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v2)

			# Triangle 2: v0, v1, v3 — outward-facing CCW
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v0)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v1)
			st.set_normal(cliff_normal)
			st.set_color(cliff_color)
			st.add_vertex(v3)

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
