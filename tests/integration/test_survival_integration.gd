extends GdUnitTestSuite
class_name TestSurvivalIntegration

## Integration tests for delivery-004: Full Survival Lifecycle.
## Tests stat depletion, HP drain, consumption, death/respawn,
## ground item lifecycle, save/load round-trip, ScreenFade wiring,
## stat bar signal propagation, and night-death deferral.
##
## Time simulation: directly call _process(delta) with large deltas
## to force stat changes without waiting real-time.
##
## Manual-only verification (not automatable — documented here):
##   - ScreenFade tween transitions are visually smooth
##   - Stat bar colors change correctly at thresholds
##   - Ground item MultiMesh markers appear at correct world positions

const _SurvivalSystem = preload("res://scripts/survival/survival_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _ScreenFade = preload("res://ui/screen_fade.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")


# --- Mock classes ---

class MockDayNightCycle extends Node:
	signal dawn()
	signal day_started()
	signal phase_changed(old_phase: int, new_phase: int)
	var is_daytime: bool = true
	var current_phase: int = 0  # DAY

	func skip_to_dawn() -> void:
		is_daytime = true


class MockHexGrid extends Node:
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)
	signal tile_entered(coords: Vector2i)

	var _mock_tiles: Dictionary = {}  # Vector2i → MockHexTile
	var _mock_neighbors: Dictionary = {}  # Vector2i → Array[Vector2i]

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		if _mock_neighbors.has(coords):
			return _mock_neighbors[coords]
		return [] as Array[Vector2i]

	func get_tile(coords: Vector2i) -> Resource:
		return _mock_tiles.get(coords)


class MockPlayer extends Node:
	var current_tile: Vector2i = Vector2i.ZERO
	var _inventory: RefCounted
	var _snapped_to: Vector2i = Vector2i.ZERO

	func get_inventory() -> RefCounted:
		return _inventory

	func _snap_to_tile(coords: Vector2i) -> void:
		current_tile = coords
		_snapped_to = coords


# --- Test state ---

var _ss: Node  # SurvivalSystem
var _player: MockPlayer
var _dnc: MockDayNightCycle
var _grid: MockHexGrid
var _inv: RefCounted  # Inventory


func before_test() -> void:
	_dnc = MockDayNightCycle.new()
	add_child(_dnc)

	_grid = MockHexGrid.new()
	add_child(_grid)

	_inv = _Inventory.new()

	_player = MockPlayer.new()
	_player._inventory = _inv
	add_child(_player)

	_ss = _SurvivalSystem.new()
	_ss._day_night_cycle = _dnc
	_ss._hex_grid = _grid
	_player.add_child(_ss)

	# Build mock neighbors around origin for item dropping
	_setup_mock_grid()


func after_test() -> void:
	_player.queue_free()
	_grid.queue_free()
	_dnc.queue_free()


func _setup_mock_grid() -> void:
	# Origin + 6 neighbors, all GRASSLAND (biome 1)
	var tiles: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
	]
	for coords in tiles:
		var tile := _HexTile.new()
		tile.coords = coords
		tile.biome = _HexTile.Biome.GRASSLAND
		tile.elevation = 0
		_grid._mock_tiles[coords] = tile

	# Neighbors of origin
	_grid._mock_neighbors[Vector2i.ZERO] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
	] as Array[Vector2i]


func _simulate(delta: float) -> void:
	_ss._process(delta)


# ===========================================================================
# Stat depletion over time
# ===========================================================================

func test_hunger_depletes_at_configured_rate() -> void:
	var rate: float = _SurvivalSystem.STAT_CONFIG["hunger_rate"]
	assert_float(rate).is_equal(0.4)
	_simulate(10.0)
	# hunger = 100 - 0.4 * 10 = 96
	assert_float(_ss.hunger).is_equal_approx(96.0, 0.01)


func test_thirst_depletes_at_configured_rate() -> void:
	var rate: float = _SurvivalSystem.STAT_CONFIG["thirst_rate"]
	assert_float(rate).is_equal(0.8)
	_simulate(10.0)
	# thirst = 100 - 0.8 * 10 = 92
	assert_float(_ss.thirst).is_equal_approx(92.0, 0.01)


