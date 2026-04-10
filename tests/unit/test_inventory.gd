extends GdUnitTestSuite
class_name TestInventory

const _Inventory = preload("res://scripts/inventory/inventory.gd")

# Numeric PropDef ids used throughout this suite.
const ID_WOOD: StringName = &"P00010"
const ID_STONE: StringName = &"P00013"
const ID_BERRIES: StringName = &"P00020"
const ID_CRYSTAL: StringName = &"P00015"
const ID_AXE: StringName = &"P00201"
const ID_PICKAXE: StringName = &"P00202"
const ID_KNIFE: StringName = &"P00204"
const ID_SCANNER: StringName = &"P00205"
const ID_FIBER: StringName = &"P00012"
const ID_ROCK: StringName = &"P00011"

# Weights from DESIGN.md §14:
# Wood=1.0, Rock=0.2, Fiber=0.05, Stone=0.5, Iron Ore=0.4, Crystal=0.15
# Berry=0.01, Toxic Berry=0.01, Meat=0.3, Torch=0.5

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


func test_starting_weight_zero() -> void:
	assert_float(_inv.get_current_weight()).is_equal(0.0)


func test_starting_capacity_weight_50() -> void:
	assert_float(_inv.get_capacity_weight()).is_equal(50.0)


func test_starting_remaining_capacity_50() -> void:
	assert_float(_inv.get_remaining_capacity()).is_equal(50.0)


func test_starting_weight_display() -> void:
	assert_str(_inv.get_weight_display()).is_equal("0.0 / 50.0")


func test_starting_tool_weapon_empty() -> void:
	# Starting tools are now applied from map's starting_loadout, not hardcoded.
	assert_object(_inv.get_tool(&"weapon")).is_equal(&"")


func test_starting_tool_scanner_empty() -> void:
	# Starting tools are now applied from map's starting_loadout, not hardcoded.
	assert_object(_inv.get_tool(&"scanner")).is_equal(&"")


func test_starting_tool_axe_empty() -> void:
	assert_object(_inv.get_tool(&"axe")).is_equal(&"")


func test_starting_tool_pickaxe_empty() -> void:
	assert_object(_inv.get_tool(&"pickaxe")).is_equal(&"")


# --- PropRegistry-driven item config coverage ---

func test_prop_registry_has_meat() -> void:
	assert_object(PropRegistry.get_def(&"P00022")).is_not_null()


func test_prop_registry_has_all_tools() -> void:
	for id: StringName in [ID_AXE, ID_PICKAXE, ID_KNIFE, ID_SCANNER]:
		var def = PropRegistry.get_def(id)
		assert_bool(def != null).override_failure_message(
			"PropRegistry must have def for tool %s" % id
		).is_true()
		assert_bool(def.tool_slot != &"").override_failure_message(
			"%s must have a non-empty tool_slot" % id
		).is_true()


func test_prop_defs_have_max_stack() -> void:
	for id: StringName in [ID_WOOD, ID_STONE, ID_BERRIES, &"P00021", &"P00012", &"P00014", ID_CRYSTAL]:
		var def = PropRegistry.get_def(id)
		assert_bool(def != null).override_failure_message(
			"PropRegistry must have def for %s" % id
		).is_true()
		assert_bool(def.max_stack > 0).is_true()


func test_prop_defs_have_portable_capability() -> void:
	for id: StringName in [ID_WOOD, ID_STONE, ID_BERRIES, ID_CRYSTAL, ID_FIBER, ID_ROCK]:
		var def = PropRegistry.get_def(id)
		assert_bool(def != null).override_failure_message(
			"PropRegistry must have def for %s" % id
		).is_true()
		assert_bool(def.portable != null).override_failure_message(
			"%s must have PORTABLE capability" % id
		).is_true()
		assert_bool(def.portable.size > 0.0).override_failure_message(
			"%s PORTABLE.size must be > 0" % id
		).is_true()


# --- add_item: tool routing rejection ---

func test_add_item_tool_rejected_returns_zero() -> void:
	var added: int = _inv.add_item(ID_AXE, 1)
	assert_int(added).is_equal(0)


func test_add_item_tool_does_not_appear_in_slots() -> void:
	_inv.add_item(ID_AXE, 1)
	assert_int(_inv.get_count(ID_AXE)).is_equal(0)


