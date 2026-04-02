extends GdUnitTestSuite

## Unit tests for ScanProgressRenderer (task-013).

const _ScanProgressRenderer = preload("res://scripts/rendering/scan_progress_renderer.gd")
const _ScannerSystem = preload("res://scripts/scanner/scanner_system.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")


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

var _renderer: Node3D
var _grid: FakeGrid
var _player: FakePlayer
var _scanner: Node


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_player = FakePlayer.new()
	_player.name = "Player"

	_scanner = _ScannerSystem.new()
	_scanner.name = "ScannerSystem"
	_scanner._grid = _grid
	_scanner.set_process(false)
	_player.add_child(_scanner)

	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	world.add_child(_player)

	_renderer = _ScanProgressRenderer.new()
	_renderer.name = "ScanProgressRenderer"
	_renderer._grid = _grid
	world.add_child(_renderer)

	# Manually wire signals
	_renderer._scanner = _scanner
	if not _scanner.scan_started.is_connected(_renderer._on_scan_started):
		_scanner.scan_started.connect(_renderer._on_scan_started)
	if not _scanner.scan_progress_updated.is_connected(_renderer._on_scan_progress_updated):
		_scanner.scan_progress_updated.connect(_renderer._on_scan_progress_updated)
	if not _scanner.scan_completed.is_connected(_renderer._on_scan_completed):
		_scanner.scan_completed.connect(_renderer._on_scan_completed)
	if not _scanner.scan_interrupted.is_connected(_renderer._on_scan_interrupted):
		_scanner.scan_interrupted.connect(_renderer._on_scan_interrupted)


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
	_grid = null


# --- Show/hide on scan lifecycle ---

func test_bar_hidden_initially() -> void:
	assert_bool(_renderer.is_bar_visible()).is_false()


func test_bar_shows_on_scan_started() -> void:
	var tile: HexTile = _HexTile.new()
	tile.elevation = 1
	_grid._tiles[Vector2i(1, 0)] = tile

	_scanner.scan_started.emit(&"berry_bush", Vector2i(1, 0))

	assert_bool(_renderer.is_bar_visible()).is_true()


func test_bar_hides_on_scan_completed() -> void:
	_grid._tiles[Vector2i(1, 0)] = _HexTile.new()
	_scanner.scan_started.emit(&"berry_bush", Vector2i(1, 0))
	assert_bool(_renderer.is_bar_visible()).is_true()

	_scanner.scan_completed.emit(&"berry_bush")

	assert_bool(_renderer.is_bar_visible()).is_false()


func test_bar_hides_on_scan_interrupted() -> void:
	_grid._tiles[Vector2i(1, 0)] = _HexTile.new()
	_scanner.scan_started.emit(&"berry_bush", Vector2i(1, 0))

	_scanner.scan_interrupted.emit()

	assert_bool(_renderer.is_bar_visible()).is_false()


# --- Progress bar fill updates ---

func test_progress_updates_on_signal() -> void:
	_grid._tiles[Vector2i(1, 0)] = _HexTile.new()
	_scanner.scan_started.emit(&"berry_bush", Vector2i(1, 0))

	_scanner.scan_progress_updated.emit(0.5)

	assert_float(_renderer.get_progress()).is_equal(0.5)


func test_progress_resets_on_completed() -> void:
	_grid._tiles[Vector2i(1, 0)] = _HexTile.new()
	_scanner.scan_started.emit(&"berry_bush", Vector2i(1, 0))
	_scanner.scan_progress_updated.emit(0.8)

	_scanner.scan_completed.emit(&"berry_bush")

	assert_float(_renderer.get_progress()).is_equal(0.0)


func test_progress_resets_on_interrupted() -> void:
	_grid._tiles[Vector2i(1, 0)] = _HexTile.new()
	_scanner.scan_started.emit(&"berry_bush", Vector2i(1, 0))
	_scanner.scan_progress_updated.emit(0.6)

	_scanner.scan_interrupted.emit()

	assert_float(_renderer.get_progress()).is_equal(0.0)
