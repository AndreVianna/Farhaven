extends GdUnitTestSuite
class_name TestAutoInteractionStubs

## Unit tests for task-018: respawn queue, auto-defend stub, auto-pickup stub.

const _AutoInteraction = preload("res://scripts/auto_interaction/auto_interaction_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")


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


class FakePlayer extends Node:
	var current_tile: Vector2i = Vector2i.ZERO

	func get_inventory():
		return null


class FakeFaunaManager extends Node:
	signal fauna_moved(fauna_id: int, coords: Vector2i)

	var _entries: Dictionary = {}  # fauna_id -> entry_id
	var _hostile: Dictionary = {}  # fauna_id -> bool

	func get_fauna_entry_id(fauna_id: int) -> StringName:
		return _entries.get(fauna_id, &"")

	func is_hostile(fauna_id: int) -> bool:
		return _hostile.get(fauna_id, false)


class FakeSurvivalSystem extends Node:
	var _ground_items: Dictionary = {}  # coords -> Array[Dictionary]

	func get_ground_items_at(coords: Vector2i) -> Array:
		return _ground_items.get(coords, [])


# --- Test state ---

var _sys: _AutoInteraction
var _grid: FakeGrid
var _player: FakePlayer
var _catalog: _Catalog
var _inv: _Inventory

# Signal captures
var _defend_fauna_id: int = -1
var _defend_damage: int = 0
var _defend_count: int = 0
var _pickup_name: StringName = &""
var _pickup_amount: int = 0
var _pickup_count: int = 0
var _respawned_coords: Vector2i = Vector2i(-999, -999)
var _respawned_type: StringName = &""
var _respawned_count: int = 0


func before_test() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_player = FakePlayer.new()
	add_child(_player)

	_catalog = _Catalog.new()
	_catalog._knowledge = {}
	_catalog._all_entries = {}

	_inv = _Inventory.new()

	_sys = _AutoInteraction.new()
	_sys._grid = _grid
	_sys._player = _player
	_sys._catalog = _catalog
	_sys._inventory = _inv
	_player.add_child(_sys)

	# Connect signal captures
	_sys.auto_defend_triggered.connect(_on_defend_triggered)
	_sys.ground_item_picked_up.connect(_on_pickup)
	_grid.resource_respawned.connect(_on_respawned)

	# Reset counters
	_defend_fauna_id = -1
	_defend_damage = 0
	_defend_count = 0
	_pickup_name = &""
	_pickup_amount = 0
	_pickup_count = 0
	_respawned_coords = Vector2i(-999, -999)
	_respawned_type = &""
	_respawned_count = 0


func after_test() -> void:
	_player.queue_free()
	_grid.queue_free()


func _on_defend_triggered(fauna_id: int, damage: int) -> void:
	_defend_fauna_id = fauna_id
	_defend_damage = damage
	_defend_count += 1


func _on_pickup(item_name: StringName, amount: int) -> void:
	_pickup_name = item_name
	_pickup_amount = amount
	_pickup_count += 1


func _on_respawned(coords: Vector2i, resource_type: StringName) -> void:
	_respawned_coords = coords
	_respawned_type = resource_type
	_respawned_count += 1


# --- Helpers ---

func _make_resource(type: StringName, tool_req: StringName = &"", remaining: int = 3, respawn: float = 0.0) -> Resource:
	var rn: Resource = _ResourceNode.new()
	rn.type = type
	rn.remaining = remaining
	rn.max_amount = remaining
	rn.tool_required = tool_req
	rn.respawn_time = respawn
	return rn


func _make_tile(coords: Vector2i, resources: Array = [], fog: int = _HexTile.FogState.VISIBLE) -> Resource:
	var tile: Resource = _HexTile.new()
	tile.coords = coords
	tile.biome = _HexTile.Biome.FOREST
	tile.elevation = 0
	tile.fog_state = fog
	tile.resource_nodes = resources
	return tile


# ===================================================================
# RESPAWN QUEUE TESTS
# ===================================================================

