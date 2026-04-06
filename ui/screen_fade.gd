extends CanvasLayer

## ScreenFade — full-screen fade overlay for death/respawn transitions.
## Layer 30 so it renders above all game UI.

signal fade_out_completed()
signal fade_in_completed()

var _color_rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 30
	_color_rect = ColorRect.new()
	_color_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)


## Fade screen to black: alpha 0 → 1.
func fade_out(duration: float = 1.5) -> void:
	_kill_tween()
	_color_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_tween = create_tween()
	_tween.tween_property(_color_rect, "color:a", 1.0, duration)
	_tween.finished.connect(func() -> void:
		fade_out_completed.emit()
	)


## Fade screen from black: alpha 1 → 0.
func fade_in(duration: float = 1.5) -> void:
	_kill_tween()
	_color_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_tween = create_tween()
	_tween.tween_property(_color_rect, "color:a", 0.0, duration)
	_tween.finished.connect(func() -> void:
		fade_in_completed.emit()
	)


## Brief color pulse: alpha 0 → 1 → 0.
func flash(color: Color = Color.RED, duration: float = 0.2) -> void:
	_kill_tween()
	_color_rect.color = Color(color.r, color.g, color.b, 0.0)
	_tween = create_tween()
	var half: float = duration * 0.5
	_tween.tween_property(_color_rect, "color:a", 1.0, half)
	_tween.tween_property(_color_rect, "color:a", 0.0, half)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
