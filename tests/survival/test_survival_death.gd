extends GdUnitTestSuite
class_name TestSurvivalDeath

## Tests for death, respawn, ground items, save/load — task-029.

const _SurvivalSystem = preload("res://scripts/survival/survival_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")

var _sys: _SurvivalSystem
var _inv: _Inventory
var _dnc: MockDayNightCycle
var _grid: MockHexGrid


# --- Mock DayNightCycle ---

class MockDayNightCycle extends Node:
	signal dawn()
	var is_daytime: bool = true

	func skip_to_dawn() -> void:
		is_daytime = true


# --- Mock HexTile ---

class MockHexTile extends Resource:
	var coords: Vector2i = Vector2i.ZERO
	var biome: int = 1  # GRASSLAND
	var elevation: int = 0


# --- Mock HexGrid ---

class MockHexGrid extends Node:
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	var _tiles: Dictionary = {}

	func add_tile(coords: Vector2i, biome: int = 1) -> void:
		var tile: MockHexTile = MockHexTile.new()
		tile.coords = coords
		tile.biome = biome
		_tiles[coords] = tile

	func get_tile(coords: Vector2i) -> Resource:
		return _tiles.get(coords, null)

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		var offsets: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, -1), Vector2i(-1, 1),
		]
		var result: Array[Vector2i] = []
		for o: Vector2i in offsets:
			var n: Vector2i = coords + o
			if _tiles.has(n):
				result.append(n)
		return result


# --- Mock Player ---

class MockPlayer extends Node:
	var _inventory: RefCounted
	var current_tile: Vector2i = Vector2i.ZERO

	func _init(inv: RefCounted) -> void:
		_inventory = inv

	func get_inventory() -> RefCounted:
		return _inventory

	func _snap_to_tile(coords: Vector2i) -> void:
		current_tile = coords


# --- Setup / Teardown ---

func before_test() -> void:
	_inv = _Inventory.new()
	_dnc = MockDayNightCycle.new()
	_grid = MockHexGrid.new()
	add_child(_dnc)
	add_child(_grid)

	# Set up some tiles around origin
	_grid.add_tile(Vector2i(0, 0))
	_grid.add_tile(Vector2i(1, 0))
	_grid.add_tile(Vector2i(-1, 0))
	_grid.add_tile(Vector2i(0, 1))
	_grid.add_tile(Vector2i(0, -1))

	var player: MockPlayer = MockPlayer.new(_inv)
	add_child(player)

	_sys = _SurvivalSystem.new()
	_sys._day_night_cycle = _dnc
	_sys._hex_grid = _grid
	_sys._screen_fade = null  # No fade in tests
	player.add_child(_sys)


func after_test() -> void:
	var player: Node = _sys.get_parent()
	player.remove_child(_sys)
	_sys.queue_free()
	remove_child(player)
	player.queue_free()
	remove_child(_dnc)
	_dnc.queue_free()
	remove_child(_grid)
	_grid.queue_free()
	_inv = null
	_sys = null
	_dnc = null
	_grid = null


# --- Drop calculation (100% drop on death) ---

func test_drop_100_percent_of_10() -> void:
	_inv.add_item(&"berries", 10)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	# 10 berries → drop all 10, keep 0
	assert_int(_inv.get_count(&"berries")).is_equal(0)


func test_drop_100_percent_of_7() -> void:
	_inv.add_item(&"berries", 7)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	# 7 berries → drop all 7, keep 0
	assert_int(_inv.get_count(&"berries")).is_equal(0)


func test_drop_100_percent_of_1() -> void:
	_inv.add_item(&"berries", 1)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	# 1 berry → drop 1, keep 0
	assert_int(_inv.get_count(&"berries")).is_equal(0)


func test_tools_are_not_dropped() -> void:
	# stone_axe and stone_pickaxe are tools — set them directly
	_inv.set_tool(&"axe", &"stone_axe")
	_inv.set_tool(&"pickaxe", &"stone_pickaxe")
	# Add some berries too
	_inv.add_item(&"berries", 10)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	# Tools still equipped
	assert_str(_inv.get_tool(&"axe")).is_equal(&"stone_axe")
	assert_str(_inv.get_tool(&"pickaxe")).is_equal(&"stone_pickaxe")


func test_dropped_items_appear_on_ground() -> void:
	_inv.add_item(&"berries", 10)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	var all_items: Array[Dictionary] = _sys.get_all_ground_items()
	assert_int(all_items.size()).is_greater(0)
	var total_ground: int = 0
	for entry: Dictionary in all_items:
		if entry["item_type"] == &"berries":
			total_ground += entry["count"]
	assert_int(total_ground).is_equal(10)