func test_hunger_and_thirst_deplete_simultaneously() -> void:
	_simulate(50.0)
	assert_float(_ss.hunger).is_equal_approx(80.0, 0.01)
	assert_float(_ss.thirst).is_equal_approx(60.0, 0.01)


func test_stats_clamp_at_zero() -> void:
	_simulate(300.0)  # Way past depletion
	assert_float(_ss.hunger).is_equal(0.0)
	assert_float(_ss.thirst).is_equal(0.0)


# ===========================================================================
# HP drain when starving / dehydrated
# ===========================================================================

func test_hp_drain_when_hunger_zero() -> void:
	_ss.hunger = 0.0
	_ss.thirst = 100.0
	_dnc.is_daytime = false  # No regen
	_simulate(10.0)
	# HP drain: 0.1/s for 10s = 1.0. HP = 100 - 1.0 = 99
	# thirst also depletes but doesn't hit 0
	assert_float(_ss.hp).is_equal_approx(99.0, 0.1)


func test_hp_drain_when_thirst_zero() -> void:
	_ss.thirst = 0.0
	_ss.hunger = 100.0
	_dnc.is_daytime = false
	_simulate(10.0)
	# HP drain: 0.2/s for 10s = 2.0. HP = 100 - 2.0 = 98
	assert_float(_ss.hp).is_equal_approx(98.0, 0.1)


func test_hp_drain_both_zero_stacks() -> void:
	_ss.hunger = 0.0
	_ss.thirst = 0.0
	_dnc.is_daytime = false
	_simulate(10.0)
	# HP drain: (0.1 + 0.2) = 0.3/s for 10s = 3.0. HP = 100 - 3.0 = 97
	assert_float(_ss.hp).is_equal_approx(97.0, 0.1)


# ===========================================================================
# HP regen during daytime when fed
# ===========================================================================

func test_hp_regen_during_day_when_fed() -> void:
	_ss.hp = 50.0
	_ss.hunger = 50.0
	_ss.thirst = 50.0
	_dnc.is_daytime = true
	_simulate(10.0)
	# Regen: 0.5/s for 10s = 5.0. HP = 50 + 5 = 55
	# hunger depletes by 4, thirst by 8 (still > 0)
	assert_float(_ss.hp).is_equal_approx(55.0, 0.1)


func test_no_regen_at_night() -> void:
	_ss.hp = 50.0
	_ss.hunger = 100.0
	_ss.thirst = 100.0
	_dnc.is_daytime = false
	_simulate(10.0)
	# No drain (hunger/thirst > 0), no regen (night). HP stays 50
	assert_float(_ss.hp).is_equal_approx(50.0, 0.1)


func test_no_regen_when_starving() -> void:
	_ss.hp = 50.0
	_ss.hunger = 0.0
	_ss.thirst = 50.0
	_dnc.is_daytime = true
	# Hunger is 0 → no regen, plus HP drain
	_simulate(5.0)
	# HP drain 0.1/s * 5 = 0.5. HP = 50 - 0.5 = 49.5
	assert_float(_ss.hp).is_less(50.0)


func test_hp_clamps_at_max() -> void:
	_ss.hp = 99.0
	_ss.hunger = 100.0
	_ss.thirst = 100.0
	_dnc.is_daytime = true
	_simulate(20.0)
	assert_float(_ss.hp).is_equal(100.0)


# ===========================================================================
# Consume items
# ===========================================================================

func test_consume_berries_restores_hunger_and_thirst() -> void:
	_ss.hunger = 50.0
	_ss.thirst = 50.0
	_ss.consume(&"berries")
	assert_float(_ss.hunger).is_equal(55.0)  # +5
	assert_float(_ss.thirst).is_equal(60.0)  # +10


func test_consume_toxic_berries_restores_hunger_damages_hp() -> void:
	_ss.hunger = 50.0
	_ss.hp = 100.0
	_ss.consume(&"toxic_berries")
	assert_float(_ss.hunger).is_equal(60.0)  # +10
	assert_float(_ss.hp).is_equal(75.0)  # -25 toxic


