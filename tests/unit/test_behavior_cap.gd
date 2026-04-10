class_name TestBehaviorCap
extends GdUnitTestSuite

const _BehaviorCap = preload("res://scripts/data/capabilities/behavior_cap.gd")


func test_default_detection_range_is_two() -> void:
	var cap := _BehaviorCap.new()
	assert_int(cap.detection_range).is_equal(2)


func test_default_activity_cycle_is_always() -> void:
	var cap := _BehaviorCap.new()
	assert_int(cap.activity_cycle).is_equal(_BehaviorCap.ActivityCycle.ALWAYS)


func test_default_group_behavior_is_solo() -> void:
	var cap := _BehaviorCap.new()
	assert_int(cap.group_behavior).is_equal(_BehaviorCap.GroupBehavior.SOLO)


func test_default_diet_is_empty() -> void:
	var cap := _BehaviorCap.new()
	assert_int(cap.diet.size()).is_equal(0)


func test_default_reactions_is_empty() -> void:
	var cap := _BehaviorCap.new()
	assert_int(cap.reactions.size()).is_equal(0)


func test_activity_cycle_can_be_diurnal() -> void:
	var cap := _BehaviorCap.new()
	cap.activity_cycle = _BehaviorCap.ActivityCycle.DIURNAL
	assert_int(cap.activity_cycle).is_equal(_BehaviorCap.ActivityCycle.DIURNAL)


func test_activity_cycle_can_be_nocturnal() -> void:
	var cap := _BehaviorCap.new()
	cap.activity_cycle = _BehaviorCap.ActivityCycle.NOCTURNAL
	assert_int(cap.activity_cycle).is_equal(_BehaviorCap.ActivityCycle.NOCTURNAL)


func test_activity_cycle_can_be_crepuscular() -> void:
	var cap := _BehaviorCap.new()
	cap.activity_cycle = _BehaviorCap.ActivityCycle.CREPUSCULAR
	assert_int(cap.activity_cycle).is_equal(_BehaviorCap.ActivityCycle.CREPUSCULAR)


func test_group_behavior_can_be_pair() -> void:
	var cap := _BehaviorCap.new()
	cap.group_behavior = _BehaviorCap.GroupBehavior.PAIR
	assert_int(cap.group_behavior).is_equal(_BehaviorCap.GroupBehavior.PAIR)


func test_group_behavior_can_be_pack() -> void:
	var cap := _BehaviorCap.new()
	cap.group_behavior = _BehaviorCap.GroupBehavior.PACK
	assert_int(cap.group_behavior).is_equal(_BehaviorCap.GroupBehavior.PACK)


func test_detection_range_custom() -> void:
	var cap := _BehaviorCap.new()
	cap.detection_range = 5
	assert_int(cap.detection_range).is_equal(5)


func test_diet_can_be_assigned() -> void:
	var cap := _BehaviorCap.new()
	cap.diet = [&"FLORA", &"FAUNA"]
	assert_int(cap.diet.size()).is_equal(2)
	assert_bool(cap.diet.has(&"FLORA")).is_true()
	assert_bool(cap.diet.has(&"FAUNA")).is_true()


func test_reactions_can_be_assigned() -> void:
	var cap := _BehaviorCap.new()
	cap.reactions = [Resource.new(), Resource.new()]
	assert_int(cap.reactions.size()).is_equal(2)


func test_cap_is_resource() -> void:
	var cap := _BehaviorCap.new()
	assert_bool(cap is Resource).is_true()
