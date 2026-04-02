extends GdUnitTestSuite

## Unit tests for PropRenderer + PropLabelRenderer (task-013).
## Tests for PropRenderer and PropLabelRenderer.

const _PropRenderer = preload("res://scripts/rendering/prop_renderer.gd")
const _PropLabelRenderer = preload("res://scripts/rendering/prop_label_renderer.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")
const _ScannerSystem = preload("res://scripts/scanner/scanner_system.gd")


# --- Minimal fakes ---

class FakeGrid extends Node:
	var _tiles: Dictionary = {}
	signal map_generated()
	signal tile_revealed(coords: Vector2i)
	signal tile_visibility_changed(coords: Vector2i, state: int)
	signal tile_entered(coords: Vector2i)
	signal tile_exited(coords: Vector2i)
	signal resource_depleted(coords: Vector2i, resource_type: StringName)
	signal resource_respawned(coords: Vector2i, resource_type: StringName)
	signal tile_contents_changed(coords: Vector2i)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)

	func distance(a: Vector2i, b: Vector2i) -> int:
		var cube_a: Vector3i = Vector3i(a.x, -a.x - a.y, a.y)
		var cube_b: Vector3i = Vector3i(b.x, -b.x - b.y, b.y)
		return (abs(cube_a.x - cube_b.x) + abs(cube_a.y - cube_b.y) + abs(cube_a.z - cube_b.z)) / 2

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		var directions: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
		]
		var result: Array[Vector2i] = []
		for d in directions:
			var n: Vector2i = coords + d
			if _tiles.has(n):
				result.append(n)
		return result


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO


# --- Test state ---

var _prop_renderer: Node3D
var _label_renderer: Node3D
var _grid: FakeGrid
var _player: FakePlayer
var _scanner: Node


func _make_tile_with_resource(resource_type: StringName, elev: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.fog_state = _HexTile.FogState.VISIBLE
	var node: ResourceNode = _ResourceNode.new()
	node.type = resource_type
	tile.resource_nodes = [node]
	return tile


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	# Build player + scanner in tree
	_player = FakePlayer.new()
	_player.name = "Player"

	_scanner = _ScannerSystem.new()
	_scanner.name = "ScannerSystem"
	_scanner._grid = _grid
	_scanner.set_process(false)
	_player.add_child(_scanner)

	# World container
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	world.add_child(_player)

	# PropRenderer
	_prop_renderer = _PropRenderer.new()
	_prop_renderer.name = "PropRenderer"
	_prop_renderer._grid = _grid
	world.add_child(_prop_renderer)

	# PropLabelRenderer
	_label_renderer = _PropLabelRenderer.new()
	_label_renderer.name = "PropLabelRenderer"
	_label_renderer._grid = _grid
	world.add_child(_label_renderer)

	# Manually connect scanner signals
	_prop_renderer._scanner = _scanner
	_label_renderer._scanner = _scanner

	# PropRenderer connections
	if not _scanner.element_identified.is_connected(_prop_renderer._on_element_identified):
		_scanner.element_identified.connect(_prop_renderer._on_element_identified)
	if not _scanner.element_unknown.is_connected(_prop_renderer._on_element_unknown):
		_scanner.element_unknown.connect(_prop_renderer._on_element_unknown)
	if not _scanner.element_encountered.is_connected(_prop_renderer._on_element_encountered):
		_scanner.element_encountered.connect(_prop_renderer._on_element_encountered)

	# PropLabelRenderer connections
	if not _scanner.element_identified.is_connected(_label_renderer._on_element_identified):
		_scanner.element_identified.connect(_label_renderer._on_element_identified)
	if not _scanner.element_unknown.is_connected(_label_renderer._on_element_unknown):
		_scanner.element_unknown.connect(_label_renderer._on_element_unknown)
	if not _scanner.element_encountered.is_connected(_label_renderer._on_element_encountered):
		_scanner.element_encountered.connect(_label_renderer._on_element_encountered)
	if not _scanner.entry_cataloged.is_connected(_label_renderer._on_entry_cataloged):
		_scanner.entry_cataloged.connect(_label_renderer._on_entry_cataloged)
	if not _scanner.entry_encountered.is_connected(_label_renderer._on_entry_encountered):
		_scanner.entry_encountered.connect(_label_renderer._on_entry_encountered)


func after_test() -> void:
	var world: Node = get_node_or_null("World")
	if world != null:
		remove_child(world)
		world.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_prop_renderer = null
	_label_renderer = null
	_scanner = null
	_player = null
	_grid = null


# ===========================================
# PropRenderer tests
# ===========================================

func test_five_multimesh_pools_created() -> void:
	assert_int(_prop_renderer.get_pool_count()).is_equal(5)


func test_pools_have_zero_visible_instances_initially() -> void:
	for i in range(5):
		assert_int(_prop_renderer.get_pool_visible_count(i)).is_equal(0)


func test_unknown_element_adds_prop_to_correct_pool() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")

	# Emit element_unknown with FLORA category
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	assert_int(_prop_renderer.get_pool_visible_count(_PropRenderer.Pool.FLORA)).is_equal(1)


func test_identified_element_adds_prop_to_category_pool() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"stone")

	_scanner.element_identified.emit(Vector2i(1, 0), &"stone_deposit")

	assert_int(_prop_renderer.get_pool_visible_count(_PropRenderer.Pool.MINERAL)).is_equal(1)


