extends GdUnitTestSuite
class_name TestSurvivalSystem

const _SurvivalSystem = preload("res://scripts/survival/survival_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")

# Numeric PropDef ids for consumables.
const ID_BERRIES: StringName = &"00020"
const ID_TOXIC_BERRIES: StringName = &"00021"
const ID_MEAT: StringName = &"00022"

var _sys: _SurvivalSystem
var _inv: _Inventory
var _dnc: MockDayNightCycle


# --- Mock DayNightCycle ---

class MockDayNightCycle extends Node:
	var is_daytime: bool = true

	func skip_to_dawn() -> void:
		is_daytime = true


# --- Mock Player ---

class MockPlayer extends Node:
	var _inventory: RefCounted

	func _init(inv: RefCounted) -> void:
		_inventory = inv

	func get_inventory() -> RefCounted:
		return _inventory


# --- Setup / Teardown ---

func before_test() -> void:
	_inv = _Inventory.new()
	_dnc = MockDayNightCycle.new()
	add_child(_dnc)

	var player: MockPlayer = MockPlayer.new(_inv)
	add_child(player)

	_sys = _SurvivalSystem.new()
	_sys._day_night_cycle = _dnc
	player.add_child(_sys)


func after_test() -> void:
	var player: Node = _sys.get_parent()
	player.remove_child(_sys)
	_sys.queue_free()
	remove_child(player)
	player.queue_free()
	remove_child(_dnc)
	_dnc.queue_free()
	_inv = null
	_sys = null
	_dnc = null


# --- Helpers ---

func _tick(delta: float) -> void:
	_sys._process(delta)


# --- Initial state ---

func test_initial_hp_is_100() -> void:
	assert_float(_sys.hp).is_equal(100.0)


func test_initial_hunger_is_100() -> void:
	assert_float(_sys.hunger).is_equal(100.0)


func test_initial_thirst_is_100() -> void:
	assert_float(_sys.thirst).is_equal(100.0)


func test_initial_is_dead_false() -> void:
	assert_bool(_sys.is_dead).is_false()


func test_max_values() -> void:
	assert_float(_sys.hp_max).is_equal(100.0)
	assert_float(_sys.hunger_max).is_equal(100.0)
	assert_float(_sys.thirst_max).is_equal(100.0)


# --- STAT_CONFIG constants ---

func test_stat_config_hunger_rate() -> void:
	assert_float(_SurvivalSystem.STAT_CONFIG["hunger_rate"]).is_equal(0.4)


func test_stat_config_thirst_rate() -> void:
	assert_float(_SurvivalSystem.STAT_CONFIG["thirst_rate"]).is_equal(0.8)


func test_stat_config_hp_drain_no_hunger() -> void:
	assert_float(_SurvivalSystem.STAT_CONFIG["hp_drain_no_hunger"]).is_equal(0.1)


func test_stat_config_hp_drain_no_thirst() -> void:
	assert_float(_SurvivalSystem.STAT_CONFIG["hp_drain_no_thirst"]).is_equal(0.2)


func test_stat_config_hp_regen_day() -> void:
	assert_float(_SurvivalSystem.STAT_CONFIG["hp_regen_day"]).is_equal(0.5)


# --- Consumable PropDef constants (data-driven via PropRegistry) ---

func test_consumable_berries_hunger() -> void:
	assert_float(PropRegistry.get_def(ID_BERRIES).hunger_restore).is_equal(5.0)


func test_consumable_berries_thirst() -> void:
	assert_float(PropRegistry.get_def(ID_BERRIES).thirst_restore).is_equal(10.0)


func test_consumable_berries_health() -> void:
	assert_float(PropRegistry.get_def(ID_BERRIES).health_amount).is_equal(0.0)


func test_consumable_toxic_berries_hunger() -> void:
	assert_float(PropRegistry.get_def(ID_TOXIC_BERRIES).hunger_restore).is_equal(10.0)


func test_consumable_toxic_berries_damages_health() -> void:
	assert_float(PropRegistry.get_def(ID_TOXIC_BERRIES).health_amount).is_equal(-25.0)


func test_consumable_meat_hunger() -> void:
	assert_float(PropRegistry.get_def(ID_MEAT).hunger_restore).is_equal(25.0)


# --- Depletion rates ---

func test_hunger_depletes_at_1_per_second() -> void:
	_tick(1.0)
	assert_float(_sys.hunger).is_equal(99.6)


