extends GdUnitTestSuite
class_name TestInventory

const _Inventory = preload("res://scripts/inventory/inventory.gd")

var _inv: _Inventory


func before_test() -> void:
	_inv = _Inventory.new()


func after_test() -> void:
	_inv = null


# --- Starting state ---

func test_starting_state_12_empty_slots() -> void:
	assert_int(_inv.get_max_slots()).is_equal(12)
	assert_int(_inv.get_used_slot_count()).is_equal(0)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_int(slots.size()).is_equal(12)
	for slot in slots:
		assert_object(slot["type"]).is_equal(&"")
		assert_int(slot["quantity"]).is_equal(0)


func test_starting_tool_weapon_survival_knife() -> void:
	assert_object(_inv.get_tool(&"weapon")).is_equal(&"survival_knife")


func test_starting_tool_scanner() -> void:
	assert_object(_inv.get_tool(&"scanner")).is_equal(&"scanner")


func test_starting_tool_axe_empty() -> void:
	assert_object(_inv.get_tool(&"axe")).is_equal(&"")


func test_starting_tool_pickaxe_empty() -> void:
	assert_object(_inv.get_tool(&"pickaxe")).is_equal(&"")


# --- item_config coverage ---

func test_item_config_has_meat() -> void:
	assert_bool(_Inventory.ITEM_CONFIG.has(&"meat")).is_true()


func test_item_config_has_all_tools() -> void:
	for name in [&"stone_axe", &"stone_pickaxe", &"survival_knife", &"scanner"]:
		assert_bool(_Inventory.ITEM_CONFIG.has(name)).is_true()


func test_prop_defs_have_max_stack() -> void:
	for name in [&"wood", &"stone", &"berries", &"toxic_berries", &"fiber", &"ore", &"crystal"]:
		var def = PropRegistry.get_def(name)
		assert_bool(def != null).override_failure_message(
			"PropRegistry must have def for %s" % name
		).is_true()
		assert_bool(def.max_stack > 0).is_true()


func test_item_config_tools_have_tool_slot() -> void:
	for name in [&"stone_axe", &"stone_pickaxe", &"survival_knife", &"scanner"]:
		var cfg: Dictionary = _Inventory.ITEM_CONFIG[name]
		assert_bool(cfg.has("tool_slot")).is_true()


# --- add_item: tool routing rejection ---

func test_add_item_tool_rejected_returns_zero() -> void:
	var added: int = _inv.add_item(&"stone_axe", 1)
	assert_int(added).is_equal(0)


func test_add_item_tool_does_not_appear_in_slots() -> void:
	_inv.add_item(&"stone_axe", 1)
	assert_int(_inv.get_count(&"stone_axe")).is_equal(0)


# --- add_item: new stack ---

func test_add_item_new_stack() -> void:
	var added: int = _inv.add_item(&"wood", 5)
	assert_int(added).is_equal(5)
	assert_int(_inv.get_count(&"wood")).is_equal(5)


func test_add_item_new_stack_uses_one_slot() -> void:
	_inv.add_item(&"wood", 5)
	assert_int(_inv.get_used_slot_count()).is_equal(1)


# --- add_item: partial stack fill ---

func test_add_item_fills_partial_stack() -> void:
	_inv.add_item(&"wood", 90)
	# wood max_stack=99, slot has 90. Adding 15 → fills to 99 then new stack of 6
	var added: int = _inv.add_item(&"wood", 15)
	assert_int(added).is_equal(15)
	assert_int(_inv.get_count(&"wood")).is_equal(105)


func test_add_item_partial_fill_reuses_existing_slot() -> void:
	_inv.add_item(&"wood", 90)
	_inv.add_item(&"wood", 9)
	# Both fit in the same slot (90+9=99)
	assert_int(_inv.get_used_slot_count()).is_equal(1)


func test_add_item_spills_to_new_slot_when_stack_full() -> void:
	_inv.add_item(&"wood", 99)  # fills slot 0 completely
	_inv.add_item(&"wood", 1)   # goes to slot 1
	assert_int(_inv.get_used_slot_count()).is_equal(2)


# --- add_item: overflow / rejection ---

func test_add_item_overflow_emits_inventory_full() -> void:
	var fired: Array = []
	_inv.inventory_full.connect(func(t: StringName, r: int) -> void:
		fired.append({"type": t, "rejected": r})
	)
	for i in 12:
		_inv.add_item(&"berries", 20)
	_inv.add_item(&"berries", 1)
	assert_int(fired.size()).is_greater(0)


func test_add_item_overflow_returns_zero() -> void:
	for i in 12:
		_inv.add_item(&"berries", 20)
	var added: int = _inv.add_item(&"berries", 5)
	assert_int(added).is_equal(0)


func test_add_item_partial_overflow_returns_partial() -> void:
	for i in 11:
		_inv.add_item(&"berries", 20)
	# Last slot can take 20; try to add 25
	var added: int = _inv.add_item(&"berries", 25)
	assert_int(added).is_equal(20)


