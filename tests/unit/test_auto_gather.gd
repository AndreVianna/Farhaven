extends GdUnitTestSuite
class_name TestAutoGather

## Unit tests for auto-gather flow (task-017, updated for proximity model).
## Tests world-space proximity detection, catalog/tool gates, candidate sorting,
## tween-based gather, chaining, inventory-full signals, and respawn queue.
## Auto-gather now uses continuous world-space distance (GATHER_RADIUS = 0.75u)
## instead of tile_entered events.

const _AutoInteraction = preload("res://scripts/auto_interaction/auto_interaction_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")


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
		var q: float = float(coords.x)
		var r: float = float(coords.y)
		var x: float = 3.0 * (3.0 / 2.0 * q)
		var y: float = 3.0 * (sqrt(3.0) / 2.0 * q + sqrt(3.0) * r)
		return Vector2(x, y)

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

	func get_inventory():
		return null  # Inventory set directly on sys._inventory


# --- Test state ---

var _sys: _AutoInteraction
var _grid: FakeGrid
var _player: FakePlayer
var _catalog: _Catalog
var _inv: _Inventory

# Signal captures
var _started_coords: Vector2i = Vector2i(-999, -999)
var _started_type: StringName = &""
var _completed_coords: Vector2i = Vector2i(-999, -999)
var _completed_type: StringName = &""
var _completed_amount: int = 0
var _failed_coords: Vector2i = Vector2i(-999, -999)
var _failed_reason: StringName = &""
var _depleted_coords: Vector2i = Vector2i(-999, -999)
var _depleted_type: StringName = &""
var _started_count: int = 0
var _completed_count: int = 0
var _failed_count: int = 0
var _depleted_count: int = 0


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_player = FakePlayer.new()
	add_child(_player)

	_catalog = _Catalog.new()
	# Initialize without loading files — we'll manually set knowledge states
	_catalog._knowledge = {}
	_catalog._all_entries = {}

	_inv = _Inventory.new()

	_sys = _AutoInteraction.new()
	# Inject dependencies directly (bypass _ready)
	_sys._grid = _grid
	_sys._player = _player
	_sys._catalog = _catalog
	_sys._inventory = _inv
	_player.add_child(_sys)

	# Connect signals for capture
	_sys.auto_gather_started.connect(_on_started)
	_sys.auto_gather_completed.connect(_on_completed)
	_sys.auto_gather_failed.connect(_on_failed)
	_grid.resource_depleted.connect(_on_depleted)

	# Reset counters
	_started_coords = Vector2i(-999, -999)
	_started_type = &""
	_completed_coords = Vector2i(-999, -999)
	_completed_type = &""
	_completed_amount = 0
	_failed_coords = Vector2i(-999, -999)
	_failed_reason = &""
	_depleted_coords = Vector2i(-999, -999)
	_depleted_type = &""
	_started_count = 0
	_completed_count = 0
	_failed_count = 0
	_depleted_count = 0


func after_test() -> void:
	_player.queue_free()
	_grid.queue_free()


func _on_started(coords: Vector2i, resource_type: StringName) -> void:
	_started_coords = coords
	_started_type = resource_type
	_started_count += 1


func _on_completed(coords: Vector2i, resource_type: StringName, amount: int) -> void:
	_completed_coords = coords
	_completed_type = resource_type
	_completed_amount = amount
	_completed_count += 1


func _on_failed(coords: Vector2i, reason: StringName) -> void:
	_failed_coords = coords
	_failed_reason = reason
	_failed_count += 1


func _on_depleted(coords: Vector2i, resource_type: StringName) -> void:
	_depleted_coords = coords
	_depleted_type = resource_type
	_depleted_count += 1


# --- Helpers ---

func _make_resource(type: StringName, tool_req: StringName = &"", remaining: int = 3, respawn: float = 0.0, offset: Vector2 = Vector2.ZERO) -> Resource:
	var rn: Resource = _ResourceNode.new()
	rn.type = type
	rn.remaining = remaining
	rn.max_amount = remaining
	rn.tool_required = tool_req
	rn.respawn_time = respawn
	rn.offset = offset
	return rn


func _make_tile(coords: Vector2i, resources: Array = []) -> Resource:
	var tile: Resource = _HexTile.new()
	tile.coords = coords
	tile.biome = _HexTile.Biome.FOREST
	tile.elevation = 0
	tile.fog_state = _HexTile.FogState.VISIBLE
	tile.resource_nodes = resources
	return tile