func test_encountered_element_adds_prop_to_fauna_pool() -> void:
	_scanner.element_encountered.emit(Vector2i(1, 0), &"thornback", "Hostile")

	assert_int(_prop_renderer.get_pool_visible_count(_PropRenderer.Pool.FAUNA)).is_equal(1)


func test_prop_at_correct_tile_position() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")

	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	var entries: Dictionary = _prop_renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(1, 0))).is_true()
	assert_int(entries[Vector2i(1, 0)].size()).is_equal(1)


func test_props_removed_when_tile_becomes_revealed() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	assert_int(_prop_renderer.get_pool_visible_count(_PropRenderer.Pool.FLORA)).is_equal(1)

	_prop_renderer._on_tile_visibility_changed(Vector2i(1, 0), _HexTile.FogState.REVEALED)

	assert_int(_prop_renderer.get_pool_visible_count(_PropRenderer.Pool.FLORA)).is_equal(0)


func test_props_removed_when_tile_becomes_hidden() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	_prop_renderer._on_tile_visibility_changed(Vector2i(1, 0), _HexTile.FogState.HIDDEN)

	assert_int(_prop_renderer.get_pool_visible_count(_PropRenderer.Pool.FLORA)).is_equal(0)


func test_multi_prop_tile_entries() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")

	# Add two props on same tile
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)
	_scanner.element_unknown.emit(Vector2i(1, 0), &"fiber_grass", _Catalog.CatalogCategory.FLORA)

	var entries: Dictionary = _prop_renderer.get_tile_entries()
	assert_int(entries[Vector2i(1, 0)].size()).is_equal(2)


func test_same_mesh_regardless_of_knowledge_state() -> void:
	# Unknown flora and identified flora both go to FLORA pool
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)
	_scanner.element_identified.emit(Vector2i(2, 0), &"wood_tree")

	# Both should be in FLORA pool
	assert_int(_prop_renderer.get_pool_visible_count(_PropRenderer.Pool.FLORA)).is_equal(2)


# ===========================================
# PropLabelRenderer tests (colored ❓/⚠️ markers)
# ===========================================

func test_unknown_label_shows_question_mark() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")

	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")


func test_unknown_mineral_label() -> void:
	_scanner.element_unknown.emit(Vector2i(1, 0), &"stone_deposit", _Catalog.CatalogCategory.MINERAL)

	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")


func test_encountered_label_shows_warning() -> void:
	_scanner.element_encountered.emit(Vector2i(1, 0), &"thornback", "Hostile")

	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("⚠️")


func test_encountered_shy_label() -> void:
	_scanner.element_encountered.emit(Vector2i(1, 0), &"some_fauna", "Shy")

	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("⚠️")


func test_identified_element_creates_no_marker() -> void:
	_scanner.element_identified.emit(Vector2i(1, 0), &"berry_bush")

	# CATALOGED = no marker at all
	assert_int(_label_renderer.get_label_count()).is_equal(0)