func test_consume_meat_restores_hunger() -> void:
	_ss.hunger = 50.0
	_ss.consume(&"meat")
	assert_float(_ss.hunger).is_equal(75.0)  # +25


func test_consume_clamps_at_max() -> void:
	_ss.hunger = 95.0
	_ss.thirst = 98.0
	_ss.consume(&"berries")
	assert_float(_ss.hunger).is_equal(100.0)
	assert_float(_ss.thirst).is_equal(100.0)


func test_consume_unknown_item_does_nothing() -> void:
	var prev_hp: float = _ss.hp
	var prev_hunger: float = _ss.hunger
	_ss.consume(&"unknown_thing")
	assert_float(_ss.hp).is_equal(prev_hp)
	assert_float(_ss.hunger).is_equal(prev_hunger)


func test_toxic_berries_can_kill() -> void:
	var died: Array = []
	_ss.player_died.connect(func() -> void: died.append(true))
	_ss.hp = 20.0
	_ss.consume(&"toxic_berries")
	# Death triggers then auto-respawn restores stats
	assert_int(died.size()).is_equal(1)
	assert_float(_ss.hp).is_equal(100.0)
	assert_bool(_ss.is_dead).is_false()


# ===========================================================================
# Inventory item_used signal → consume integration
# ===========================================================================

func test_inventory_use_item_triggers_consume() -> void:
	_ss.hunger = 50.0
	_ss.thirst = 50.0
	# add_item needs ResourceRegistry for berries — use item_used signal directly
	_inv.item_used.emit(&"berries")
	assert_float(_ss.hunger).is_equal(55.0)
	assert_float(_ss.thirst).is_equal(60.0)


# ===========================================================================
# Death + respawn
# ===========================================================================

func test_death_at_hp_zero() -> void:
	var died: Array = []
	var respawned: Array = []
	_ss.player_died.connect(func() -> void: died.append(true))
	_ss.player_respawned.connect(func() -> void: respawned.append(true))
	_ss.take_damage(100.0)
	# Death fires then auto-respawn
	assert_int(died.size()).is_equal(1)
	assert_int(respawned.size()).is_equal(1)
	assert_bool(_ss.is_dead).is_false()
	assert_float(_ss.hp).is_equal(100.0)


func test_death_stops_stat_ticking() -> void:
	# Manually set is_dead to verify the gate works
	_ss.is_dead = true
	_ss.hp = 50.0
	_ss.hunger = 50.0
	_simulate(10.0)
	# Stats should NOT change while dead
	assert_float(_ss.hp).is_equal(50.0)
	assert_float(_ss.hunger).is_equal(50.0)


func test_respawn_restores_stats() -> void:
	_ss.take_damage(100.0)
	# Auto-respawn fires immediately
	assert_float(_ss.hp).is_equal(100.0)
	assert_float(_ss.hunger).is_equal(50.0)
	assert_float(_ss.thirst).is_equal(50.0)
	assert_bool(_ss.is_dead).is_false()


func test_respawn_emits_signal() -> void:
	var respawned: Array = []
	_ss.player_respawned.connect(func() -> void: respawned.append(true))
	_ss.take_damage(100.0)
	# Auto-respawn fires the signal immediately
	assert_int(respawned.size()).is_equal(1)


func test_respawn_teleports_to_respawn_tile() -> void:
	_ss._respawn_tile = Vector2i(5, 3)
	_ss.take_damage(100.0)
	# Auto-respawn teleports to respawn tile
	assert_object(_player._snapped_to).is_equal(Vector2i(5, 3))


func test_shelter_updates_respawn_tile() -> void:
	_grid.structure_placed.emit(Vector2i(4, 2), &"shelter")
	assert_object(_ss._respawn_tile).is_equal(Vector2i(4, 2))


func test_shelter_destroy_resets_respawn_tile() -> void:
	_grid.structure_placed.emit(Vector2i(4, 2), &"shelter")
	_grid.structure_destroyed.emit(Vector2i(4, 2), &"shelter")
	assert_object(_ss._respawn_tile).is_equal(Vector2i.ZERO)


# ===========================================================================
# Item dropping on death (100% each stack, tools safe)
# ===========================================================================