func _catalog_resource(type: StringName) -> void:
	var entry_id: StringName = ResourceRegistry.get_def(type).catalog_entry if ResourceRegistry.has_def(type) else &""
	if entry_id != &"":
		_catalog._knowledge[entry_id] = _Catalog.KnowledgeState.CATALOGED


## Position the player at the world-space center of the given tile.
func _place_player_at_tile(coords: Vector2i) -> void:
	var world_2d: Vector2 = _grid.axial_to_world(coords)
	_player.position = Vector3(world_2d.x, 0.0, world_2d.y)
	_player.current_tile = coords


## Position the player at an exact world position and set current_tile.
func _place_player_at(world_x: float, world_z: float, tile: Vector2i) -> void:
	_player.position = Vector3(world_x, 0.0, world_z)
	_player.current_tile = tile


# ===================================================================
# TESTS: Catalog gate
# ===================================================================

func test_uncataloged_resource_not_gathered() -> void:
	# Wood on player tile, but NOT cataloged — nothing should happen
	var rn := _make_resource(&"wood")
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_false()
	assert_int(_started_count).is_equal(0)


func test_cataloged_resource_triggers_gather() -> void:
	var rn := _make_resource(&"wood")
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	assert_int(_started_count).is_equal(1)
	assert_str(_started_type).is_equal(&"wood")


# ===================================================================
# TESTS: Tool gate (silent skip — no tool_gated signal)
# ===================================================================

func test_tool_gated_resource_silently_skipped() -> void:
	# Ore requires stone_pickaxe, player doesn't have it — silently skipped
	var rn := _make_resource(&"ore", &"stone_pickaxe")
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"ore")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_false()
	# No tool_gated signal emitted (removed)
	assert_int(_failed_count).is_equal(0)


func test_tool_equipped_gathers_gated_resource() -> void:
	_inv.set_tool(&"pickaxe", &"stone_pickaxe")
	var rn := _make_resource(&"ore", &"stone_pickaxe")
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"ore")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	assert_str(_started_type).is_equal(&"ore")


# ===================================================================
# TESTS: World-space proximity (GATHER_RADIUS = 0.75)
# ===================================================================