# --- add_item: stacking rules per type ---

func test_stacking_berries_max_20() -> void:
	_inv.add_item(&"berries", 20)
	_inv.add_item(&"berries", 1)
	assert_int(_inv.get_used_slot_count()).is_equal(2)


func test_stacking_wood_max_99() -> void:
	_inv.add_item(&"wood", 99)
	_inv.add_item(&"wood", 1)
	assert_int(_inv.get_used_slot_count()).is_equal(2)


func test_stacking_crystal_max_50() -> void:
	_inv.add_item(&"crystal", 50)
	_inv.add_item(&"crystal", 1)
	assert_int(_inv.get_used_slot_count()).is_equal(2)


# --- add_item signals ---

func test_add_item_emits_item_added() -> void:
	var fired: Array = []
	_inv.item_added.connect(func(t: StringName, a: int) -> void: fired.append(a))
	_inv.add_item(&"wood", 3)
	assert_int(fired.size()).is_equal(1)
	assert_int(fired[0]).is_equal(3)


func test_add_item_emits_inventory_changed() -> void:
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.add_item(&"wood", 1)
	assert_int(fired.size()).is_greater(0)


# --- remove_item ---

func test_remove_item_returns_removed_amount() -> void:
	_inv.add_item(&"wood", 10)
	var removed: int = _inv.remove_item(&"wood", 4)
	assert_int(removed).is_equal(4)
	assert_int(_inv.get_count(&"wood")).is_equal(6)


func test_remove_item_partial_removal() -> void:
	_inv.add_item(&"wood", 3)
	var removed: int = _inv.remove_item(&"wood", 10)
	assert_int(removed).is_equal(3)
	assert_int(_inv.get_count(&"wood")).is_equal(0)


func test_remove_item_clears_empty_slot() -> void:
	_inv.add_item(&"wood", 5)
	_inv.remove_item(&"wood", 5)
	assert_int(_inv.get_used_slot_count()).is_equal(0)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_object(slots[0]["type"]).is_equal(&"")
	assert_int(slots[0]["quantity"]).is_equal(0)


func test_remove_item_reverse_order() -> void:
	# Add 99 wood (slot 0), then 50 wood (slot 1)
	_inv.add_item(&"wood", 99)
	_inv.add_item(&"wood", 50)
	# Remove 60 — reverse order: takes 50 from slot 1, then 10 from slot 0
	_inv.remove_item(&"wood", 60)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_object(slots[1]["type"]).is_equal(&"")
	assert_int(slots[0]["quantity"]).is_equal(89)


func test_remove_item_emits_item_removed() -> void:
	_inv.add_item(&"wood", 5)
	var fired: Array = []
	_inv.item_removed.connect(func(t: StringName, a: int) -> void: fired.append(a))
	_inv.remove_item(&"wood", 2)
	assert_int(fired.size()).is_equal(1)
	assert_int(fired[0]).is_equal(2)


func test_remove_item_emits_inventory_changed() -> void:
	_inv.add_item(&"wood", 5)
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.remove_item(&"wood", 1)
	assert_int(fired.size()).is_greater(0)


func test_remove_item_not_present_returns_zero() -> void:
	var removed: int = _inv.remove_item(&"wood", 5)
	assert_int(removed).is_equal(0)


# --- has_item / get_count ---

func test_has_item_true_when_present() -> void:
	_inv.add_item(&"stone", 3)
	assert_bool(_inv.has_item(&"stone", 3)).is_true()


func test_has_item_false_when_insufficient() -> void:
	_inv.add_item(&"stone", 2)
	assert_bool(_inv.has_item(&"stone", 3)).is_false()


func test_get_count_sums_across_slots() -> void:
	_inv.add_item(&"wood", 99)
	_inv.add_item(&"wood", 50)
	assert_int(_inv.get_count(&"wood")).is_equal(149)


# --- is_full ---

func test_is_full_false_when_slots_available() -> void:
	assert_bool(_inv.is_full()).is_false()


func test_is_full_true_when_all_slots_maxed() -> void:
	for i in 12:
		_inv.add_item(&"berries", 20)
	assert_bool(_inv.is_full()).is_true()


func test_is_full_false_with_partial_stack() -> void:
	for i in 12:
		_inv.add_item(&"berries", 19)  # one short of max
	assert_bool(_inv.is_full()).is_false()


# --- use_item ---

func test_use_item_removes_one() -> void:
	_inv.add_item(&"berries", 5)
	_inv.use_item(&"berries")
	assert_int(_inv.get_count(&"berries")).is_equal(4)


func test_use_item_returns_true_when_present() -> void:
	_inv.add_item(&"berries", 1)
	assert_bool(_inv.use_item(&"berries")).is_true()


func test_use_item_returns_false_when_not_present() -> void:
	assert_bool(_inv.use_item(&"berries")).is_false()


