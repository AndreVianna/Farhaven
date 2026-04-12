class_name DamageResolver

## Resolves damage by applying EnduranceCap vulnerability/resistance/immunity
## multipliers, then subtracting from HP.
##
## Returns the final damage dealt (after multipliers).

const _DamageType = preload("res://scripts/combat/damage_type.gd")
const _DamageEvent = preload("res://scripts/combat/damage_event.gd")
const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")

static func resolve(event: _DamageEvent, endurance: _EnduranceCap) -> int:
	var type_name: StringName = _type_to_name(event.damage_type)
	var multiplier: float = 1.0

	if endurance.immunities.has(type_name):
		multiplier = 0.0
	elif endurance.resistances.has(type_name):
		multiplier = 0.5
	elif endurance.vulnerabilities.has(type_name):
		multiplier = 2.0

	var final_damage: int = int(ceil(float(event.amount) * multiplier))
	endurance.hp -= final_damage
	return final_damage


static func _type_to_name(t: _DamageType.Type) -> StringName:
	match t:
		_DamageType.Type.PHYSICAL: return &"PHYSICAL"
		_DamageType.Type.FIRE: return &"FIRE"
		_DamageType.Type.COLD: return &"COLD"
		_DamageType.Type.POISON: return &"POISON"
		_DamageType.Type.ELECTRIC: return &"ELECTRIC"
		_DamageType.Type.MAGIC: return &"MAGIC"
	return &"PHYSICAL"
