class_name StatusStatsSection
extends VBoxContainer

## Player stats sub-section for the Status combined panel (task-082).
## Shows HP / Hunger / Thirst bars, day counter, chapter label.
## Reads live state from a SurvivalSystem (duck-typed — any Node with the
## expected fields + stat_changed signal works). DayNightCycle is also
## duck-typed so tests can inject a mock.

const _STAT_HP: StringName = &"hp"
const _STAT_HUNGER: StringName = &"hunger"
const _STAT_THIRST: StringName = &"thirst"

const _STAT_ROWS: Array = [
	{"key": _STAT_HP, "label": "HP"},
	{"key": _STAT_HUNGER, "label": "Hunger"},
	{"key": _STAT_THIRST, "label": "Thirst"},
]

var _bars: Dictionary = {}         # StringName → ProgressBar
var _value_labels: Dictionary = {} # StringName → Label
var _bar_fills: Dictionary = {}    # StringName → StyleBoxFlat
var _day_label: Label = null
var _chapter_label: Label = null

var _survival: Node = null
var _day_night: Node = null


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	_build_ui()
	_refresh_all()


func _build_ui() -> void:
	# Section header
	var header := Label.new()
	header.name = "StatsHeader"
	header.text = "PLAYER STATS"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95, 1.0))
	add_child(header)

	var sep := HSeparator.new()
	add_child(sep)

	# Stat bars
	for row: Dictionary in _STAT_ROWS:
		_build_stat_row(row["key"], row["label"])

	# Divider before day / chapter
	var sep2 := HSeparator.new()
	sep2.custom_minimum_size = Vector2(0, 4)
	add_child(sep2)

	# Day counter row
	var day_row := HBoxContainer.new()
	day_row.name = "DayRow"
	day_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_row.add_theme_constant_override("separation", 12)
	add_child(day_row)

	var day_title := Label.new()
	day_title.text = "Day"
	day_title.custom_minimum_size = Vector2(80, 0)
	day_title.add_theme_font_size_override("font_size", 18)
	day_row.add_child(day_title)

	_day_label = Label.new()
	_day_label.name = "DayValue"
	_day_label.text = "01"
	_day_label.add_theme_font_size_override("font_size", 18)
	_day_label.add_theme_color_override("font_color", Color(1.0, 0.851, 0.239, 1.0))
	day_row.add_child(_day_label)

	# Chapter row
	var chapter_row := HBoxContainer.new()
	chapter_row.name = "ChapterRow"
	chapter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_row.add_theme_constant_override("separation", 12)
	add_child(chapter_row)

	var chapter_title := Label.new()
	chapter_title.text = "Chapter"
	chapter_title.custom_minimum_size = Vector2(80, 0)
	chapter_title.add_theme_font_size_override("font_size", 18)
	chapter_row.add_child(chapter_title)

	_chapter_label = Label.new()
	_chapter_label.name = "ChapterValue"
	_chapter_label.text = "Chapter 1"
	_chapter_label.add_theme_font_size_override("font_size", 18)
	_chapter_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.95, 1.0))
	chapter_row.add_child(_chapter_label)


func _build_stat_row(key: StringName, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.name = String(key).capitalize() + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	var title := Label.new()
	title.text = label_text
	title.custom_minimum_size = Vector2(80, 0)
	title.add_theme_font_size_override("font_size", 16)
	row.add_child(title)

	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fill := StyleBoxFlat.new()
	fill.bg_color = _color_for_stat(key, 1.0)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)

	row.add_child(bar)

	var value := Label.new()
	value.name = "Value"
	value.text = "-- / --"
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 14)
	row.add_child(value)

	_bars[key] = bar
	_bar_fills[key] = fill
	_value_labels[key] = value


# --- Public API ---

func set_survival_system(survival: Node) -> void:
	if _survival != null and _survival.has_signal("stat_changed"):
		if _survival.stat_changed.is_connected(_on_stat_changed):
			_survival.stat_changed.disconnect(_on_stat_changed)
	_survival = survival
	if _survival != null and _survival.has_signal("stat_changed"):
		_survival.stat_changed.connect(_on_stat_changed)
	_refresh_all()