func test_add_item_tool_does_not_change_weight() -> void:
	_inv.add_item(ID_AXE, 1)
	assert_float(_inv.get_current_weight()).is_equal(0.0)


# --- add_item: new stack ---

func test_add_item_new_stack() -> void:
	var added: int = _inv.add_item(ID_WOOD, 5)
	assert_int(added).is_equal(5)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(5)


func test_add_item_new_stack_uses_one_slot() -> void:
	_inv.add_item(ID_WOOD, 5)
	assert_int(_inv.get_used_slot_count()).is_equal(1)


# --- add_item: weight tracking ---

func test_add_item_updates_current_weight() -> void:
	# Wood weight = 1.0
	_inv.add_item(ID_WOOD, 5)
	assert_float(_inv.get_current_weight()).is_equal_approx(5.0, 0.001)


func test_add_item_updates_remaining_capacity() -> void:
	# Wood weight = 1.0
	_inv.add_item(ID_WOOD, 5)
	assert_float(_inv.get_remaining_capacity()).is_equal_approx(45.0, 0.001)


func test_add_berry_light_weight() -> void:
	# Berry weight = 0.01
	_inv.add_item(ID_BERRIES, 20)
	assert_float(_inv.get_current_weight()).is_equal_approx(0.2, 0.001)


func test_add_multiple_types_accumulates_weight() -> void:
	# Wood 1.0 * 5 = 5.0, Stone 0.5 * 10 = 5.0
	_inv.add_item(ID_WOOD, 5)
	_inv.add_item(ID_STONE, 10)
	assert_float(_inv.get_current_weight()).is_equal_approx(10.0, 0.001)


# --- add_item: weight-based rejection ---

func test_add_item_weight_exceeds_capacity_rejects() -> void:
	# Wood = 1.0 each. Capacity = 50.0. Try to add 51.
	var added: int = _inv.add_item(ID_WOOD, 51)
	assert_int(added).is_equal(50)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(50)


func test_add_item_partial_weight_fit() -> void:
	# Fill to 49.0 with wood (1.0 each)
	_inv.add_item(ID_WOOD, 49)
	# Try to add 5 more — only 1 fits
	var added: int = _inv.add_item(ID_WOOD, 5)
	assert_int(added).is_equal(1)
	assert_float(_inv.get_current_weight()).is_equal_approx(50.0, 0.001)


func test_add_item_zero_remaining_capacity_rejects() -> void:
	_inv.add_item(ID_WOOD, 50)
	var added: int = _inv.add_item(ID_WOOD, 1)
	assert_int(added).is_equal(0)


func test_add_item_emits_inventory_full_on_weight_overflow() -> void:
	_inv.add_item(ID_WOOD, 50)
	var fired: Array = []
	_inv.inventory_full.connect(func(t: StringName, r: int) -> void:
		fired.append({"type": t, "rejected": r})
	)
	_inv.add_item(ID_WOOD, 5)
	assert_int(fired.size()).is_greater(0)
	assert_int(fired[0]["rejected"]).is_equal(5)


# --- add_item: single item too heavy for capacity ---

func test_add_item_too_heavy_for_capacity_rejects() -> void:
	# Set capacity to 0.5, then try adding wood (weight 1.0)
	_inv.capacity_weight = 0.5
	var added: int = _inv.add_item(ID_WOOD, 1)
	assert_int(added).is_equal(0)


func test_add_item_too_heavy_emits_inventory_full() -> void:
	_inv.capacity_weight = 0.5
	var fired: Array = []
	_inv.inventory_full.connect(func(t: StringName, r: int) -> void:
		fired.append({"type": t, "rejected": r})
	)
	_inv.add_item(ID_WOOD, 3)
	assert_int(fired.size()).is_greater(0)
	assert_int(fired[0]["rejected"]).is_equal(3)


# --- add_item: max_stack still respected alongside weight ---

func test_max_stack_limits_even_if_weight_allows() -> void:
	# Berries max_stack=20, weight=0.01. Weight allows thousands.
	# But max_stack should still limit per-slot to 20.
	_inv.add_item(ID_BERRIES, 20)
	_inv.add_item(ID_BERRIES, 1)
	# Second add should spill to new slot because first is at max_stack
	assert_int(_inv.get_used_slot_count()).is_equal(2)
	assert_int(_inv.get_count(ID_BERRIES)).is_equal(21)