func test_death_drops_100_percent_of_stacks() -> void:
	# Manually set up inventory slots with berries
	# Use item_used to bypass ResourceRegistry, but for drop testing
	# we need actual slots. Directly manipulate _inv._slots.
	_inv._slots[0] = {"type": &"berries", "quantity": 10}
	_inv._slots[1] = {"type": &"meat", "quantity": 6}

	var dropped: Array = []
	_ss.ground_item_dropped.connect(
		func(tile: Vector2i, item_type: StringName, count: int, _sub_hex: Vector2i) -> void:
			dropped.append({"tile": tile, "type": item_type, "count": count})
	)

	_ss.take_damage(100.0)

	# berries: 10 dropped, meat: 6 dropped
	assert_int(dropped.size()).is_equal(2)
	var berry_drop: Dictionary = dropped[0]
	var meat_drop: Dictionary = dropped[1]
	assert_int(berry_drop["count"]).is_equal(10)
	assert_int(meat_drop["count"]).is_equal(6)


func test_death_does_not_drop_tools() -> void:
	_inv._slots[0] = {"type": &"berries", "quantity": 10}
	# Set a tool in a regular slot — shouldn't happen normally, but verify safety
	_inv.set_tool(&"axe", &"stone_axe")

	var dropped: Array = []
	_ss.ground_item_dropped.connect(
		func(_tile: Vector2i, item_type: StringName, _count: int, _sub_hex: Vector2i) -> void:
			dropped.append(item_type)
	)

	_ss.take_damage(100.0)

	# Only berries should drop, no tools
	for d: Variant in dropped:
		var item: StringName = d
		assert_bool(item in _SurvivalSystem.TOOL_TYPES).is_false()


func test_death_drops_all_items() -> void:
	_inv._slots[0] = {"type": &"berries", "quantity": 7}

	var dropped: Array = []
	_ss.ground_item_dropped.connect(
		func(_tile: Vector2i, _item_type: StringName, count: int, _sub_hex: Vector2i) -> void:
			dropped.append(count)
	)

	_ss.take_damage(100.0)
	# 100% drop: all 7
	assert_int(dropped[0]).is_equal(7)


func test_death_single_item_drops_one() -> void:
	_inv._slots[0] = {"type": &"berries", "quantity": 1}

	var dropped: Array = []
	_ss.ground_item_dropped.connect(
		func(_tile: Vector2i, _item_type: StringName, count: int, _sub_hex: Vector2i) -> void:
			dropped.append(count)
	)

	_ss.take_damage(100.0)
	# 100% drop: 1 item dropped
	assert_int(dropped.size()).is_equal(1)
	assert_int(dropped[0]).is_equal(1)


# ===========================================================================
# Night death deferred to dawn
# ===========================================================================

func test_night_death_skips_to_dawn_and_respawns() -> void:
	_dnc.is_daytime = false
	_ss.take_damage(100.0)
	# New behavior: skip_to_dawn called, then immediate respawn
	assert_bool(_dnc.is_daytime).is_true()
	assert_bool(_ss.is_dead).is_false()
	assert_float(_ss.hp).is_equal(100.0)


func test_day_death_respawns_immediately() -> void:
	_dnc.is_daytime = true
	_ss.take_damage(100.0)
	# Daytime death: immediate respawn, no skip_to_dawn needed
	assert_bool(_ss.is_dead).is_false()
	assert_float(_ss.hp).is_equal(100.0)
	assert_bool(_dnc.is_daytime).is_true()


# ===========================================================================
# Ground item lifecycle
# ===========================================================================

func test_add_ground_item() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 5)
	var items: Array[Dictionary] = _ss.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(1)
	assert_int(items[0]["count"]).is_equal(5)


func test_add_ground_item_merges_same_tile_and_type() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 3)
	var items: Array[Dictionary] = _ss.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(1)
	assert_int(items[0]["count"]).is_equal(8)


func test_add_different_types_separate_entries() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_ss.add_ground_item(Vector2i(1, 0), &"meat", 3)
	var items: Array[Dictionary] = _ss.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(2)


