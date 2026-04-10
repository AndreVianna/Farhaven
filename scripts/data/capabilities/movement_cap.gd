class_name MovementCap
extends Resource

## How the entity moves through the world.
enum Mode { WALK, SWIM, FLY, BURROW, CLIMB }
@export var mode: Mode = Mode.WALK

## Cooldown between movements (seconds). Lower = faster.
@export var move_cooldown: float = 1.0

## Maximum elevation difference the entity can traverse in one move.
@export var max_jump: int = 1