func test_bulk_label_update_on_entry_cataloged() -> void:
	# Add two unknown berry markers
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)
	_scanner.element_unknown.emit(Vector2i(2, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	# Verify they show ❓
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")
	assert_str(_label_renderer.get_label_text_at(Vector2i(2, 0))).is_equal("❓")

	# Catalog berry_bush — bulk update: markers cleared
	_scanner.entry_cataloged.emit(&"berry_bush", _Catalog.CatalogCategory.FLORA)

	# Both markers should now be empty (CATALOGED = no marker)
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("")
	assert_str(_label_renderer.get_label_text_at(Vector2i(2, 0))).is_equal("")


func test_bulk_label_update_only_affects_matching_entry() -> void:
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)
	_scanner.element_unknown.emit(Vector2i(2, 0), &"stone_deposit", _Catalog.CatalogCategory.MINERAL)

	_scanner.entry_cataloged.emit(&"berry_bush", _Catalog.CatalogCategory.FLORA)

	# Berry marker cleared, stone marker unchanged
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("")
	assert_str(_label_renderer.get_label_text_at(Vector2i(2, 0))).is_equal("❓")


func test_label_update_on_entry_encountered() -> void:
	# Add unknown fauna marker
	_scanner.element_unknown.emit(Vector2i(1, 0), &"thornback", _Catalog.CatalogCategory.FAUNA)

	# Verify it shows ❓
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")

	# Encounter thornback
	_scanner.entry_encountered.emit(&"thornback", "Hostile")

	# Marker should now show ⚠️
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("⚠️")


func test_labels_removed_when_tile_becomes_revealed() -> void:
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	assert_int(_label_renderer.get_label_count()).is_equal(1)

	_label_renderer._on_tile_visibility_changed(Vector2i(1, 0), _HexTile.FogState.REVEALED)

	assert_int(_label_renderer.get_label_count()).is_equal(0)


func test_labels_removed_when_tile_becomes_hidden() -> void:
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	_label_renderer._on_tile_visibility_changed(Vector2i(1, 0), _HexTile.FogState.HIDDEN)

	assert_int(_label_renderer.get_label_count()).is_equal(0)


func test_labels_billboard_enabled() -> void:
	_scanner.element_unknown.emit(Vector2i(1, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	var labels: Dictionary = _label_renderer.get_tile_labels()
	var label_node: Label3D = labels[Vector2i(1, 0)][0].label_node
	assert_int(label_node.billboard).is_equal(BaseMaterial3D.BILLBOARD_ENABLED)


# ===========================================
# Draw calls estimate
# ===========================================

func test_resource_with_offset_adds_prop_and_matches_entry() -> void:
	# Create a tile with a resource that has a specific offset
	var tile: HexTile = _HexTile.new()
	tile.elevation = 0
	tile.fog_state = _HexTile.FogState.VISIBLE
	var node: ResourceNode = _ResourceNode.new()
	node.type = &"berries"
	node.offset = Vector2(0.5, -0.3)
	node.rotation_deg = 45.0
	tile.resource_nodes = [node]
	_grid._tiles[Vector2i(0, 0)] = tile

	_scanner.element_unknown.emit(Vector2i(0, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	# Verify prop was added
	var entries: Dictionary = _prop_renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(0, 0))).is_true()
	assert_int(entries[Vector2i(0, 0)].size()).is_equal(1)

	# Verify the resource_node offset is accessible from the tile
	var retrieved_tile = _grid.get_tile(Vector2i(0, 0))
	assert_bool(retrieved_tile != null).is_true()
	var rn: ResourceNode = retrieved_tile.resource_nodes[0]
	assert_float(rn.offset.x).is_equal_approx(0.5, 0.001)
	assert_float(rn.offset.y).is_equal_approx(-0.3, 0.001)
	assert_float(rn.rotation_deg).is_equal_approx(45.0, 0.001)

	# Verify the reverse lookup maps correctly (now via PropUtils)
	var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"berries")
	assert_str(String(entry_id)).is_equal("berry_bush")

	# Verify expected world offset calculation
	# HEX_SIZE=3.0, PropUtils.OFFSET_SCALE=0.4
	# world_offset = (0.5 * 3.0 * 0.4, -0.3 * 3.0 * 0.4) = (0.6, -0.36)
	var expected_offset_x: float = 0.5 * _PropRenderer.HEX_SIZE * _PropUtils.OFFSET_SCALE
	var expected_offset_z: float = -0.3 * _PropRenderer.HEX_SIZE * _PropUtils.OFFSET_SCALE
	assert_float(expected_offset_x).is_equal_approx(0.6, 0.001)
	assert_float(expected_offset_z).is_equal_approx(-0.36, 0.001)


func test_resource_without_offset_has_zero_offset() -> void:
	# Default offset (0,0) should remain zero
	var tile: HexTile = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(0, 0)] = tile

	_scanner.element_unknown.emit(Vector2i(0, 0), &"berry_bush", _Catalog.CatalogCategory.FLORA)

	var entries: Dictionary = _prop_renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(0, 0))).is_true()

	# Verify the resource_node has default zero offset
	var rn: ResourceNode = tile.resource_nodes[0]
	assert_float(rn.offset.x).is_equal_approx(0.0, 0.001)
	assert_float(rn.offset.y).is_equal_approx(0.0, 0.001)
	assert_float(rn.rotation_deg).is_equal_approx(0.0, 0.001)


func test_draw_calls_five_prop_pools() -> void:
	assert_int(_prop_renderer.get_pool_count()).is_equal(5)
