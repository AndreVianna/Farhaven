extends GdUnitTestSuite
class_name TestScannerSystem

## Unit tests for ScannerSystem (task-012).

const _ScannerSystem = preload("res://scripts/scanner/scanner_system.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")
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

	func axial_to_world(coords: Vector2i) -> Vector2:
		return Vector2(float(coords.x) * 4.5, float(coords.y) * 5.196)


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO


class FakePlayerInput extends Node:
	signal scan_hold_started(coords: Vector2i)
	signal scan_hold_update(screen_pos: Vector2)
	signal scan_hold_ended()


# --- Test state ---

var _system: Node  # ScannerSystem
var _grid: FakeGrid
var _player: FakePlayer
var _input: FakePlayerInput

# Signal capture
var _started_entry_id: StringName = &""
var _started_coords: Vector2i = Vector2i.ZERO
var _progress_value: float = -1.0
var _completed_entry_id: StringName = &""
var _cancelled_count: int = 0
var _rejected_coords: Vector2i = Vector2i(-999, -999)
var _cataloged_entry_id: StringName = &""
var _cataloged_category: int = -1
var _surprise_entry_id: StringName = &""
var _identified_coords: Vector2i = Vector2i(-999, -999)
var _identified_entry_id: StringName = &""
var _unknown_coords: Vector2i = Vector2i(-999, -999)
var _unknown_count: int = 0
var _identified_count: int = 0


func _on_scan_started(eid: StringName, c: Vector2i) -> void:
	_started_entry_id = eid
	_started_coords = c

func _on_scan_progress(p: float) -> void:
	_progress_value = p

func _on_scan_completed(eid: StringName) -> void:
	_completed_entry_id = eid

func _on_scan_cancelled() -> void:
	_cancelled_count += 1

func _on_scan_rejected(c: Vector2i) -> void:
	_rejected_coords = c

func _on_entry_cataloged(eid: StringName, cat: int) -> void:
	_cataloged_entry_id = eid
	_cataloged_category = cat

func _on_surprise_cataloged(eid: StringName) -> void:
	_surprise_entry_id = eid

func _on_element_identified(c: Vector2i, eid: StringName) -> void:
	_identified_coords = c
	_identified_entry_id = eid
	_identified_count += 1

func _on_element_unknown(c: Vector2i) -> void:
	_unknown_coords = c
	_unknown_count += 1


func _make_tile_with_resource(resource_type: StringName) -> HexTile:
	var tile: HexTile = _HexTile.new()
	var node: ResourceNode = _ResourceNode.new()
	node.type = resource_type
	tile.resource_nodes = [node]
	return tile


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_player = FakePlayer.new()
	_input = FakePlayerInput.new()
	_input.name = "PlayerInput"
	_player.add_child(_input)
	add_child(_player)

	_system = _ScannerSystem.new()
	_system._grid = _grid  # Set before add_child so _ready uses our fake
	_system.set_process(false)  # manual control in tests
	_player.add_child(_system)

	# Wire signals for capture
	_system.scan_started.connect(_on_scan_started)
	_system.scan_progress_updated.connect(_on_scan_progress)
	_system.scan_completed.connect(_on_scan_completed)
	_system.scan_cancelled.connect(_on_scan_cancelled)
	_system.scan_rejected.connect(_on_scan_rejected)
	_system.entry_cataloged.connect(_on_entry_cataloged)
	_system.surprise_cataloged.connect(_on_surprise_cataloged)
	_system.element_identified.connect(_on_element_identified)
	_system.element_unknown.connect(_on_element_unknown)

	# Reset capture state
	_started_entry_id = &""
	_started_coords = Vector2i.ZERO
	_progress_value = -1.0
	_completed_entry_id = &""
	_cancelled_count = 0
	_rejected_coords = Vector2i(-999, -999)
	_cataloged_entry_id = &""
	_cataloged_category = -1
	_surprise_entry_id = &""
	_identified_coords = Vector2i(-999, -999)
	_identified_entry_id = &""
	_unknown_coords = Vector2i(-999, -999)
	_unknown_count = 0
	_identified_count = 0


func after_test() -> void:
	if is_instance_valid(_player):
		remove_child(_player)
		_player.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_system = null
	_grid = null
	_player = null
	_input = null


# --- Eligibility tests ---