func set_day_night_cycle(day_night: Node) -> void:
	if _day_night != null and _day_night.has_signal("day_started"):
		if _day_night.day_started.is_connected(_on_day_started):
			_day_night.day_started.disconnect(_on_day_started)
	_day_night = day_night
	if _day_night != null and _day_night.has_signal("day_started"):
		_day_night.day_started.connect(_on_day_started)
	_refresh_day()


func set_chapter(chapter_text: String) -> void:
	if _chapter_label != null:
		_chapter_label.text = chapter_text


# --- Accessors used by tests ---

func get_bar(key: StringName) -> ProgressBar:
	return _bars.get(key, null)


func get_value_label(key: StringName) -> Label:
	return _value_labels.get(key, null)


func get_day_label() -> Label:
	return _day_label


func get_chapter_label() -> Label:
	return _chapter_label


# --- Refresh logic ---

func _refresh_all() -> void:
	_refresh_stat(_STAT_HP)
	_refresh_stat(_STAT_HUNGER)
	_refresh_stat(_STAT_THIRST)
	_refresh_day()


func _refresh_stat(key: StringName) -> void:
	if _bars.is_empty():
		return
	var bar: ProgressBar = _bars.get(key, null)
	var value_label: Label = _value_labels.get(key, null)
	if bar == null or value_label == null:
		return
	var current: float = -1.0
	var max_val: float = -1.0
	if _survival != null:
		var pair: Array = _read_stat(key)
		current = pair[0]
		max_val = pair[1]
	if current < 0.0 or max_val <= 0.0:
		# Not available → show N/A
		bar.max_value = 1.0
		bar.value = 0.0
		value_label.text = "N/A"
		var fill: StyleBoxFlat = _bar_fills.get(key, null)
		if fill != null:
			fill.bg_color = Color(0.4, 0.4, 0.45, 0.6)
		return
	bar.max_value = max_val
	bar.value = current
	value_label.text = "%d / %d" % [int(round(current)), int(round(max_val))]
	var fill2: StyleBoxFlat = _bar_fills.get(key, null)
	if fill2 != null:
		var ratio: float = current / max_val if max_val > 0.0 else 0.0
		fill2.bg_color = _color_for_stat(key, ratio)


func _read_stat(key: StringName) -> Array:
	## Returns [current, max] for the given stat, or [-1, -1] if not available.
	## Duck-typed read — tolerates any Node exposing the expected properties.
	if _survival == null:
		return [-1.0, -1.0]
	match key:
		_STAT_HP:
			if "hp" in _survival and "hp_max" in _survival:
				return [float(_survival.hp), float(_survival.hp_max)]
		_STAT_HUNGER:
			if "hunger" in _survival and "hunger_max" in _survival:
				return [float(_survival.hunger), float(_survival.hunger_max)]
		_STAT_THIRST:
			if "thirst" in _survival and "thirst_max" in _survival:
				return [float(_survival.thirst), float(_survival.thirst_max)]
	return [-1.0, -1.0]


func _refresh_day() -> void:
	if _day_label == null:
		return
	var day: int = 1
	if _day_night != null and "day_count" in _day_night:
		day = int(_day_night.day_count)
	_day_label.text = "%02d" % day


# --- Signal handlers ---

func _on_stat_changed(stat_name: StringName, current: float, max_val: float) -> void:
	var bar: ProgressBar = _bars.get(stat_name, null)
	var value_label: Label = _value_labels.get(stat_name, null)
	if bar == null or value_label == null:
		return
	bar.max_value = max_val
	bar.value = current
	value_label.text = "%d / %d" % [int(round(current)), int(round(max_val))]
	var fill: StyleBoxFlat = _bar_fills.get(stat_name, null)
	if fill != null:
		var ratio: float = current / max_val if max_val > 0.0 else 0.0
		fill.bg_color = _color_for_stat(stat_name, ratio)


func _on_day_started() -> void:
	_refresh_day()


# --- Helpers ---

static func _color_for_stat(stat_name: StringName, ratio: float) -> Color:
	if stat_name == &"thirst":
		if ratio > 0.5:
			return Color(0.2, 0.5, 0.9)
		elif ratio > 0.25:
			return Color(0.9, 0.8, 0.2)
		return Color(0.9, 0.2, 0.2)
	# hp and hunger default
	if ratio > 0.5:
		return Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		return Color(0.9, 0.8, 0.2)
	return Color(0.9, 0.2, 0.2)
