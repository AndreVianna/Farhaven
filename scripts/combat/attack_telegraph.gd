class_name AttackTelegraph

## Tween-based attack telegraph — a brief visual cue before damage applies.
## Creates a scale pulse on the fauna sprite, or a plain timer delay if no visual.
##
## task-107: Attack telegraph animation stub.


## Play a scale-pulse telegraph on [param target_node] and return the tween's
## [signal Tween.finished] signal so the caller can [code]await[/code] it.
## If [param target_node] has no visual representation, falls back to a simple
## timer delay.
static func telegraph(target_node: Node, duration: float = 0.4) -> Signal:
	var sprite: Node = _find_sprite(target_node)
	if sprite != null:
		return _pulse_sprite(sprite, duration)
	return _timer_delay(target_node, duration)


## Locate a Sprite3D, Sprite2D, or MeshInstance3D child for the scale pulse.
static func _find_sprite(node: Node) -> Node:
	if node is Sprite3D or node is Sprite2D or node is MeshInstance3D:
		return node
	for child: Node in node.get_children():
		if child is Sprite3D or child is Sprite2D or child is MeshInstance3D:
			return child
	return null


## Scale the sprite from 1.0 -> 1.2 -> 1.0 over [param duration].
static func _pulse_sprite(sprite: Node, duration: float) -> Signal:
	var original_scale = sprite.scale
	var peak_scale = original_scale * 1.2
	var half: float = duration * 0.5
	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "scale", peak_scale, half)
	tween.tween_property(sprite, "scale", original_scale, half)
	return tween.finished


## Plain timer fallback when there is no visual to pulse.
static func _timer_delay(node: Node, duration: float) -> Signal:
	var tween: Tween = node.create_tween()
	tween.tween_interval(duration)
	return tween.finished