func test_thirst_depletes_at_1_5_per_second() -> void:
	_tick(1.0)
	assert_float(_sys.thirst).is_equal(99.2)


func test_hunger_depletes_proportional_to_delta() -> void:
	_tick(10.0)
	assert_float(_sys.hunger).is_equal(96.0)


func test_thirst_depletes_proportional_to_delta() -> void:
	_tick(10.0)
	assert_float(_sys.thirst).is_equal(92.0)


func test_hunger_clamps_at_zero() -> void:
	_tick(300.0)
	assert_float(_sys.hunger).is_equal(0.0)


func test_thirst_clamps_at_zero() -> void:
	_tick(300.0)
	assert_float(_sys.thirst).is_equal(0.0)


# --- HP drain when hungry ---

func test_hp_drains_2_per_second_when_hunger_zero() -> void:
	_sys.hunger = 0.0
	_sys.thirst = 100.0
	_tick(1.0)
	# thirst depletes 0.8 in 1s, still > 0; hunger already 0 so no thirst drain
	# HP drain: 0.1/s from hunger=0
	# HP regen: no (hunger=0)
	assert_float(_sys.hp).is_equal_approx(99.9, 0.001)


func test_hp_drains_3_per_second_when_thirst_zero() -> void:
	_sys.hunger = 100.0
	_sys.thirst = 0.0
	_tick(1.0)
	# hunger depletes 0.4 → 99.6; thirst already 0
	# HP drain: 0.2/s from thirst=0
	# HP regen: no (thirst=0)
	assert_float(_sys.hp).is_equal_approx(99.8, 0.001)


func test_hp_drains_5_per_second_when_both_zero() -> void:
	_sys.hunger = 0.0
	_sys.thirst = 0.0
	_tick(1.0)
	# HP drain: 0.1 + 0.2 = 0.3/s
	# HP regen: no (both zero)
	assert_float(_sys.hp).is_equal_approx(99.7, 0.001)


func test_hp_drain_stacks_no_regen_when_starving() -> void:
	_sys.hunger = 0.0
	_sys.thirst = 0.0
	_tick(10.0)
	# 0.3 * 10 = 3.0 drain
	assert_float(_sys.hp).is_equal_approx(97.0, 0.001)


# --- HP regen ---

func test_hp_regens_half_per_second_daytime_when_fed() -> void:
	_dnc.is_daytime = true
	_sys.hp = 50.0
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# hunger: 99.6, thirst: 99.2 (both > 0)
	# no drain; regen 0.5
	assert_float(_sys.hp).is_equal_approx(50.5, 0.001)


func test_no_regen_at_night() -> void:
	_dnc.is_daytime = false
	_sys.hp = 50.0
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# no drain (both fed), no regen (night)
	assert_float(_sys.hp).is_equal_approx(50.0, 0.001)


func test_no_regen_when_hunger_zero() -> void:
	_dnc.is_daytime = true
	_sys.hp = 80.0
	_sys.hunger = 0.0
	_sys.thirst = 100.0
	_tick(1.0)
	# HP drain from hunger=0: 0.1; no regen (hunger=0)
	assert_float(_sys.hp).is_equal_approx(79.9, 0.001)


func test_no_regen_when_thirst_zero() -> void:
	_dnc.is_daytime = true
	_sys.hp = 80.0
	_sys.hunger = 100.0
	_sys.thirst = 0.0
	_tick(1.0)
	# HP drain from thirst=0: 0.2; no regen (thirst=0)
	assert_float(_sys.hp).is_equal_approx(79.8, 0.001)


func test_hp_regen_clamps_at_max() -> void:
	_dnc.is_daytime = true
	_sys.hp = 100.0
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(10.0)
	assert_float(_sys.hp).is_equal_approx(100.0, 0.001)


# --- consume: berries ---

func test_consume_berries_increases_hunger() -> void:
	_sys.hunger = 50.0
	_sys.consume(ID_BERRIES)
	assert_float(_sys.hunger).is_equal_approx(55.0, 0.001)


func test_consume_berries_increases_thirst() -> void:
	_sys.thirst = 80.0
	_sys.consume(ID_BERRIES)
	assert_float(_sys.thirst).is_equal_approx(90.0, 0.001)


