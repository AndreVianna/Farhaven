extends GdUnitTestSuite
class_name TestInventory

## Tests for the grid-based Inventory (delivery-006f, tasks 090+091).
## Props have varying shapes: berries/fiber/rock are 1-cell, wood is 2-cell,
## stone is 2x2 (4-cell). Tests that need single-cell items use berries/fiber.

const _Inventory = preload("res://scripts/inventory/inventory.gd")

# Real prop IDs (all single-cell shapes via PropRegistry).
const ID_WOOD: StringName = &"P00010"
const ID_STONE: StringName = &"P00013"
const ID_BERRIES: StringName = &"P00020"
const ID_SCANNER: StringName = &"P00205"
const ID_ROCK: StringName = &"P00011"
const ID_FIBER: StringName = &"P00012"

# Reusable multi-cell shapes for grid-engine tests.
var _line_3: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
var _l_shape: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2),
]
var _single: Array[Vector2i] = [Vector2i(0, 0)]

var _inv: _Inventory


func before_test() -> void:
	_inv = _Inventory.new(5, 5)


func after_test() -> void:
	_inv = null


# ---------------------------------------------------------------------------
# 1. Construction
# ---------------------------------------------------------------------------

func test_default_grid_is_30x40() -> void:
	var inv := _Inventory.new()
	assert_int(inv.grid_width).is_equal(30)
	assert_int(inv.grid_height).is_equal(40)
	assert_float(inv.get_capacity_size()).is_equal(1200.0)


func test_custom_grid_size() -> void:
	assert_int(_inv.grid_width).is_equal(5)
	assert_int(_inv.grid_height).is_equal(5)
	assert_float(_inv.get_capacity_size()).is_equal(25.0)


func test_new_grid_all_cells_empty() -> void:
	assert_float(_inv.get_current_size()).is_equal(0.0)
	assert_int(_inv.get_used_slot_count()).is_equal(0)


# ---------------------------------------------------------------------------
# 2. Shape rotation (static utilities)
# ---------------------------------------------------------------------------

func test_rotate_single_cell_is_noop() -> void:
	var result: Array[Vector2i] = _Inventory.rotate_shape_once(_single)
	assert_int(result.size()).is_equal(1)
	assert_that(result[0]).is_equal(Vector2i(0, 0))


func test_rotate_line_90cw() -> void:
	# Horizontal line (3x1) -> vertical line (1x3) after 90 CW
	var result: Array[Vector2i] = _Inventory.rotate_shape_once(_line_3)
	assert_int(result.size()).is_equal(3)
	# (0,0)->(-0,0)=(0,0), (1,0)->(0,1), (2,0)->(0,2)
	assert_that(result[0]).is_equal(Vector2i(0, 0))
	assert_that(result[1]).is_equal(Vector2i(0, 1))
	assert_that(result[2]).is_equal(Vector2i(0, 2))


func test_rotate_l_shape_4_rotations_return_to_original() -> void:
	var shape: Array[Vector2i] = _l_shape.duplicate()
	var rotated: Array[Vector2i] = _Inventory.get_rotated_shape(shape, 4)
	# 4 rotations = identity
	rotated.sort()
	var original: Array[Vector2i] = shape.duplicate()
	original.sort()
	assert_int(rotated.size()).is_equal(original.size())
	for i in rotated.size():
		assert_that(rotated[i]).is_equal(original[i])


func test_get_rotated_shape_0_returns_copy() -> void:
	var result: Array[Vector2i] = _Inventory.get_rotated_shape(_line_3, 0)
	assert_int(result.size()).is_equal(3)
	assert_that(result[0]).is_equal(Vector2i(0, 0))
	assert_that(result[2]).is_equal(Vector2i(2, 0))


func test_get_shape_bounds_single_cell() -> void:
	var bounds: Vector2i = _Inventory.get_shape_bounds(_single)
	assert_that(bounds).is_equal(Vector2i(1, 1))


func test_get_shape_bounds_line() -> void:
	var bounds: Vector2i = _Inventory.get_shape_bounds(_line_3)
	assert_that(bounds).is_equal(Vector2i(3, 1))


func test_get_shape_bounds_l_shape() -> void:
	var bounds: Vector2i = _Inventory.get_shape_bounds(_l_shape)
	assert_that(bounds).is_equal(Vector2i(2, 3))


