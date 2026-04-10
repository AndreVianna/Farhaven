class_name TestPropRegistry
extends GdUnitTestSuite

## Tests for the PropRegistry autoload.
## PropRegistry scans res://data/props/ on _ready; it's already populated in the test env.


func test_registry_has_small_tree() -> void:
	assert_bool(PropRegistry.has_def(&"P00001")).is_true()


func test_registry_has_wood() -> void:
	assert_bool(PropRegistry.has_def(&"P00010")).is_true()


func test_registry_get_def_returns_resource() -> void:
	var def = PropRegistry.get_def(&"P00010")
	assert_object(def).is_not_null()
	assert_bool(def is Resource).is_true()


func test_get_def_unknown_returns_null() -> void:
	var def = PropRegistry.get_def(&"P99999")
	assert_object(def).is_null()


func test_has_def_false_for_nonexistent() -> void:
	assert_bool(PropRegistry.has_def(&"ZZZZZ")).is_false()


func test_get_all_returns_nonempty_array() -> void:
	var all: Array = PropRegistry.get_all()
	assert_bool(all.size() > 0).is_true()


func test_get_yield_type_returns_self_when_no_yield() -> void:
	# Wood (00010) doesn't have a yield_type — it IS the yield.
	var yield_id: StringName = PropRegistry.get_yield_type(&"P00010")
	assert_str(String(yield_id)).is_equal("P00010")


func test_get_yield_type_returns_mapped_type_for_source() -> void:
	# Small Tree (00001) yields Wood (00010).
	var yield_id: StringName = PropRegistry.get_yield_type(&"P00001")
	assert_str(String(yield_id)).is_equal("P00010")


func test_get_yield_type_unknown_returns_same_type() -> void:
	var yield_id: StringName = PropRegistry.get_yield_type(&"P99999")
	assert_str(String(yield_id)).is_equal("P99999")


func test_get_tool_speed_default_is_one() -> void:
	var speed: float = PropRegistry.get_tool_speed(&"P00001", &"fists")
	assert_float(speed).is_equal_approx(1.0, 0.001)


func test_get_tool_speed_returns_configured_value() -> void:
	# Small tree (00001) has tool_speed for axe: should be faster.
	var def = PropRegistry.get_def(&"P00001")
	if def != null and def.tool_speed.has(&"axe"):
		var speed: float = PropRegistry.get_tool_speed(&"P00001", &"axe")
		assert_float(speed).is_not_equal(1.0)
	else:
		# If no tool_speed configured, default is 1.0
		var speed: float = PropRegistry.get_tool_speed(&"P00001", &"axe")
		assert_float(speed).is_equal_approx(1.0, 0.001)


func test_get_tool_speed_unknown_prop_returns_one() -> void:
	var speed: float = PropRegistry.get_tool_speed(&"P99999", &"axe")
	assert_float(speed).is_equal_approx(1.0, 0.001)