func test_dropped_items_at_death_tile() -> void:
	_inv.add_item(&"berries", 10)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	var all_items: Array[Dictionary] = _sys.get_all_ground_items()
	# All items drop at death tile (0,0)
	for entry: Dictionary in all_items:
		assert_object(entry["tile"]).is_equal(Vector2i(0, 0))


func test_player_died_signal_emits() -> void:
	var fired: Array = []
	_sys.player_died.connect(func() -> void:
		fired.append(true)
	)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	assert_int(fired.size()).is_equal(1)


func test_ground_item_dropped_signal_emits() -> void:
	var fired: Array = []
	_sys.ground_item_dropped.connect(func(tile: Vector2i, item_type: StringName, count: int, sub_hex: Vector2i) -> void:
		fired.append({"tile": tile, "item_type": item_type, "count": count, "sub_hex": sub_hex})
	)
	_inv.add_item(&"berries", 10)
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	assert_int(fired.size()).is_greater(0)
	assert_int(fired[0]["count"]).is_equal(10)


# --- Respawn stats ---

func test_respawn_sets_hp_to_max() -> void:
	_sys.hp = 0.0
	_sys.is_dead = true
	_sys.respawn()
	assert_float(_sys.hp).is_equal(100.0)


func test_respawn_sets_hunger_to_50_percent() -> void:
	_sys.hp = 0.0
	_sys.is_dead = true
	_sys.respawn()
	assert_float(_sys.hunger).is_equal(50.0)


func test_respawn_sets_thirst_to_50_percent() -> void:
	_sys.hp = 0.0
	_sys.is_dead = true
	_sys.respawn()
	assert_float(_sys.thirst).is_equal(50.0)


func test_respawn_clears_is_dead() -> void:
	_sys.hp = 0.0
	_sys.is_dead = true
	_sys.respawn()
	assert_bool(_sys.is_dead).is_false()


func test_respawn_emits_player_respawned() -> void:
	var fired: Array = []
	_sys.player_respawned.connect(func() -> void:
		fired.append(true)
	)
	_sys.hp = 0.0
	_sys.is_dead = true
	_sys.respawn()
	assert_int(fired.size()).is_equal(1)


func test_respawn_teleports_to_respawn_tile() -> void:
	_sys._respawn_tile = Vector2i(3, 4)
	_sys.hp = 0.0
	_sys.is_dead = true
	_sys.respawn()
	var player: MockPlayer = _sys.get_parent() as MockPlayer
	assert_object(player.current_tile).is_equal(Vector2i(3, 4))


# --- Respawn tile updates on shelter ---

func test_shelter_placed_updates_respawn_tile() -> void:
	assert_object(_sys._respawn_tile).is_equal(Vector2i.ZERO)
	_grid.structure_placed.emit(Vector2i(2, 3), &"00102")
	assert_object(_sys._respawn_tile).is_equal(Vector2i(2, 3))


func test_shelter_destroyed_resets_respawn_tile() -> void:
	_grid.structure_placed.emit(Vector2i(2, 3), &"00102")
	_grid.structure_destroyed.emit(Vector2i(2, 3), &"00102")
	assert_object(_sys._respawn_tile).is_equal(Vector2i.ZERO)


func test_non_shelter_structure_does_not_update_respawn() -> void:
	_grid.structure_placed.emit(Vector2i(2, 3), &"00103")
	assert_object(_sys._respawn_tile).is_equal(Vector2i.ZERO)


func test_destroy_different_shelter_does_not_reset() -> void:
	_grid.structure_placed.emit(Vector2i(2, 3), &"00102")
	_grid.structure_destroyed.emit(Vector2i(5, 5), &"00102")
	# Different coords — should keep the original
	assert_object(_sys._respawn_tile).is_equal(Vector2i(2, 3))


# --- Night death deferred to dawn ---

func test_night_death_skips_to_dawn_and_respawns() -> void:
	_dnc.is_daytime = false
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	# New behavior: skip_to_dawn called, then immediate respawn
	assert_bool(_dnc.is_daytime).is_true()
	assert_bool(_sys.is_dead).is_false()
	assert_float(_sys.hp).is_equal(100.0)


func test_day_death_respawns_immediately() -> void:
	_dnc.is_daytime = true
	_sys.hp = 1.0
	_sys.take_damage(10.0)
	# Daytime death: immediate respawn, no skip_to_dawn needed
	assert_bool(_sys.is_dead).is_false()
	assert_float(_sys.hp).is_equal(100.0)


