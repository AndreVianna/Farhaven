class_name TestCombatRuntime
extends GdUnitTestSuite

## Unit tests for CombatRuntime (task-104).

const _CombatRuntime = preload("res://scripts/combat/combat_runtime.gd")
const _DamageType = preload("res://scripts/combat/damage_type.gd")
const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")
const _CombatCap = preload("res://scripts/data/capabilities/combat_cap.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _GameEvent = preload("res://scripts/core/event.gd")


func _make_endurance(hp: int = 100) -> _EnduranceCap:
	var e := _EnduranceCap.new()
	e.hp = hp
	return e


func _make_attacker_def(damage_type: String = "PHYSICAL", amount: int = 15) -> _PropDef:
	var def := _PropDef.new()
	def.id = &"TEST_ATTACKER"

	var combat := _CombatCap.new()
	var attack := _GameEvent.new()
	var effect := _RecipeEffect.new()
	effect.kind = &"deal_damage"
	effect.params = {"damage_type": damage_type, "amount": amount}
	attack.effects = [effect]
	combat.attacks = [attack]
	def.combat = combat
	return def


func _make_attacker_def_no_combat() -> _PropDef:
	var def := _PropDef.new()
	def.id = &"TEST_UNARMED"
	return def


# --- Tests ---


func test_apply_attack_with_deal_damage_effect() -> void:
	var attacker := _make_attacker_def("PHYSICAL", 15)
	var endurance := _make_endurance(100)
	var dealt := _CombatRuntime.apply_attack(attacker, endurance)
	assert_int(dealt).is_equal(15)
	assert_int(endurance.hp).is_equal(85)


func test_apply_attack_fire_damage_with_vulnerability() -> void:
	var attacker := _make_attacker_def("FIRE", 10)
	var endurance := _make_endurance(100)
	endurance.vulnerabilities = [&"FIRE"]
	var dealt := _CombatRuntime.apply_attack(attacker, endurance)
	assert_int(dealt).is_equal(20)  # 2x vulnerability
	assert_int(endurance.hp).is_equal(80)


func test_apply_attack_with_resistance() -> void:
	var attacker := _make_attacker_def("COLD", 10)
	var endurance := _make_endurance(100)
	endurance.resistances = [&"COLD"]
	var dealt := _CombatRuntime.apply_attack(attacker, endurance)
	assert_int(dealt).is_equal(5)  # 0.5x resistance
	assert_int(endurance.hp).is_equal(95)


func test_apply_attack_with_immunity() -> void:
	var attacker := _make_attacker_def("POISON", 20)
	var endurance := _make_endurance(100)
	endurance.immunities = [&"POISON"]
	var dealt := _CombatRuntime.apply_attack(attacker, endurance)
	assert_int(dealt).is_equal(0)
	assert_int(endurance.hp).is_equal(100)


func test_apply_attack_fallback_when_no_combat_cap() -> void:
	var attacker := _make_attacker_def_no_combat()
	var endurance := _make_endurance(100)
	var dealt := _CombatRuntime.apply_attack(attacker, endurance)
	# Should use DEFAULT_DAMAGE_AMOUNT (10) PHYSICAL
	assert_int(dealt).is_equal(10)
	assert_int(endurance.hp).is_equal(90)


func test_apply_attack_null_attacker_uses_default() -> void:
	var endurance := _make_endurance(50)
	var dealt := _CombatRuntime.apply_attack(null, endurance)
	assert_int(dealt).is_equal(10)
	assert_int(endurance.hp).is_equal(40)


func test_apply_attack_null_endurance_returns_zero() -> void:
	var attacker := _make_attacker_def("PHYSICAL", 15)
	var dealt := _CombatRuntime.apply_attack(attacker, null)
	assert_int(dealt).is_equal(0)


func test_apply_attack_can_kill() -> void:
	var attacker := _make_attacker_def("PHYSICAL", 30)
	var endurance := _make_endurance(20)
	var dealt := _CombatRuntime.apply_attack(attacker, endurance)
	assert_int(dealt).is_equal(30)
	assert_int(endurance.hp).is_equal(-10)


func test_apply_attack_empty_attacks_array_uses_default() -> void:
	var def := _PropDef.new()
	def.id = &"TEST_EMPTY"
	def.combat = _CombatCap.new()
	# combat.attacks is empty []
	var endurance := _make_endurance(100)
	var dealt := _CombatRuntime.apply_attack(def, endurance)
	assert_int(dealt).is_equal(10)
	assert_int(endurance.hp).is_equal(90)


func test_apply_attack_effect_without_deal_damage_uses_default() -> void:
	var def := _PropDef.new()
	def.id = &"TEST_NO_DAMAGE_EFFECT"
	var combat := _CombatCap.new()
	var attack := _GameEvent.new()
	var effect := _RecipeEffect.new()
	effect.kind = &"sound"
	effect.params = {"sound_id": "growl"}
	attack.effects = [effect]
	combat.attacks = [attack]
	def.combat = combat
	var endurance := _make_endurance(100)
	var dealt := _CombatRuntime.apply_attack(def, endurance)
	assert_int(dealt).is_equal(10)
	assert_int(endurance.hp).is_equal(90)
