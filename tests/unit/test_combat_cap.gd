class_name TestCombatCap
extends GdUnitTestSuite

const _CombatCap = preload("res://scripts/data/capabilities/combat_cap.gd")


func test_default_attacks_is_empty() -> void:
	var cap := _CombatCap.new()
	assert_int(cap.attacks.size()).is_equal(0)


func test_default_defenses_is_empty() -> void:
	var cap := _CombatCap.new()
	assert_int(cap.defenses.size()).is_equal(0)


func test_attacks_can_be_assigned() -> void:
	var cap := _CombatCap.new()
	var stub_attack := Resource.new()
	cap.attacks = [stub_attack]
	assert_int(cap.attacks.size()).is_equal(1)
	assert_object(cap.attacks[0]).is_same(stub_attack)


func test_defenses_can_be_assigned() -> void:
	var cap := _CombatCap.new()
	var stub_defense := Resource.new()
	cap.defenses = [stub_defense]
	assert_int(cap.defenses.size()).is_equal(1)
	assert_object(cap.defenses[0]).is_same(stub_defense)


func test_multiple_attacks_and_defenses() -> void:
	var cap := _CombatCap.new()
	cap.attacks = [Resource.new(), Resource.new(), Resource.new()]
	cap.defenses = [Resource.new(), Resource.new()]
	assert_int(cap.attacks.size()).is_equal(3)
	assert_int(cap.defenses.size()).is_equal(2)


func test_cap_is_resource() -> void:
	var cap := _CombatCap.new()
	assert_bool(cap is Resource).is_true()