func test_use_item_emits_item_used() -> void:
	_inv.add_item(&"berries", 1)
	var fired: Array = []
	_inv.item_used.connect(func(t: StringName) -> void: fired.append(t))
	_inv.use_item(&"berries")
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]).is_equal(&"berries")


func test_use_item_emits_inventory_changed() -> void:
	_inv.add_item(&"berries", 1)
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.use_item(&"berries")
	assert_int(fired.size()).is_greater(0)


func test_use_item_no_signal_when_not_present() -> void:
	var fired: Array = []
	_inv.item_used.connect(func(t: StringName) -> void: fired.append(t))
	_inv.use_item(&"berries")
	assert_int(fired.size()).is_equal(0)


# --- Tool slots ---

func test_get_tool_returns_current() -> void:
	assert_object(_inv.get_tool(&"weapon")).is_equal(&"survival_knife")


func test_set_tool_returns_old() -> void:
	var old: StringName = _inv.set_tool(&"axe", &"stone_axe")
	assert_object(old).is_equal(&"")


func test_set_tool_updates_slot() -> void:
	_inv.set_tool(&"axe", &"stone_axe")
	assert_object(_inv.get_tool(&"axe")).is_equal(&"stone_axe")


func test_set_tool_replaces_existing() -> void:
	_inv.set_tool(&"weapon", &"stone_axe")
	var old: StringName = _inv.set_tool(&"weapon", &"survival_knife")
	assert_object(old).is_equal(&"stone_axe")
	assert_object(_inv.get_tool(&"weapon")).is_equal(&"survival_knife")


func test_has_tool_for_true_when_set() -> void:
	assert_bool(_inv.has_tool_for(&"weapon")).is_true()


func test_has_tool_for_false_when_empty() -> void:
	assert_bool(_inv.has_tool_for(&"axe")).is_false()


func test_set_tool_emits_tool_changed() -> void:
	var fired: Array = []
	_inv.tool_changed.connect(func(s: StringName, n: StringName, o: StringName) -> void:
		fired.append({"slot": s, "new": n, "old": o})
	)
	_inv.set_tool(&"axe", &"stone_axe")
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["slot"]).is_equal(&"axe")
	assert_object(fired[0]["new"]).is_equal(&"stone_axe")
	assert_object(fired[0]["old"]).is_equal(&"")


func test_set_tool_emits_inventory_changed() -> void:
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.set_tool(&"axe", &"stone_axe")
	assert_int(fired.size()).is_greater(0)


# --- expand ---

func test_expand_increases_max_slots() -> void:
	_inv.expand(12)
	assert_int(_inv.get_max_slots()).is_equal(24)


func test_expand_appends_empty_slots() -> void:
	_inv.expand(12)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_int(slots.size()).is_equal(24)
	for i in range(12, 24):
		assert_object(slots[i]["type"]).is_equal(&"")
		assert_int(slots[i]["quantity"]).is_equal(0)


func test_expand_emits_inventory_changed() -> void:
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.expand(12)
	assert_int(fired.size()).is_greater(0)


func test_expand_multiple_times_stacks() -> void:
	_inv.expand(12)
	_inv.expand(12)
	assert_int(_inv.get_max_slots()).is_equal(36)
	assert_int(_inv.get_slots().size()).is_equal(36)


# --- save / load round-trip ---

func test_save_load_round_trip_slots() -> void:
	_inv.add_item(&"wood", 15)
	_inv.add_item(&"stone", 8)
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	assert_int(inv2.get_count(&"wood")).is_equal(15)
	assert_int(inv2.get_count(&"stone")).is_equal(8)


func test_save_load_round_trip_tools() -> void:
	_inv.set_tool(&"axe", &"stone_axe")
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	assert_object(inv2.get_tool(&"axe")).is_equal(&"stone_axe")
	assert_object(inv2.get_tool(&"weapon")).is_equal(&"survival_knife")
	assert_object(inv2.get_tool(&"scanner")).is_equal(&"scanner")


func test_save_load_round_trip_bonus_slots() -> void:
	_inv.expand(12)
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	assert_int(inv2.get_max_slots()).is_equal(24)
	assert_int(inv2.get_slots().size()).is_equal(24)


func test_save_data_format_has_required_keys() -> void:
	var data: Dictionary = _inv.get_save_data()
	assert_bool(data.has("bonus_slots")).is_true()
	assert_bool(data.has("tools")).is_true()
	assert_bool(data.has("slots")).is_true()


func test_save_load_preserves_slot_positions() -> void:
	_inv.add_item(&"stone", 5)
	_inv.add_item(&"wood", 3)
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	var slots: Array[Dictionary] = inv2.get_slots()
	assert_object(slots[0]["type"]).is_equal(&"stone")
	assert_int(slots[0]["quantity"]).is_equal(5)
	assert_object(slots[1]["type"]).is_equal(&"wood")
	assert_int(slots[1]["quantity"]).is_equal(3)
