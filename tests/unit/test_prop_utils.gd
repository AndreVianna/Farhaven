class_name TestPropUtils
extends GdUnitTestSuite

const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")


# --- OFFSET_SCALE constant ---

func test_offset_scale_constant() -> void:
	assert_float(_PropUtils.OFFSET_SCALE).is_equal_approx(0.4, 0.001)


# --- get_entry_id_for_type ---

func test_get_entry_id_for_catalogable_prop() -> void:
	# Small tree (00001) has catalogable cap, so entry_id = 00001.
	var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"P00001")
	assert_str(String(entry_id)).is_equal("P00001")


func test_get_entry_id_for_non_catalogable_returns_empty() -> void:
	# Wood (00010) is a resource item, not catalogable in the field.
	var def = PropRegistry.get_def(&"P00010")
	if def != null and def.catalogable == null:
		var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"P00010")
		assert_str(String(entry_id)).is_empty()


func test_get_entry_id_for_unknown_type_returns_empty() -> void:
	var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"P99999")
	assert_str(String(entry_id)).is_empty()


# --- get_prop_placement ---

func test_get_prop_placement_null_tile_returns_zero() -> void:
	var result: Array = _PropUtils.get_prop_placement(null, &"P00001")
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


# --- sub_hex_to_world (task-084d) ---

func test_sub_hex_to_world_zero_returns_zero() -> void:
	var result: Vector2 = _PropUtils.sub_hex_to_world(Vector2i.ZERO)
	assert_float(result.x).is_equal_approx(0.0, 0.001)
	assert_float(result.y).is_equal_approx(0.0, 0.001)


func test_sub_hex_to_world_non_zero_is_non_zero() -> void:
	# Any non-zero sub-hex should produce a non-zero world offset.
	var result: Vector2 = _PropUtils.sub_hex_to_world(Vector2i(1, 0))
	assert_bool(result == Vector2.ZERO).is_false()


func test_sub_hex_to_world_is_deterministic() -> void:
	# Same input → same output across calls (pure function contract).
	var a: Vector2 = _PropUtils.sub_hex_to_world(Vector2i(2, -1))
	var b: Vector2 = _PropUtils.sub_hex_to_world(Vector2i(2, -1))
	assert_float(a.x).is_equal_approx(b.x, 0.001)
	assert_float(a.y).is_equal_approx(b.y, 0.001)


func test_sub_hex_to_world_opposite_signs() -> void:
	# Negating the axial coord should negate the world offset.
	var pos: Vector2 = _PropUtils.sub_hex_to_world(Vector2i(1, 1))
	var neg: Vector2 = _PropUtils.sub_hex_to_world(Vector2i(-1, -1))
	assert_float(pos.x + neg.x).is_equal_approx(0.0, 0.001)
	assert_float(pos.y + neg.y).is_equal_approx(0.0, 0.001)


# --- get_prop_placement with a populated tile (task-084d) ---

class _FakeTile extends Resource:
	var props: Array = []

	func get_props() -> Array:
		return props


class _FakeProp:
	var type: StringName = &""
	var sub_hex: Vector2i = Vector2i.ZERO
	var rotation_deg: float = 0.0


func test_get_prop_placement_empty_tile_returns_zero() -> void:
	var tile := _FakeTile.new()
	var result: Array = _PropUtils.get_prop_placement(tile, &"P00001")
	assert_bool(result[0] == Vector2.ZERO).is_true()
	assert_float(result[1]).is_equal_approx(0.0, 0.001)


func test_get_prop_placement_no_match_returns_zero() -> void:
	var tile := _FakeTile.new()
	var prop := _FakeProp.new()
	prop.type = &"P00001"  # small tree (catalogable)
	prop.sub_hex = Vector2i(1, 0)
	prop.rotation_deg = 45.0
	tile.props = [prop]
	# Asking for a different entry_id should return the zero fallback.
	var result: Array = _PropUtils.get_prop_placement(tile, &"P99999")
	assert_bool(result[0] == Vector2.ZERO).is_true()
	assert_float(result[1]).is_equal_approx(0.0, 0.001)


func test_get_prop_placement_match_returns_rotation() -> void:
	var tile := _FakeTile.new()
	var prop := _FakeProp.new()
	# P00001 is small tree — a catalogable prop, entry_id == id
	prop.type = &"P00001"
	prop.sub_hex = Vector2i(1, 0)
	prop.rotation_deg = 90.0
	tile.props = [prop]
	var result: Array = _PropUtils.get_prop_placement(tile, &"P00001")
	assert_float(result[1]).is_equal_approx(90.0, 0.001)


func test_get_prop_placement_match_returns_non_zero_world_offset() -> void:
	var tile := _FakeTile.new()
	var prop := _FakeProp.new()
	prop.type = &"P00001"
	prop.sub_hex = Vector2i(1, 0)
	prop.rotation_deg = 0.0
	tile.props = [prop]
	var result: Array = _PropUtils.get_prop_placement(tile, &"P00001")
	# Non-zero sub-hex should produce a non-zero world offset
	assert_bool(result[0] == Vector2.ZERO).is_false()


# --- get_entry_id_for_type negative path (task-084d) ---

func test_get_entry_id_for_type_empty_string_input() -> void:
	var entry_id: StringName = _PropUtils.get_entry_id_for_type(&"")
	assert_str(String(entry_id)).is_empty()
