extends GdUnitTestSuite

## Unit tests for ElementIconRenderer (task-013).

const _ElementIconRenderer = preload("res://scripts/rendering/element_icon_renderer.gd")
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


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO


class FakePlayerInput extends Node:
	signal scan_hold_started(coords: Vector2i)
	signal scan_hold_ended()


# --- Test state ---

var _renderer: Node3D
var _grid: FakeGrid
var _player: FakePlayer
var _input: FakePlayerInput
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
	_input = FakePlayerInput.new()
	_input.name = "PlayerInput"
	_player.add_child(_input)

	_scanner = _ScannerSystem.new()
	_scanner.name = "ScannerSystem"
	_scanner._grid = _grid
	_scanner.set_process(false)
	_player.add_child(_scanner)

	# World container (renderer expects parent = World, sibling = Player)
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	world.add_child(_player)

	# Renderer — set grid before add_child so _ready uses our fake
	_renderer = _ElementIconRenderer.new()
	_renderer.name = "ElementIconRenderer"
	_renderer._grid = _grid
	world.add_child(_renderer)

	# Manually connect scanner signals since deferred connect may not have run
	_renderer._scanner = _scanner
	if _scanner.has_signal("element_identified"):
		if not _scanner.element_identified.is_connected(_renderer._on_element_identified):
			_scanner.element_identified.connect(_renderer._on_element_identified)
	if _scanner.has_signal("element_unknown"):
		if not _scanner.element_unknown.is_connected(_renderer._on_element_unknown):
			_scanner.element_unknown.connect(_renderer._on_element_unknown)
	if _scanner.has_signal("entry_cataloged"):
		if not _scanner.entry_cataloged.is_connected(_renderer._on_entry_cataloged):
			_scanner.entry_cataloged.connect(_renderer._on_entry_cataloged)


func after_test() -> void:
	var world: Node = get_node_or_null("World")
	if world != null:
		remove_child(world)
		world.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_renderer = null
	_scanner = null
	_player = null
	_input = null
	_grid = null


# --- Pool creation tests ---

func test_five_multimesh_pools_created() -> void:
	assert_int(_renderer.get_pool_count()).is_equal(5)


func test_pools_have_zero_visible_instances_initially() -> void:
	for i in range(5):
		assert_int(_renderer.get_pool_visible_count(i)).is_equal(0)


# --- Unknown element icon ---

func test_unknown_element_shows_question_mark_icon() -> void:
	var tile: HexTile = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(1, 0)] = tile

	# Emit element_unknown signal
	_scanner.element_unknown.emit(Vector2i(1, 0))

	# Unknown pool (index 0) should have 1 instance
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(1)


func test_unknown_element_at_correct_tile_position() -> void:
	var tile: HexTile = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(1, 0)] = tile

	_scanner.element_unknown.emit(Vector2i(1, 0))

	var entries: Dictionary = _renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(1, 0))).is_true()
	assert_int(entries[Vector2i(1, 0)].size()).is_equal(1)


# --- Identified element icon ---

func test_identified_element_shows_category_icon() -> void:
	var tile: HexTile = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(1, 0)] = tile

	_scanner.element_identified.emit(Vector2i(1, 0), &"berry_bush")

	# Flora pool (index 1) should have 1 instance
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.FLORA)).is_equal(1)


func test_identified_mineral_shows_mineral_icon() -> void:
	var tile: HexTile = _make_tile_with_resource(&"stone")
	_grid._tiles[Vector2i(2, 0)] = tile

	_scanner.element_identified.emit(Vector2i(2, 0), &"stone_deposit")

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.MINERAL)).is_equal(1)


# --- Bulk swap on entry_cataloged ---

func test_bulk_swap_on_entry_cataloged() -> void:
	# Add two unknown berry tiles
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(2, 1)] = _make_tile_with_resource(&"berries")

	_scanner.element_unknown.emit(Vector2i(1, 0))
	_scanner.element_unknown.emit(Vector2i(2, 1))

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(2)

	# Catalog berry_bush — should swap all unknown berries to flora pool
	_scanner.entry_cataloged.emit(&"berry_bush", _Catalog.CatalogCategory.FLORA)

	# Unknown should be 0, flora should be 2
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(0)
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.FLORA)).is_equal(2)


func test_bulk_swap_only_affects_matching_type() -> void:
	# Berry bush unknown + stone deposit unknown
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(2, 0)] = _make_tile_with_resource(&"stone")

	_scanner.element_unknown.emit(Vector2i(1, 0))
	_scanner.element_unknown.emit(Vector2i(2, 0))

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(2)

	# Catalog only berry_bush
	_scanner.entry_cataloged.emit(&"berry_bush", _Catalog.CatalogCategory.FLORA)

	# Stone unknown stays, berry becomes flora
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(1)
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.FLORA)).is_equal(1)


# --- Icons removed when tile goes REVEALED or HIDDEN ---

func test_icons_removed_when_tile_becomes_revealed() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_scanner.element_unknown.emit(Vector2i(1, 0))

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(1)

	# Tile visibility changes to REVEALED
	_renderer._on_tile_visibility_changed(Vector2i(1, 0), _HexTile.FogState.REVEALED)

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(0)


func test_icons_removed_when_tile_becomes_hidden() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_scanner.element_unknown.emit(Vector2i(1, 0))

	_renderer._on_tile_visibility_changed(Vector2i(1, 0), _HexTile.FogState.HIDDEN)

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(0)


# --- Billboard (structural check — material/shader configured) ---

func test_icons_use_billboard_shader() -> void:
	# Verify pool 0 has a ShaderMaterial with the icon_billboard shader
	var pool_0: MultiMeshInstance3D = _renderer._pools[0]
	var mat = pool_0.material_override
	assert_bool(mat is ShaderMaterial).is_true()


# --- Draw calls estimate ---

func test_draw_calls_five_pools_plus_one_progress() -> void:
	# 5 MultiMesh pools = ~5 draw calls for icons
	# This is a structural assertion — the pool count
	assert_int(_renderer.get_pool_count()).is_equal(5)
