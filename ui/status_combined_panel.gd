class_name StatusCombinedPanel
extends CombinedPanel

## STATUS panel: Left = Status (stats + discoveries + nav), Right = Inventory.

const _InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")
const _StatsSection = preload("res://ui/status_stats_section.gd")
const _DiscoveriesSection = preload("res://ui/status_discoveries_section.gd")
const _NavSection = preload("res://ui/status_nav_section.gd")

var _inventory_panel: InventoryPanel = null
# Sections are typed as Node (duck-typed) on purpose: the concrete classes
# (StatusStatsSection / StatusDiscoveriesSection / StatusNavSection) are
# loaded via preload-as-const above, matching inventory_panel.gd's pattern
# that avoids the class_name-not-yet-registered race at parse time. The
# methods called below (set_survival_system / set_day_night_cycle /
# set_catalog) live on the concrete subclasses and are resolved at runtime.
var _stats_section: Node = null
var _discoveries_section: Node = null
var _nav_section: Node = null


func _init() -> void:
	super("STATUS", "INVENTORY")


func _build_left_content(parent: VBoxContainer) -> void:
	# Section container with padding between sections
	var vbox := VBoxContainer.new()
	vbox.name = "StatusLeft"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18)
	parent.add_child(vbox)

	# Header
	var header := Label.new()
	header.name = "StatusHeader"
	header.text = "STATUS"
	header.add_theme_font_size_override("font_size", 28)
	vbox.add_child(header)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Stats section
	_stats_section = _StatsSection.new()
	_stats_section.name = "StatsSection"
	vbox.add_child(_stats_section)

	# Discoveries section
	_discoveries_section = _DiscoveriesSection.new()
	_discoveries_section.name = "DiscoveriesSection"
	vbox.add_child(_discoveries_section)

	# Navigation section
	_nav_section = _NavSection.new()
	_nav_section.name = "NavSection"
	vbox.add_child(_nav_section)

	# Spacer pushes everything up
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)


func _build_right_content(parent: VBoxContainer) -> void:
	_inventory_panel = _InventoryPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_inventory_panel, parent)


func _on_opened() -> void:
	if _inventory_panel != null:
		_inventory_panel.open()


# --- Pass-through API ---

func set_inventory(inv) -> void:
	if _inventory_panel != null:
		_inventory_panel.set_inventory(inv)


func set_catalog(cat) -> void:
	if _inventory_panel != null:
		_inventory_panel.set_catalog(cat)
	if _discoveries_section != null:
		_discoveries_section.set_catalog(cat)


## Forwarded to the inventory sub-panel so its header can display the
## equipped container's name + current occupancy percentage.
func set_container_def(def) -> void:
	if _inventory_panel != null:
		_inventory_panel.set_container_def(def)


func set_survival_system(survival: Node) -> void:
	if _stats_section != null:
		_stats_section.set_survival_system(survival)


func set_day_night_cycle(day_night: Node) -> void:
	if _stats_section != null:
		_stats_section.set_day_night_cycle(day_night)


func set_chapter(chapter_text: String) -> void:
	if _stats_section != null:
		_stats_section.set_chapter(chapter_text)


func get_inventory_panel() -> InventoryPanel:
	return _inventory_panel


func get_stats_section() -> Node:
	return _stats_section


func get_discoveries_section() -> Node:
	return _discoveries_section


func get_nav_section() -> Node:
	return _nav_section
