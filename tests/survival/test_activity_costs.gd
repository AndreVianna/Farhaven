extends GdUnitTestSuite
class_name TestActivityCosts

## Tests for activity-based survival costs — one-time costs and continuous drains.

const _SurvivalSystem = preload("res://scripts/survival/survival_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")

var _sys: _SurvivalSystem
var _inv: _Inventory
var _dnc: MockDayNightCycle


# --- Mock DayNightCycle ---

class MockDayNightCycle extends Node:
	var is_daytime: bool = true


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


# --- ACTIVITY_CONFIG constant ---

func test_activity_config_has_gathering() -> void:
	assert_bool(_SurvivalSystem.ACTIVITY_CONFIG.has(&"gathering")).is_true()


func test_activity_config_has_crafting() -> void:
	assert_bool(_SurvivalSystem.ACTIVITY_CONFIG.has(&"crafting")).is_true()


func test_activity_config_has_scanning() -> void:
	assert_bool(_SurvivalSystem.ACTIVITY_CONFIG.has(&"scanning")).is_true()


func test_activity_config_has_building() -> void:
	assert_bool(_SurvivalSystem.ACTIVITY_CONFIG.has(&"building")).is_true()


func test_activity_config_has_attacking() -> void:
	assert_bool(_SurvivalSystem.ACTIVITY_CONFIG.has(&"attacking")).is_true()


func test_activity_config_has_moving() -> void:
	assert_bool(_SurvivalSystem.ACTIVITY_CONFIG.has(&"moving")).is_true()


# --- apply_activity_cost: gathering ---

func test_gathering_cost_reduces_hunger() -> void:
	_sys.hunger = 50.0
	_sys.apply_activity_cost(&"gathering")
	assert_float(_sys.hunger).is_equal_approx(49.9, 0.001)


func test_gathering_cost_reduces_thirst() -> void:
	_sys.thirst = 50.0
	_sys.apply_activity_cost(&"gathering")
	assert_float(_sys.thirst).is_equal_approx(49.8, 0.001)


func test_gathering_cost_no_hp_damage() -> void:
	_sys.hp = 100.0
	_sys.apply_activity_cost(&"gathering")
	assert_float(_sys.hp).is_equal_approx(100.0, 0.001)


# --- apply_activity_cost: crafting ---

func test_crafting_cost_reduces_hunger() -> void:
	_sys.hunger = 50.0
	_sys.apply_activity_cost(&"crafting")
	assert_float(_sys.hunger).is_equal_approx(49.8, 0.001)


func test_crafting_cost_reduces_thirst() -> void:
	_sys.thirst = 50.0
	_sys.apply_activity_cost(&"crafting")
	assert_float(_sys.thirst).is_equal_approx(49.5, 0.001)


# --- apply_activity_cost: scanning ---

func test_scanning_cost_reduces_hunger() -> void:
	_sys.hunger = 50.0
	_sys.apply_activity_cost(&"scanning")
	assert_float(_sys.hunger).is_equal_approx(49.95, 0.001)


func test_scanning_cost_reduces_thirst() -> void:
	_sys.thirst = 50.0
	_sys.apply_activity_cost(&"scanning")
	assert_float(_sys.thirst).is_equal_approx(49.9, 0.001)


# --- apply_activity_cost: building ---

func test_building_cost_reduces_hunger() -> void:
	_sys.hunger = 50.0
	_sys.apply_activity_cost(&"building")
	assert_float(_sys.hunger).is_equal_approx(49.5, 0.001)


func test_building_cost_reduces_thirst() -> void:
	_sys.thirst = 50.0
	_sys.apply_activity_cost(&"building")
	assert_float(_sys.thirst).is_equal_approx(49.0, 0.001)


# --- apply_activity_cost: attacking ---

func test_attacking_cost_reduces_hunger() -> void:
	_sys.hunger = 50.0
	_sys.apply_activity_cost(&"attacking")
	assert_float(_sys.hunger).is_equal_approx(49.8, 0.001)


func test_attacking_cost_reduces_thirst() -> void:
	_sys.thirst = 50.0
	_sys.apply_activity_cost(&"attacking")
	assert_float(_sys.thirst).is_equal_approx(49.7, 0.001)


# --- apply_activity_cost: moving (zero cost) ---

func test_moving_cost_no_hunger_change() -> void:
	_sys.hunger = 50.0
	_sys.apply_activity_cost(&"moving")
	assert_float(_sys.hunger).is_equal_approx(50.0, 0.001)


func test_moving_cost_no_thirst_change() -> void:
	_sys.thirst = 50.0
	_sys.apply_activity_cost(&"moving")
	assert_float(_sys.thirst).is_equal_approx(50.0, 0.001)


# --- apply_activity_cost: dead player ---

func test_activity_cost_ignored_when_dead() -> void:
	_sys.is_dead = true
	_sys.hunger = 50.0
	_sys.thirst = 50.0
	_sys.apply_activity_cost(&"building")
	assert_float(_sys.hunger).is_equal_approx(50.0, 0.001)
	assert_float(_sys.thirst).is_equal_approx(50.0, 0.001)


# --- apply_activity_cost: clamping ---

