extends GdUnitTestSuite
class_name TestInventoryGrid

## Grid-engine focused tests for the Tetris inventory (delivery-006f, task-098).
## Uses real PropRegistry data (multi-cell shapes) to exercise placement, rotation,
## add/remove, tool slots, save/load round-trip, and backward-compat APIs.

const _Inventory = preload("res://scripts/inventory/inventory.gd")

# Real prop IDs — shapes via PropRegistry.
const ID_WOOD: StringName = &"P00010"      # 2-cell horizontal [0,0],[1,0]
const ID_ROCK: StringName = &"P00011"      # 1-cell
const ID_BERRY: StringName = &"P00020"     # 1-cell
const ID_STONE: StringName = &"P00013"     # 4-cell 2x2
const ID_AXE: StringName = &"P00201"       # 7-cell L, tool_slot = "axe"
const ID_KNIFE: StringName = &"P00204"     # 4-cell L, tool_slot = "weapon"
const ID_SCANNER: StringName = &"P00205"   # 1-cell, tool_slot = "scanner"

var _inv: _Inventory


func before_test() -> void:
	_inv = _Inventory.new()


func after_test() -> void:
	_inv = null


# ---------------------------------------------------------------------------
# 1. Grid initialization
# ---------------------------------------------------------------------------

func test_empty_grid_has_default_dimensions() -> void:
	assert_int(_inv.grid_width).is_equal(30)
	assert_int(_inv.grid_height).is_equal(40)


func test_custom_dimensions_via_init() -> void:
	var inv := _Inventory.new(10, 20)
	assert_int(inv.grid_width).is_equal(10)
	assert_int(inv.grid_height).is_equal(20)


func test_all_cells_start_at_zero() -> void:
	var inv := _Inventory.new(3, 3)
	assert_float(inv.get_current_size()).is_equal(0.0)
	assert_bool(inv.is_full()).is_false()


# ---------------------------------------------------------------------------
# 2. Shape rotation (static methods)
# ---------------------------------------------------------------------------

func test_rotate_shape_once_single_cell_stays_at_origin() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	var result: Array[Vector2i] = _Inventory.rotate_shape_once(shape)
	assert_int(result.size()).is_equal(1)
	assert_that(result[0]).is_equal(Vector2i(0, 0))


func test_rotate_shape_once_2x1_horizontal_becomes_1x2_vertical() -> void:
	# Wood shape: [0,0],[1,0] → rotate CW → [0,0],[0,1]
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var result: Array[Vector2i] = _Inventory.rotate_shape_once(shape)
	assert_int(result.size()).is_equal(2)
	var sorted := result.duplicate()
	sorted.sort()
	assert_that(sorted[0]).is_equal(Vector2i(0, 0))
	assert_that(sorted[1]).is_equal(Vector2i(0, 1))


func test_rotate_shape_once_l_shape_rotates_correctly() -> void:
	# Knife shape: [0,0],[0,1],[0,2],[1,2] — vertical L
	var shape: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2),
	]
	var result: Array[Vector2i] = _Inventory.rotate_shape_once(shape)
	# After 90 CW: (x,y)->(-y,x) then normalize.
	# (0,0)->(0,0), (0,1)->(-1,0), (0,2)->(-2,0), (1,2)->(-2,1)
	# Normalize by shifting +2 in x: (2,0),(1,0),(0,0),(0,1)
	var sorted := result.duplicate()
	sorted.sort()
	assert_int(sorted.size()).is_equal(4)
	assert_that(sorted[0]).is_equal(Vector2i(0, 0))
	assert_that(sorted[1]).is_equal(Vector2i(0, 1))
	assert_that(sorted[2]).is_equal(Vector2i(1, 0))
	assert_that(sorted[3]).is_equal(Vector2i(2, 0))


func test_get_rotated_shape_0_rotations_is_identity() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var result: Array[Vector2i] = _Inventory.get_rotated_shape(shape, 0)
	assert_int(result.size()).is_equal(2)
	assert_that(result[0]).is_equal(Vector2i(0, 0))
	assert_that(result[1]).is_equal(Vector2i(1, 0))


func test_get_rotated_shape_4_rotations_is_identity() -> void:
	var shape: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2),
	]
	var result: Array[Vector2i] = _Inventory.get_rotated_shape(shape, 4)
	var sorted_result := result.duplicate()
	sorted_result.sort()
	var sorted_orig := shape.duplicate()
	sorted_orig.sort()
	assert_int(sorted_result.size()).is_equal(sorted_orig.size())
	for i in sorted_result.size():
		assert_that(sorted_result[i]).is_equal(sorted_orig[i])


