class_name TestDamageResolver
extends GdUnitTestSuite

const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")
const _DamageType = preload("res://scripts/combat/damage_type.gd")
const _DamageEvent = preload("res://scripts/combat/damage_event.gd")
const _DamageResolver = preload("res://scripts/combat/damage_resolver.gd")


func _make_endurance(hp: int = 100, vulns: Array[StringName] = [], resists: Array[StringName] = [], immunes: Array[StringName] = []) -> _EnduranceCap:
	var e := _EnduranceCap.new()
	e.hp = hp
	e.vulnerabilities = vulns
	e.resistances = resists
	e.immunities = immunes
	return e


func test_physical_damage_no_modifiers() -> void:
	var endurance := _make_endurance(100)
	var event := _DamageEvent.create(_DamageType.Type.PHYSICAL, 10)
	var dealt := _DamageResolver.resolve(event, endurance)
	assert_int(dealt).is_equal(10)
	assert_int(endurance.hp).is_equal(90)


func test_vulnerability_doubles_damage() -> void:
	var endurance := _make_endurance(100, [&"FIRE"])
	var event := _DamageEvent.create(_DamageType.Type.FIRE, 10)
	var dealt := _DamageResolver.resolve(event, endurance)
	assert_int(dealt).is_equal(20)
	assert_int(endurance.hp).is_equal(80)


func test_resistance_halves_damage() -> void:
	var endurance := _make_endurance(100, [], [&"COLD"])
	var event := _DamageEvent.create(_DamageType.Type.COLD, 10)
	var dealt := _DamageResolver.resolve(event, endurance)
	assert_int(dealt).is_equal(5)
	assert_int(endurance.hp).is_equal(95)


func test_immunity_negates_damage() -> void:
	var endurance := _make_endurance(100, [], [], [&"POISON"])
	var event := _DamageEvent.create(_DamageType.Type.POISON, 10)
	var dealt := _DamageResolver.resolve(event, endurance)
	assert_int(dealt).is_equal(0)
	assert_int(endurance.hp).is_equal(100)


func test_hp_decreases_by_final_damage() -> void:
	var endurance := _make_endurance(50)
	var event := _DamageEvent.create(_DamageType.Type.PHYSICAL, 30)
	var dealt := _DamageResolver.resolve(event, endurance)
	assert_int(dealt).is_equal(30)
	assert_int(endurance.hp).is_equal(20)


func test_hp_can_go_negative() -> void:
	var endurance := _make_endurance(5)
	var event := _DamageEvent.create(_DamageType.Type.PHYSICAL, 20)
	var dealt := _DamageResolver.resolve(event, endurance)
	assert_int(dealt).is_equal(20)
	assert_int(endurance.hp).is_equal(-15)


func test_damage_event_factory() -> void:
	var ev := _DamageEvent.create(_DamageType.Type.FIRE, 42)
	assert_int(ev.amount).is_equal(42)
	assert_int(ev.damage_type).is_equal(_DamageType.Type.FIRE)
	assert_object(ev.source).is_null()
	assert_object(ev.attack_event).is_null()


func test_damage_type_enum_has_six_values() -> void:
	assert_int(_DamageType.Type.size()).is_equal(6)


func test_odd_damage_with_resistance_rounds_up() -> void:
	var endurance := _make_endurance(100, [], [&"PHYSICAL"])
	var event := _DamageEvent.create(_DamageType.Type.PHYSICAL, 7)
	var dealt := _DamageResolver.resolve(event, endurance)
	# 7 * 0.5 = 3.5 -> ceil -> 4
	assert_int(dealt).is_equal(4)
	assert_int(endurance.hp).is_equal(96)