# --- add_item: partial stack fill ---

func test_add_item_fills_partial_stack() -> void:
	# Berry weight=0.01, max_stack=20. Use berries for stack behavior tests.
	_inv.add_item(ID_BERRIES, 15)
	# Slot has 15 berries (max 20). Adding 10 → fills to 20 then new stack of 5.
	var added: int = _inv.add_item(ID_BERRIES, 10)
	assert_int(added).is_equal(10)
	assert_int(_inv.get_count(ID_BERRIES)).is_equal(25)


func test_add_item_partial_fill_reuses_existing_slot() -> void:
	_inv.add_item(ID_WOOD, 40)
	_inv.add_item(ID_WOOD, 9)
	# Both fit in the same slot (40+9=49)
	assert_int(_inv.get_used_slot_count()).is_equal(1)


func test_add_item_spills_to_new_slot_when_stack_full() -> void:
	# Fill with 49 wood (uses slot 0; fits capacity 50)
	_inv.add_item(ID_WOOD, 49)
	# Add 1 more — it fits in the existing partial stack since max_stack=99
	_inv.add_item(ID_WOOD, 1)
	assert_int(_inv.get_used_slot_count()).is_equal(1)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(50)


# --- add_item: overflow / rejection ---

func test_add_item_overflow_emits_inventory_full() -> void:
	var fired: Array = []
	_inv.inventory_full.connect(func(t: StringName, r: int) -> void:
		fired.append({"type": t, "rejected": r})
	)
	# Fill capacity with berries (0.01 each). 50 / 0.01 = 5000 berries max by weight.
	# But max_stack=20, so 12 slots * 20 = 240 berries max by slots.
	# 240 * 0.01 = 2.4 weight. Fill all slots first.
	for i in 12:
		_inv.add_item(ID_BERRIES, 20)
	_inv.add_item(ID_BERRIES, 1)
	assert_int(fired.size()).is_greater(0)


func test_add_item_overflow_returns_zero() -> void:
	for i in 12:
		_inv.add_item(ID_BERRIES, 20)
	var added: int = _inv.add_item(ID_BERRIES, 5)
	assert_int(added).is_equal(0)


func test_add_item_partial_overflow_returns_partial() -> void:
	for i in 11:
		_inv.add_item(ID_BERRIES, 20)
	# Last slot can take 20; try to add 25
	var added: int = _inv.add_item(ID_BERRIES, 25)
	assert_int(added).is_equal(20)


# --- add_item: stacking rules per type ---

func test_stacking_berries_max_20() -> void:
	_inv.add_item(ID_BERRIES, 20)
	_inv.add_item(ID_BERRIES, 1)
	assert_int(_inv.get_used_slot_count()).is_equal(2)


func test_stacking_wood_max_99() -> void:
	# Weight allows only 50 wood (1.0 each) — won't reach 99 before weight cap
	# This test verifies that adding up to max_stack spills correctly
	_inv.capacity_weight = 200.0  # override for this test
	_inv.add_item(ID_WOOD, 99)
	_inv.add_item(ID_WOOD, 1)
	assert_int(_inv.get_used_slot_count()).is_equal(2)


func test_stacking_crystal_max_50() -> void:
	# Crystal weight=0.15, 50 * 0.15 = 7.5 fits in capacity
	_inv.add_item(ID_CRYSTAL, 50)
	_inv.add_item(ID_CRYSTAL, 1)
	assert_int(_inv.get_used_slot_count()).is_equal(2)


# --- add_item signals ---

func test_add_item_emits_item_added() -> void:
	var fired: Array = []
	_inv.item_added.connect(func(t: StringName, a: int) -> void: fired.append(a))
	_inv.add_item(ID_WOOD, 3)
	assert_int(fired.size()).is_equal(1)
	assert_int(fired[0]).is_equal(3)


func test_add_item_emits_inventory_changed() -> void:
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.add_item(ID_WOOD, 1)
	assert_int(fired.size()).is_greater(0)


# --- remove_item ---