func test_respawn_ticks_when_revealed() -> void:
	var rn := _make_resource(&"wood", &"", 0, 5.0)
	rn.max_amount = 3
	var tile := _make_tile(Vector2i.ZERO, [rn], _HexTile.FogState.REVEALED)
	_grid._tiles[Vector2i.ZERO] = tile

	_sys._respawn_queue.append({
		"coords": Vector2i.ZERO,
		"resource_index": 0,
		"time_remaining": 5.0,
	})

	_sys._process(2.0)

	assert_int(_sys._respawn_queue.size()).is_equal(1)
	assert_float(_sys._respawn_queue[0]["time_remaining"]).is_equal_approx(3.0, 0.01)


func test_respawn_ticks_when_hidden() -> void:
	var rn := _make_resource(&"wood", &"", 0, 5.0)
	rn.max_amount = 3
	var tile := _make_tile(Vector2i.ZERO, [rn], _HexTile.FogState.HIDDEN)
	_grid._tiles[Vector2i.ZERO] = tile

	_sys._respawn_queue.append({
		"coords": Vector2i.ZERO,
		"resource_index": 0,
		"time_remaining": 5.0,
	})

	_sys._process(2.0)

	assert_int(_sys._respawn_queue.size()).is_equal(1)
	assert_float(_sys._respawn_queue[0]["time_remaining"]).is_equal_approx(3.0, 0.01)


func test_respawn_pauses_when_visible() -> void:
	var rn := _make_resource(&"wood", &"", 0, 5.0)
	rn.max_amount = 3
	var tile := _make_tile(Vector2i.ZERO, [rn], _HexTile.FogState.VISIBLE)
	_grid._tiles[Vector2i.ZERO] = tile

	_sys._respawn_queue.append({
		"coords": Vector2i.ZERO,
		"resource_index": 0,
		"time_remaining": 5.0,
	})

	_sys._process(2.0)

	# Should NOT tick — time_remaining unchanged
	assert_int(_sys._respawn_queue.size()).is_equal(1)
	assert_float(_sys._respawn_queue[0]["time_remaining"]).is_equal(5.0)


func test_respawn_resumes_after_visibility_change() -> void:
	var rn := _make_resource(&"wood", &"", 0, 5.0)
	rn.max_amount = 3
	var tile := _make_tile(Vector2i.ZERO, [rn], _HexTile.FogState.VISIBLE)
	_grid._tiles[Vector2i.ZERO] = tile

	_sys._respawn_queue.append({
		"coords": Vector2i.ZERO,
		"resource_index": 0,
		"time_remaining": 5.0,
	})

	# Tick while VISIBLE — should not decrement
	_sys._process(2.0)
	assert_float(_sys._respawn_queue[0]["time_remaining"]).is_equal(5.0)

	# Change to REVEALED — should now tick
	tile.fog_state = _HexTile.FogState.REVEALED
	_sys._process(2.0)
	assert_float(_sys._respawn_queue[0]["time_remaining"]).is_equal_approx(3.0, 0.01)


func test_respawn_triggers_at_zero() -> void:
	var rn := _make_resource(&"wood", &"", 0, 1.0)
	rn.max_amount = 3
	var tile := _make_tile(Vector2i.ZERO, [rn], _HexTile.FogState.REVEALED)
	_grid._tiles[Vector2i.ZERO] = tile

	_sys._respawn_queue.append({
		"coords": Vector2i.ZERO,
		"resource_index": 0,
		"time_remaining": 1.0,
	})

	_sys._process(1.5)

	# Should have respawned and removed from queue
	assert_int(_sys._respawn_queue.size()).is_equal(0)
	assert_int(rn.remaining).is_equal(3)
	assert_int(_respawned_count).is_equal(1)
	assert_object(_respawned_coords).is_equal(Vector2i.ZERO)
	assert_str(_respawned_type).is_equal(&"wood")


func test_respawn_resets_to_max_amount() -> void:
	var rn := _make_resource(&"wood", &"", 0, 1.0)
	rn.max_amount = 5
	var tile := _make_tile(Vector2i.ZERO, [rn], _HexTile.FogState.HIDDEN)
	_grid._tiles[Vector2i.ZERO] = tile

	_sys._respawn_queue.append({
		"coords": Vector2i.ZERO,
		"resource_index": 0,
		"time_remaining": 0.5,
	})

	_sys._process(1.0)

	assert_int(rn.remaining).is_equal(5)


