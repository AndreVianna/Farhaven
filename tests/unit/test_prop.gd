extends GdUnitTestSuite
class_name TestProp

const PropClass = preload("res://scripts/hex/prop.gd")

# --- Default creation ---

func test_prop_default_type_is_empty() -> void:
	var prop: Prop = PropClass.new()
	assert_str(String(prop.type)).is_empty()

func test_prop_default_sub_hex_is_zero() -> void:
	var prop: Prop = PropClass.new()
	assert_bool(prop.sub_hex == Vector2i.ZERO).is_true()

func test_prop_default_category_is_resource() -> void:
	var prop: Prop = PropClass.new()
	assert_int(prop.category).is_equal(Prop.Category.RESOURCE)

func test_prop_default_remaining_is_zero() -> void:
	var prop: Prop = PropClass.new()
	assert_int(prop.remaining).is_equal(0)

func test_prop_default_blocks_movement_is_false() -> void:
	var prop: Prop = PropClass.new()
	assert_bool(prop.blocks_movement).is_false()

func test_prop_default_footprint_is_empty() -> void:
	var prop: Prop = PropClass.new()
	assert_int(prop.footprint.size()).is_equal(0)

# --- Resource-specific fields ---

func test_prop_resource_fields() -> void:
	var prop: Prop = PropClass.new()
	prop.type = &"iron_ore"
	prop.category = Prop.Category.RESOURCE
	prop.remaining = 5
	prop.max_amount = 10
	prop.tool_required = &"pickaxe"
	prop.respawn_time = 60.0
	assert_str(String(prop.type)).is_equal("iron_ore")
	assert_int(prop.remaining).is_equal(5)
	assert_int(prop.max_amount).is_equal(10)
	assert_str(String(prop.tool_required)).is_equal("pickaxe")
	assert_float(prop.respawn_time).is_equal_approx(60.0, 0.0001)

# --- Structure-specific fields ---

func test_prop_structure_with_footprint() -> void:
	var prop: Prop = PropClass.new()
	prop.type = &"shelter"
	prop.category = Prop.Category.STRUCTURE
	prop.footprint = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	prop.blocks_movement = true
	assert_int(prop.category).is_equal(Prop.Category.STRUCTURE)
	assert_int(prop.footprint.size()).is_equal(3)
	assert_bool(prop.blocks_movement).is_true()

# --- Category enum values ---

func test_category_resource_value() -> void:
	assert_int(Prop.Category.RESOURCE).is_equal(0)

func test_category_structure_value() -> void:
	assert_int(Prop.Category.STRUCTURE).is_equal(1)

func test_category_anomaly_value() -> void:
	assert_int(Prop.Category.ANOMALY).is_equal(2)

func test_category_spawn_value() -> void:
	assert_int(Prop.Category.SPAWN).is_equal(3)

# --- Sub-hex assignment ---

func test_prop_sub_hex_assignment() -> void:
	var prop: Prop = PropClass.new()
	prop.sub_hex = Vector2i(1, -1)
	assert_bool(prop.sub_hex == Vector2i(1, -1)).is_true()

func test_prop_rotation_deg() -> void:
	var prop: Prop = PropClass.new()
	prop.rotation_deg = 45.0
	assert_float(prop.rotation_deg).is_equal_approx(45.0, 0.0001)
