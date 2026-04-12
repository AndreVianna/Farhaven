class_name TestPortableCap
extends GdUnitTestSuite

## delivery-006f/task-089: PortableCap dropped the float `size` field and
## replaced it with `slot_shape: Array[Vector2i]` (grid cell offsets). These
## tests cover the new shape field. The full grid engine (task-090) and
## content migration (task-095) land in follow-up tasks.

const _PortableCap = preload("res://scripts/data/capabilities/portable_cap.gd")


func test_default_slot_shape_is_single_cell() -> void:
	var cap := _PortableCap.new()
	assert_int(cap.slot_shape.size()).is_equal(1)
	assert_that(cap.slot_shape[0]).is_equal(Vector2i(0, 0))


func test_custom_line_shape() -> void:
	var cap := _PortableCap.new()
	cap.slot_shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_int(cap.slot_shape.size()).is_equal(3)
	assert_that(cap.slot_shape[2]).is_equal(Vector2i(2, 0))


func test_custom_l_shape() -> void:
	var cap := _PortableCap.new()
	# 4x2 knife-ish L: blade along top row, handle hanging off the right.
	cap.slot_shape = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(3, 1), Vector2i(2, 1),
	]
	assert_int(cap.slot_shape.size()).is_equal(6)


func test_custom_blob_shape() -> void:
	var cap := _PortableCap.new()
	# 2x2 stone blob.
	cap.slot_shape = [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(1, 1),
	]
	assert_int(cap.slot_shape.size()).is_equal(4)


func test_empty_shape_is_allowed_but_represents_nothing() -> void:
	var cap := _PortableCap.new()
	cap.slot_shape = []
	assert_int(cap.slot_shape.size()).is_equal(0)


func test_cap_is_resource() -> void:
	var cap := _PortableCap.new()
	assert_bool(cap is Resource).is_true()
