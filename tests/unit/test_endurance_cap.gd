class_name TestEnduranceCap
extends GdUnitTestSuite

const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")


func test_default_hp_is_one() -> void:
	var cap := _EnduranceCap.new()
	assert_int(cap.hp).is_equal(1)


func test_default_vulnerabilities_is_empty() -> void:
	var cap := _EnduranceCap.new()
	assert_int(cap.vulnerabilities.size()).is_equal(0)


func test_default_resistances_is_empty() -> void:
	var cap := _EnduranceCap.new()
	assert_int(cap.resistances.size()).is_equal(0)


func test_default_immunities_is_empty() -> void:
	var cap := _EnduranceCap.new()
	assert_int(cap.immunities.size()).is_equal(0)


func test_custom_hp() -> void:
	var cap := _EnduranceCap.new()
	cap.hp = 25
	assert_int(cap.hp).is_equal(25)


func test_vulnerabilities_can_be_assigned() -> void:
	var cap := _EnduranceCap.new()
	cap.vulnerabilities = [&"FIRE", &"BLUNT"]
	assert_int(cap.vulnerabilities.size()).is_equal(2)
	assert_bool(cap.vulnerabilities.has(&"FIRE")).is_true()
	assert_bool(cap.vulnerabilities.has(&"BLUNT")).is_true()


func test_resistances_can_be_assigned() -> void:
	var cap := _EnduranceCap.new()
	cap.resistances = [&"PIERCING"]
	assert_int(cap.resistances.size()).is_equal(1)
	assert_bool(cap.resistances.has(&"PIERCING")).is_true()


func test_immunities_can_be_assigned() -> void:
	var cap := _EnduranceCap.new()
	cap.immunities = [&"POISON", &"COLD"]
	assert_int(cap.immunities.size()).is_equal(2)
	assert_bool(cap.immunities.has(&"POISON")).is_true()
	assert_bool(cap.immunities.has(&"COLD")).is_true()


func test_cap_is_resource() -> void:
	var cap := _EnduranceCap.new()
	assert_bool(cap is Resource).is_true()