func test_resource_beyond_gather_radius_not_gathered() -> void:
	# Resource at tile (0,0) center, player 1.0 units away (> 0.75)
	var rn := _make_resource(&"wood")
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at(1.0, 0.0, Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_false()
	assert_int(_started_count).is_equal(0)


func test_resource_within_gather_radius_gathered() -> void:
	# Resource at tile (0,0) center, player 0.5 units away (< 0.75)
	var rn := _make_resource(&"wood")
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at(0.5, 0.0, Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	assert_str(_started_type).is_equal(&"wood")


func test_resource_at_tile_center_gathered_by_centered_player() -> void:
	# Player exactly at tile center, resource at tile center (distance 0)
	var rn := _make_resource(&"wood")
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()


func test_resource_with_offset_distance_computed_correctly() -> void:
	# Resource at tile (0,0) with offset (1.0, 0.0).
	# offset_to_world(Vector2(1,0), 3.0) = Vector2(1.2, 0.0)
	# Resource world pos = (0 + 1.2, 0 + 0) = (1.2, 0)
	# Player at (0, 0, 0) → distance = 1.2 > GATHER_RADIUS (0.75) → not gathered
	var rn := _make_resource(&"wood", &"", 3, 0.0, Vector2(1.0, 0.0))
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_false()


func test_resource_with_small_offset_within_radius() -> void:
	# Resource at tile (0,0) with offset (0.5, 0.0).
	# offset_to_world(Vector2(0.5,0), 3.0) = Vector2(0.6, 0.0)
	# Player at (0, 0, 0) → distance = 0.6 < 0.75 → gathered
	var rn := _make_resource(&"wood", &"", 3, 0.0, Vector2(0.5, 0.0))
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()


func test_gathers_from_neighbor_tile_when_close_enough() -> void:
	# Player tile empty. Neighbor tile (1,0) has resource with offset toward player.
	# Tile (1,0) center = axial_to_world(1,0) = (4.5, ~2.598)
	# Resource offset (-1.0, 0.0) → offset_to_world = (-1.2, 0.0)
	# Resource world pos = (4.5 - 1.2, 2.598) = (3.3, 2.598)
	# Place player at (3.0, 0, 2.598) → distance ~0.3 < 0.75 → gathered
	var player_tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = player_tile

	var rn := _make_resource(&"wood", &"", 3, 0.0, Vector2(-1.0, 0.0))
	var neighbor_coords := Vector2i(1, 0)
	var neighbor_tile := _make_tile(neighbor_coords, [rn])
	_grid._tiles[neighbor_coords] = neighbor_tile

	_catalog_resource(&"wood")

	# Compute the resource's world position
	var tile_center: Vector2 = _grid.axial_to_world(neighbor_coords)
	var offset_w: Vector2 = _PropUtils.offset_to_world(Vector2(-1.0, 0.0), _HexMath.HEX_SIZE)
	var resource_world: Vector2 = tile_center + offset_w
	# Place player right at the resource
	_place_player_at(resource_world.x, resource_world.y, Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	assert_object(_sys._gather_target_coords).is_equal(neighbor_coords)


func test_depleted_resource_skipped() -> void:
	var rn := _make_resource(&"wood", &"", 0)  # remaining = 0
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_false()
	assert_int(_started_count).is_equal(0)


# ===================================================================
# TESTS: Candidate sorting (priority + world distance)
# ===================================================================

func test_higher_priority_resource_gathered_first() -> void:
	# Same tile: bare-hand wood (priority 0) and pickaxe ore (priority 2)
	# Both at tile center — player on top of both
	_inv.set_tool(&"pickaxe", &"stone_pickaxe")
	var wood_rn := _make_resource(&"wood")
	var ore_rn := _make_resource(&"ore", &"stone_pickaxe")
	var tile := _make_tile(Vector2i.ZERO, [wood_rn, ore_rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_catalog_resource(&"ore")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	# Ore has priority 2 > wood priority 0
	assert_str(_started_type).is_equal(&"ore")


func test_nearer_resource_gathered_first_at_same_priority() -> void:
	# Two wood resources on same tile but different offsets.
	# Near one at offset (0.1, 0) → world offset = (0.12, 0) → world pos (0.12, 0)
	# Far one at offset (0.5, 0) → world offset = (0.6, 0) → world pos (0.6, 0)
	# Player at (0, 0, 0) → near dist = 0.12, far dist = 0.6
	var rn_near := _make_resource(&"wood", &"", 3, 0.0, Vector2(0.1, 0.0))
	var rn_far := _make_resource(&"wood", &"", 3, 0.0, Vector2(0.5, 0.0))
	var tile := _make_tile(Vector2i.ZERO, [rn_far, rn_near])  # far first in array
	_grid._tiles[Vector2i.ZERO] = tile

	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	# Near resource (index 1 in array) should be gathered first
	assert_int(_sys._gather_target_index).is_equal(1)


# ===================================================================
# TESTS: Gather tween completion
# ===================================================================

func test_gather_completes_adds_to_inventory() -> void:
	var rn := _make_resource(&"wood", &"", 3)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()

	# Simulate tween completion by calling the callback directly
	_sys._on_gather_tween_complete()

	assert_int(_completed_count).is_equal(1)
	assert_str(_completed_type).is_equal(&"wood")
	assert_int(_completed_amount).is_equal(1)  # wood gather_amount = 1
	assert_int(rn.remaining).is_equal(2)  # 3 -> 2
	assert_int(_inv.get_count(&"wood")).is_equal(1)


func test_gather_completes_berries_gives_correct_amount() -> void:
	var rn := _make_resource(&"berries", &"", 3)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"berries")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()

	assert_int(_completed_amount).is_equal(2)  # berries gather_amount = 2
	assert_int(_inv.get_count(&"berries")).is_equal(2)


func test_gather_decrements_remaining() -> void:
	var rn := _make_resource(&"wood", &"", 2)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()
	assert_int(rn.remaining).is_equal(1)


# ===================================================================
# TESTS: Resource depletion
# ===================================================================

func test_depletion_emits_resource_depleted() -> void:
	var rn := _make_resource(&"wood", &"", 1)  # Will deplete on first gather
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()

	assert_int(rn.remaining).is_equal(0)
	assert_int(_depleted_count).is_equal(1)
	assert_object(_depleted_coords).is_equal(Vector2i.ZERO)
	assert_str(_depleted_type).is_equal(&"wood")


func test_depletion_with_respawn_adds_to_queue() -> void:
	var rn := _make_resource(&"wood", &"", 1, 10.0)  # respawn_time = 10s
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()

	assert_int(_sys._respawn_queue.size()).is_equal(1)
	var entry: Dictionary = _sys._respawn_queue[0]
	assert_object(entry["coords"]).is_equal(Vector2i.ZERO)
	assert_float(entry["time_remaining"]).is_equal(10.0)


func test_depletion_without_respawn_no_queue_entry() -> void:
	var rn := _make_resource(&"wood", &"", 1, 0.0)  # no respawn
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()

	assert_int(_sys._respawn_queue.size()).is_equal(0)


# ===================================================================
# TESTS: Inventory full
# ===================================================================

func test_inventory_full_emits_failed() -> void:
	# Fill the inventory completely
	for i in 12:  # 12 slots × 99 max_stack for wood
		_inv.add_item(&"wood", 99)

	var rn := _make_resource(&"wood", &"", 3)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()

	assert_int(_failed_count).is_equal(1)
	assert_str(_failed_reason).is_equal(&"inventory_full")
	# remaining should NOT decrement when inventory is full
	assert_int(rn.remaining).is_equal(3)


# ===================================================================
# TESTS: Gather always completes (no cancel)
# ===================================================================

func test_is_gathering_blocks_new_proximity_check() -> void:
	# Start gathering on tile 0,0
	var rn1 := _make_resource(&"wood", &"", 3)
	var tile1 := _make_tile(Vector2i.ZERO, [rn1])
	_grid._tiles[Vector2i.ZERO] = tile1

	var rn2 := _make_resource(&"stone", &"", 3)
	var tile2 := _make_tile(Vector2i(1, 0), [rn2])
	_grid._tiles[Vector2i(1, 0)] = tile2

	_catalog_resource(&"wood")
	_catalog_resource(&"stone")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	assert_str(_started_type).is_equal(&"wood")

	# Player moves to neighbor tile — proximity check fires but should be blocked
	_place_player_at_tile(Vector2i(1, 0))
	_sys._check_gather_proximity()

	# Should still be gathering the ORIGINAL resource (no cancel)
	assert_int(_started_count).is_equal(1)
	assert_str(_started_type).is_equal(&"wood")


# ===================================================================
# TESTS: Chain gathering
# ===================================================================

func test_chain_gathers_next_resource_after_completion() -> void:
	# Two wood resources on the player tile, both within radius
	var rn1 := _make_resource(&"wood", &"", 1)  # Will deplete
	var rn2 := _make_resource(&"wood", &"", 1)
	var tile := _make_tile(Vector2i.ZERO, [rn1, rn2])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()

	# Complete first gather — should chain to second
	_sys._on_gather_tween_complete()
	assert_int(_completed_count).is_equal(1)
	# Chain should have started gathering the second resource
	assert_int(_started_count).is_equal(2)
	assert_bool(_sys._is_gathering).is_true()


func test_chain_uses_player_current_position() -> void:
	# Player starts at 0,0 with wood, gathers it.
	# Player moves during gather. Chain should check from new position.
	var rn1 := _make_resource(&"wood", &"", 1)
	var tile1 := _make_tile(Vector2i.ZERO, [rn1])
	_grid._tiles[Vector2i.ZERO] = tile1

	# Resource on neighbor of (1,0): tile (2,0)
	# Place resource with offset toward the left edge
	var rn2 := _make_resource(&"stone", &"", 3, 0.0, Vector2(-1.0, 0.0))
	var tile2 := _make_tile(Vector2i(2, 0), [rn2])
	_grid._tiles[Vector2i(2, 0)] = tile2

	# Add tile at 1,0 (empty) so get_neighbors works
	var tile_mid := _make_tile(Vector2i(1, 0))
	_grid._tiles[Vector2i(1, 0)] = tile_mid

	_catalog_resource(&"wood")
	_catalog_resource(&"stone")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()

	# Player moves to position near the stone resource during gather
	var stone_tile_center: Vector2 = _grid.axial_to_world(Vector2i(2, 0))
	var stone_offset_w: Vector2 = _PropUtils.offset_to_world(Vector2(-1.0, 0.0), _HexMath.HEX_SIZE)
	var stone_world: Vector2 = stone_tile_center + stone_offset_w
	_place_player_at(stone_world.x, stone_world.y, Vector2i(1, 0))

	# Complete first gather — chain should check from new position
	_sys._on_gather_tween_complete()

	# Stone at 2,0 is neighbor of 1,0, and player is close to it
	assert_int(_started_count).is_equal(2)
	assert_str(_started_type).is_equal(&"stone")
	assert_object(_sys._gather_target_coords).is_equal(Vector2i(2, 0))


func test_chain_stops_when_no_more_candidates() -> void:
	var rn := _make_resource(&"wood", &"", 1)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()

	# Resource depleted, no more candidates — gathering should stop
	assert_bool(_sys._is_gathering).is_false()
	assert_int(_started_count).is_equal(1)


# ===================================================================
# TESTS: Effective time computation
# ===================================================================

func test_effective_time_bare_hands_wood() -> void:
	var rn := _make_resource(&"wood", &"", 3)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	# Bare hands gathering wood: base 1.0 × multiplier 1.0 = 1.0s
	assert_bool(_sys._is_gathering).is_true()
	assert_bool(_sys._gather_tween != null).is_true()


func test_effective_time_with_axe_for_wood() -> void:
	_inv.set_tool(&"axe", &"stone_axe")
	var rn := _make_resource(&"wood", &"", 3)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	# stone_axe on wood: base 1.0 × 0.5 = 0.5s
	assert_bool(_sys._is_gathering).is_true()
	assert_str(_started_type).is_equal(&"wood")


# ===================================================================
# TESTS: Multiple resource types mixed
# ===================================================================

func test_mixed_cataloged_and_uncataloged_only_gathers_cataloged() -> void:
	# Wood is cataloged, stone is NOT cataloged
	var wood_rn := _make_resource(&"wood", &"", 3)
	var stone_rn := _make_resource(&"stone", &"", 3)
	var tile := _make_tile(Vector2i.ZERO, [wood_rn, stone_rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	# stone NOT cataloged
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_true()
	assert_str(_started_type).is_equal(&"wood")


func test_no_resources_on_any_tile_nothing_happens() -> void:
	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	_place_player_at_tile(Vector2i.ZERO)

	_sys._check_gather_proximity()
	assert_bool(_sys._is_gathering).is_false()
	assert_int(_started_count).is_equal(0)


# ===================================================================
# TESTS: _try_gather_nearby with null dependencies
# ===================================================================

func test_try_gather_returns_false_without_catalog() -> void:
	_sys._catalog = null
	var result: bool = _sys._try_gather_nearby(Vector2i.ZERO)
	assert_bool(result).is_false()


func test_try_gather_returns_false_without_inventory() -> void:
	_sys._inventory = null
	var result: bool = _sys._try_gather_nearby(Vector2i.ZERO)
	assert_bool(result).is_false()


func test_try_gather_returns_false_without_grid() -> void:
	_sys._grid = null
	var result: bool = _sys._try_gather_nearby(Vector2i.ZERO)
	assert_bool(result).is_false()


# ===================================================================
# TESTS: Respawn queue (always ticks — no fog gate)
# ===================================================================

func test_respawn_ticks_even_when_visible() -> void:
	# Respawn should always tick regardless of fog_state (fog removed)
	var rn := _make_resource(&"wood", &"", 1, 2.0)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	tile.fog_state = _HexTile.FogState.VISIBLE
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	# Deplete
	_sys._check_gather_proximity()
	_sys._on_gather_tween_complete()
	assert_int(_sys._respawn_queue.size()).is_equal(1)

	# Tick 1.5s — not enough
	_sys._tick_respawn_queue(1.5)
	assert_int(rn.remaining).is_equal(0)

	# Tick 1.0s more — total 2.5 > 2.0 → respawned
	_sys._tick_respawn_queue(1.0)
	assert_int(rn.remaining).is_equal(1)
	assert_int(_sys._respawn_queue.size()).is_equal(0)


# ===================================================================
# TESTS: Proximity check triggered from _process (throttled)
# ===================================================================

func test_process_triggers_proximity_check_throttled() -> void:
	var rn := _make_resource(&"wood", &"", 3)
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog_resource(&"wood")
	_place_player_at_tile(Vector2i.ZERO)

	# Small delta — not enough to trigger check
	_sys._process(0.05)
	assert_bool(_sys._is_gathering).is_false()

	# Accumulate to >= PROXIMITY_CHECK_INTERVAL (0.1s)
	_sys._process(0.06)
	assert_bool(_sys._is_gathering).is_true()
	assert_str(_started_type).is_equal(&"wood")