func test_dawn_without_waiting_does_nothing() -> void:
	_sys.hp = 50.0
	_dnc.dawn.emit()
	# Should not respawn — no death happened
	assert_float(_sys.hp).is_equal(50.0)


# --- Ground items CRUD ---

func test_add_ground_item() -> void:
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 5)
	var items: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(1)
	assert_int(items[0]["count"]).is_equal(5)


func test_add_ground_item_merges_same_tile_and_type() -> void:
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 3)
	var items: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(1)
	assert_int(items[0]["count"]).is_equal(8)


func test_add_ground_item_different_types_separate() -> void:
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_sys.add_ground_item(Vector2i(1, 0), &"meat", 3)
	var items: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(2)


func test_remove_ground_item() -> void:
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 5)
	var removed: int = _sys.remove_ground_item(Vector2i(1, 0), &"berries", 3)
	assert_int(removed).is_equal(3)
	var items: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(1, 0))
	assert_int(items[0]["count"]).is_equal(2)


func test_remove_ground_item_removes_entry_when_zero() -> void:
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_sys.remove_ground_item(Vector2i(1, 0), &"berries", 5)
	var items: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(0)


func test_remove_ground_item_returns_zero_for_missing() -> void:
	var removed: int = _sys.remove_ground_item(Vector2i(9, 9), &"berries", 1)
	assert_int(removed).is_equal(0)


func test_remove_ground_item_emits_picked_up_signal() -> void:
	var fired: Array = []
	_sys.ground_item_picked_up.connect(func(tile: Vector2i, item_type: StringName, count: int) -> void:
		fired.append({"tile": tile, "item_type": item_type, "count": count})
	)
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_sys.remove_ground_item(Vector2i(1, 0), &"berries", 3)
	assert_int(fired.size()).is_equal(1)
	assert_int(fired[0]["count"]).is_equal(3)


func test_get_ground_items_at_empty_tile() -> void:
	var items: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(99, 99))
	assert_int(items.size()).is_equal(0)


# --- Save / Load round-trip ---

func test_save_load_preserves_hp() -> void:
	_sys.hp = 42.5
	var data: Dictionary = _sys.get_save_data()
	_sys.hp = 100.0
	_sys.load_save_data(data)
	assert_float(_sys.hp).is_equal_approx(42.5, 0.001)


func test_save_load_preserves_hunger() -> void:
	_sys.hunger = 33.0
	var data: Dictionary = _sys.get_save_data()
	_sys.hunger = 100.0
	_sys.load_save_data(data)
	assert_float(_sys.hunger).is_equal_approx(33.0, 0.001)


func test_save_load_preserves_thirst() -> void:
	_sys.thirst = 77.0
	var data: Dictionary = _sys.get_save_data()
	_sys.thirst = 100.0
	_sys.load_save_data(data)
	assert_float(_sys.thirst).is_equal_approx(77.0, 0.001)


func test_save_load_is_dead_always_false() -> void:
	_sys.hp = 0.0
	_sys.is_dead = true
	var data: Dictionary = _sys.get_save_data()
	_sys.load_save_data(data)
	assert_bool(_sys.is_dead).is_false()


func test_save_load_preserves_respawn_tile() -> void:
	_sys._respawn_tile = Vector2i(5, 7)
	var data: Dictionary = _sys.get_save_data()
	_sys._respawn_tile = Vector2i.ZERO
	_sys.load_save_data(data)
	assert_object(_sys._respawn_tile).is_equal(Vector2i(5, 7))


func test_save_load_preserves_ground_items() -> void:
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_sys.add_ground_item(Vector2i(2, 0), &"meat", 3)
	var data: Dictionary = _sys.get_save_data()
	# Clear and reload
	_sys.load_save_data(data)
	var berries: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(1, 0))
	assert_int(berries.size()).is_equal(1)
	assert_int(berries[0]["count"]).is_equal(5)
	var meat: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(2, 0))
	assert_int(meat.size()).is_equal(1)
	assert_int(meat[0]["count"]).is_equal(3)


func test_save_load_clears_previous_ground_items() -> void:
	_sys.add_ground_item(Vector2i(1, 0), &"berries", 10)
	var data: Dictionary = _sys.get_save_data()
	_sys.add_ground_item(Vector2i(3, 3), &"meat", 99)
	_sys.load_save_data(data)
	# The extra meat added after save should be gone
	var meat: Array[Dictionary] = _sys.get_ground_items_at(Vector2i(3, 3))
	assert_int(meat.size()).is_equal(0)
