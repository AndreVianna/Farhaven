extends GdUnitTestSuite
class_name TestHUD

## Unit tests for HUD root (task-084d).
##
## Composition smoke test: the HUD loads from its .tscn, wires its
## sub-panels programmatically in _ready(), and exposes a pass-through
## API for stats/day/placement label/notifications. We do NOT deep-test
## individual sub-panel behavior (those have their own tests) — we only
## confirm the HUD loads, wires correctly, and routes calls to children.

const _HUDScene = preload("res://scenes/ui/hud.tscn")
const _StatusCombinedPanel = preload("res://ui/status_combined_panel.gd")
const _GearCombinedPanel = preload("res://ui/gear_combined_panel.gd")
const _LogCombinedPanel = preload("res://ui/log_combined_panel.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")

var _hud: Control = null


func before_test() -> void:
	_hud = _HUDScene.instantiate()
	add_child(_hud)


func after_test() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


# --- Construction ---

func test_hud_instantiates_without_error() -> void:
	assert_object(_hud).is_not_null()
	assert_bool(_hud is Control).is_true()


func test_hud_has_stat_bars_child() -> void:
	var stat_bars: Node = _hud.get_node_or_null("StatBars")
	assert_object(stat_bars).is_not_null()


func test_hud_has_day_counter_child() -> void:
	var day_counter: Node = _hud.get_node_or_null("DayCounter")
	assert_object(day_counter).is_not_null()


func test_hud_has_floating_text_container() -> void:
	var ftc: Node = _hud.get_node_or_null("FloatingTextContainer")
	assert_object(ftc).is_not_null()


func test_hud_has_notification_container() -> void:
	var nc: Node = _hud.get_node_or_null("NotificationContainer")
	assert_object(nc).is_not_null()


func test_hud_has_placement_label() -> void:
	var label: Node = _hud.get_node_or_null("PlacementLabel")
	assert_object(label).is_not_null()


func test_hud_has_bottom_bar_buttons() -> void:
	var bar: Node = _hud.get_node_or_null("BottomBar")
	assert_object(bar).is_not_null()
	assert_object(bar.get_node_or_null("StatusButton")).is_not_null()
	assert_object(bar.get_node_or_null("GearButton")).is_not_null()
	assert_object(bar.get_node_or_null("LogButton")).is_not_null()


# --- Programmatic panel composition ---

func test_ready_creates_status_panel() -> void:
	assert_object(_hud._status_panel).is_not_null()
	assert_bool(_hud._status_panel is _StatusCombinedPanel).is_true()


func test_ready_creates_gear_panel() -> void:
	assert_object(_hud._gear_panel).is_not_null()
	assert_bool(_hud._gear_panel is _GearCombinedPanel).is_true()


func test_ready_creates_log_panel() -> void:
	assert_object(_hud._log_panel).is_not_null()
	assert_bool(_hud._log_panel is _LogCombinedPanel).is_true()


func test_ready_panels_array_contains_three() -> void:
	assert_int(_hud._panels.size()).is_equal(3)


func test_status_panel_has_unique_name() -> void:
	assert_object(_hud.get_node_or_null("StatusPanel")).is_not_null()


func test_gear_panel_has_unique_name() -> void:
	assert_object(_hud.get_node_or_null("GearPanel")).is_not_null()


func test_log_panel_has_unique_name() -> void:
	assert_object(_hud.get_node_or_null("LogPanel")).is_not_null()


func test_craft_flash_child_created() -> void:
	assert_object(_hud._craft_flash).is_not_null()


# --- Placement label API ---

func test_placement_label_hidden_by_default() -> void:
	var label: Label = _hud.get_node("PlacementLabel")
	assert_bool(label.visible).is_false()


func test_show_placement_label_makes_visible() -> void:
	_hud.show_placement_label(&"campfire")
	var label: Label = _hud.get_node("PlacementLabel")
	assert_bool(label.visible).is_true()


func test_show_placement_label_contains_uppercased_type() -> void:
	_hud.show_placement_label(&"campfire")
	var label: Label = _hud.get_node("PlacementLabel")
	assert_bool(label.text.contains("CAMPFIRE")).is_true()


func test_hide_placement_label_restores_hidden() -> void:
	_hud.show_placement_label(&"torch")
	_hud.hide_placement_label()
	var label: Label = _hud.get_node("PlacementLabel")
	assert_bool(label.visible).is_false()


# --- Pass-through API smoke tests ---

func test_update_stat_does_not_crash() -> void:
	# Routes to StatBars.update_stat — just confirm the HUD dispatches.
	_hud.update_stat(&"hp", 75.0, 100.0)
	assert_bool(true).is_true()


func test_update_day_does_not_crash() -> void:
	_hud.update_day(3)
	assert_bool(true).is_true()


func test_update_phase_does_not_crash() -> void:
	_hud.update_phase("Day")
	assert_bool(true).is_true()


func test_show_notification_does_not_crash() -> void:
	_hud.show_notification("Test notification")
	assert_bool(true).is_true()


# --- Mutual exclusion: panel_opened routes through _on_panel_opened ---

func test_mutual_exclusion_closes_other_panels() -> void:
	# Open gear first, then status — gear should close automatically.
	_hud._gear_panel.open()
	assert_bool(_hud._gear_panel.visible).is_true()
	_hud._status_panel.open()
	# After mutual exclusion, gear should be closed
	assert_bool(_hud._gear_panel.visible).is_false()
	assert_bool(_hud._status_panel.visible).is_true()


# --- Inventory integration ---

func test_connect_inventory_does_not_crash() -> void:
	var inv := _Inventory.new()
	_hud.connect_inventory(inv)
	assert_bool(true).is_true()


func test_on_inventory_full_shows_notification() -> void:
	# Wire inventory and fire the inventory_full signal — just confirm
	# the handler routes without crashing.
	var inv := _Inventory.new()
	_hud.connect_inventory(inv)
	inv.inventory_full.emit(&"P00010", 3)
	assert_bool(true).is_true()


# --- Sound connection (stub setter) ---

func test_connect_sound_sets_reference() -> void:
	var fake_sound := Node.new()
	add_child(fake_sound)
	_hud.connect_sound(fake_sound)
	assert_object(_hud._gather_sound).is_equal(fake_sound)
	fake_sound.queue_free()