func test_respawn_time_zero_never_enters_queue() -> void:
	# This is tested in test_auto_gather.gd already, but verify again explicitly
	var rn := _make_resource(&"wood", &"", 1, 0.0)  # respawn_time = 0
	var tile := _make_tile(Vector2i.ZERO, [rn])
	_grid._tiles[Vector2i.ZERO] = tile
	_catalog._knowledge[&"wood_tree"] = _Catalog.KnowledgeState.CATALOGED
	_player.current_tile = Vector2i.ZERO

	_grid.tile_entered.emit(Vector2i.ZERO)
	_sys._on_gather_tween_complete()

	assert_int(_sys._respawn_queue.size()).is_equal(0)


func test_respawn_queue_handles_multiple_entries() -> void:
	var rn1 := _make_resource(&"wood", &"", 0, 3.0)
	rn1.max_amount = 2
	var tile1 := _make_tile(Vector2i.ZERO, [rn1], _HexTile.FogState.REVEALED)
	_grid._tiles[Vector2i.ZERO] = tile1

	var rn2 := _make_resource(&"stone", &"", 0, 1.0)
	rn2.max_amount = 4
	var tile2 := _make_tile(Vector2i(1, 0), [rn2], _HexTile.FogState.HIDDEN)
	_grid._tiles[Vector2i(1, 0)] = tile2

	_sys._respawn_queue.append({
		"coords": Vector2i.ZERO,
		"resource_index": 0,
		"time_remaining": 3.0,
	})
	_sys._respawn_queue.append({
		"coords": Vector2i(1, 0),
		"resource_index": 0,
		"time_remaining": 1.0,
	})

	_sys._process(1.5)

	# Stone should have respawned (1.0 < 1.5), wood should still be ticking
	assert_int(_sys._respawn_queue.size()).is_equal(1)
	assert_int(rn2.remaining).is_equal(4)
	assert_int(rn1.remaining).is_equal(0)
	assert_int(_respawned_count).is_equal(1)
	assert_str(_respawned_type).is_equal(&"stone")


# ===================================================================
# AUTO-DEFEND STUB TESTS
# ===================================================================

func test_defend_fires_on_adjacent_hostile_cataloged() -> void:
	var fm := FakeFaunaManager.new()
	fm._entries[42] = &"wolf"
	fm._hostile[42] = true
	add_child(fm)

	_sys._fauna_manager = fm
	_catalog._knowledge[&"wolf"] = _Catalog.KnowledgeState.CATALOGED
	_inv.set_tool(&"weapon", &"")  # Ensure bare hands
	_player.current_tile = Vector2i.ZERO

	# Wolf at adjacent tile (distance 1)
	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	var adj_tile := _make_tile(Vector2i(1, 0))
	_grid._tiles[Vector2i(1, 0)] = adj_tile

	_sys._on_fauna_moved(42, Vector2i(1, 0))

	assert_int(_defend_count).is_equal(1)
	assert_int(_defend_fauna_id).is_equal(42)
	assert_int(_defend_damage).is_equal(5)  # bare hands

	fm.queue_free()


func test_defend_fires_on_encountered_hostile() -> void:
	var fm := FakeFaunaManager.new()
	fm._entries[42] = &"wolf"
	fm._hostile[42] = true
	add_child(fm)

	_sys._fauna_manager = fm
	_catalog._knowledge[&"wolf"] = _Catalog.KnowledgeState.ENCOUNTERED
	_player.current_tile = Vector2i.ZERO

	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	var adj_tile := _make_tile(Vector2i(1, 0))
	_grid._tiles[Vector2i(1, 0)] = adj_tile

	_sys._on_fauna_moved(42, Vector2i(1, 0))

	assert_int(_defend_count).is_equal(1)

	fm.queue_free()


