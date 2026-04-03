extends ColorRect
class_name CraftFlash

## Brief screen flash effect for successful crafting.
## Flashes a white overlay that fades out quickly.

const FLASH_DURATION: float = 0.25
const FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.3)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(1.0, 1.0, 1.0, 0.0)
	visible = false


## Trigger the craft-success flash.
func flash() -> void:
	color = FLASH_COLOR
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "color:a", 0.0, FLASH_DURATION)
	tween.tween_callback(func() -> void: visible = false)
