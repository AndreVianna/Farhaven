extends GdUnitTestSuite
class_name TestHexGridRenderer

## TDD tests for the single-ArrayMesh HexGridRenderer.
## Written BEFORE implementation per TDD discipline.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")

const RENDERER_SCENE := "res://scenes/world/hex_grid_renderer.tscn"


func _setup_small_grid() -> void:
	HexGrid._tiles.clear()
	for q: int in range(-2, 3):
		for r: int in range(-2, 3):
			var s: int = -q - r
			if abs(q) + abs(r) + abs(s) > 4:
				continue
			var tile := _HexTile.new()
			tile.coords = Vector2i(q, r)
			tile.biome = _HexTile.Biome.GRASSLAND
			tile.elevation = 0
			tile.fog_state = _HexTile.FogState.VISIBLE
			HexGrid._tiles[Vector2i(q, r)] = tile


func after_test() -> void:
	HexGrid._tiles.clear()


# ---------------------------------------------------------------------------
# Scene structure
# ---------------------------------------------------------------------------

func test_renderer_has_mesh_instance_child() -> void:
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	var mi: Node = renderer.get_node_or_null("MeshInstance3D")
	assert_bool(mi != null).override_failure_message(
		"HexGridRenderer must have a child named MeshInstance3D"
	).is_true()
	renderer.queue_free()


func test_renderer_has_no_multimesh_children() -> void:
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	for biome_name: String in ["CRASH_SITE", "GRASSLAND", "FOREST", "ROCKY", "WATER"]:
		var n: Node = renderer.get_node_or_null(biome_name)
		assert_bool(n == null).override_failure_message(
			"Old MultiMeshInstance3D child '%s' must not exist in new renderer" % biome_name
		).is_true()
	renderer.queue_free()


# ---------------------------------------------------------------------------
# Tile data population
# ---------------------------------------------------------------------------

func test_renderer_tile_data_populated_after_map_generated() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()
	assert_bool(renderer._tile_data.size() > 0).override_failure_message(
		"_tile_data must be non-empty after map_generated"
	).is_true()
	renderer.queue_free()


func test_renderer_tile_data_size_matches_hex_grid() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()
	assert_int(renderer._tile_data.size()).is_equal(HexGrid._tiles.size())
	renderer.queue_free()


func test_renderer_tile_data_cleared_on_second_map_generated() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()
	var first_size: int = renderer._tile_data.size()

	# Add one more tile and re-emit.
	var extra := _HexTile.new()
	extra.coords = Vector2i(99, 99)
	extra.biome = _HexTile.Biome.ROCKY
	extra.elevation = 0
	extra.fog_state = _HexTile.FogState.VISIBLE
	HexGrid._tiles[Vector2i(99, 99)] = extra
	HexGrid.map_generated.emit()

	assert_int(renderer._tile_data.size()).is_equal(first_size + 1)
	renderer.queue_free()


# ---------------------------------------------------------------------------
# ArrayMesh built on map_generated
# ---------------------------------------------------------------------------

func test_renderer_builds_array_mesh_after_map_generated() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()
	var mi: MeshInstance3D = renderer.get_node("MeshInstance3D")
	assert_bool(mi.mesh != null).override_failure_message(
		"MeshInstance3D must have a mesh after map_generated with visible tiles"
	).is_true()
	renderer.queue_free()


func test_renderer_hidden_tiles_only_produce_no_mesh() -> void:
	HexGrid._tiles.clear()
	var tile := _HexTile.new()
	tile.coords = Vector2i(0, 0)
	tile.biome = _HexTile.Biome.GRASSLAND
	tile.fog_state = _HexTile.FogState.HIDDEN
	HexGrid._tiles[Vector2i(0, 0)] = tile

	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()

	# With all tiles hidden, mesh should be null or empty.
	var mi: MeshInstance3D = renderer.get_node("MeshInstance3D")
	var is_empty: bool = (mi.mesh == null) or (mi.mesh.get_surface_count() == 0)
	assert_bool(is_empty).override_failure_message(
		"All-HIDDEN grid should produce no mesh geometry"
	).is_true()
	renderer.queue_free()


# ---------------------------------------------------------------------------
# Highlight API
# ---------------------------------------------------------------------------

func test_highlight_tiles_tracks_in_highlights_dict() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()

	var coords: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	renderer.highlight_tiles(coords, Color.RED)
	assert_bool(renderer._highlights.size() > 0).override_failure_message(
		"_highlights must be non-empty after highlight_tiles()"
	).is_true()
	renderer.queue_free()


func test_clear_highlights_empties_highlights_dict() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()

	var coords: Array[Vector2i] = [Vector2i(0, 0)]
	renderer.highlight_tiles(coords, Color.BLUE)
	renderer.clear_highlights()
	assert_int(renderer._highlights.size()).is_equal(0)
	renderer.queue_free()


func test_highlight_tiles_replaces_previous_highlights() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()

	var coords_a: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	renderer.highlight_tiles(coords_a, Color.RED)
	var coords_b: Array[Vector2i] = [Vector2i(-1, 0)]
	renderer.highlight_tiles(coords_b, Color.GREEN)
	# Only coords_b should be highlighted now.
	assert_int(renderer._highlights.size()).is_equal(1)
	renderer.queue_free()


# ---------------------------------------------------------------------------
# Fog state handling
# ---------------------------------------------------------------------------

func test_fog_visibility_changed_updates_tile_data() -> void:
	_setup_small_grid()
	var renderer: Node = load(RENDERER_SCENE).instantiate()
	add_child(renderer)
	HexGrid.map_generated.emit()

	# Change fog state via signal.
	HexGrid.tile_visibility_changed.emit(Vector2i(0, 0), _HexTile.FogState.REVEALED)
	var data: Dictionary = renderer._tile_data[Vector2i(0, 0)]
	assert_int(data.fog_state).is_equal(_HexTile.FogState.REVEALED)
	renderer.queue_free()
