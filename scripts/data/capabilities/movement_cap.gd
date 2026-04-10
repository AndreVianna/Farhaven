class_name MovementCap
extends Resource

## Movement modes available to this entity.
enum Mode { WALK, SWIM, FLY, BURROW, CLIMB, JUMP }

## Map of Mode -> [normal_speed, max_speed] (Array of 2 floats).
## Each entry is a movement mode the entity can use.
## Examples:
##   {0: [1.0, 1.5]} — walks (mode 0=WALK)
##   {0: [1.0, 1.5], 1: [0.8, 1.2]} — walks and swims (amphibian)
##   {2: [3.0, 5.0]} — flies (mode 2=FLY)
##   {0: [1.0, 1.5], 5: [2.0, 3.0]} — walks and jumps (frog: WALK + JUMP)
##
## move_cooldown is derived: cooldown = 1.0 / normal_speed
## max_jump (elevation diff) is derived: if JUMP mode present, use JUMP normal value; otherwise 1.
@export var modes: Dictionary = {}