func test_get_shape_bounds_correct_bounding_box() -> void:
	# 2x2 stone shape
	var shape_2x2: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
	]
	assert_that(_Inventory.get_shape_bounds(shape_2x2)).is_equal(Vector2i(2, 2))

	# Single cell
	var single: Array[Vector2i] = [Vector2i(0, 0)]
	assert_that(_Inventory.get_shape_bounds(single)).is_equal(Vector2i(1, 1))

	# L-shape knife: max x=1, max y=2 => bounds (2, 3)
	var l_shape: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2),
	]
	assert_that(_Inventory.get_shape_bounds(l_shape)).is_equal(Vector2i(2, 3))


# ---------------------------------------------------------------------------
# 3. Placement (can_fit, find_placement)
# ---------------------------------------------------------------------------

func test_can_fit_1_cell_at_origin_on_empty_grid() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	assert_bool(_inv.can_fit(shape, Vector2i(0, 0))).is_true()


func test_can_fit_shape_at_grid_edge_fits_exactly() -> void:
	var inv := _Inventory.new(5, 5)
	# 2-cell horizontal at x=3 in 5-wide grid: cells 3,4 — fits
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	assert_bool(inv.can_fit(shape, Vector2i(3, 0))).is_true()


func test_can_fit_shape_overlapping_edge_returns_false() -> void:
	var inv := _Inventory.new(5, 5)
	# 2-cell horizontal at x=4 in 5-wide grid: cells 4,5 — out of bounds
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	assert_bool(inv.can_fit(shape, Vector2i(4, 0))).is_false()


func test_can_fit_shape_overlapping_existing_item_returns_false() -> void:
	var inv := _Inventory.new(5, 5)
	inv.place_item_at(ID_ROCK, Vector2i(1, 0))
	# 2-cell horizontal at x=0: cells 0,1 — cell 1 is occupied
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	assert_bool(inv.can_fit(shape, Vector2i(0, 0))).is_false()


func test_can_fit_with_exclude_id_ignores_that_item() -> void:
	var inv := _Inventory.new(5, 5)
	var id: int = inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	# Without exclude: blocked
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	assert_bool(inv.can_fit(shape, Vector2i(0, 0), 0, 0)).is_false()
	# With exclude: ignores that item
	assert_bool(inv.can_fit(shape, Vector2i(0, 0), 0, id)).is_true()


func test_find_placement_finds_first_fit_for_1_cell_on_empty_grid() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	var result: Dictionary = _inv.find_placement(shape)
	assert_bool(result.is_empty()).is_false()
	assert_that(result["origin"]).is_equal(Vector2i(0, 0))
	assert_int(result["rotation"]).is_equal(0)


func test_find_placement_finds_fit_around_existing_items() -> void:
	var inv := _Inventory.new(5, 5)
	# Fill origin cell
	inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	var result: Dictionary = inv.find_placement(shape)
	assert_bool(result.is_empty()).is_false()
	# Should skip (0,0) and find (1,0)
	assert_that(result["origin"]).is_equal(Vector2i(1, 0))


func test_find_placement_returns_empty_dict_when_grid_full() -> void:
	var inv := _Inventory.new(2, 2)
	inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	inv.place_item_at(ID_ROCK, Vector2i(1, 0))
	inv.place_item_at(ID_ROCK, Vector2i(0, 1))
	inv.place_item_at(ID_ROCK, Vector2i(1, 1))
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	var result: Dictionary = inv.find_placement(shape)
	assert_bool(result.is_empty()).is_true()


# ---------------------------------------------------------------------------
# 4. Add/remove items
# ---------------------------------------------------------------------------

func test_add_item_adds_1_berry_get_count_returns_1() -> void:
	var added: int = _inv.add_item(ID_BERRY, 1)
	assert_int(added).is_equal(1)
	assert_int(_inv.get_count(ID_BERRY)).is_equal(1)


func test_add_item_adds_5_berries_get_count_returns_5() -> void:
	var added: int = _inv.add_item(ID_BERRY, 5)
	assert_int(added).is_equal(5)
	assert_int(_inv.get_count(ID_BERRY)).is_equal(5)


func test_add_item_returns_count_added() -> void:
	# On a small grid, adding more than fits should return partial count
	var inv := _Inventory.new(3, 1)
	# Berry is 1-cell, grid has 3 cells
	var added: int = inv.add_item(ID_BERRY, 5)
	assert_int(added).is_equal(3)


