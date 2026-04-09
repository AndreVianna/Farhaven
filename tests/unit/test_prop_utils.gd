class_name TestPropUtils
extends GdUnitTestSuite

const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")


# --- OFFSET_SCALE constant ---

func test_offset_scale_constant() -> void:
	assert_float(_PropUtils.OFFSET_SCALE).is_equal_approx(0.4, 0.001)


# --- get_entry_id_for_type ---

func test_get_entry_id_for_catalogable_prop() -> void:
	# Small tree (00001) has catalogable cap, so entry_id = 00001.
	var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"00001")
	assert_str(String(entry_id)).is_equal("00001")


func test_get_entry_id_for_non_catalogable_returns_empty() -> void:
	# Wood (00010) is a resource item, not catalogable in the field.
	var def = PropRegistry.get_def(&"00010")
	if def != null and def.catalogable == null:
		var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"00010")
		assert_str(String(entry_id)).is_empty()


func test_get_entry_id_for_unknown_type_returns_empty() -> void:
	var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"99999")
	assert_str(String(entry_id)).is_empty()


# --- get_prop_placement ---

func test_get_prop_placement_null_tile_returns_zero() -> void:
	var result: Array = _PropUtils.get_prop_placement(null, &"00001")
	assert_bool(result[0] == Vector2.ZERO).is_true()
	assert_float(result[1]).is_equal_approx(0.0, 0.001)


# --- offset_to_world (legacy) ---

func test_offset_to_world_zero_offset() -> void:
	var result: Vector2 = _PropUtils.offset_to_world(Vector2.ZERO, 1.0)
	assert_bool(result == Vector2.ZERO).is_true()


func test_offset_to_world_applies_scale() -> void:
	var result: Vector2 = _PropUtils.offset_to_world(Vector2(1.0, 0.0), 2.0)
	# Expected: 1.0 * 2.0 * 0.4 = 0.8
	assert_float(result.x).is_equal_approx(0.8, 0.001)
	assert_float(result.y).is_equal_approx(0.0, 0.001)


func test_offset_to_world_negative_values() -> void:
	var result: Vector2 = _PropUtils.offset_to_world(Vector2(-0.5, 0.5), 1.0)
	assert_float(result.x).is_equal_approx(-0.2, 0.001)
	assert_float(result.y).is_equal_approx(0.2, 0.001)
