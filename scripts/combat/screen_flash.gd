class_name ScreenFlash
extends ColorRect

## Lightweight full-screen colour flash overlay.
## Used for hit feedback — flashes red when the player takes damage.
##
## task-110: Screen flash on player hit.


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(1.0, 0.0, 0.0, 0.0)
	visible = false


func flash(flash_color: Color = Color(1, 0, 0, 0.3), duration: float = 0.2) -> void:
	self.color = flash_color
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "color:a", 0.0, duration)
	tween.tween_callback(func() -> void: visible = false)
