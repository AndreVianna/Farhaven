class_name DamageEvent
extends RefCounted

## A damage event carrying type, raw amount, and source info.

const _DamageType = preload("res://scripts/combat/damage_type.gd")

var damage_type: _DamageType.Type = _DamageType.Type.PHYSICAL
var amount: int = 0          ## Raw damage before multipliers
var source: Resource = null   ## Attacker PropDef or null for environmental
var attack_event: Resource = null  ## The GameEvent that triggered this (for effect chaining)


static func create(p_type: _DamageType.Type, p_amount: int, p_source: Resource = null, p_event: Resource = null) -> DamageEvent:
	var ev := DamageEvent.new()
	ev.damage_type = p_type
	ev.amount = p_amount
	ev.source = p_source
	ev.attack_event = p_event
	return ev