func test_remove_ground_item_returns_count() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 10)
	var removed: int = _ss.remove_ground_item(Vector2i(1, 0), &"berries", 4)
	assert_int(removed).is_equal(4)
	var items: Array[Dictionary] = _ss.get_ground_items_at(Vector2i(1, 0))
	assert_int(items[0]["count"]).is_equal(6)


func test_remove_ground_item_full_removal() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 5)
	var removed: int = _ss.remove_ground_item(Vector2i(1, 0), &"berries", 5)
	assert_int(removed).is_equal(5)
	var items: Array[Dictionary] = _ss.get_ground_items_at(Vector2i(1, 0))
	assert_int(items.size()).is_equal(0)


func test_remove_ground_item_over_count() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 3)
	var removed: int = _ss.remove_ground_item(Vector2i(1, 0), &"berries", 10)
	assert_int(removed).is_equal(3)  # Only removes what exists


func test_remove_ground_item_emits_signal() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 5)
	var picked: Array = []
	_ss.ground_item_picked_up.connect(
		func(tile: Vector2i, item_type: StringName, count: int) -> void:
			picked.append({"tile": tile, "type": item_type, "count": count})
	)
	_ss.remove_ground_item(Vector2i(1, 0), &"berries", 3)
	assert_int(picked.size()).is_equal(1)
	assert_int(picked[0]["count"]).is_equal(3)


func test_remove_nonexistent_returns_zero() -> void:
	var removed: int = _ss.remove_ground_item(Vector2i(9, 9), &"berries", 5)
	assert_int(removed).is_equal(0)


func test_get_all_ground_items() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_ss.add_ground_item(Vector2i(2, 0), &"meat", 3)
	var all_items: Array[Dictionary] = _ss.get_all_ground_items()
	assert_int(all_items.size()).is_equal(2)


func test_death_creates_ground_items() -> void:
	_inv._slots[0] = {"type": &"berries", "quantity": 10}
	_ss.take_damage(100.0)
	# Items should now exist on the ground at death tile
	var all_items: Array[Dictionary] = _ss.get_all_ground_items()
	assert_int(all_items.size()).is_greater(0)
	assert_str(all_items[0]["item_type"]).is_equal("berries")
	assert_int(all_items[0]["count"]).is_equal(10)


# ===========================================================================
# Save/load round-trip for survival data
# ===========================================================================

func test_save_data_structure() -> void:
	var data: Dictionary = _ss.get_save_data()
	assert_bool(data.has("hp")).is_true()
	assert_bool(data.has("hunger")).is_true()
	assert_bool(data.has("thirst")).is_true()
	assert_bool(data.has("respawn_tile_col")).is_true()
	assert_bool(data.has("respawn_tile_row")).is_true()
	assert_bool(data.has("ground_items")).is_true()


func test_save_load_preserves_stats() -> void:
	_ss.hp = 75.0
	_ss.hunger = 40.0
	_ss.thirst = 30.0
	var data: Dictionary = _ss.get_save_data()

	# Create fresh system and load
	var ss2: Node = _SurvivalSystem.new()
	ss2.load_save_data(data)
	assert_float(ss2.hp).is_equal(75.0)
	assert_float(ss2.hunger).is_equal(40.0)
	assert_float(ss2.thirst).is_equal(30.0)
	assert_bool(ss2.is_dead).is_false()  # Never saved as dead
	ss2.free()


func test_save_load_preserves_respawn_tile() -> void:
	_ss._respawn_tile = Vector2i(7, 3)
	var data: Dictionary = _ss.get_save_data()

	var ss2: Node = _SurvivalSystem.new()
	ss2.load_save_data(data)
	assert_object(ss2._respawn_tile).is_equal(Vector2i(7, 3))
	ss2.free()