# ---------------------------------------------------------------------------
# 3. Placement (can_fit, find_placement, place_item, place_item_at)
# ---------------------------------------------------------------------------

func test_can_fit_single_cell_in_empty_grid() -> void:
	assert_bool(_inv.can_fit(_single, Vector2i(0, 0))).is_true()


func test_can_fit_at_last_cell() -> void:
	assert_bool(_inv.can_fit(_single, Vector2i(4, 4))).is_true()


func test_can_fit_fails_out_of_bounds() -> void:
	assert_bool(_inv.can_fit(_single, Vector2i(5, 0))).is_false()
	assert_bool(_inv.can_fit(_single, Vector2i(0, 5))).is_false()
	assert_bool(_inv.can_fit(_single, Vector2i(-1, 0))).is_false()


func test_can_fit_line_at_edge() -> void:
	# 3-wide line at x=2 in 5-wide grid: cells 2,3,4 — fits
	assert_bool(_inv.can_fit(_line_3, Vector2i(2, 0))).is_true()
	# At x=3: cells 3,4,5 — out of bounds
	assert_bool(_inv.can_fit(_line_3, Vector2i(3, 0))).is_false()


func test_can_fit_fails_on_overlap() -> void:
	_inv.place_item_at(ID_WOOD, Vector2i(0, 0))
	assert_bool(_inv.can_fit(_single, Vector2i(0, 0))).is_false()


func test_place_item_at_returns_item_id() -> void:
	var id: int = _inv.place_item_at(ID_WOOD, Vector2i(0, 0))
	assert_int(id).is_greater(0)


func test_place_item_at_fails_on_overlap() -> void:
	_inv.place_item_at(ID_WOOD, Vector2i(0, 0))
	var id: int = _inv.place_item_at(ID_STONE, Vector2i(0, 0))
	assert_int(id).is_equal(0)


func test_place_item_auto_places_in_empty_grid() -> void:
	var id: int = _inv.place_item(ID_WOOD)
	assert_int(id).is_greater(0)


func test_find_placement_finds_first_fit() -> void:
	var result: Dictionary = _inv.find_placement(_single)
	assert_bool(result.is_empty()).is_false()
	assert_that(result["origin"]).is_equal(Vector2i(0, 0))
	assert_int(result["rotation"]).is_equal(0)


func test_find_placement_skips_occupied_cell() -> void:
	_inv.place_item_at(ID_BERRIES, Vector2i(0, 0))
	var result: Dictionary = _inv.find_placement(_single)
	assert_bool(result.is_empty()).is_false()
	# Should find (1,0) next since scanning left-to-right
	assert_that(result["origin"]).is_equal(Vector2i(1, 0))


# ---------------------------------------------------------------------------
# 4. Item operations (remove, move, get_item, get_items_by_type, get_count)
# ---------------------------------------------------------------------------

func test_remove_item_by_id_frees_cells() -> void:
	var id: int = _inv.place_item_at(ID_BERRIES, Vector2i(0, 0))
	assert_float(_inv.get_current_size()).is_equal(1.0)
	var ok: bool = _inv.remove_item_by_id(id)
	assert_bool(ok).is_true()
	assert_float(_inv.get_current_size()).is_equal(0.0)
	# Cell is free again
	assert_bool(_inv.can_fit(_single, Vector2i(0, 0))).is_true()


func test_remove_item_by_id_invalid_returns_false() -> void:
	assert_bool(_inv.remove_item_by_id(999)).is_false()


func test_move_item_to_new_position() -> void:
	var id: int = _inv.place_item_at(ID_WOOD, Vector2i(0, 0))
	var ok: bool = _inv.move_item(id, Vector2i(3, 3), 0)
	assert_bool(ok).is_true()
	var data: Variant = _inv.get_item(id)
	assert_that(data["origin"]).is_equal(Vector2i(3, 3))
	# Old cell is free
	assert_bool(_inv.can_fit(_single, Vector2i(0, 0))).is_true()


func test_move_item_fails_on_overlap() -> void:
	var id1: int = _inv.place_item_at(ID_BERRIES, Vector2i(0, 0))
	_inv.place_item_at(ID_BERRIES, Vector2i(1, 0))
	var ok: bool = _inv.move_item(id1, Vector2i(1, 0), 0)
	assert_bool(ok).is_false()
	# Item should still be in original position
	var data: Variant = _inv.get_item(id1)
	assert_that(data["origin"]).is_equal(Vector2i(0, 0))