func test_eligibility_uncataloged_returns_entry_id() -> void:
	_grid._tiles[Vector2i.ZERO] = _make_tile_with_resource(&"berries")
	var result: StringName = _system._catalog.get_scannable_at(Vector2i.ZERO)
	assert_str(String(result)).is_equal("berry_bush")


func test_eligibility_cataloged_returns_empty() -> void:
	_grid._tiles[Vector2i.ZERO] = _make_tile_with_resource(&"berries")
	_system._catalog.catalog_entry(&"berry_bush")
	var result: StringName = _system._catalog.get_scannable_at(Vector2i.ZERO)
	assert_str(String(result)).is_equal("")


# --- Scan lifecycle: IDLE -> SCANNING -> COMPLETE ---

func test_scan_lifecycle_idle_to_scanning_to_complete() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)

	# Start scan
	_system._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)
	assert_str(String(_started_entry_id)).is_equal("berry_bush")
	assert_int(_started_coords.x).is_equal(1)

	# Simulate progress to completion (flora = 2.0s, simulate 2.1s)
	_system._scan_progress = 0.99
	_system._process(0.05)  # pushes past 1.0

	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)
	assert_str(String(_completed_entry_id)).is_equal("berry_bush")
	assert_str(String(_cataloged_entry_id)).is_equal("berry_bush")
	assert_int(_cataloged_category).is_equal(_Catalog.CatalogCategory.FLORA)


# --- Scan lifecycle: IDLE -> SCANNING -> cancelled on touch UP ---

func test_scan_cancelled_on_hold_ended() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	# Touch up before completion
	_system._on_scan_hold_ended()
	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)
	assert_int(_cancelled_count).is_equal(1)
	assert_float(_system.get_scan_progress()).is_equal(0.0)


# --- Scan duration per category ---

func test_scan_duration_flora_is_2s() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	assert_float(_system._scan_duration).is_equal(2.0)


func test_scan_duration_mineral_is_2s() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"stone")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	assert_float(_system._scan_duration).is_equal(2.0)


func test_scan_duration_anomaly_is_3s() -> void:
	var tile: HexTile = _HexTile.new()
	tile.anomaly = &"anomaly_ch1_001"
	_grid._tiles[Vector2i(1, 0)] = tile
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	assert_float(_system._scan_duration).is_equal(3.0)


# --- Range check: cancel if player > _scan_range from target ---

func test_range_check_cancels_scan_when_player_moves_away() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	# Move player 3 hexes away (beyond range of 2)
	_player.current_tile = Vector2i(4, 0)
	_system._process(0.016)

	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)
	assert_int(_cancelled_count).is_equal(1)


func test_range_check_allows_scan_within_range() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))

	# Player stays at distance 1 (within range of 2)
	_player.current_tile = Vector2i.ZERO
	_system._process(0.5)

	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)
	assert_int(_cancelled_count).is_equal(0)


# --- Surprise catalog ---

func test_surprise_catalog_uncataloged_species() -> void:
	_system.on_fauna_attacked_player(1, 10, &"thornback")

	assert_str(String(_surprise_entry_id)).is_equal("thornback")
	assert_str(String(_cataloged_entry_id)).is_equal("thornback")
	assert_int(_cataloged_category).is_equal(_Catalog.CatalogCategory.FAUNA)
	assert_bool(_system._catalog.is_cataloged(&"thornback")).is_true()


func test_surprise_catalog_already_cataloged_is_noop() -> void:
	_system._catalog.catalog_entry(&"thornback")
	# Reset capture
	_cataloged_entry_id = &""
	_surprise_entry_id = &""

	_system.on_fauna_attacked_player(1, 10, &"thornback")
	assert_str(String(_surprise_entry_id)).is_equal("")


func test_surprise_catalog_unknown_species_is_noop() -> void:
	_system.on_fauna_attacked_player(1, 10, &"nonexistent_creature")
	assert_str(String(_surprise_entry_id)).is_equal("")


# --- Passive identification ---

func test_passive_id_cataloged_resource_emits_element_identified() -> void:
	_system._catalog.catalog_entry(&"berry_bush")
	_grid._tiles[Vector2i(2, 0)] = _make_tile_with_resource(&"berries")

	_system._check_passive_identification(Vector2i(2, 0))
	assert_str(String(_identified_entry_id)).is_equal("berry_bush")
	assert_int(_identified_coords.x).is_equal(2)
	assert_int(_identified_count).is_equal(1)