func test_save_load_preserves_ground_items() -> void:
	_ss.add_ground_item(Vector2i(1, 0), &"berries", 5)
	_ss.add_ground_item(Vector2i(2, 1), &"meat", 3)
	var data: Dictionary = _ss.get_save_data()

	var ss2: Node = _SurvivalSystem.new()
	ss2.load_save_data(data)
	var items: Array[Dictionary] = ss2.get_all_ground_items()
	assert_int(items.size()).is_equal(2)

	# Verify first item
	assert_object(items[0]["tile"]).is_equal(Vector2i(1, 0))
	assert_str(items[0]["item_type"]).is_equal("berries")
	assert_int(items[0]["count"]).is_equal(5)

	# Verify second item
	assert_object(items[1]["tile"]).is_equal(Vector2i(2, 1))
	assert_str(items[1]["item_type"]).is_equal("meat")
	assert_int(items[1]["count"]).is_equal(3)
	ss2.free()


func test_save_load_round_trip_after_depletion() -> void:
	_simulate(60.0)  # Deplete some stats
	var data: Dictionary = _ss.get_save_data()

	var ss2: Node = _SurvivalSystem.new()
	ss2.load_save_data(data)
	assert_float(ss2.hp).is_equal_approx(_ss.hp, 0.01)
	assert_float(ss2.hunger).is_equal_approx(_ss.hunger, 0.01)
	assert_float(ss2.thirst).is_equal_approx(_ss.thirst, 0.01)
	ss2.free()


func test_load_clears_dead_state() -> void:
	# Manually set dead state to test that load clears it
	_ss.is_dead = true
	_ss._waiting_for_dawn = true
	var data: Dictionary = {"hp": 80.0, "hunger": 60.0, "thirst": 50.0}
	_ss.load_save_data(data)
	assert_bool(_ss.is_dead).is_false()
	assert_bool(_ss._waiting_for_dawn).is_false()
	assert_float(_ss.hp).is_equal(80.0)


# ===========================================================================
# Stat signals (stat_changed emission verified)
# ===========================================================================

func test_stat_changed_emits_for_all_three_stats() -> void:
	var emitted: Dictionary = {}
	_ss.stat_changed.connect(
		func(stat_name: StringName, current: float, max_val: float) -> void:
			emitted[stat_name] = {"current": current, "max": max_val}
	)
	_simulate(1.0)
	assert_bool(emitted.has(&"hp")).override_failure_message("hp signal missing").is_true()
	assert_bool(emitted.has(&"hunger")).override_failure_message("hunger signal missing").is_true()
	assert_bool(emitted.has(&"thirst")).override_failure_message("thirst signal missing").is_true()


func test_stat_changed_values_match_current_state() -> void:
	_simulate(10.0)
	var last_values: Dictionary = {}
	_ss.stat_changed.connect(
		func(stat_name: StringName, current: float, _max_val: float) -> void:
			last_values[stat_name] = current
	)
	_simulate(1.0)  # One more tick to capture signals
	# After 11s total: hunger = 100 - 0.4*11 = 95.6, thirst = 100 - 0.8*11 = 91.2
	assert_float(last_values.get(&"hunger", 0.0)).is_equal_approx(95.6, 0.1)
	assert_float(last_values.get(&"thirst", 0.0)).is_equal_approx(91.2, 0.1)


func test_take_damage_emits_hp_stat_changed() -> void:
	var hp_values: Array = []
	_ss.stat_changed.connect(
		func(stat_name: StringName, current: float, _max_val: float) -> void:
			if stat_name == &"hp":
				hp_values.append(current)
	)
	_ss.take_damage(30.0)
	assert_int(hp_values.size()).is_greater(0)
	assert_float(hp_values[-1]).is_equal(70.0)


# ===========================================================================
# ScreenFade integration (using real ScreenFade node)
# ===========================================================================

func test_screen_fade_fade_out_emits_signal() -> void:
	var sf: CanvasLayer = _ScreenFade.new()
	add_child(sf)
	var completed: Array = []
	sf.fade_out_completed.connect(func() -> void: completed.append(true))
	sf.fade_out(0.01)  # Very short duration for test
	# Wait for tween to complete
	await get_tree().create_timer(0.1).timeout
	assert_int(completed.size()).is_equal(1)
	sf.queue_free()


func test_screen_fade_fade_in_emits_signal() -> void:
	var sf: CanvasLayer = _ScreenFade.new()
	add_child(sf)
	var completed: Array = []
	sf.fade_in_completed.connect(func() -> void: completed.append(true))
	sf.fade_in(0.01)
	await get_tree().create_timer(0.1).timeout
	assert_int(completed.size()).is_equal(1)
	sf.queue_free()