func test_activity_cost_clamps_hunger_at_zero() -> void:
	_sys.hunger = 0.05
	_sys.apply_activity_cost(&"gathering")
	assert_float(_sys.hunger).is_equal(0.0)


func test_activity_cost_clamps_thirst_at_zero() -> void:
	_sys.thirst = 0.1
	_sys.apply_activity_cost(&"gathering")
	assert_float(_sys.thirst).is_equal(0.0)


# --- apply_activity_cost: unknown activity ---

func test_unknown_activity_no_effect() -> void:
	_sys.hunger = 50.0
	_sys.thirst = 50.0
	_sys.hp = 100.0
	_sys.apply_activity_cost(&"flying")
	assert_float(_sys.hunger).is_equal_approx(50.0, 0.001)
	assert_float(_sys.thirst).is_equal_approx(50.0, 0.001)
	assert_float(_sys.hp).is_equal_approx(100.0, 0.001)


# --- apply_activity_cost: emits stat_changed ---

func test_activity_cost_emits_stat_changed() -> void:
	var fired: Array = []
	_sys.stat_changed.connect(func(name: StringName, _c: float, _m: float) -> void:
		fired.append(name)
	)
	_sys.apply_activity_cost(&"gathering")
	assert_int(fired.size()).is_equal(3)
	assert_bool(fired.has(&"hp")).is_true()
	assert_bool(fired.has(&"hunger")).is_true()
	assert_bool(fired.has(&"thirst")).is_true()


# --- start_activity_drain / stop_activity_drain ---

func test_start_drain_adds_entry() -> void:
	_sys.start_activity_drain(&"scanning")
	assert_bool(_sys._active_drains.has(&"scanning")).is_true()


func test_stop_drain_removes_entry() -> void:
	_sys.start_activity_drain(&"scanning")
	_sys.stop_activity_drain(&"scanning")
	assert_bool(_sys._active_drains.has(&"scanning")).is_false()


func test_stop_nonexistent_drain_safe() -> void:
	_sys.stop_activity_drain(&"nonexistent")
	assert_int(_sys._active_drains.size()).is_equal(0)


func test_start_unknown_activity_drain_ignored() -> void:
	_sys.start_activity_drain(&"flying")
	assert_bool(_sys._active_drains.has(&"flying")).is_false()


# --- Active drain applies during tick ---

func test_scanning_drain_adds_to_passive_thirst_drain() -> void:
	_sys.start_activity_drain(&"scanning")
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# Passive thirst: 0.8/s, scanning drain thirst: 0.05/s → total 0.85/s
	assert_float(_sys.thirst).is_equal_approx(99.15, 0.001)


func test_scanning_drain_adds_to_passive_hunger_drain() -> void:
	_sys.start_activity_drain(&"scanning")
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# Passive hunger: 0.4/s, scanning drain hunger: 0.02/s → total 0.42/s
	assert_float(_sys.hunger).is_equal_approx(99.58, 0.001)


func test_moving_drain_applies_during_tick() -> void:
	_sys.start_activity_drain(&"moving")
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# Passive thirst: 0.8/s, moving drain thirst: 0.05/s → total 0.85/s
	assert_float(_sys.thirst).is_equal_approx(99.15, 0.001)
	# Passive hunger: 0.4/s, moving drain hunger: 0.02/s → total 0.42/s
	assert_float(_sys.hunger).is_equal_approx(99.58, 0.001)


func test_building_drain_applies_during_tick() -> void:
	_sys.start_activity_drain(&"building")
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# Passive thirst: 0.8/s, building drain thirst: 0.1/s → total 0.9/s
	assert_float(_sys.thirst).is_equal_approx(99.1, 0.001)
	# Passive hunger: 0.4/s, building drain hunger: 0.05/s → total 0.45/s
	assert_float(_sys.hunger).is_equal_approx(99.55, 0.001)


func test_multiple_drains_stack() -> void:
	_sys.start_activity_drain(&"scanning")
	_sys.start_activity_drain(&"moving")
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# Passive thirst: 0.8/s, scanning: 0.05, moving: 0.05 → total 0.9/s
	assert_float(_sys.thirst).is_equal_approx(99.1, 0.001)
	# Passive hunger: 0.4/s, scanning: 0.02, moving: 0.02 → total 0.44/s
	assert_float(_sys.hunger).is_equal_approx(99.56, 0.001)


func test_stopped_drain_no_longer_applies() -> void:
	_sys.start_activity_drain(&"moving")
	_sys.stop_activity_drain(&"moving")
	_sys.hunger = 100.0
	_sys.thirst = 100.0
	_tick(1.0)
	# Only passive drain remains
	assert_float(_sys.thirst).is_equal_approx(99.2, 0.001)
	assert_float(_sys.hunger).is_equal_approx(99.6, 0.001)


func test_drain_does_not_apply_when_dead() -> void:
	_sys.start_activity_drain(&"building")
	_sys.is_dead = true
	_sys.hunger = 50.0
	_sys.thirst = 50.0
	_tick(10.0)
	assert_float(_sys.hunger).is_equal_approx(50.0, 0.001)
	assert_float(_sys.thirst).is_equal_approx(50.0, 0.001)
