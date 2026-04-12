extends GdUnitTestSuite

## Unit tests for FaunaRenderer (task-038: renderer instance management)
## and FaunaManager signal wiring to downstream systems.

const _FaunaRenderer = preload("res://scripts/fauna/fauna_renderer.gd")
const _FaunaManager = preload("res://scripts/fauna/fauna_manager.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

var _renderer: Node3D
var _fauna_mgr: Node


# === Mocks ===

class MockHexGridSimple extends Node:
	var _tiles: Dictionary = {}

	func get_tile(coords: Vector2i) -> Resource:
		return _tiles.get(coords, null)

	func has_tile(coords: Vector2i) -> bool:
		return _tiles.has(coords)

	func get_terrain_y(_x: float, _z: float) -> float:
		return 0.0


# === Setup / Teardown ===

func before_test() -> void:
	_renderer = _FaunaRenderer.new()
	_renderer._grid = MockHexGridSimple.new()
	add_child(_renderer)


func after_test() -> void:
	remove_child(_renderer)
	_renderer.queue_free()


# =========================================================================
# RENDERER INSTANCE MANAGEMENT TESTS
# =========================================================================

func test_initial_visible_count_is_zero() -> void:
	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_add_fauna_increases_visible_count() -> void:
	_renderer.add_fauna(0, Vector2i(1, 0))
	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_add_multiple_fauna() -> void:
	_renderer.add_fauna(0, Vector2i(1, 0))
	_renderer.add_fauna(1, Vector2i(2, 0))
	_renderer.add_fauna(2, Vector2i(3, 0))
	assert_int(_renderer.get_visible_count()).is_equal(3)


func test_add_duplicate_id_is_ignored() -> void:
	_renderer.add_fauna(0, Vector2i(1, 0))
	_renderer.add_fauna(0, Vector2i(2, 0))
	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_remove_fauna_decreases_visible_count() -> void:
	_renderer.add_fauna(0, Vector2i(1, 0))
	_renderer.add_fauna(1, Vector2i(2, 0))
	_renderer.remove_fauna(0)
	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_remove_nonexistent_fauna_is_noop() -> void:
	_renderer.add_fauna(0, Vector2i(1, 0))
	_renderer.remove_fauna(99)
	assert_int(_renderer.get_visible_count()).is_equal(1)


func test_remove_all_fauna() -> void:
	_renderer.add_fauna(0, Vector2i(1, 0))
	_renderer.add_fauna(1, Vector2i(2, 0))
	_renderer.remove_fauna(0)
	_renderer.remove_fauna(1)
	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_has_fauna_returns_true_after_add() -> void:
	_renderer.add_fauna(5, Vector2i(1, 0))
	assert_bool(_renderer.has_fauna(5)).is_true()


func test_has_fauna_returns_false_after_remove() -> void:
	_renderer.add_fauna(5, Vector2i(1, 0))
	_renderer.remove_fauna(5)
	assert_bool(_renderer.has_fauna(5)).is_false()


func test_move_fauna_updates_position() -> void:
	_renderer.add_fauna(0, Vector2i(0, 0))
	assert_object(_renderer.get_fauna_coords(0)).is_equal(Vector2i(0, 0))
	_renderer.move_fauna(0, Vector2i(3, 0))
	# Coords should have updated to the new tile
	assert_object(_renderer.get_fauna_coords(0)).is_equal(Vector2i(3, 0))


func test_move_nonexistent_fauna_is_noop() -> void:
	# Should not crash
	_renderer.move_fauna(99, Vector2i(1, 0))
	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_add_fauna_coords_match_input() -> void:
	var coords := Vector2i(2, 1)
	_renderer.add_fauna(0, coords)
	# Stored coords should match what was passed in
	assert_object(_renderer.get_fauna_coords(0)).is_equal(coords)


func test_swap_remove_preserves_remaining_instances() -> void:
	# Add 3, remove middle one — remaining should still be accessible
	_renderer.add_fauna(10, Vector2i(0, 0))
	_renderer.add_fauna(20, Vector2i(1, 0))
	_renderer.add_fauna(30, Vector2i(2, 0))
	_renderer.remove_fauna(10)
	assert_int(_renderer.get_visible_count()).is_equal(2)
	assert_bool(_renderer.has_fauna(20)).is_true()
	assert_bool(_renderer.has_fauna(30)).is_true()
	assert_bool(_renderer.has_fauna(10)).is_false()


func test_remove_first_then_move_swapped() -> void:
	# Ensure the swapped instance can still be moved correctly
	_renderer.add_fauna(10, Vector2i(0, 0))
	_renderer.add_fauna(20, Vector2i(1, 0))
	_renderer.add_fauna(30, Vector2i(2, 0))
	_renderer.remove_fauna(10)
	# fauna 30 was swapped into index 0 — move it
	_renderer.move_fauna(30, Vector2i(5, 0))
	assert_object(_renderer.get_fauna_coords(30)).is_equal(Vector2i(5, 0))


# =========================================================================
# SIGNAL-DRIVEN TESTS (renderer responds to FaunaManager signals)
# =========================================================================

func test_fauna_spawned_signal_adds_instance() -> void:
	_fauna_mgr = _FaunaManager.new()
	_renderer._fauna_manager = _fauna_mgr
	_renderer._connect_fauna_manager()
	add_child(_fauna_mgr)

	_fauna_mgr.fauna_spawned.emit(0, Vector2i(1, 0), &"P00108")
	assert_int(_renderer.get_visible_count()).is_equal(1)

	remove_child(_fauna_mgr)
	_fauna_mgr.queue_free()


func test_fauna_moved_signal_updates_position() -> void:
	_fauna_mgr = _FaunaManager.new()
	_renderer._fauna_manager = _fauna_mgr
	_renderer._connect_fauna_manager()
	add_child(_fauna_mgr)

	_fauna_mgr.fauna_spawned.emit(0, Vector2i(0, 0), &"P00108")
	_fauna_mgr.fauna_moved.emit(0, Vector2i(0, 0), Vector2i(2, 1), &"P00108")
	assert_object(_renderer.get_fauna_coords(0)).is_equal(Vector2i(2, 1))

	remove_child(_fauna_mgr)
	_fauna_mgr.queue_free()


func test_fauna_killed_signal_removes_instance() -> void:
	_fauna_mgr = _FaunaManager.new()
	_renderer._fauna_manager = _fauna_mgr
	_renderer._connect_fauna_manager()
	add_child(_fauna_mgr)

	_fauna_mgr.fauna_spawned.emit(0, Vector2i(1, 0), &"P00108")
	assert_int(_renderer.get_visible_count()).is_equal(1)
	_fauna_mgr.fauna_killed.emit(0, Vector2i(1, 0), &"P00108")
	assert_int(_renderer.get_visible_count()).is_equal(0)

	remove_child(_fauna_mgr)
	_fauna_mgr.queue_free()


func test_fauna_despawned_signal_removes_instance() -> void:
	_fauna_mgr = _FaunaManager.new()
	_renderer._fauna_manager = _fauna_mgr
	_renderer._connect_fauna_manager()
	add_child(_fauna_mgr)

	_fauna_mgr.fauna_spawned.emit(0, Vector2i(1, 0), &"P00108")
	_fauna_mgr.fauna_despawned.emit(0, Vector2i(1, 0), &"P00108")
	assert_int(_renderer.get_visible_count()).is_equal(0)

	remove_child(_fauna_mgr)
	_fauna_mgr.queue_free()


func test_multiple_spawn_and_despawn_cycle() -> void:
	_fauna_mgr = _FaunaManager.new()
	_renderer._fauna_manager = _fauna_mgr
	_renderer._connect_fauna_manager()
	add_child(_fauna_mgr)

	# Spawn 3
	_fauna_mgr.fauna_spawned.emit(0, Vector2i(3, 0), &"P00108")
	_fauna_mgr.fauna_spawned.emit(1, Vector2i(4, 0), &"P00108")
	_fauna_mgr.fauna_spawned.emit(2, Vector2i(5, 0), &"P00108")
	assert_int(_renderer.get_visible_count()).is_equal(3)

	# Despawn all
	_fauna_mgr.fauna_despawned.emit(0, Vector2i(3, 0), &"P00108")
	_fauna_mgr.fauna_despawned.emit(1, Vector2i(4, 0), &"P00108")
	_fauna_mgr.fauna_despawned.emit(2, Vector2i(5, 0), &"P00108")
	assert_int(_renderer.get_visible_count()).is_equal(0)

	remove_child(_fauna_mgr)
	_fauna_mgr.queue_free()


# =========================================================================
# DRAW CALL TEST
# =========================================================================

func test_single_multimesh_child() -> void:
	# The renderer should have exactly 1 MultiMeshInstance3D child (1 draw call)
	var mmi_count: int = 0
	for child in _renderer.get_children():
		if child is MultiMeshInstance3D:
			mmi_count += 1
	assert_int(mmi_count).is_equal(1)


# =========================================================================
# POOL CAP & CLEANUP EDGE CASES (task-084d)
# =========================================================================

func test_pool_cap_rejects_overflow() -> void:
	# MAX_INSTANCES=8 — attempting to add a 9th instance should be a no-op
	for i in range(_FaunaRenderer.MAX_INSTANCES):
		_renderer.add_fauna(i, Vector2i(i, 0))
	assert_int(_renderer.get_visible_count()).is_equal(_FaunaRenderer.MAX_INSTANCES)
	# Now try to add one more — should be silently dropped
	_renderer.add_fauna(999, Vector2i(10, 0))
	assert_int(_renderer.get_visible_count()).is_equal(_FaunaRenderer.MAX_INSTANCES)
	assert_bool(_renderer.has_fauna(999)).is_false()


func test_despawn_then_respawn_reuses_slot() -> void:
	# After a despawn-via-signal, the freed slot should be available for
	# a subsequent spawn (no orphan tracking).
	_renderer.add_fauna(1, Vector2i(1, 0))
	_renderer.add_fauna(2, Vector2i(2, 0))
	_renderer.remove_fauna(1)
	assert_int(_renderer.get_visible_count()).is_equal(1)
	# Respawn with a new id at a new coord — should fill the freed slot
	_renderer.add_fauna(3, Vector2i(5, 0))
	assert_int(_renderer.get_visible_count()).is_equal(2)
	assert_bool(_renderer.has_fauna(3)).is_true()
	assert_bool(_renderer.has_fauna(1)).is_false()


func test_despawn_cleanup_leaves_no_orphan_coord_map() -> void:
	# After remove_fauna, get_fauna_coords should return the sentinel value
	# (no stale entry in the internal map).
	_renderer.add_fauna(7, Vector2i(3, 4))
	assert_object(_renderer.get_fauna_coords(7)).is_equal(Vector2i(3, 4))
	_renderer.remove_fauna(7)
	var sentinel := Vector2i(-99999, -99999)
	assert_object(_renderer.get_fauna_coords(7)).is_equal(sentinel)


func test_full_spawn_cycle_returns_to_zero() -> void:
	# Spawn a full pool, then despawn all — visible count must be exactly 0.
	for i in range(_FaunaRenderer.MAX_INSTANCES):
		_renderer.add_fauna(i, Vector2i(i, 0))
	for i in range(_FaunaRenderer.MAX_INSTANCES):
		_renderer.remove_fauna(i)
	assert_int(_renderer.get_visible_count()).is_equal(0)


func test_move_after_swap_remove_keeps_coord_map_consistent() -> void:
	# Edge case: when fauna A is removed via swap-with-last, the swapped-in
	# fauna B's get_fauna_coords must still return the correct coords.
	_renderer.add_fauna(10, Vector2i(1, 0))  # idx 0
	_renderer.add_fauna(20, Vector2i(2, 0))  # idx 1
	_renderer.add_fauna(30, Vector2i(3, 0))  # idx 2
	_renderer.remove_fauna(10)  # idx 0 now holds id=30 (swapped from last)
	# Confirm 30's coords still resolve through the coord map
	assert_object(_renderer.get_fauna_coords(30)).is_equal(Vector2i(3, 0))
	assert_object(_renderer.get_fauna_coords(20)).is_equal(Vector2i(2, 0))


func test_add_same_id_different_coords_is_idempotent() -> void:
	# Re-adding a tracked id should be ignored (no duplicate, original coords preserved).
	_renderer.add_fauna(5, Vector2i(1, 0))
	_renderer.add_fauna(5, Vector2i(9, 9))  # duplicate id, different coords
	assert_int(_renderer.get_visible_count()).is_equal(1)
	# First add wins — the coords should remain the original
	assert_object(_renderer.get_fauna_coords(5)).is_equal(Vector2i(1, 0))