func test_screen_fade_flash_sets_color() -> void:
	var sf: CanvasLayer = _ScreenFade.new()
	add_child(sf)
	sf.flash(Color.RED, 0.01)
	# Flash uses the specified color's RGB channels
	assert_float(sf._color_rect.color.r).is_equal(1.0)
	assert_float(sf._color_rect.color.g).is_equal(0.0)
	assert_float(sf._color_rect.color.b).is_equal(0.0)
	await get_tree().create_timer(0.1).timeout
	sf.queue_free()


# ===========================================================================
# Full lifecycle: deplete → death → drop → respawn → pickup
# ===========================================================================

func test_full_lifecycle_deplete_die_respawn() -> void:
	# Stock inventory
	_inv._slots[0] = {"type": &"berries", "quantity": 20}
	_inv._slots[1] = {"type": &"meat", "quantity": 10}

	# Track all lifecycle events
	var events: Array = []
	_ss.stat_changed.connect(
		func(_stat: StringName, _current: float, _max_val: float) -> void:
			if events.is_empty() or events[-1] != "stat_changed":
				events.append("stat_changed")
	)
	_ss.player_died.connect(func() -> void: events.append("died"))
	_ss.player_respawned.connect(func() -> void: events.append("respawned"))
	_ss.ground_item_dropped.connect(
		func(_t: Vector2i, _i: StringName, _c: int, _sh: Vector2i) -> void:
			if events.is_empty() or events[-1] != "item_dropped":
				events.append("item_dropped")
	)

	# Phase 1: Deplete stats to death
	_dnc.is_daytime = false  # No regen
	_ss.hunger = 0.0
	_ss.thirst = 0.0
	# Both zero: 0.3/s drain. At 100 HP, death in ~334s
	_simulate(334.0)

	# Auto-respawn fires immediately after death
	assert_bool(_ss.is_dead).is_false()
	assert_bool(events.has("stat_changed")).is_true()
	assert_bool(events.has("died")).is_true()
	assert_bool(events.has("respawned")).is_true()
	assert_bool(events.has("item_dropped")).is_true()

	# Phase 2: Verify ground items created and stats restored
	var ground: Array[Dictionary] = _ss.get_all_ground_items()
	assert_int(ground.size()).is_greater(0)
	assert_float(_ss.hp).is_equal(100.0)
	assert_float(_ss.hunger).is_equal(50.0)
	assert_float(_ss.thirst).is_equal(50.0)

	# Phase 3: Pickup ground items
	for item: Dictionary in ground:
		_ss.remove_ground_item(item["tile"], item["item_type"], item["count"])
	assert_int(_ss.get_all_ground_items().size()).is_equal(0)


func test_full_lifecycle_eat_to_survive() -> void:
	# Start with low hunger, consume to stay alive
	_ss.hunger = 5.0
	_ss.thirst = 100.0
	_dnc.is_daytime = true

	# Simulate 3 seconds — hunger drops to ~3.8
	_simulate(3.0)
	assert_float(_ss.hunger).is_equal_approx(3.8, 0.1)

	# Eat berries to restore (+5)
	_ss.consume(&"berries")
	assert_float(_ss.hunger).is_equal_approx(8.8, 0.1)

	# Continue simulating — player stays alive
	_simulate(10.0)
	assert_bool(_ss.is_dead).is_false()
	assert_float(_ss.hunger).is_equal_approx(4.8, 0.1)


# ===========================================================================
# Deterministic setup/teardown verification
# ===========================================================================

func test_clean_state_initial_stats() -> void:
	assert_float(_ss.hp).is_equal(100.0)
	assert_float(_ss.hunger).is_equal(100.0)
	assert_float(_ss.thirst).is_equal(100.0)
	assert_bool(_ss.is_dead).is_false()


func test_clean_state_no_ground_items() -> void:
	assert_int(_ss.get_all_ground_items().size()).is_equal(0)


func test_clean_state_respawn_at_origin() -> void:
	assert_object(_ss._respawn_tile).is_equal(Vector2i.ZERO)
