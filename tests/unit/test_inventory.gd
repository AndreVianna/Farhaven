extends GdUnitTestSuite
class_name TestInventory

const _Inventory = preload("res://scripts/inventory/inventory.gd")

# Numeric PropDef ids used throughout this suite.
const ID_WOOD: StringName = &"00010"
const ID_STONE: StringName = &"00013"
const ID_BERRIES: StringName = &"00020"
const ID_CRYSTAL: StringName = &"00015"
const ID_AXE: StringName = &"00201"
const ID_PICKAXE: StringName = &"00202"
const ID_KNIFE: StringName = &"00204"
const ID_SCANNER: StringName = &"00205"

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
	assert_object(_inv.get_tool(&"weapon")).is_equal(ID_KNIFE)


func test_starting_tool_scanner() -> void:
	assert_object(_inv.get_tool(&"scanner")).is_equal(ID_SCANNER)


func test_starting_tool_axe_empty() -> void:
	assert_object(_inv.get_tool(&"axe")).is_equal(&"")


func test_starting_tool_pickaxe_empty() -> void:
	assert_object(_inv.get_tool(&"pickaxe")).is_equal(&"")


# --- PropRegistry-driven item config coverage ---

func test_prop_registry_has_meat() -> void:
	assert_object(PropRegistry.get_def(&"00022")).is_not_null()


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
	for id: StringName in [ID_WOOD, ID_STONE, ID_BERRIES, &"00021", &"00012", &"00014", ID_CRYSTAL]:
		var def = PropRegistry.get_def(id)
		assert_bool(def != null).override_failure_message(
			"PropRegistry must have def for %s" % id
		).is_true()
		assert_bool(def.max_stack > 0).is_true()


# --- add_item: tool routing rejection ---

func test_add_item_tool_rejected_returns_zero() -> void:
	var added: int = _inv.add_item(ID_AXE, 1)
	assert_int(added).is_equal(0)


func test_add_item_tool_does_not_appear_in_slots() -> void:
	_inv.add_item(ID_AXE, 1)
	assert_int(_inv.get_count(ID_AXE)).is_equal(0)


# --- add_item: new stack ---

func test_add_item_new_stack() -> void:
	var added: int = _inv.add_item(ID_WOOD, 5)
	assert_int(added).is_equal(5)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(5)


func test_add_item_new_stack_uses_one_slot() -> void:
	_inv.add_item(ID_WOOD, 5)
	assert_int(_inv.get_used_slot_count()).is_equal(1)


# --- add_item: partial stack fill ---

func test_add_item_fills_partial_stack() -> void:
	_inv.add_item(ID_WOOD, 90)
	# wood max_stack=99, slot has 90. Adding 15 → fills to 99 then new stack of 6
	var added: int = _inv.add_item(ID_WOOD, 15)
	assert_int(added).is_equal(15)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(105)


func test_add_item_partial_fill_reuses_existing_slot() -> void:
	_inv.add_item(ID_WOOD, 90)
	_inv.add_item(ID_WOOD, 9)
	# Both fit in the same slot (90+9=99)
	assert_int(_inv.get_used_slot_count()).is_equal(1)


func test_add_item_spills_to_new_slot_when_stack_full() -> void:
	_inv.add_item(ID_WOOD, 99)  # fills slot 0 completely
	_inv.add_item(ID_WOOD, 1)   # goes to slot 1
	assert_int(_inv.get_used_slot_count()).is_equal(2)


# --- add_item: overflow / rejection ---

func test_add_item_overflow_emits_inventory_full() -> void:
	var fired: Array = []
	_inv.inventory_full.connect(func(t: StringName, r: int) -> void:
		fired.append({"type": t, "rejected": r})
	)
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
	_inv.add_item(ID_WOOD, 99)
	_inv.add_item(ID_WOOD, 1)
	assert_int(_inv.get_used_slot_count()).is_equal(2)


func test_stacking_crystal_max_50() -> void:
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


# --- has_item / get_count ---

func test_has_item_true_when_present() -> void:
	_inv.add_item(ID_STONE, 3)
	assert_bool(_inv.has_item(ID_STONE, 3)).is_true()


func test_has_item_false_when_insufficient() -> void:
	_inv.add_item(ID_STONE, 2)
	assert_bool(_inv.has_item(ID_STONE, 3)).is_false()


func test_get_count_sums_across_slots() -> void:
	_inv.add_item(ID_WOOD, 99)
	_inv.add_item(ID_WOOD, 50)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(149)


# --- is_full ---

func test_is_full_false_when_slots_available() -> void:
	assert_bool(_inv.is_full()).is_false()


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


# --- Tool slots ---

func test_get_tool_returns_current() -> void:
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
