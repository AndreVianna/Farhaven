class_name StatBars
extends VBoxContainer

var _bars: Dictionary = {}
var _bar_fills: Dictionary = {}
var _tweens: Dictionary = {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_bars[&"hp"] = $HPBar
	_bars[&"hunger"] = $HungerBar
	_bars[&"thirst"] = $ThirstBar
	for stat_name in _bars:
		_setup_bar(stat_name, _bars[stat_name])


func update_stat(stat_name: StringName, value: float, max_value: float) -> void:
	var bar: ProgressBar = _bars.get(stat_name)
	if not bar:
		return
	bar.max_value = max_value
	var ratio: float = value / max_value if max_value > 0.0 else 0.0
	var fill: StyleBoxFlat = _bar_fills.get(stat_name)
	if fill:
		fill.bg_color = _color_for_stat(stat_name, ratio)
	if _tweens.has(stat_name) and is_instance_valid(_tweens[stat_name]):
		_tweens[stat_name].kill()
	var tween := create_tween()
	_tweens[stat_name] = tween
	tween.tween_property(bar, "value", value, 0.2)


func _setup_bar(stat_name: StringName, bar: ProgressBar) -> void:
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0

	var fill := StyleBoxFlat.new()
	fill.bg_color = _color_for_stat(stat_name, 1.0)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	_bar_fills[stat_name] = fill

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)


func _color_for_stat(stat_name: StringName, ratio: float) -> Color:
	if stat_name == &"thirst":
		if ratio > 0.5:
			return Color(0.2, 0.5, 0.9)   # blue
		elif ratio > 0.25:
			return Color(0.9, 0.8, 0.2)   # yellow
		return Color(0.9, 0.2, 0.2)       # red
	else:
		if ratio > 0.5:
			return Color(0.2, 0.8, 0.2)   # green
		elif ratio > 0.25:
			return Color(0.9, 0.8, 0.2)   # yellow
		return Color(0.9, 0.2, 0.2)       # red
