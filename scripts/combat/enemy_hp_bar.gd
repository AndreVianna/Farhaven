class_name EnemyHpBar
extends Control

## A simple HP bar that renders a green-to-red gradient based on HP ratio.
## Designed to be positioned in world-space above fauna instances.
##
## task-109: Enemy HP bar component.

var max_hp: int = 1
var current_hp: int = 1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40, 6)


func update_hp(hp: int, hp_max: int) -> void:
	current_hp = hp
	max_hp = hp_max
	queue_redraw()


func _draw() -> void:
	var ratio: float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
	var color: Color = Color.GREEN.lerp(Color.RED, 1.0 - ratio)
	var bar_width: float = size.x * ratio
	# Background
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.2, 0.2, 0.2))
	# Fill
	draw_rect(Rect2(0, 0, bar_width, size.y), color)
