class_name HUD
extends Control

const _CraftFlash = preload("res://scripts/hud/craft_flash.gd")
const _StatusCombinedPanel = preload("res://ui/status_combined_panel.gd")
const _GearCombinedPanel = preload("res://ui/gear_combined_panel.gd")
const _LogCombinedPanel = preload("res://ui/log_combined_panel.gd")

@onready var _stat_bars := $StatBars
@onready var _day_counter := $DayCounter
@onready var _floating_text := $FloatingTextContainer
@onready var _notifications := $NotificationContainer
@onready var _placement_label: Label = $PlacementLabel
@onready var _status_button: Button = $BottomBar/StatusButton
@onready var _gear_button: Button = $BottomBar/GearButton
@onready var _log_button: Button = $BottomBar/LogButton

var _status_panel: StatusCombinedPanel = null
var _gear_panel: GearCombinedPanel = null
var _log_panel: LogCombinedPanel = null
var _panels: Array = []
var _craft_flash: ColorRect = null
var _gather_sound: Node = null  # GatherSound (set via connect_sound)


func _ready() -> void:
	_placement_label.hide()

	# Create combined panels programmatically
	_status_panel = _StatusCombinedPanel.new()
	_status_panel.name = "StatusPanel"
	add_child(_status_panel)

	_gear_panel = _GearCombinedPanel.new()
	_gear_panel.name = "GearPanel"
	add_child(_gear_panel)

	_log_panel = _LogCombinedPanel.new()
	_log_panel.name = "LogPanel"
	add_child(_log_panel)

	# Wire buttons to combined panels
	_status_button.pressed.connect(_status_panel.toggle)
	_gear_button.pressed.connect(_gear_panel.toggle)
	_log_button.pressed.connect(_log_panel.toggle)

	# Mutual exclusion
	_panels = [_status_panel, _gear_panel, _log_panel]
	_status_panel.panel_opened.connect(_on_panel_opened.bind(_status_panel))
	_gear_panel.panel_opened.connect(_on_panel_opened.bind(_gear_panel))
	_log_panel.panel_opened.connect(_on_panel_opened.bind(_log_panel))

	# Craft flash overlay (fullscreen, on top)
	_craft_flash = _CraftFlash.new()
	add_child(_craft_flash)


# --- Placement label API (called by BuildingSystem feature-009) ---

func show_placement_label(structure_type: StringName) -> void:
	_placement_label.text = "TAP TO PLACE %s" % String(structure_type).to_upper()
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


# --- Inventory integration ---

func connect_inventory(inv) -> void:
	_status_panel.set_inventory(inv)
	inv.inventory_full.connect(_on_inventory_full)


func _on_inventory_full(_type: StringName, _rejected: int) -> void:
	# Using show_notification instead of FloatingTextManager because the
	# inventory_full signal carries no world position — the item was rejected
	# before placement, so there is no spatial anchor to attach a float to.
	show_notification("INVENTORY FULL")


# --- Catalog integration ---

func connect_catalog(cat) -> void:
	_log_panel.set_catalog(cat)
	# Also pass catalog to inventory panel for toxic flora checks
	_status_panel.set_catalog(cat)


# --- Crafting integration ---

func connect_crafting(crafting_system: Node, inv) -> void:
	_gear_panel.set_crafting_system(crafting_system)
	_gear_panel.set_inventory(inv)
	crafting_system.station_proximity_changed.connect(_on_station_proximity_changed)
	crafting_system.recipe_discovered.connect(_on_recipe_discovered)
	crafting_system.craft_completed.connect(_on_craft_completed)


func _on_station_proximity_changed(_near: bool) -> void:
	# Craft button visible whenever recipes are discovered (not just near station)
	pass


func _on_recipe_discovered(recipe_name: StringName) -> void:
	var display_name: String = String(recipe_name).replace("_", " ").capitalize()
	show_notification("New recipe: %s!" % display_name)


func _on_craft_completed(recipe_name: StringName) -> void:
	var display_name: String = String(recipe_name).replace("_", " ").capitalize()
	show_notification("Crafted %s!" % display_name)
	# Flash + sound feedback
	if _craft_flash != null:
		_craft_flash.flash()
	if _gather_sound != null and _gather_sound.has_method("play_craft_success"):
		_gather_sound.play_craft_success()


# --- Auto-gather feedback integration ---

func connect_auto_interaction(auto_interaction: Node) -> void:
	auto_interaction.auto_gather_completed.connect(_on_auto_gather_completed)
	auto_interaction.auto_gather_failed.connect(_on_auto_gather_failed)
	auto_interaction.auto_defend_triggered.connect(_on_auto_defend_triggered)


func _on_auto_gather_completed(_coords: Vector2i, resource_type: StringName, amount: int) -> void:
	var display_name: String = String(resource_type).replace("_", " ").capitalize()
	var text: String = "+%d %s" % [amount, display_name]
	var player: Node = _get_player()
	if player:
		show_text(player.position, text, Color.GREEN)
	# Sound hook
	if _gather_sound != null and _gather_sound.has_method("play_gather_ding"):
		_gather_sound.play_gather_ding()


func _on_auto_gather_failed(_coords: Vector2i, reason: StringName) -> void:
	var player: Node = _get_player()
	var pos: Vector3 = player.position if player else Vector3.ZERO
	if reason == &"inventory_full":
		show_text(pos, "INVENTORY FULL", Color.RED)
	elif reason == &"tool_gated":
		show_text(pos, "REQUIRES TOOL", Color.RED)


func _on_auto_defend_triggered(_fauna_id: int, damage: int) -> void:
	# Stub: show damage at player position until fauna positions are available.
	var player: Node = _get_player()
	if player:
		show_text(player.position, "-%d" % damage, Color.RED)


func _get_player() -> Node:
	# Walk up to find the Main node, then locate Player
	var main: Node = get_parent()  # CanvasLayer "HUD"
	if main:
		main = main.get_parent()  # Main node
	if main:
		return main.get_node_or_null("World/Player")
	return null


# --- Sound integration ---

func connect_sound(sound_node: Node) -> void:
	_gather_sound = sound_node


# --- Mutual exclusion: closing other panels when one opens ---

func _on_panel_opened(opened_panel) -> void:
	for panel in _panels:
		if panel != opened_panel:
			panel.close()