func test_consume_berries_clamps_thirst_at_max() -> void:
	_sys.thirst = 98.0
	_sys.consume(ID_BERRIES)
	assert_float(_sys.thirst).is_equal_approx(100.0, 0.001)


func test_consume_berries_clamps_hunger_at_max() -> void:
	_sys.hunger = 97.0
	_sys.consume(ID_BERRIES)
	assert_float(_sys.hunger).is_equal_approx(100.0, 0.001)


func test_consume_berries_no_hp_damage() -> void:
	_sys.hp = 100.0
	_sys.consume(ID_BERRIES)
	assert_float(_sys.hp).is_equal_approx(100.0, 0.001)


# --- consume: toxic_berries ---

func test_consume_toxic_berries_increases_hunger() -> void:
	_sys.hunger = 50.0
	_sys.consume(ID_TOXIC_BERRIES)
	assert_float(_sys.hunger).is_equal_approx(60.0, 0.001)


func test_consume_toxic_berries_no_thirst_restore() -> void:
	_sys.thirst = 80.0
	_sys.consume(ID_TOXIC_BERRIES)
	assert_float(_sys.thirst).is_equal_approx(80.0, 0.001)


func test_consume_toxic_berries_deals_25_damage() -> void:
	_sys.hp = 100.0
	_sys.consume(ID_TOXIC_BERRIES)
	assert_float(_sys.hp).is_equal_approx(75.0, 0.001)


func test_consume_toxic_berries_can_kill() -> void:
	var died: Array = []
	var respawned: Array = []
	_sys.player_died.connect(func() -> void: died.append(true))
	_sys.player_respawned.connect(func() -> void: respawned.append(true))
	_sys.hp = 20.0
	_sys.consume(ID_TOXIC_BERRIES)
	# Death triggers then auto-respawn restores stats
	assert_int(died.size()).is_equal(1)
	assert_int(respawned.size()).is_equal(1)
	assert_float(_sys.hp).is_equal(100.0)
	assert_bool(_sys.is_dead).is_false()


# --- consume: meat ---

func test_consume_meat_increases_hunger() -> void:
	_sys.hunger = 50.0
	_sys.consume(ID_MEAT)
	assert_float(_sys.hunger).is_equal_approx(75.0, 0.001)


func test_consume_meat_no_thirst_restore() -> void:
	_sys.thirst = 80.0
	_sys.consume(ID_MEAT)
	assert_float(_sys.thirst).is_equal_approx(80.0, 0.001)


func test_consume_meat_no_hp_damage() -> void:
	_sys.hp = 100.0
	_sys.consume(ID_MEAT)
	assert_float(_sys.hp).is_equal_approx(100.0, 0.001)


func test_consume_unknown_item_no_effect() -> void:
	_sys.hunger = 50.0
	_sys.consume(&"unknown_item")
	assert_float(_sys.hunger).is_equal_approx(50.0, 0.001)


# --- take_damage ---

func test_take_damage_reduces_hp() -> void:
	_sys.hp = 100.0
	_sys.take_damage(30.0)
	assert_float(_sys.hp).is_equal_approx(70.0, 0.001)


func test_take_damage_clamps_hp_at_zero() -> void:
	_sys.hp = 20.0
	_sys.take_damage(50.0)
	# Lethal damage triggers auto-respawn, hp restored to max
	assert_float(_sys.hp).is_equal(100.0)
	assert_bool(_sys.is_dead).is_false()


func test_take_damage_emits_stat_changed() -> void:
	var fired: Array = []
	_sys.stat_changed.connect(func(name: StringName, current: float, max_val: float) -> void:
		fired.append({"name": name, "current": current, "max_val": max_val})
	)
	_sys.take_damage(10.0)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["name"]).is_equal(&"hp")
	assert_float(fired[0]["current"]).is_equal_approx(90.0, 0.001)
	assert_float(fired[0]["max_val"]).is_equal_approx(100.0, 0.001)


func test_take_damage_triggers_death_and_respawn() -> void:
	var died: Array = []
	var respawned: Array = []
	_sys.player_died.connect(func() -> void: died.append(true))
	_sys.player_respawned.connect(func() -> void: respawned.append(true))
	_sys.hp = 5.0
	_sys.take_damage(10.0)
	# Death fires then auto-respawn
	assert_int(died.size()).is_equal(1)
	assert_int(respawned.size()).is_equal(1)
	assert_bool(_sys.is_dead).is_false()


