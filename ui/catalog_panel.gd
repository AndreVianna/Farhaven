class_name CatalogPanel
extends PanelContainer

## Catalog bottom drawer panel (~45% screen height).
## Opens/closes on ScannerButton tap. Shows 4 category tabs with discovered entries.
## Emits panel_opened for mutual exclusion with other panels.

signal panel_opened()

const CatalogEntryUI = preload("res://ui/catalog_entry_ui.gd")

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
		_catalog.entry_cataloged.disconnect(_on_entry_cataloged)
	_catalog = cat
	if _catalog != null:
		_catalog.entry_cataloged.connect(_on_entry_cataloged)


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
	var entries: Array = _catalog.get_discovered_by_category(category)
	for entry in entries:
		var row := CatalogEntryUI.new()
		list.add_child(row)
		row.setup(entry)


func _on_entry_cataloged(_entry_id: StringName, _category: int) -> void:
	if visible:
		_refresh()
	elif _catalog != null:
		_counter_label.text = _catalog.get_discovery_text()