func test_get_item_returns_data() -> void:
	var id: int = _inv.place_item_at(ID_WOOD, Vector2i(2, 3))
	var data: Variant = _inv.get_item(id)
	assert_object(data).is_not_null()
	assert_object(data["type"]).is_equal(ID_WOOD)
	assert_that(data["origin"]).is_equal(Vector2i(2, 3))
	assert_int(data["rotation"]).is_equal(0)


func test_get_item_returns_null_for_invalid_id() -> void:
	assert_object(_inv.get_item(999)).is_null()


func test_get_items_by_type() -> void:
	_inv.place_item_at(ID_BERRIES, Vector2i(0, 0))
	_inv.place_item_at(ID_BERRIES, Vector2i(1, 0))
	_inv.place_item_at(ID_FIBER, Vector2i(2, 0))
	var berry_ids: Array[int] = _inv.get_items_by_type(ID_BERRIES)
	assert_int(berry_ids.size()).is_equal(2)
	var fiber_ids: Array[int] = _inv.get_items_by_type(ID_FIBER)
	assert_int(fiber_ids.size()).is_equal(1)


func test_get_count() -> void:
	_inv.place_item_at(ID_BERRIES, Vector2i(0, 0))
	_inv.place_item_at(ID_BERRIES, Vector2i(1, 0))
	assert_int(_inv.get_count(ID_BERRIES)).is_equal(2)
	assert_int(_inv.get_count(ID_FIBER)).is_equal(0)


# ---------------------------------------------------------------------------
# 5. Backward-compat API (add_item, remove_item, has_item, use_item)
# ---------------------------------------------------------------------------

func test_add_item_places_items_returns_count() -> void:
	var added: int = _inv.add_item(ID_WOOD, 3)
	assert_int(added).is_equal(3)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(3)


func test_add_item_rejects_scanner() -> void:
	var added: int = _inv.add_item(ID_SCANNER, 1)
	assert_int(added).is_equal(0)
	assert_int(_inv.get_count(ID_SCANNER)).is_equal(0)


func test_remove_item_removes_n_instances() -> void:
	_inv.add_item(ID_WOOD, 5)
	var removed: int = _inv.remove_item(ID_WOOD, 3)
	assert_int(removed).is_equal(3)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(2)


func test_remove_item_caps_at_available() -> void:
	_inv.add_item(ID_WOOD, 2)
	var removed: int = _inv.remove_item(ID_WOOD, 10)
	assert_int(removed).is_equal(2)
	assert_int(_inv.get_count(ID_WOOD)).is_equal(0)


func test_remove_item_not_present_returns_zero() -> void:
	var removed: int = _inv.remove_item(ID_WOOD, 1)
	assert_int(removed).is_equal(0)


func test_has_item_true_when_sufficient() -> void:
	_inv.add_item(ID_WOOD, 5)
	assert_bool(_inv.has_item(ID_WOOD, 5)).is_true()
	assert_bool(_inv.has_item(ID_WOOD, 3)).is_true()


func test_has_item_false_when_insufficient() -> void:
	_inv.add_item(ID_WOOD, 2)
	assert_bool(_inv.has_item(ID_WOOD, 3)).is_false()


func test_use_item_removes_one_returns_true() -> void:
	_inv.add_item(ID_BERRIES, 3)
	var ok: bool = _inv.use_item(ID_BERRIES)
	assert_bool(ok).is_true()
	assert_int(_inv.get_count(ID_BERRIES)).is_equal(2)


func test_use_item_not_present_returns_false() -> void:
	assert_bool(_inv.use_item(ID_BERRIES)).is_false()


# ---------------------------------------------------------------------------
# 6. Grid full / overflow
# ---------------------------------------------------------------------------

func test_is_full_false_when_empty() -> void:
	assert_bool(_inv.is_full()).is_false()


func test_fill_small_grid_completely() -> void:
	# 5x5 = 25 cells; berries are single-cell
	var added: int = _inv.add_item(ID_BERRIES, 25)
	assert_int(added).is_equal(25)
	assert_bool(_inv.is_full()).is_true()


func test_add_item_on_full_grid_returns_zero() -> void:
	_inv.add_item(ID_BERRIES, 25)
	var added: int = _inv.add_item(ID_FIBER, 1)
	assert_int(added).is_equal(0)


