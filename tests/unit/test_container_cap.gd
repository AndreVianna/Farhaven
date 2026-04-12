class_name TestContainerCap
extends GdUnitTestSuite

## delivery-006f/task-089: ContainerCap dropped the float `capacity_size`
## field and replaced it with `grid_width: int` and `grid_height: int`.
## Legacy callers can still read a compatibility `capacity_size` property
## that returns `grid_width * grid_height` until task-090 rewrites the
## Inventory engine and task-095 migrates all .tres files.

const _ContainerCap = preload("res://scripts/data/capabilities/container_cap.gd")


func test_default_grid_is_player_backpack() -> void:
	var cap := _ContainerCap.new()
	assert_int(cap.grid_width).is_equal(30)
	assert_int(cap.grid_height).is_equal(40)


func test_default_accepts_filter_is_empty() -> void:
	var cap := _ContainerCap.new()
	assert_int(cap.accepts_filter.size()).is_equal(0)


func test_custom_grid_dimensions() -> void:
	var cap := _ContainerCap.new()
	cap.grid_width = 15
	cap.grid_height = 15
	assert_int(cap.grid_width).is_equal(15)
	assert_int(cap.grid_height).is_equal(15)


func test_configured_container_filter() -> void:
	var cap := _ContainerCap.new()
	cap.grid_width = 6
	cap.grid_height = 6
	cap.accepts_filter = [&"BURNABLE.log", &"RESOURCE"]
	assert_int(cap.accepts_filter.size()).is_equal(2)
	assert_bool(cap.accepts_filter.has(&"BURNABLE.log")).is_true()
	assert_bool(cap.accepts_filter.has(&"RESOURCE")).is_true()


func test_filter_does_not_contain_unset_tags() -> void:
	var cap := _ContainerCap.new()
	cap.accepts_filter = [&"WOOD"]
	assert_bool(cap.accepts_filter.has(&"STONE")).is_false()


## Legacy capacity_size property returns grid_width * grid_height so old
## float-math callers keep working during the transition (see task-090 TODO
## in container_cap.gd).
func test_legacy_capacity_size_reflects_grid_area() -> void:
	var cap := _ContainerCap.new()
	cap.grid_width = 10
	cap.grid_height = 5
	assert_float(cap.capacity_size).is_equal_approx(50.0, 0.001)


func test_legacy_capacity_size_setter_reconstructs_grid() -> void:
	var cap := _ContainerCap.new()
	cap.capacity_size = 100.0
	# Round-trip: setter derives a near-square grid that covers the request.
	assert_float(cap.capacity_size).is_greater_equal(100.0)


func test_cap_is_resource() -> void:
	var cap := _ContainerCap.new()
	assert_bool(cap is Resource).is_true()
