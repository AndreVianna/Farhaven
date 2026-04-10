class_name CombatCap
extends Resource

## Attack events the entity can perform. Each is a GameEvent reference.
## Conditions check things like target_in_range, cooldown_elapsed.
## Effects apply damage with damage_type, status effects, etc.
@export var attacks: Array[Resource] = []  # Array of GameEvent

## Defense events the entity can perform.
## Triggered when being attacked. Can block/dodge/parry based on damage_type.
@export var defenses: Array[Resource] = []  # Array of GameEvent
