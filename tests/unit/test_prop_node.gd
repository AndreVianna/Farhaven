class_name TestPropNode
extends GdUnitTestSuite

const _PropNode = preload("res://scripts/hex/prop_node.gd")


func test_default_type_is_empty() -> void:
	var pn := _PropNode.new()
	assert_str(String(pn.type)).is_empty()


func test_default_remaining_is_zero() -> void:
	var pn := _PropNode.new()
	assert_int(pn.remaining).is_equal(0)


func test_default_max_amount_is_zero() -> void:
	var pn := _PropNode.new()
	assert_int(pn.max_amount).is_equal(0)


func test_default_tool_required_is_empty() -> void:
	var pn := _PropNode.new()
	assert_str(String(pn.tool_required)).is_empty()


func test_default_respawn_time_is_zero() -> void:
	var pn := _PropNode.new()
	assert_float(pn.respawn_time).is_equal_approx(0.0, 0.001)


func test_default_offset_is_zero() -> void:
	var pn := _PropNode.new()
	assert_bool(pn.offset == Vector2.ZERO).is_true()


func test_default_rotation_deg_is_zero() -> void:
	var pn := _PropNode.new()
	assert_float(pn.rotation_deg).is_equal_approx(0.0, 0.001)


func test_configured_tree_node() -> void:
	var pn := _PropNode.new()
	pn.type = &"P00001"
	pn.remaining = 5
	pn.max_amount = 5
	pn.tool_required = &"axe"
	pn.respawn_time = 30.0
	pn.offset = Vector2(0.3, -0.2)
	pn.rotation_deg = 45.0
	assert_str(String(pn.type)).is_equal("P00001")
	assert_int(pn.remaining).is_equal(5)
	assert_int(pn.max_amount).is_equal(5)
	assert_str(String(pn.tool_required)).is_equal("axe")
	assert_float(pn.respawn_time).is_equal_approx(30.0, 0.001)
	assert_float(pn.rotation_deg).is_equal_approx(45.0, 0.001)


func test_depleted_node_has_zero_remaining() -> void:
	var pn := _PropNode.new()
	pn.max_amount = 5
	pn.remaining = 0
	assert_int(pn.remaining).is_equal(0)
	assert_int(pn.max_amount).is_equal(5)


func test_no_respawn_when_time_is_zero() -> void:
	var pn := _PropNode.new()
	pn.respawn_time = 0.0
	assert_float(pn.respawn_time).is_equal_approx(0.0, 0.001)


func test_prop_node_is_resource() -> void:
	var pn := _PropNode.new()
	assert_bool(pn is Resource).is_true()