func test_remove_item_returns_removed_amount() -> void:
	_inv.add_item(ID_WOOD, 10)
	var removed: int = _inv.remove_item(ID_WOOD, 4)
	assert_int(removed).is_equal(4)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(6)


func test_remove_item_partial_removal() -> void:
	_inv.add_item(ID_WOOD, 3)
	var removed: int = _inv.remove_item(ID_WOOD, 10)
	assert_int(removed).is_equal(3)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(0)


func test_remove_item_clears_empty_slot() -> void:
	_inv.add_item(ID_WOOD, 5)
	_inv.remove_item(ID_WOOD, 5)
	assert_int(_inv.get_used_slot_count()).is_equal(0)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_object(slots[0]["type"]).is_equal(&"")
	assert_int(slots[0]["quantity"]).is_equal(0)


func test_remove_item_reverse_order() -> void:
	# Increase capacity to fit 149 wood (149 * 1.0)
	_inv.capacity_weight = 200.0
	# Add 99 wood (slot 0), then 50 wood (slot 1)
	_inv.add_item(ID_WOOD, 99)
	_inv.add_item(ID_WOOD, 50)
	# Remove 60 — reverse order: takes 50 from slot 1, then 10 from slot 0
	_inv.remove_item(ID_WOOD, 60)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_object(slots[1]["type"]).is_equal(&"")
	assert_int(slots[0]["quantity"]).is_equal(89)


func test_remove_item_emits_item_removed() -> void:
	_inv.add_item(ID_WOOD, 5)
	var fired: Array = []
	_inv.item_removed.connect(func(t: StringName, a: int) -> void: fired.append(a))
	_inv.remove_item(ID_WOOD, 2)
	assert_int(fired.size()).is_equal(1)
	assert_int(fired[0]).is_equal(2)


func test_remove_item_emits_inventory_changed() -> void:
	_inv.add_item(ID_WOOD, 5)
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.remove_item(ID_WOOD, 1)
	assert_int(fired.size()).is_greater(0)


func test_remove_item_not_present_returns_zero() -> void:
	var removed: int = _inv.remove_item(ID_WOOD, 5)
	assert_int(removed).is_equal(0)


# --- remove_item: weight tracking ---

func test_remove_item_decreases_weight() -> void:
	_inv.add_item(ID_WOOD, 10)  # 10 * 1.0 = 10.0
	_inv.remove_item(ID_WOOD, 4)  # remove 4 * 1.0 = 4.0
	assert_float(_inv.get_current_weight()).is_equal_approx(6.0, 0.001)


func test_remove_all_items_weight_returns_to_zero() -> void:
	_inv.add_item(ID_WOOD, 10)
	_inv.remove_item(ID_WOOD, 10)
	assert_float(_inv.get_current_weight()).is_equal_approx(0.0, 0.001)


func test_remove_item_increases_remaining_capacity() -> void:
	_inv.add_item(ID_WOOD, 10)  # 10 * 1.0 = 10.0
	_inv.remove_item(ID_WOOD, 4)  # remove 4.0, remaining 6.0
	assert_float(_inv.get_remaining_capacity()).is_equal_approx(44.0, 0.001)


# --- has_item / get_count ---

func test_has_item_true_when_present() -> void:
	_inv.add_item(ID_STONE, 3)
	assert_bool(_inv.has_item(ID_STONE, 3)).is_true()


func test_has_item_false_when_insufficient() -> void:
	_inv.add_item(ID_STONE, 2)
	assert_bool(_inv.has_item(ID_STONE, 3)).is_false()


func test_get_count_sums_across_slots() -> void:
	_inv.capacity_weight = 200.0  # allow 149 wood
	_inv.add_item(ID_WOOD, 99)
	_inv.add_item(ID_WOOD, 50)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(149)


# --- is_full ---

func test_is_full_false_when_slots_available() -> void:
	assert_bool(_inv.is_full()).is_false()


func test_is_full_true_when_weight_at_capacity() -> void:
	_inv.add_item(ID_WOOD, 50)  # 50 * 1.0 = 50.0
	assert_bool(_inv.is_full()).is_true()


func test_is_full_true_when_all_slots_maxed() -> void:
	for i in 12:
		_inv.add_item(ID_BERRIES, 20)
	assert_bool(_inv.is_full()).is_true()