func test_add_item_rejects_tools_with_tool_slot() -> void:
	# Axe has tool_slot = "axe" — add_item should reject
	var added: int = _inv.add_item(ID_AXE, 1)
	assert_int(added).is_equal(0)
	assert_int(_inv.get_count(ID_AXE)).is_equal(0)

	# Scanner has tool_slot = "scanner"
	added = _inv.add_item(ID_SCANNER, 1)
	assert_int(added).is_equal(0)

	# Knife has tool_slot = "weapon"
	added = _inv.add_item(ID_KNIFE, 1)
	assert_int(added).is_equal(0)


func test_add_item_emits_item_added_signal() -> void:
	var fired := [0]
	_inv.item_added.connect(func(_t: StringName, _a: int) -> void: fired[0] += 1)
	_inv.add_item(ID_BERRY, 2)
	assert_int(fired[0]).is_equal(1)


func test_add_item_emits_inventory_changed_signal() -> void:
	var fired := [0]
	_inv.inventory_changed.connect(func() -> void: fired[0] += 1)
	_inv.add_item(ID_BERRY, 1)
	assert_int(fired[0]).is_equal(1)


func test_add_item_emits_inventory_full_when_grid_cant_fit() -> void:
	var inv := _Inventory.new(2, 2)
	inv.add_item(ID_BERRY, 4)  # fills the grid
	var fired := [0]
	inv.inventory_full.connect(func(_t: StringName, _r: int) -> void: fired[0] += 1)
	inv.add_item(ID_BERRY, 1)
	assert_int(fired[0]).is_equal(1)


func test_remove_item_removes_by_type_returns_count() -> void:
	_inv.add_item(ID_BERRY, 5)
	var removed: int = _inv.remove_item(ID_BERRY, 3)
	assert_int(removed).is_equal(3)
	assert_int(_inv.get_count(ID_BERRY)).is_equal(2)


func test_remove_item_emits_item_removed_signal() -> void:
	_inv.add_item(ID_BERRY, 3)
	var fired := [0]
	_inv.item_removed.connect(func(_t: StringName, _a: int) -> void: fired[0] += 1)
	_inv.remove_item(ID_BERRY, 1)
	assert_int(fired[0]).is_equal(1)


func test_remove_item_partial_removal_when_not_enough() -> void:
	_inv.add_item(ID_BERRY, 2)
	var removed: int = _inv.remove_item(ID_BERRY, 10)
	assert_int(removed).is_equal(2)
	assert_int(_inv.get_count(ID_BERRY)).is_equal(0)


func test_has_item_true_when_sufficient_count() -> void:
	_inv.add_item(ID_BERRY, 5)
	assert_bool(_inv.has_item(ID_BERRY, 3)).is_true()
	assert_bool(_inv.has_item(ID_BERRY, 5)).is_true()


func test_has_item_false_when_insufficient_count() -> void:
	_inv.add_item(ID_BERRY, 2)
	assert_bool(_inv.has_item(ID_BERRY, 3)).is_false()


func test_use_item_removes_1_and_emits_item_used() -> void:
	_inv.add_item(ID_BERRY, 3)
	var fired := [0]
	_inv.item_used.connect(func(_t: StringName) -> void: fired[0] += 1)
	var ok: bool = _inv.use_item(ID_BERRY)
	assert_bool(ok).is_true()
	assert_int(_inv.get_count(ID_BERRY)).is_equal(2)
	assert_int(fired[0]).is_equal(1)


# ---------------------------------------------------------------------------
# 5. Grid-specific operations
# ---------------------------------------------------------------------------

func test_place_item_returns_item_id_greater_than_zero() -> void:
	var id: int = _inv.place_item(ID_ROCK)
	assert_int(id).is_greater(0)


func test_place_item_at_places_at_specific_position() -> void:
	var id: int = _inv.place_item_at(ID_ROCK, Vector2i(5, 5))
	assert_int(id).is_greater(0)
	var data: Variant = _inv.get_item(id)
	assert_that(data["origin"]).is_equal(Vector2i(5, 5))


func test_place_item_at_returns_0_when_position_blocked() -> void:
	_inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	var id: int = _inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	assert_int(id).is_equal(0)