func test_defend_ignores_passive_fauna() -> void:
	var fm := FakeFaunaManager.new()
	fm._entries[10] = &"deer"
	fm._hostile[10] = false  # passive
	add_child(fm)

	_sys._fauna_manager = fm
	_catalog._knowledge[&"deer"] = _Catalog.KnowledgeState.CATALOGED
	_player.current_tile = Vector2i.ZERO

	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	var adj_tile := _make_tile(Vector2i(1, 0))
	_grid._tiles[Vector2i(1, 0)] = adj_tile

	_sys._on_fauna_moved(10, Vector2i(1, 0))

	assert_int(_defend_count).is_equal(0)

	fm.queue_free()


func test_defend_ignores_unknown_fauna() -> void:
	var fm := FakeFaunaManager.new()
	fm._entries[42] = &"wolf"
	fm._hostile[42] = true
	add_child(fm)

	_sys._fauna_manager = fm
	# wolf is UNKNOWN (not in _knowledge)
	_player.current_tile = Vector2i.ZERO

	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	var adj_tile := _make_tile(Vector2i(1, 0))
	_grid._tiles[Vector2i(1, 0)] = adj_tile

	_sys._on_fauna_moved(42, Vector2i(1, 0))

	assert_int(_defend_count).is_equal(0)

	fm.queue_free()


func test_defend_cooldown_blocks_second_attack() -> void:
	var fm := FakeFaunaManager.new()
	fm._entries[42] = &"wolf"
	fm._hostile[42] = true
	add_child(fm)

	_sys._fauna_manager = fm
	_catalog._knowledge[&"wolf"] = _Catalog.KnowledgeState.CATALOGED
	_player.current_tile = Vector2i.ZERO

	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	var adj_tile := _make_tile(Vector2i(1, 0))
	_grid._tiles[Vector2i(1, 0)] = adj_tile

	# First attack fires
	_sys._on_fauna_moved(42, Vector2i(1, 0))
	assert_int(_defend_count).is_equal(1)

	# Second attack immediately — blocked by cooldown
	_sys._on_fauna_moved(42, Vector2i(1, 0))
	assert_int(_defend_count).is_equal(1)

	fm.queue_free()


func test_defend_cooldown_decrements_in_process() -> void:
	_sys._defend_cooldown = 1.0

	_sys._process(0.5)
	assert_float(_sys._defend_cooldown).is_equal_approx(0.5, 0.01)

	_sys._process(0.6)
	# Should be <= 0 now (0.5 - 0.6 = -0.1, then clamped by condition)
	assert_bool(_sys._defend_cooldown <= 0.0).is_true()


func test_defend_with_weapon_uses_weapon_damage() -> void:
	var fm := FakeFaunaManager.new()
	fm._entries[42] = &"wolf"
	fm._hostile[42] = true
	add_child(fm)

	_sys._fauna_manager = fm
	_catalog._knowledge[&"wolf"] = _Catalog.KnowledgeState.CATALOGED
	_inv.set_tool(&"weapon", &"survival_knife")
	_player.current_tile = Vector2i.ZERO

	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	var adj_tile := _make_tile(Vector2i(1, 0))
	_grid._tiles[Vector2i(1, 0)] = adj_tile

	_sys._on_fauna_moved(42, Vector2i(1, 0))

	assert_int(_defend_count).is_equal(1)
	assert_int(_defend_damage).is_equal(10)  # survival_knife = 10

	fm.queue_free()


func test_defend_ignores_distant_fauna() -> void:
	var fm := FakeFaunaManager.new()
	fm._entries[42] = &"wolf"
	fm._hostile[42] = true
	add_child(fm)

	_sys._fauna_manager = fm
	_catalog._knowledge[&"wolf"] = _Catalog.KnowledgeState.CATALOGED
	_player.current_tile = Vector2i.ZERO

	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile
	# Distance 2 tile — outside attack_range of 1
	var far_tile := _make_tile(Vector2i(2, 0))
	_grid._tiles[Vector2i(2, 0)] = far_tile

	_sys._on_fauna_moved(42, Vector2i(2, 0))

	assert_int(_defend_count).is_equal(0)

	fm.queue_free()


func test_no_crash_without_fauna_manager() -> void:
	# _fauna_manager is null by default — should be safe
	_sys._on_fauna_moved(42, Vector2i(1, 0))
	assert_int(_defend_count).is_equal(0)


