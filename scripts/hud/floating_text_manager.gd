class_name FloatingTextManager
extends Control

const RISE_PIXELS: float = 60.0
const STACK_OFFSET: float = 30.0

var _active_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_text(world_pos: Vector3, text: String, color: Color, duration: float = 1.0) -> void:
	var screen_pos := _world_to_screen(world_pos)
	screen_pos.y -= float(_active_labels.size()) * STACK_OFFSET

	var label := Label.new()
	label.text = text
	label.modulate = color
	label.position = screen_pos
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	_active_labels.append(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - RISE_PIXELS, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(_on_label_done.bind(label))


func _on_label_done(label: Label) -> void:
	_active_labels.erase(label)
	label.queue_free()


func _world_to_screen(world_pos: Vector3) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if camera and is_instance_valid(camera):
		return camera.unproject_position(world_pos)
	# Fallback when camera not yet available (task-006 adds Camera3D)
	return get_viewport_rect().size * 0.5