func test_add_item_partial_fit_on_nearly_full_grid() -> void:
	_inv.add_item(ID_BERRIES, 23)
	var added: int = _inv.add_item(ID_FIBER, 5)
	assert_int(added).is_equal(2)
	assert_bool(_inv.is_full()).is_true()


func test_get_remaining_capacity() -> void:
	_inv.add_item(ID_BERRIES, 10)
	assert_float(_inv.get_remaining_capacity()).is_equal(15.0)


# ---------------------------------------------------------------------------
# 7. Size / capacity compat
# ---------------------------------------------------------------------------

func test_capacity_size_property_get() -> void:
	assert_float(_inv.capacity_size).is_equal(25.0)


func test_capacity_size_property_set_resizes_grid() -> void:
	_inv.capacity_size = 100.0
	assert_float(_inv.get_capacity_size()).is_greater_equal(100.0)


func test_get_current_size_tracks_occupied_cells() -> void:
	_inv.add_item(ID_BERRIES, 7)
	assert_float(_inv.get_current_size()).is_equal(7.0)


func test_get_slots_groups_by_type() -> void:
	_inv.add_item(ID_BERRIES, 3)
	_inv.add_item(ID_FIBER, 2)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_int(slots.size()).is_equal(2)
	var types: Array = []
	for s in slots:
		types.append(s["type"])
	assert_bool(types.has(ID_BERRIES)).is_true()
	assert_bool(types.has(ID_FIBER)).is_true()


func test_get_stacks_includes_size_info() -> void:
	_inv.add_item(ID_BERRIES, 4)
	var stacks: Array[Dictionary] = _inv.get_stacks()
	assert_int(stacks.size()).is_equal(1)
	assert_object(stacks[0]["type"]).is_equal(ID_BERRIES)
	assert_int(stacks[0]["count"]).is_equal(4)
	assert_float(stacks[0]["size_per_unit"]).is_equal(1.0)
	assert_float(stacks[0]["total_size"]).is_equal(4.0)


# ---------------------------------------------------------------------------
# 8. Tool slots (scanner only)
# ---------------------------------------------------------------------------

func test_scanner_slot_starts_empty() -> void:
	assert_object(_inv.get_tool(&"scanner")).is_equal(&"")
	assert_bool(_inv.has_tool_for(&"scanner")).is_false()


func test_set_tool_scanner() -> void:
	var old: StringName = _inv.set_tool(&"scanner", ID_SCANNER)
	assert_object(old).is_equal(&"")
	assert_object(_inv.get_tool(&"scanner")).is_equal(ID_SCANNER)
	assert_bool(_inv.has_tool_for(&"scanner")).is_true()


func test_set_tool_replaces_and_returns_old() -> void:
	_inv.set_tool(&"scanner", ID_SCANNER)
	var old: StringName = _inv.set_tool(&"scanner", &"P99999")
	assert_object(old).is_equal(ID_SCANNER)


# ---------------------------------------------------------------------------
# 9. Save / load
# ---------------------------------------------------------------------------

func test_save_data_has_required_keys() -> void:
	var data: Dictionary = _inv.get_save_data()
	assert_bool(data.has("grid_width")).is_true()
	assert_bool(data.has("grid_height")).is_true()
	assert_bool(data.has("items")).is_true()
	assert_bool(data.has("scanner")).is_true()


func test_save_load_round_trip_items() -> void:
	_inv.place_item_at(ID_WOOD, Vector2i(0, 0))
	_inv.place_item_at(ID_STONE, Vector2i(2, 3))
	var data: Dictionary = _inv.get_save_data()
	var inv2 := _Inventory.new(5, 5)
	inv2.load_save_data(data)
	assert_int(inv2.get_count(ID_WOOD)).is_equal(1)
	assert_int(inv2.get_count(ID_STONE)).is_equal(1)
	# Verify positions preserved
	var wood_ids: Array[int] = inv2.get_items_by_type(ID_WOOD)
	var wood_item: Variant = inv2.get_item(wood_ids[0])
	assert_that(wood_item["origin"]).is_equal(Vector2i(0, 0))
	var stone_ids: Array[int] = inv2.get_items_by_type(ID_STONE)
	var stone_item: Variant = inv2.get_item(stone_ids[0])
	assert_that(stone_item["origin"]).is_equal(Vector2i(2, 3))


