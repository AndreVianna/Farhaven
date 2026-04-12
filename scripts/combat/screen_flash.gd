class_name ScreenFlash
extends ColorRect

## Lightweight full-screen colour flash overlay.
## Used for hit feedback — flashes red when the player takes damage.
##
## task-110: Screen flash on player hit.


var _active_tween: Tween = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(1.0, 0.0, 0.0, 0.0)
	visible = false


func flash(flash_color: Color = Color(1, 0, 0, 0.3), duration: float = 0.2) -> void:
	# Kill any in-flight tween so rapid flashes don't stomp each other's
	# visibility callback and produce flicker / truncated feedback.
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	self.color = flash_color
	visible = true
	_active_tween = create_tween()
	_active_tween.tween_property(self, "color:a", 0.0, duration)
	_active_tween.tween_callback(func() -> void: visible = false)