func test_remove_item_by_id_frees_cells() -> void:
	var id: int = _inv.place_item_at(ID_WOOD, Vector2i(0, 0))
	# Wood is 2-cell horizontal: occupies (0,0) and (1,0)
	assert_float(_inv.get_current_size()).is_equal(2.0)
	_inv.remove_item_by_id(id)
	assert_float(_inv.get_current_size()).is_equal(0.0)
	# Cells should be free again
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	assert_bool(_inv.can_fit(shape, Vector2i(0, 0))).is_true()
	assert_bool(_inv.can_fit(shape, Vector2i(1, 0))).is_true()


func test_move_item_to_new_position() -> void:
	var id: int = _inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	var ok: bool = _inv.move_item(id, Vector2i(10, 10), 0)
	assert_bool(ok).is_true()
	var data: Variant = _inv.get_item(id)
	assert_that(data["origin"]).is_equal(Vector2i(10, 10))
	# Old cell should be free
	var shape: Array[Vector2i] = [Vector2i(0, 0)]
	assert_bool(_inv.can_fit(shape, Vector2i(0, 0))).is_true()


func test_move_item_fails_when_destination_blocked() -> void:
	var id1: int = _inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	_inv.place_item_at(ID_ROCK, Vector2i(1, 0))
	var ok: bool = _inv.move_item(id1, Vector2i(1, 0), 0)
	assert_bool(ok).is_false()
	# Item should remain at original position
	var data: Variant = _inv.get_item(id1)
	assert_that(data["origin"]).is_equal(Vector2i(0, 0))


func test_get_item_returns_item_data() -> void:
	var id: int = _inv.place_item_at(ID_WOOD, Vector2i(3, 7))
	var data: Variant = _inv.get_item(id)
	assert_object(data).is_not_null()
	assert_object(data["type"]).is_equal(ID_WOOD)
	assert_that(data["origin"]).is_equal(Vector2i(3, 7))
	assert_int(data["rotation"]).is_equal(0)


func test_get_items_by_type_returns_matching_ids() -> void:
	_inv.place_item_at(ID_ROCK, Vector2i(0, 0))
	_inv.place_item_at(ID_ROCK, Vector2i(1, 0))
	_inv.place_item_at(ID_WOOD, Vector2i(5, 5))
	var rock_ids: Array[int] = _inv.get_items_by_type(ID_ROCK)
	assert_int(rock_ids.size()).is_equal(2)
	var wood_ids: Array[int] = _inv.get_items_by_type(ID_WOOD)
	assert_int(wood_ids.size()).is_equal(1)


# ---------------------------------------------------------------------------
# 6. Tool slots
# ---------------------------------------------------------------------------

func test_get_tool_returns_empty_for_unset_slot() -> void:
	assert_object(_inv.get_tool(&"scanner")).is_equal(&"")
	assert_object(_inv.get_tool(&"axe")).is_equal(&"")


func test_set_tool_stores_and_retrieves_tool() -> void:
	_inv.set_tool(&"scanner", ID_SCANNER)
	assert_object(_inv.get_tool(&"scanner")).is_equal(ID_SCANNER)


func test_set_tool_emits_tool_changed_signal() -> void:
	var fired: Array = []
	_inv.tool_changed.connect(func(s: StringName, n: StringName, o: StringName) -> void:
		fired.append({"slot": s, "new": n, "old": o})
	)
	_inv.set_tool(&"scanner", ID_SCANNER)
	assert_int(fired.size()).is_equal(1)
	assert_object(fired[0]["slot"]).is_equal(&"scanner")
	assert_object(fired[0]["new"]).is_equal(ID_SCANNER)
	assert_object(fired[0]["old"]).is_equal(&"")


func test_has_tool_for_true_when_set() -> void:
	_inv.set_tool(&"scanner", ID_SCANNER)
	assert_bool(_inv.has_tool_for(&"scanner")).is_true()


func test_has_tool_for_false_when_not_set() -> void:
	assert_bool(_inv.has_tool_for(&"scanner")).is_false()


# ---------------------------------------------------------------------------
# 7. Save / load
# ---------------------------------------------------------------------------

func test_round_trip_add_items_save_load_verify_counts() -> void:
	_inv.add_item(ID_BERRY, 3)
	_inv.add_item(ID_WOOD, 2)
	_inv.add_item(ID_ROCK, 4)
	var data: Dictionary = _inv.get_save_data()
	var inv2 := _Inventory.new()
	inv2.load_save_data(data)
	assert_int(inv2.get_count(ID_BERRY)).is_equal(3)
	assert_int(inv2.get_count(ID_WOOD)).is_equal(2)
	assert_int(inv2.get_count(ID_ROCK)).is_equal(4)


