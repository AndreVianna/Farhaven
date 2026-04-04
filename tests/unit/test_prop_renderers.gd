extends GdUnitTestSuite

## Unit tests for PropLabelRenderer (task-013, updated task-019).
## PropRenderer tests moved to test_resource_renderer.gd.

const _PropLabelRenderer = preload("res://scripts/rendering/prop_label_renderer.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
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

var _label_renderer: Node3D
var _grid: FakeGrid
var _player: FakePlayer
var _scanner: Node


func _make_tile_with_resource(resource_type: StringName, elev: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.fog_state = _HexTile.FogState.VISIBLE
	var prop: Prop = _Prop.new()
	prop.type = resource_type
	prop.category = Prop.Category.RESOURCE
	prop.sub_hex = Vector2i.ZERO
	tile.props = [prop]
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

	# PropLabelRenderer
	_label_renderer = _PropLabelRenderer.new()
	_label_renderer.name = "PropLabelRenderer"
	_label_renderer._grid = _grid
	world.add_child(_label_renderer)

	# Manually connect scanner signals
	_label_renderer._scanner = _scanner

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
	_label_renderer = null
	_scanner = null
	_player = null
	_grid = null


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
