class_name CatalogPanel
extends PanelContainer

## Catalog bottom drawer panel (~45% screen height).
## Opens/closes on ScannerButton tap. Shows 4 category tabs with discovered entries.
## Supports 3-state display: ENCOUNTERED entries show "Unidentified Fauna (label)"
## with no details. CATALOGED entries show full info.
## Emits panel_opened for mutual exclusion with other panels.

signal panel_opened()

const CatalogEntryUI = preload("res://ui/catalog_entry_ui.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")

@onready var _counter_label: Label = $VBox/Header/CounterLabel
@onready var _close_button: Button = $VBox/Header/CloseButton
@onready var _tabs: TabContainer = $VBox/CategoryTabs
@onready var _flora_list: VBoxContainer = $VBox/CategoryTabs/Flora/FloraList
@onready var _fauna_list: VBoxContainer = $VBox/CategoryTabs/Fauna/FaunaList
@onready var _mineral_list: VBoxContainer = $VBox/CategoryTabs/Minerals/MineralList
@onready var _anomaly_list: VBoxContainer = $VBox/CategoryTabs/Anomalies/AnomalyList

var _catalog: Catalog = null


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_top = 2
	style.border_color = Color(0.40, 0.40, 0.50, 0.8)
	add_theme_stylebox_override("panel", style)


# --- Public API ---

func set_catalog(cat: Catalog) -> void:
	if _catalog != null:
		if _catalog.entry_cataloged.is_connected(_on_entry_cataloged):
			_catalog.entry_cataloged.disconnect(_on_entry_cataloged)
		if _catalog.entry_encountered.is_connected(_on_entry_encountered):
			_catalog.entry_encountered.disconnect(_on_entry_encountered)
	_catalog = cat
	if _catalog != null:
		_catalog.entry_cataloged.connect(_on_entry_cataloged)
		_catalog.entry_encountered.connect(_on_entry_encountered)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	visible = true
	_refresh()
	panel_opened.emit()


func close() -> void:
	visible = false


# --- Internal ---

func _refresh() -> void:
	if _catalog == null:
		return
	_counter_label.text = _catalog.get_discovery_text()
	_populate_list(_flora_list, Catalog.CatalogCategory.FLORA)
	_populate_list(_fauna_list, Catalog.CatalogCategory.FAUNA)
	_populate_list(_mineral_list, Catalog.CatalogCategory.MINERAL)
	_populate_list(_anomaly_list, Catalog.CatalogCategory.ANOMALY)


func _populate_list(list: VBoxContainer, category: int) -> void:
	for child in list.get_children():
		child.queue_free()
	var discovered: Array = _catalog.get_discovered_by_category(category)
	for item in discovered:
		var row := CatalogEntryUI.new()
		list.add_child(row)
		var eid: StringName = item.entry_id
		var state: int = _catalog.get_knowledge_state(eid)
		if state == Catalog.KnowledgeState.ENCOUNTERED:
			var label: String = _catalog.get_encounter_label(eid)
			row.setup_encountered(label)
		else:
			row.setup(item.entry)


func _on_entry_cataloged(_entry_id: StringName, _category: int) -> void:
	if visible:
		_refresh()
	elif _catalog != null:
		_counter_label.text = _catalog.get_discovery_text()


func _on_entry_encountered(_entry_id: StringName, _label: String) -> void:
	if visible:
		_refresh()
	elif _catalog != null:
		_counter_label.text = _catalog.get_discovery_text()
