class_name CombatRuntime

## Dispatches combat between entities using the damage pipeline.
## Static utility — no instance state.
##
## task-104: CombatRuntime — attack dispatch via DamageResolver.

const _DamageType = preload("res://scripts/combat/damage_type.gd")
const _DamageEvent = preload("res://scripts/combat/damage_event.gd")
const _DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")

## Default fallback damage when no attack events are configured.
const DEFAULT_DAMAGE_TYPE: _DamageType.Type = _DamageType.Type.PHYSICAL
const DEFAULT_DAMAGE_AMOUNT: int = 10


## Apply the first attack from attacker_def.combat.attacks against target endurance.
## Returns the final damage dealt (after multipliers), or 0 if no attack possible.
static func apply_attack(attacker_def: _PropDef, target_endurance: _EnduranceCap) -> int:
	if target_endurance == null:
		return 0

	var damage_type: _DamageType.Type = DEFAULT_DAMAGE_TYPE
	var damage_amount: int = DEFAULT_DAMAGE_AMOUNT

	# Try to read damage params from the first attack event's effects
	if attacker_def != null and attacker_def.combat != null and not attacker_def.combat.attacks.is_empty():
		var attack_event: Resource = attacker_def.combat.attacks[0]
		var parsed := _parse_deal_damage_effect(attack_event)
		if not parsed.is_empty():
			damage_type = parsed["damage_type"]
			damage_amount = parsed["amount"]

	var event := _DamageEvent.create(damage_type, damage_amount, attacker_def)
	return _DamageResolver.resolve(event, target_endurance)


## Parse the first "deal_damage" effect from an attack event's effects array.
## Returns {"damage_type": DamageType.Type, "amount": int} or empty dict.
static func _parse_deal_damage_effect(attack_event: Resource) -> Dictionary:
	if attack_event == null:
		return {}
	if not "effects" in attack_event:
		return {}
	for effect: Resource in attack_event.effects:
		if effect is _RecipeEffect and effect.kind == &"deal_damage":
			var params: Dictionary = effect.params
			var amount: int = int(params.get("amount", DEFAULT_DAMAGE_AMOUNT))
			var type_str: String = str(params.get("damage_type", "PHYSICAL"))
			var dtype: _DamageType.Type = _name_to_type(type_str)
			return {"damage_type": dtype, "amount": amount}
	return {}


## Convert a damage type name string to the enum value.
static func _name_to_type(name: String) -> _DamageType.Type:
	match name.to_upper():
		"PHYSICAL": return _DamageType.Type.PHYSICAL
		"FIRE": return _DamageType.Type.FIRE
		"COLD": return _DamageType.Type.COLD
		"POISON": return _DamageType.Type.POISON
		"ELECTRIC": return _DamageType.Type.ELECTRIC
		"MAGIC": return _DamageType.Type.MAGIC
	return _DamageType.Type.PHYSICAL
