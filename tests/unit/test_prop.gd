class_name TestProp
extends GdUnitTestSuite

const PropClass = preload("res://scripts/hex/prop.gd")

# --- Default creation ---

func test_prop_default_type_is_empty() -> void:
	var prop: Prop = PropClass.new()
	assert_str(String(prop.type)).is_empty()

func test_prop_default_sub_hex_is_zero() -> void:
	var prop: Prop = PropClass.new()
	assert_bool(prop.sub_hex == Vector2i.ZERO).is_true()

func test_prop_default_category_is_plant() -> void:
	var prop: Prop = PropClass.new()
	assert_int(prop.category).is_equal(Prop.Category.PLANT)

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

func test_prop_fields() -> void:
	var prop: Prop = PropClass.new()
	prop.type = &"iron_ore"
	prop.category = Prop.Category.MINERAL
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

func test_category_plant_value() -> void:
	assert_int(Prop.Category.PLANT).is_equal(0)

func test_category_mineral_value() -> void:
	assert_int(Prop.Category.MINERAL).is_equal(1)

func test_category_animal_value() -> void:
	assert_int(Prop.Category.ANIMAL).is_equal(2)

func test_category_fungi_value() -> void:
	assert_int(Prop.Category.FUNGI).is_equal(3)

func test_category_liquid_value() -> void:
	assert_int(Prop.Category.LIQUID).is_equal(4)

func test_category_ooze_value() -> void:
	assert_int(Prop.Category.OOZE).is_equal(5)

func test_category_structure_value() -> void:
	assert_int(Prop.Category.STRUCTURE).is_equal(6)

func test_category_vehicle_value() -> void:
	assert_int(Prop.Category.VEHICLE).is_equal(7)

func test_category_equipment_value() -> void:
	assert_int(Prop.Category.EQUIPMENT).is_equal(8)

func test_category_storage_value() -> void:
	assert_int(Prop.Category.STORAGE).is_equal(9)

# --- Origin enum values ---

func test_origin_natural_value() -> void:
	assert_int(Prop.Origin.NATURAL).is_equal(0)

func test_origin_crafted_value() -> void:
	assert_int(Prop.Origin.CRAFTED).is_equal(1)

func test_default_origin_is_natural() -> void:
	var prop: Prop = PropClass.new()
	assert_int(prop.origin).is_equal(Prop.Origin.NATURAL)

# --- is_anomaly helper ---

func test_is_anomaly_false_for_natural() -> void:
	var prop: Prop = PropClass.new()
	prop.origin = Prop.Origin.NATURAL
	assert_bool(prop.is_anomaly()).is_false()

func test_is_anomaly_false_for_crafted() -> void:
	var prop: Prop = PropClass.new()
	prop.origin = Prop.Origin.CRAFTED
	assert_bool(prop.is_anomaly()).is_false()

func test_is_anomaly_true_for_unknown() -> void:
	var prop: Prop = PropClass.new()
	prop.origin = Prop.Origin.UNKNOWN
	assert_bool(prop.is_anomaly()).is_true()

func test_is_anomaly_true_for_native_alien() -> void:
	var prop: Prop = PropClass.new()
	prop.origin = Prop.Origin.NATIVE_ALIEN
	assert_bool(prop.is_anomaly()).is_true()

# --- is_natural_category helper ---

func test_is_natural_category_true_for_plant() -> void:
	var prop: Prop = PropClass.new()
	prop.category = Prop.Category.PLANT
	assert_bool(prop.is_natural_category()).is_true()

func test_is_natural_category_true_for_ooze() -> void:
	var prop: Prop = PropClass.new()
	prop.category = Prop.Category.OOZE
	assert_bool(prop.is_natural_category()).is_true()

func test_is_natural_category_false_for_structure() -> void:
	var prop: Prop = PropClass.new()
	prop.category = Prop.Category.STRUCTURE
	assert_bool(prop.is_natural_category()).is_false()

# --- Sub-hex assignment ---

func test_prop_sub_hex_assignment() -> void:
	var prop: Prop = PropClass.new()
	prop.sub_hex = Vector2i(1, -1)
	assert_bool(prop.sub_hex == Vector2i(1, -1)).is_true()

func test_prop_rotation_deg() -> void:
	var prop: Prop = PropClass.new()
	prop.rotation_deg = 45.0
	assert_float(prop.rotation_deg).is_equal_approx(45.0, 0.0001)