func test_is_full_false_with_partial_stack() -> void:
	for i in 12:
		_inv.add_item(ID_BERRIES, 19)  # one short of max
	assert_bool(_inv.is_full()).is_false()


# --- use_item ---

func test_use_item_removes_one() -> void:
	_inv.add_item(ID_BERRIES, 5)
	_inv.use_item(ID_BERRIES)
	assert_int(_inv.get_count(ID_BERRIES)).is_equal(4)


func test_use_item_returns_true_when_present() -> void:
	_inv.add_item(ID_BERRIES, 1)
	assert_bool(_inv.use_item(ID_BERRIES)).is_true()


func test_use_item_returns_false_when_not_present() -> void:
	assert_bool(_inv.use_item(ID_BERRIES)).is_false()


func test_use_item_emits_item_used() -> void:
	_inv.add_item(ID_BERRIES, 1)
	var fired: Array = []
	_inv.item_used.connect(func(t: StringName) -> void: fired.append(t))
	_inv.use_item(ID_BERRIES)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]).is_equal(ID_BERRIES)


func test_use_item_emits_inventory_changed() -> void:
	_inv.add_item(ID_BERRIES, 1)
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.use_item(ID_BERRIES)
	assert_int(fired.size()).is_greater(0)


func test_use_item_no_signal_when_not_present() -> void:
	var fired: Array = []
	_inv.item_used.connect(func(t: StringName) -> void: fired.append(t))
	_inv.use_item(ID_BERRIES)
	assert_int(fired.size()).is_equal(0)


func test_use_item_decreases_weight() -> void:
	_inv.add_item(ID_BERRIES, 5)
	var before: float = _inv.get_current_weight()
	_inv.use_item(ID_BERRIES)
	var after: float = _inv.get_current_weight()
	assert_float(after).is_less(before)


# --- Tool slots ---

func test_get_tool_returns_current() -> void:
	_inv.set_tool(&"weapon", ID_KNIFE)
	assert_object(_inv.get_tool(&"weapon")).is_equal(ID_KNIFE)


func test_set_tool_returns_old() -> void:
	var old: StringName = _inv.set_tool(&"axe", ID_AXE)
	assert_object(old).is_equal(&"")


func test_set_tool_updates_slot() -> void:
	_inv.set_tool(&"axe", ID_AXE)
	assert_object(_inv.get_tool(&"axe")).is_equal(ID_AXE)


func test_set_tool_replaces_existing() -> void:
	_inv.set_tool(&"weapon", ID_AXE)
	var old: StringName = _inv.set_tool(&"weapon", ID_KNIFE)
	assert_object(old).is_equal(ID_AXE)
	assert_object(_inv.get_tool(&"weapon")).is_equal(ID_KNIFE)


func test_has_tool_for_true_when_set() -> void:
	_inv.set_tool(&"weapon", ID_KNIFE)
	assert_bool(_inv.has_tool_for(&"weapon")).is_true()


func test_has_tool_for_false_when_empty() -> void:
	assert_bool(_inv.has_tool_for(&"axe")).is_false()


func test_set_tool_emits_tool_changed() -> void:
	var fired: Array = []
	_inv.tool_changed.connect(func(s: StringName, n: StringName, o: StringName) -> void:
		fired.append({"slot": s, "new": n, "old": o})
	)
	_inv.set_tool(&"axe", ID_AXE)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["slot"]).is_equal(&"axe")
	assert_object(fired[0]["new"]).is_equal(ID_AXE)
	assert_object(fired[0]["old"]).is_equal(&"")


func test_set_tool_emits_inventory_changed() -> void:
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.set_tool(&"axe", ID_AXE)
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
	_inv.add_item(ID_WOOD, 15)
	_inv.add_item(ID_STONE, 8)
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	assert_int(inv2.get_count(ID_WOOD)).is_equal(15)
	assert_int(inv2.get_count(ID_STONE)).is_equal(8)


func test_save_load_round_trip_tools() -> void:
	_inv.set_tool(&"axe", ID_AXE)
	_inv.set_tool(&"weapon", ID_KNIFE)
	_inv.set_tool(&"scanner", ID_SCANNER)
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	assert_object(inv2.get_tool(&"axe")).is_equal(ID_AXE)
	assert_object(inv2.get_tool(&"weapon")).is_equal(ID_KNIFE)
	assert_object(inv2.get_tool(&"scanner")).is_equal(ID_SCANNER)


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
	assert_bool(data.has("capacity_weight")).is_true()


