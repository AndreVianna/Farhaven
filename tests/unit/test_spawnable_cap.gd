class_name TestSpawnableCap
extends GdUnitTestSuite

const _SpawnableCap = preload("res://scripts/data/capabilities/spawnable_cap.gd")


func test_default_spawn_min_is_one() -> void:
	var cap := _SpawnableCap.new()
	assert_int(cap.spawn_min).is_equal(1)


func test_default_spawn_max_is_one() -> void:
	var cap := _SpawnableCap.new()
	assert_int(cap.spawn_max).is_equal(1)


func test_default_first_spawn_day_is_one() -> void:
	var cap := _SpawnableCap.new()
	assert_int(cap.first_spawn_day).is_equal(1)


func test_default_spawn_min_distance_is_three() -> void:
	var cap := _SpawnableCap.new()
	assert_int(cap.spawn_min_distance).is_equal(3)


func test_default_allowed_biomes_is_empty() -> void:
	var cap := _SpawnableCap.new()
	assert_int(cap.allowed_biomes.size()).is_equal(0)


func test_custom_spawn_min_and_max() -> void:
	var cap := _SpawnableCap.new()
	cap.spawn_min = 2
	cap.spawn_max = 5
	assert_int(cap.spawn_min).is_equal(2)
	assert_int(cap.spawn_max).is_equal(5)


func test_custom_first_spawn_day() -> void:
	var cap := _SpawnableCap.new()
	cap.first_spawn_day = 4
	assert_int(cap.first_spawn_day).is_equal(4)


func test_custom_spawn_min_distance() -> void:
	var cap := _SpawnableCap.new()
	cap.spawn_min_distance = 10
	assert_int(cap.spawn_min_distance).is_equal(10)


func test_allowed_biomes_can_be_assigned() -> void:
	var cap := _SpawnableCap.new()
	cap.allowed_biomes = [&"FOREST", &"GRASSLAND"]
	assert_int(cap.allowed_biomes.size()).is_equal(2)
	assert_bool(cap.allowed_biomes.has(&"FOREST")).is_true()
	assert_bool(cap.allowed_biomes.has(&"GRASSLAND")).is_true()


func test_cap_is_resource() -> void:
	var cap := _SpawnableCap.new()
	assert_bool(cap is Resource).is_true()