func test_passive_id_uncataloged_resource_emits_element_unknown() -> void:
	_grid._tiles[Vector2i(2, 0)] = _make_tile_with_resource(&"berries")

	_system._check_passive_identification(Vector2i(2, 0))
	assert_int(_unknown_coords.x).is_equal(2)
	assert_int(_unknown_count).is_equal(1)


func test_passive_id_cataloged_anomaly_emits_element_identified() -> void:
	_system._catalog.catalog_entry(&"anomaly_ch1_001")
	var tile: HexTile = _HexTile.new()
	tile.anomaly = &"anomaly_ch1_001"
	_grid._tiles[Vector2i(3, 0)] = tile

	_system._check_passive_identification(Vector2i(3, 0))
	assert_str(String(_identified_entry_id)).is_equal("anomaly_ch1_001")


func test_passive_id_uncataloged_anomaly_emits_element_unknown() -> void:
	var tile: HexTile = _HexTile.new()
	tile.anomaly = &"anomaly_ch1_001"
	_grid._tiles[Vector2i(3, 0)] = tile

	_system._check_passive_identification(Vector2i(3, 0))
	assert_int(_unknown_count).is_equal(1)


func test_passive_id_tile_revealed_triggers_check() -> void:
	_grid._tiles[Vector2i(1, 1)] = _make_tile_with_resource(&"wood")

	_system._on_tile_revealed(Vector2i(1, 1))
	assert_int(_unknown_count).is_equal(1)


func test_passive_id_visibility_changed_to_visible_triggers_check() -> void:
	_grid._tiles[Vector2i(1, 1)] = _make_tile_with_resource(&"wood")

	_system._on_tile_visibility_changed(Vector2i(1, 1), _HexTile.FogState.VISIBLE)
	assert_int(_unknown_count).is_equal(1)


func test_passive_id_visibility_changed_to_revealed_does_not_trigger() -> void:
	_grid._tiles[Vector2i(1, 1)] = _make_tile_with_resource(&"wood")

	_system._on_tile_visibility_changed(Vector2i(1, 1), _HexTile.FogState.REVEALED)
	assert_int(_unknown_count).is_equal(0)


# --- scan_rejected never emitted while SCANNING ---

func test_scan_rejected_not_emitted_while_scanning() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	# Try to start another scan on empty tile while already scanning
	_system._on_scan_hold_started(Vector2i(5, 5))

	# scan_rejected should NOT have been emitted
	assert_int(_rejected_coords.x).is_equal(-999)


# --- entry_cataloged emitted on completion with correct data ---

func test_entry_cataloged_emitted_with_correct_data_on_scan_complete() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"stone")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	_system._scan_progress = 0.99
	_system._process(0.05)

	assert_str(String(_cataloged_entry_id)).is_equal("stone_deposit")
	assert_int(_cataloged_category).is_equal(_Catalog.CatalogCategory.MINERAL)


# --- Rejected when nothing scannable ---

func test_scan_rejected_when_no_scannable_element() -> void:
	var empty_tile: HexTile = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = empty_tile
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))

	assert_int(_rejected_coords.x).is_equal(1)
	assert_int(_system.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)


func test_scan_rejected_when_already_cataloged() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_system._catalog.catalog_entry(&"berry_bush")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))

	assert_int(_rejected_coords.x).is_equal(1)


# --- Progress updates emitted ---

func test_scan_progress_emitted_during_scan() -> void:
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	_system._on_scan_hold_started(Vector2i(1, 0))
	_system._process(0.5)  # 0.5s / 2.0s = 0.25 progress

	assert_float(_progress_value).is_greater(0.0)
	assert_float(_progress_value).is_less(1.0)


# --- Connects to PlayerInput scan_hold signals ---

func test_connects_to_player_input_signals() -> void:
	# Verify connection by emitting PlayerInput signal and checking system reacts
	_grid._tiles[Vector2i(2, 0)] = _make_tile_with_resource(&"fiber")
	_player.current_tile = Vector2i.ZERO

	_input.scan_hold_started.emit(Vector2i(2, 0))
	assert_str(String(_started_entry_id)).is_equal("fiber_grass")
