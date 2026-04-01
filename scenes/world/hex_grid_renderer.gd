extends Node3D

## HexGridRenderer — signal-driven MultiMesh terrain renderer.
## 5 MultiMeshInstance3D children, one per biome (CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER).
## Updates on map_generated / tile_visibility_changed signals only. No _process.
##
## INSTANCE_CUSTOM encoding:
##   Color.r = fog intensity (0.0=hidden/zero-scale, 0.5=revealed/dim, 1.0=visible/full)
##   Color.g = highlight R
##   Color.b = highlight G
##   Color.a = highlight B

const _HexTile = preload("res://scripts/hex/hex_tile.gd")

# Placeholder biome colors — visually distinct identifiers.
const BIOME_COLORS: Array[Color] = [
	Color(0.45, 0.32, 0.18),  # CRASH_SITE — brownish debris
	Color(0.28, 0.65, 0.18),  # GRASSLAND — green
	Color(0.08, 0.38, 0.08),  # FOREST — dark green
	Color(0.55, 0.52, 0.48),  # ROCKY — gray
	Color(0.12, 0.28, 0.72),  # WATER — blue
]

# World-space Y offset per elevation unit.
const ELEVATION_SCALE: float = 0.3

# Per-biome MultiMeshInstance3D children (indexed by Biome enum value).
var _mmi: Array[MultiMeshInstance3D] = []

# coords (Vector2i) -> {biome: int, index: int}
var _tile_data: Dictionary = {}

# coords (Vector2i) -> full Transform3D (non-zero-scale, for restoring from HIDDEN)
var _tile_transforms: Dictionary = {}

# coords (Vector2i) -> true — tracks which tiles are currently highlighted
var _highlighted: Dictionary = {}


func _ready() -> void:
	_mmi.resize(5)
	_mmi[_HexTile.Biome.CRASH_SITE] = $CRASH_SITE
	_mmi[_HexTile.Biome.GRASSLAND] = $GRASSLAND
	_mmi[_HexTile.Biome.FOREST] = $FOREST
	_mmi[_HexTile.Biome.ROCKY] = $ROCKY
	_mmi[_HexTile.Biome.WATER] = $WATER

	HexGrid.map_generated.connect(_on_map_generated)
	HexGrid.tile_visibility_changed.connect(_on_tile_visibility_changed)


# --- Signal handlers ---

func _on_map_generated() -> void:
	_tile_data.clear()
	_tile_transforms.clear()
	_highlighted.clear()
	_build_multimeshes()


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	if not _tile_data.has(coords):
		return
	var data: Dictionary = _tile_data[coords]
	var mm: MultiMesh = _mmi[data.biome].multimesh
	if mm == null:
		return
	var idx: int = data.index
	var fog_value: float = _fog_to_value(state)

	if fog_value <= 0.0:
		mm.set_instance_transform(idx, _zero_transform())
	else:
		mm.set_instance_transform(idx, _tile_transforms[coords])

	# Preserve highlight channels, update fog channel only.
	var current: Color = mm.get_instance_custom_data(idx)
	mm.set_instance_custom_data(idx, Color(fog_value, current.g, current.b, current.a))


# --- Public API ---

## Highlight the given tiles with a solid color blend. Replaces any previous highlights.
func highlight_tiles(coords: Array[Vector2i], color: Color) -> void:
	clear_highlights()
	for coord in coords:
		_set_highlight(coord, color)
		_highlighted[coord] = true


## Clear all active highlights, restoring fog-only appearance.
func clear_highlights() -> void:
	for coord: Vector2i in _highlighted:
		_set_highlight(coord, Color(0.0, 0.0, 0.0, 0.0))
	_highlighted.clear()


# --- Internal helpers ---

func _build_multimeshes() -> void:
	var hex_mesh: ArrayMesh = _create_hex_mesh()
	var shader: Shader = preload("res://shaders/hex_tile.gdshader")

	# Group tile coords by biome.
	var biome_tiles: Array = [[], [], [], [], []]
	for coords in HexGrid._tiles:
		var tile = HexGrid._tiles[coords]
		biome_tiles[tile.biome].append(coords)

	for biome in range(5):
		var tiles: Array = biome_tiles[biome]
		var mmi: MultiMeshInstance3D = _mmi[biome]

		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("base_color", BIOME_COLORS[biome])

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.instance_count = tiles.size()
		mm.mesh = hex_mesh

		for i in range(tiles.size()):
			var coords: Vector2i = tiles[i]
			var tile = HexGrid.get_tile(coords)
			_tile_data[coords] = {biome = biome, index = i}

			var world_2d: Vector2 = HexGrid.axial_to_world(coords)
			var elevation_y: float = float(tile.elevation) * ELEVATION_SCALE
			var full_xform := Transform3D(Basis.IDENTITY, Vector3(world_2d.x, elevation_y, world_2d.y))
			_tile_transforms[coords] = full_xform

			var fog_value: float = _fog_to_value(tile.fog_state)
			if fog_value <= 0.0:
				mm.set_instance_transform(i, _zero_transform())
			else:
				mm.set_instance_transform(i, full_xform)
			mm.set_instance_custom_data(i, Color(fog_value, 0.0, 0.0, 0.0))

		mmi.multimesh = mm
		mmi.material_override = mat


func _set_highlight(coords: Vector2i, color: Color) -> void:
	if not _tile_data.has(coords):
		return
	var data: Dictionary = _tile_data[coords]
	var mm: MultiMesh = _mmi[data.biome].multimesh
	if mm == null:
		return
	var idx: int = data.index
	var current: Color = mm.get_instance_custom_data(idx)
	mm.set_instance_custom_data(idx, Color(current.r, color.r, color.g, color.b))


static func _fog_to_value(fog_state: int) -> float:
	match fog_state:
		0:  # HexTile.FogState.HIDDEN
			return 0.0
		1:  # HexTile.FogState.REVEALED
			return 0.5
		_:  # HexTile.FogState.VISIBLE (2)
			return 1.0


static func _zero_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)


## Build a flat-top hexagon ArrayMesh. 6 triangles, fan from center.
## Size = 1.0 matches HexMath.HEX_SIZE. Lies flat in the XZ plane (Y=0).
static func _create_hex_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Flat-top: corner 0 points right (+X). Corners at 60° increments.
	var corners: Array[Vector3] = []
	for i in range(6):
		var angle: float = deg_to_rad(60.0 * float(i))
		corners.append(Vector3(cos(angle), 0.0, sin(angle)))

	# Fan: 6 triangles from center to each edge.
	for i in range(6):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 6]
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(a)
		st.set_normal(Vector3.UP)
		st.add_vertex(b)

	return st.commit()
