class_name BehaviorCap
extends Resource

## How far the entity can detect player/threats (in sub-hex rings).
@export var detection_range: int = 2

## When the entity is active.
enum ActivityCycle { ALWAYS, DIURNAL, NOCTURNAL, CREPUSCULAR }
@export var activity_cycle: ActivityCycle = ActivityCycle.ALWAYS

## Group behavior — how the entity organizes.
enum GroupBehavior { SOLO, PAIR, PACK }
@export var group_behavior: GroupBehavior = GroupBehavior.SOLO

## Diet — tags representing what this entity eats (e.g., FLORA, FAUNA, MINERAL).
@export var diet: Array[StringName] = []

## Reaction events — non-combat responses to stimuli (flee, call_for_help, etc.). Array of GameEvent.
@export var reactions: Array[Resource] = []
