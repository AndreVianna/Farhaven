class_name DayCounter
extends HBoxContainer

const PHASE_COLORS: Dictionary = {
	"DAY": Color(1.0, 0.851, 0.239, 1.0),    # #FFD93D warm yellow
	"DUSK": Color(1.0, 0.702, 0.278, 1.0),   # #FFB347 warm orange
	"NIGHT": Color(0.608, 0.490, 0.784, 1.0), # #9B7DC8 soft purple
	"DAWN": Color(1.0, 0.671, 0.569, 1.0),   # #FFAB91 peach
}

@onready var _day_label: Label = $DayLabel
@onready var _phase_icon: ColorRect = $PhaseIcon


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_day_label.mouse_filter = MOUSE_FILTER_IGNORE
	_phase_icon.mouse_filter = MOUSE_FILTER_IGNORE
	update_day(1)
	update_phase("DAY")


func update_day(day: int) -> void:
	_day_label.text = "DAY %02d" % day


func update_phase(phase: String) -> void:
	var color: Color = PHASE_COLORS.get(phase, PHASE_COLORS["DAY"])
	_phase_icon.color = color
	_day_label.modulate = color