func test_save_load_round_trip_scanner() -> void:
	_inv.set_tool(&"scanner", ID_SCANNER)
	var data: Dictionary = _inv.get_save_data()
	var inv2 := _Inventory.new(5, 5)
	inv2.load_save_data(data)
	assert_object(inv2.get_tool(&"scanner")).is_equal(ID_SCANNER)


func test_save_load_preserves_grid_dimensions() -> void:
	var data: Dictionary = _inv.get_save_data()
	var inv2 := _Inventory.new()
	inv2.load_save_data(data)
	assert_int(inv2.grid_width).is_equal(5)
	assert_int(inv2.grid_height).is_equal(5)


func test_load_legacy_save_migrates_slots() -> void:
	# Legacy format: {slots: [{type, quantity}], tools: {scanner: ...}}
	var legacy_data: Dictionary = {
		"slots": [
			{"type": "P00010", "quantity": 3},
			{"type": "P00013", "quantity": 2},
		],
		"tools": {
			"scanner": "P00205",
		},
	}
	var inv2 := _Inventory.new()
	inv2.load_save_data(legacy_data)
	assert_int(inv2.get_count(ID_WOOD)).is_equal(3)
	assert_int(inv2.get_count(ID_STONE)).is_equal(2)
	assert_object(inv2.get_tool(&"scanner")).is_equal(ID_SCANNER)


func test_save_load_round_trip_recomputes_size() -> void:
	_inv.add_item(ID_WOOD, 5)
	var expected: float = _inv.get_current_size()
	var data: Dictionary = _inv.get_save_data()
	var inv2 := _Inventory.new(5, 5)
	inv2.load_save_data(data)
	assert_float(inv2.get_current_size()).is_equal(expected)


# ---------------------------------------------------------------------------
# 10. Signals
# ---------------------------------------------------------------------------

func test_add_item_emits_item_added() -> void:
	var fired: Array = []
	_inv.item_added.connect(func(t: StringName, a: int) -> void: fired.append({"type": t, "amount": a}))
	_inv.add_item(ID_WOOD, 3)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["type"]).is_equal(ID_WOOD)
	assert_int(fired[0]["amount"]).is_equal(3)


func test_add_item_emits_inventory_changed() -> void:
	var fired: Array = []
	_inv.inventory_changed.connect(func() -> void: fired.append(1))
	_inv.add_item(ID_WOOD, 1)
	assert_int(fired.size()).is_equal(1)


func test_add_item_on_full_grid_emits_inventory_full() -> void:
	_inv.add_item(ID_BERRIES, 25)
	var fired: Array = []
	_inv.inventory_full.connect(func(t: StringName, r: int) -> void: fired.append({"type": t, "rejected": r}))
	_inv.add_item(ID_FIBER, 3)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["type"]).is_equal(ID_FIBER)
	assert_int(fired[0]["rejected"]).is_equal(3)


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
	assert_int(fired.size()).is_equal(1)


func test_use_item_emits_item_used() -> void:
	_inv.add_item(ID_BERRIES, 2)
	var fired: Array = []
	_inv.item_used.connect(func(t: StringName) -> void: fired.append(t))
	_inv.use_item(ID_BERRIES)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]).is_equal(ID_BERRIES)


func test_set_tool_emits_tool_changed() -> void:
	var fired: Array = []
	_inv.tool_changed.connect(func(s: StringName, n: StringName, o: StringName) -> void:
		fired.append({"slot": s, "new": n, "old": o})
	)
	_inv.set_tool(&"scanner", ID_SCANNER)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["slot"]).is_equal(&"scanner")
	assert_object(fired[0]["new"]).is_equal(ID_SCANNER)
	assert_object(fired[0]["old"]).is_equal(&"")


func test_partial_add_emits_both_item_added_and_inventory_full() -> void:
	_inv.add_item(ID_BERRIES, 23)
	var added_fired: Array = []
	var full_fired: Array = []
	_inv.item_added.connect(func(t: StringName, a: int) -> void: added_fired.append(a))
	_inv.inventory_full.connect(func(t: StringName, r: int) -> void: full_fired.append(r))
	_inv.add_item(ID_FIBER, 5)
	assert_int(added_fired.size()).is_equal(1)
	assert_int(added_fired[0]).is_equal(2)
	assert_int(full_fired.size()).is_equal(1)
	assert_int(full_fired[0]).is_equal(3)