# ===================================================================
# AUTO-PICKUP STUB TESTS
# ===================================================================

func test_pickup_collects_ground_items() -> void:
	var survival := FakeSurvivalSystem.new()
	survival._ground_items[Vector2i.ZERO] = [
		{"name": &"wood", "amount": 3},
	]
	survival.name = "SurvivalSystem"
	# We need to make it findable via get_node_or_null("/root/SurvivalSystem")
	# Since _try_auto_pickup uses get_node_or_null, we inject by calling directly
	# Instead, we override _try_auto_pickup behavior by calling it through a helper

	# For testability, we'll directly test the pickup logic
	# The function queries SurvivalSystem via get_node_or_null("/root/SurvivalSystem")
	# In test environment, let's add it to the root
	get_tree().root.add_child(survival)

	_player.current_tile = Vector2i.ZERO
	_sys._try_auto_pickup(Vector2i.ZERO)

	assert_int(_pickup_count).is_equal(1)
	assert_str(_pickup_name).is_equal(&"wood")
	assert_int(_pickup_amount).is_equal(3)
	assert_int(_inv.get_count(&"wood")).is_equal(3)

	survival.queue_free()


func test_pickup_multiple_items() -> void:
	var survival := FakeSurvivalSystem.new()
	survival._ground_items[Vector2i.ZERO] = [
		{"name": &"wood", "amount": 2},
		{"name": &"stone", "amount": 1},
	]
	survival.name = "SurvivalSystem"
	get_tree().root.add_child(survival)

	_sys._try_auto_pickup(Vector2i.ZERO)

	assert_int(_pickup_count).is_equal(2)
	assert_int(_inv.get_count(&"wood")).is_equal(2)
	assert_int(_inv.get_count(&"stone")).is_equal(1)

	survival.queue_free()


func test_pickup_no_crash_without_survival_system() -> void:
	# SurvivalSystem not present — should be safe no-op
	_sys._try_auto_pickup(Vector2i.ZERO)
	assert_int(_pickup_count).is_equal(0)


func test_pickup_empty_ground_items() -> void:
	var survival := FakeSurvivalSystem.new()
	survival._ground_items[Vector2i.ZERO] = []
	survival.name = "SurvivalSystem"
	get_tree().root.add_child(survival)

	_sys._try_auto_pickup(Vector2i.ZERO)

	assert_int(_pickup_count).is_equal(0)

	survival.queue_free()


func test_pickup_skips_empty_name() -> void:
	var survival := FakeSurvivalSystem.new()
	survival._ground_items[Vector2i.ZERO] = [
		{"name": &"", "amount": 5},
	]
	survival.name = "SurvivalSystem"
	get_tree().root.add_child(survival)

	_sys._try_auto_pickup(Vector2i.ZERO)

	assert_int(_pickup_count).is_equal(0)

	survival.queue_free()


func test_pickup_emits_ground_item_picked_up() -> void:
	var survival := FakeSurvivalSystem.new()
	survival._ground_items[Vector2i(2, 1)] = [
		{"name": &"berries", "amount": 4},
	]
	survival.name = "SurvivalSystem"
	get_tree().root.add_child(survival)

	_sys._try_auto_pickup(Vector2i(2, 1))

	assert_int(_pickup_count).is_equal(1)
	assert_str(_pickup_name).is_equal(&"berries")
	assert_int(_pickup_amount).is_equal(4)

	survival.queue_free()


func test_pickup_called_on_tile_entered() -> void:
	# Verify _on_tile_entered calls _try_auto_pickup
	var survival := FakeSurvivalSystem.new()
	survival._ground_items[Vector2i.ZERO] = [
		{"name": &"fiber", "amount": 1},
	]
	survival.name = "SurvivalSystem"
	get_tree().root.add_child(survival)

	_player.current_tile = Vector2i.ZERO
	var tile := _make_tile(Vector2i.ZERO)
	_grid._tiles[Vector2i.ZERO] = tile

	_grid.tile_entered.emit(Vector2i.ZERO)

	assert_int(_pickup_count).is_equal(1)
	assert_str(_pickup_name).is_equal(&"fiber")

	survival.queue_free()