func test_round_trip_tool_slots_preserved() -> void:
	_inv.set_tool(&"scanner", ID_SCANNER)
	var data: Dictionary = _inv.get_save_data()
	var inv2 := _Inventory.new()
	inv2.load_save_data(data)
	assert_object(inv2.get_tool(&"scanner")).is_equal(ID_SCANNER)


func test_legacy_format_loads_old_slot_based_save_with_slots_key() -> void:
	var legacy_data: Dictionary = {
		"slots": [
			{"type": "P00020", "quantity": 5},
			{"type": "P00011", "quantity": 3},
		],
		"tools": {
			"scanner": "P00205",
		},
	}
	var inv2 := _Inventory.new()
	inv2.load_save_data(legacy_data)
	assert_int(inv2.get_count(ID_BERRY)).is_equal(5)
	assert_int(inv2.get_count(ID_ROCK)).is_equal(3)
	assert_object(inv2.get_tool(&"scanner")).is_equal(ID_SCANNER)


func test_grid_format_loads_items_with_origins_and_rotations() -> void:
	# Place items, save, reload into a fresh inventory, verify origins
	_inv.place_item_at(ID_WOOD, Vector2i(2, 3))
	_inv.place_item_at(ID_ROCK, Vector2i(10, 15))
	var data: Dictionary = _inv.get_save_data()
	var inv2 := _Inventory.new()
	inv2.load_save_data(data)
	var wood_ids: Array[int] = inv2.get_items_by_type(ID_WOOD)
	assert_int(wood_ids.size()).is_equal(1)
	var wood_item: Variant = inv2.get_item(wood_ids[0])
	assert_that(wood_item["origin"]).is_equal(Vector2i(2, 3))
	var rock_ids: Array[int] = inv2.get_items_by_type(ID_ROCK)
	assert_int(rock_ids.size()).is_equal(1)
	var rock_item: Variant = inv2.get_item(rock_ids[0])
	assert_that(rock_item["origin"]).is_equal(Vector2i(10, 15))


# ---------------------------------------------------------------------------
# 8. Backward compat
# ---------------------------------------------------------------------------

func test_get_slots_returns_items_grouped_by_type() -> void:
	_inv.add_item(ID_BERRY, 3)
	_inv.add_item(ID_ROCK, 2)
	var slots: Array[Dictionary] = _inv.get_slots()
	assert_int(slots.size()).is_equal(2)
	var types: Array = []
	for s in slots:
		types.append(s["type"])
	assert_bool(types.has(ID_BERRY)).is_true()
	assert_bool(types.has(ID_ROCK)).is_true()


func test_get_stacks_includes_size_info() -> void:
	_inv.add_item(ID_WOOD, 3)
	var stacks: Array[Dictionary] = _inv.get_stacks()
	assert_int(stacks.size()).is_equal(1)
	assert_object(stacks[0]["type"]).is_equal(ID_WOOD)
	assert_int(stacks[0]["count"]).is_equal(3)
	# Wood is 2-cell, so size_per_unit = 2.0, total_size = 6.0
	assert_float(stacks[0]["size_per_unit"]).is_equal(2.0)
	assert_float(stacks[0]["total_size"]).is_equal(6.0)


func test_is_full_false_when_grid_has_empty_cells() -> void:
	var inv := _Inventory.new(3, 3)
	inv.add_item(ID_BERRY, 5)
	assert_bool(inv.is_full()).is_false()


func test_is_full_true_when_all_cells_filled() -> void:
	var inv := _Inventory.new(3, 3)
	# 9 cells, berry is 1-cell
	inv.add_item(ID_BERRY, 9)
	assert_bool(inv.is_full()).is_true()


func test_get_current_size_counts_occupied_cells() -> void:
	# Wood is 2-cell horizontal
	_inv.add_item(ID_WOOD, 3)
	assert_float(_inv.get_current_size()).is_equal(6.0)


func test_get_capacity_size_returns_total_cells() -> void:
	assert_float(_inv.get_capacity_size()).is_equal(1200.0)  # 30 * 40
	var inv := _Inventory.new(5, 5)
	assert_float(inv.get_capacity_size()).is_equal(25.0)


func test_expand_adds_rows_to_grid() -> void:
	var inv := _Inventory.new(5, 5)
	assert_float(inv.get_capacity_size()).is_equal(25.0)
	inv.expand(3)
	assert_int(inv.grid_height).is_equal(8)
	assert_float(inv.get_capacity_size()).is_equal(40.0)  # 5 * 8