# --- stat_changed signal ---

func test_stat_changed_emits_three_times_per_tick() -> void:
	var fired: Array = []
	_sys.stat_changed.connect(func(name: StringName, _c: float, _m: float) -> void:
		fired.append(name)
	)
	_tick(1.0)
	assert_int(fired.size()).is_equal(3)


func test_stat_changed_emits_hp_hunger_thirst() -> void:
	var fired: Array = []
	_sys.stat_changed.connect(func(name: StringName, _c: float, _m: float) -> void:
		fired.append(name)
	)
	_tick(1.0)
	assert_bool(fired.has(&"hp")).is_true()
	assert_bool(fired.has(&"hunger")).is_true()
	assert_bool(fired.has(&"thirst")).is_true()


func test_stat_changed_carries_correct_values() -> void:
	var hp_emit: Array = []
	_sys.stat_changed.connect(func(name: StringName, current: float, max_val: float) -> void:
		if name == &"hunger":
			hp_emit.append({"current": current, "max_val": max_val})
	)
	_tick(1.0)
	assert_int(hp_emit.size()).is_equal(1)
	assert_float(hp_emit[0]["current"]).is_equal_approx(99.6, 0.001)
	assert_float(hp_emit[0]["max_val"]).is_equal_approx(100.0, 0.001)


# --- is_dead gates tick ---

func test_is_dead_stops_hunger_depletion() -> void:
	_sys.is_dead = true
	_sys.hunger = 80.0
	_tick(10.0)
	assert_float(_sys.hunger).is_equal_approx(80.0, 0.001)


func test_is_dead_stops_thirst_depletion() -> void:
	_sys.is_dead = true
	_sys.thirst = 80.0
	_tick(10.0)
	assert_float(_sys.thirst).is_equal_approx(80.0, 0.001)


func test_is_dead_stops_hp_drain() -> void:
	_sys.is_dead = true
	_sys.hunger = 0.0
	_sys.thirst = 0.0
	_sys.hp = 50.0
	_tick(10.0)
	assert_float(_sys.hp).is_equal_approx(50.0, 0.001)


func test_is_dead_stops_stat_changed_emission() -> void:
	_sys.is_dead = true
	var fired: Array = []
	_sys.stat_changed.connect(func(_n: StringName, _c: float, _m: float) -> void:
		fired.append(true)
	)
	_tick(1.0)
	assert_int(fired.size()).is_equal(0)


# --- death trigger ---

func test_hp_reaching_zero_triggers_death_and_respawn() -> void:
	var died: Array = []
	_sys.player_died.connect(func() -> void: died.append(true))
	_sys.hunger = 0.0
	_sys.thirst = 0.0
	_sys.hp = 1.0
	_tick(10.0)
	# 0.3/s drain for 10.0s = 3.0 drain, kills at hp=1, then auto-respawns
	assert_int(died.size()).is_equal(1)
	assert_bool(_sys.is_dead).is_false()
	assert_float(_sys.hp).is_equal(100.0)


func test_hp_below_zero_triggers_respawn() -> void:
	_sys.take_damage(200.0)
	# Lethal damage triggers auto-respawn
	assert_float(_sys.hp).is_equal(100.0)
	assert_bool(_sys.is_dead).is_false()


func test_death_only_triggers_once() -> void:
	var died_count: Array = []
	_sys.player_died.connect(func() -> void: died_count.append(true))
	_sys.hp = 0.5
	_sys.take_damage(10.0)
	# First death triggers respawn (is_dead becomes false again)
	assert_int(died_count.size()).is_equal(1)
	assert_bool(_sys.is_dead).is_false()
	# Non-lethal damage after respawn should not trigger death again
	_sys.take_damage(10.0)
	assert_int(died_count.size()).is_equal(1)


# --- inventory item_used connection ---

func test_inventory_item_used_triggers_consume() -> void:
	_sys.hunger = 50.0
	_inv.add_item(ID_BERRIES, 1)
	_inv.use_item(ID_BERRIES)
	assert_float(_sys.hunger).is_equal_approx(55.0, 0.001)


func test_inventory_toxic_berries_used_deals_damage() -> void:
	_sys.hp = 100.0
	_inv.add_item(ID_TOXIC_BERRIES, 1)
	_inv.use_item(ID_TOXIC_BERRIES)
	assert_float(_sys.hp).is_equal_approx(75.0, 0.001)
