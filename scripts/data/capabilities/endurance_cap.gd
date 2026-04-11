class_name EnduranceCap
extends Resource

## Hit points / durability — how much damage the entity can take before being destroyed.
@export var hp: int = 1

## Damage tags this entity takes extra damage from (e.g., FIRE, BLUNT, PIERCING). 2x multiplier hardcoded for now.
@export var vulnerabilities: Array[StringName] = []

## Damage tags this entity takes reduced damage from. 0.5x multiplier hardcoded for now.
@export var resistances: Array[StringName] = []

## Damage tags this entity takes no damage from.
@export var immunities: Array[StringName] = []
