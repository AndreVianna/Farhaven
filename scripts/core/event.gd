class_name GameEvent
extends ScriptBase

## An executable game event — milestones, world flags, chapter gates, tutorials.
## Extends ScriptBase (conditions, effects, actions, duration) with occurrence tracking.
##
## count: runtime state — how many times this event has fired (persisted in save)
## max_count: schema — 0=unlimited, 1=one-shot (milestone/flag), N=limited (tutorial)
##
## An event is "active" (flag is set) when count >= 1.
## RecipeRuntime (or ActionRuntime) checks count < max_count before executing.
## World flags = events where count >= 1.

@export var count: int = 0          # Runtime state (persisted)
@export var max_count: int = 1      # 0=unlimited, 1=one-shot, N=limited


## Returns true if this event has fired at least once.
func is_active() -> bool:
	return count >= 1


## Returns true if this event can still fire (hasn't reached max_count).
func can_fire() -> bool:
	return max_count == 0 or count < max_count


## Increment the fire count. Returns true if successfully fired.
func fire() -> bool:
	if not can_fire():
		return false
	count += 1
	return true


## Reset the event (for testing or game reset).
func reset() -> void:
	count = 0
