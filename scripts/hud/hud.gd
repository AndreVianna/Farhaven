class_name HUD
extends Control

@onready var _stat_bars := $TopBar/StatBars
@onready var _day_counter := $TopBar/DayCounter
@onready var _floating_text := $FloatingTextContainer
@onready var _notifications := $NotificationContainer
@onready var _placement_label: Label = $PlacementLabel
@onready var _craft_button: Button = $BottomBar/CraftButton


func _ready() -> void:
	_placement_label.hide()
	_craft_button.hide()


# --- Placement label API (called by BuildingSystem feature-009) ---

func show_placement_label(structure_type: StringName) -> void:
	_placement_label.text = "TAP TO PLACE %s" % structure_type.to_upper()
	_placement_label.show()


func hide_placement_label() -> void:
	_placement_label.hide()


# --- Convenience pass-throughs so callers can use HUD as a single entry point ---

func show_text(world_pos: Vector3, text: String, color: Color, duration: float = 1.0) -> void:
	_floating_text.show_text(world_pos, text, color, duration)


func show_notification(text: String, duration: float = 2.0) -> void:
	_notifications.show_notification(text, duration)


func update_stat(stat_name: StringName, value: float, max_value: float) -> void:
	_stat_bars.update_stat(stat_name, value, max_value)


func update_day(day: int) -> void:
	_day_counter.update_day(day)


func update_phase(phase: String) -> void:
	_day_counter.update_phase(phase)
