class_name InventoryPanel
extends PanelContainer

## Inventory bottom drawer panel (~45% screen height).
## Opens/closes on InventoryButton tap. Renders tool slots + prop grid.
## Emits panel_opened for mutual exclusion with other panels.

signal panel_opened()

const InventorySlotUI = preload("res://ui/inventory_slot_ui.gd")
const ToolSlotUI = preload("res://ui/tool_slot_ui.gd")

const TOOL_SLOT_ORDER: Array[StringName] = [&"axe", &"pickaxe", &"weapon", &"scanner"]

var _inventory = null   # Inventory instance (set via set_inventory)
var _catalog = null     # Catalog instance (set via set_catalog, optional)
var _slot_nodes: Array = []
var _tool_slot_nodes: Dictionary = {}
var _pending_use_type: StringName = &""
var _confirm_dialog: ConfirmationDialog

@onready var _tool_slots_row: HBoxContainer = $VBox/ToolSlotsRow
@onready var _prop_grid: GridContainer = $VBox/ScrollContainer/PropGrid
@onready var _close_button: Button = $VBox/Header/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)

	# Create tool slot nodes
	for slot_name: StringName in TOOL_SLOT_ORDER:
		var ts := ToolSlotUI.new()
		_tool_slots_row.add_child(ts)
		ts.setup(slot_name)
		_tool_slot_nodes[slot_name] = ts

	# Toxic warning dialog
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Warning"
	_confirm_dialog.dialog_text = "This item is toxic!\nConsume anyway?"
	_confirm_dialog.get_ok_button().text = "Yes"
	_confirm_dialog.get_ok_button().custom_minimum_size = Vector2(120, 48)
	_confirm_dialog.get_cancel_button().text = "No"
	_confirm_dialog.get_cancel_button().custom_minimum_size = Vector2(120, 48)
	_confirm_dialog.confirmed.connect(_on_toxic_confirmed)
	add_child(_confirm_dialog)

	# Panel background style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_top = 2
	style.border_color = Color(0.40, 0.40, 0.50, 0.8)
	add_theme_stylebox_override("panel", style)


# --- Public API ---

func set_inventory(inv) -> void:
	if _inventory != null:
		_inventory.inventory_changed.disconnect(_on_inventory_changed)
		_inventory.tool_changed.disconnect(_on_tool_changed)
	_inventory = inv
	if _inventory != null:
		_inventory.inventory_changed.connect(_on_inventory_changed)
		_inventory.tool_changed.connect(_on_tool_changed)
		_rebuild_slots()
		_refresh_all()


func set_catalog(cat) -> void:
	_catalog = cat


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	visible = true
	_refresh_all()
	panel_opened.emit()


func close() -> void:
	visible = false


# --- Slot management ---

func _rebuild_slots() -> void:
	for node in _slot_nodes:
		node.queue_free()
	_slot_nodes.clear()
	var count: int = _inventory.get_max_slots() if _inventory != null else 12
	for i: int in count:
		var slot := InventorySlotUI.new()
		slot.slot_tapped.connect(_on_slot_tapped)
		_prop_grid.add_child(slot)
		_slot_nodes.append(slot)


func _refresh_all() -> void:
	if _inventory == null:
		return
	var slots: Array = _inventory.get_slots()
	if _slot_nodes.size() != slots.size():
		_rebuild_slots()
		slots = _inventory.get_slots()
	for i: int in _slot_nodes.size():
		if i < slots.size():
			(_slot_nodes[i] as InventorySlotUI).refresh(slots[i])
	for slot_name: StringName in TOOL_SLOT_ORDER:
		var tool_type: StringName = _inventory.get_tool(slot_name)
		if _tool_slot_nodes.has(slot_name):
			(_tool_slot_nodes[slot_name] as ToolSlotUI).refresh(tool_type)


# --- Consumable tap ---

func _on_slot_tapped(type: StringName) -> void:
	if _inventory == null:
		return
	if _is_toxic_flora(type):
		_pending_use_type = type
		_confirm_dialog.popup_centered()
	else:
		_inventory.use_item(type)


func _on_toxic_confirmed() -> void:
	if _pending_use_type != &"" and _inventory != null:
		_inventory.use_item(_pending_use_type)
	_pending_use_type = &""


func _is_toxic_flora(type: StringName) -> bool:
	# Toxicity is now driven by PropDef.toxic_amount on the consumable item itself.
	# Catalog reference no longer required — but kept available for future filtering.
	var def: PropDef = PropRegistry.get_def(type)
	if def == null:
		return false
	return def.is_consumable and def.toxic_amount > 0.0


# --- Inventory signal handlers ---

func _on_inventory_changed() -> void:
	if visible:
		_refresh_all()


func _on_tool_changed(slot: StringName, new_tool: StringName, _old_tool: StringName) -> void:
	if visible and _tool_slot_nodes.has(slot):
		(_tool_slot_nodes[slot] as ToolSlotUI).refresh(new_tool)