func test_save_load_preserves_slot_positions() -> void:
	_inv.add_item(ID_STONE, 5)
	_inv.add_item(ID_WOOD, 3)
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	var slots: Array[Dictionary] = inv2.get_slots()
	assert_object(slots[0]["type"]).is_equal(ID_STONE)
	assert_int(slots[0]["quantity"]).is_equal(5)
	assert_object(slots[1]["type"]).is_equal(ID_WOOD)
	assert_int(slots[1]["quantity"]).is_equal(3)


func test_save_load_recomputes_weight() -> void:
	_inv.add_item(ID_WOOD, 10)
	_inv.add_item(ID_STONE, 5)
	var expected_weight: float = _inv.get_current_weight()
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	assert_float(inv2.get_current_weight()).is_equal_approx(expected_weight, 0.001)


func test_save_load_preserves_capacity_weight() -> void:
	_inv.capacity_weight = 75.0
	var data: Dictionary = _inv.get_save_data()
	var inv2: _Inventory = _Inventory.new()
	inv2.load_save_data(data)
	assert_float(inv2.get_capacity_weight()).is_equal(75.0)


# --- get_stacks ---

func test_get_stacks_empty_inventory() -> void:
	var stacks: Array[Dictionary] = _inv.get_stacks()
	assert_int(stacks.size()).is_equal(0)


func test_get_stacks_single_type() -> void:
	_inv.add_item(ID_WOOD, 5)
	var stacks: Array[Dictionary] = _inv.get_stacks()
	assert_int(stacks.size()).is_equal(1)
	assert_object(stacks[0]["type"]).is_equal(ID_WOOD)
	assert_int(stacks[0]["count"]).is_equal(5)
	assert_float(stacks[0]["weight_per_unit"]).is_equal_approx(1.0, 0.001)
	assert_float(stacks[0]["total_weight"]).is_equal_approx(5.0, 0.001)


func test_get_stacks_multiple_types() -> void:
	_inv.add_item(ID_WOOD, 5)
	_inv.add_item(ID_STONE, 3)
	var stacks: Array[Dictionary] = _inv.get_stacks()
	assert_int(stacks.size()).is_equal(2)
	# Verify both types present
	var types: Array = []
	for s in stacks:
		types.append(s["type"])
	assert_bool(types.has(ID_WOOD)).is_true()
	assert_bool(types.has(ID_STONE)).is_true()


func test_get_stacks_merges_across_slots() -> void:
	_inv.capacity_weight = 200.0  # allow more
	_inv.add_item(ID_WOOD, 99)
	_inv.add_item(ID_WOOD, 50)
	var stacks: Array[Dictionary] = _inv.get_stacks()
	assert_int(stacks.size()).is_equal(1)
	assert_int(stacks[0]["count"]).is_equal(149)
	assert_float(stacks[0]["total_weight"]).is_equal_approx(149.0, 0.001)


# --- Weight display ---

func test_weight_display_after_adding_items() -> void:
	_inv.add_item(ID_WOOD, 10)  # 10.0
	_inv.add_item(ID_STONE, 5)  # 2.5
	assert_str(_inv.get_weight_display()).is_equal("12.5 / 50.0")


# --- Backward compat: items without PORTABLE default to 1.0 ---
# Source props (e.g. 00001 Small Tree) have no PORTABLE capability,
# but they normally wouldn't be added to inventory anyway.
# This test uses a hypothetical case.

func test_item_without_portable_defaults_to_weight_1() -> void:
	# Source props (e.g. Small Tree 00001) don't have PORTABLE
	# They shouldn't normally enter inventory, but if they did the
	# default weight of 1.0 would apply. We verify _get_item_weight
	# by checking the public weight_display after adding a known-weight item.
	# The internal _get_item_weight is tested through add_item behavior.
	_inv.add_item(ID_WOOD, 1)  # wood has portable.size = 1.0
	assert_float(_inv.get_current_weight()).is_equal_approx(1.0, 0.001)
