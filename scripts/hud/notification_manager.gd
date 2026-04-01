class_name NotificationManager
extends VBoxContainer

const MAX_QUEUE_DEPTH: int = 3
const DURATION_FIRST: float = 2.0
const DURATION_QUEUED: float = 1.5
const FADE_TIME: float = 0.3

var _queue: Array[Dictionary] = []
var _is_showing: bool = false


func show_notification(text: String, _duration: float = 2.0) -> void:
	var was_queued := _is_showing
	if _queue.size() >= MAX_QUEUE_DEPTH:
		# Drop oldest unshown to stay within depth
		_queue.pop_front()
	_queue.append({"text": text, "was_queued": was_queued})
	if not _is_showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_is_showing = false
		return
	_is_showing = true
	var item: Dictionary = _queue.pop_front()
	var display_duration: float = DURATION_QUEUED if item["was_queued"] else DURATION_FIRST

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = item["text"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)
	panel.modulate.a = 0.0
	add_child(panel)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(display_duration)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func() -> void:
		panel.queue_free()
		_show_next()
	)
