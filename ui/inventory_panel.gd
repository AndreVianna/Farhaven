class_name InventoryPanel
extends PanelContainer

## Inventory bottom drawer panel (~45% screen height).
## Opens/closes on InventoryButton tap. Renders tool slots + grid canvas.
## Emits panel_opened for mutual exclusion with other panels.
##
## Rewritten in delivery-006f (tasks 092+093) from list-based InventorySlotUI
## layout to a 2D grid canvas that renders item shapes as colored silhouettes.

signal panel_opened()

const ToolSlotUI = preload("res://ui/tool_slot_ui.gd")
## Uses preload because tests can be parsed before class_name registration completes.
const _PropDef = preload("res://scripts/data/prop_def.gd")

## Only the scanner stays body-integrated after delivery-006f. Axe, pickaxe,
## and weapon now live inside the grid inventory and are located via
## Inventory.find_best_tool_for_action().
const TOOL_SLOT_ORDER: Array[StringName] = [&"scanner"]

var _inventory = null   # Inventory instance (set via set_inventory)
var _catalog = null      # Catalog instance (set via set_catalog, optional)
var _container_def = null  # PropDef of the active container (for header title)
var _tool_slot_nodes: Dictionary = {}
var _pending_use_type: StringName = &""
var _confirm_dialog: ConfirmationDialog
var _grid_canvas: Control  # GridCanvas inner class instance
var _pending_inventory = null  # set_inventory() called before _ready()

@onready var _tool_slots_row: HBoxContainer = $VBox/ToolSlotsRow
@onready var _scroll: ScrollContainer = $VBox/ScrollContainer
@onready var _close_button: Button = $VBox/Header/CloseButton
@onready var _title_label: Label = $VBox/Header/TitleLabel


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)

	# Create tool slot nodes
	for slot_name: StringName in TOOL_SLOT_ORDER:
		var ts := ToolSlotUI.new()
		_tool_slots_row.add_child(ts)
		ts.setup(slot_name)
		_tool_slot_nodes[slot_name] = ts

	# Create grid canvas inside the scroll container
	_grid_canvas = GridCanvas.new()
	_grid_canvas.item_clicked.connect(_on_grid_item_clicked)
	_scroll.add_child(_grid_canvas)
	# Keep cells scaled to the available panel width. The scroll container's
	# content width is the viewport width minus the vertical scrollbar.
	_scroll.resized.connect(_on_scroll_resized)

	# Apply any inventory that was set before _ready() ran.
	if _pending_inventory != null:
		_grid_canvas.set_inventory(_pending_inventory)
		_refresh_all()
		_pending_inventory = null

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
		# Guard against set_inventory() being called before _ready() creates
		# _grid_canvas. We stash the inventory and apply it in _ready().
		if _grid_canvas != null:
			_grid_canvas.set_inventory(_inventory)
			_refresh_all()
		else:
			_pending_inventory = _inventory


func set_catalog(cat) -> void:
	_catalog = cat


## Sets the PropDef whose display_name becomes the header title. The header
## also shows the current occupancy as a percentage of total grid cells.
func set_container_def(def) -> void:
	_container_def = def
	if _title_label != null:
		_refresh_header()


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


# --- Refresh ---

func _refresh_all() -> void:
	if _inventory == null:
		return
	if _grid_canvas != null:
		# Recompute custom_minimum_size in case the grid dimensions changed
		# (e.g. expand(), capacity_size setter, or load_save_data).
		_grid_canvas._fit_to_width(_available_grid_width())
		_grid_canvas._update_size()
		_grid_canvas.queue_redraw()
	_refresh_header()
	for slot_name: StringName in TOOL_SLOT_ORDER:
		var tool_type: StringName = _inventory.get_tool(slot_name)
		if _tool_slot_nodes.has(slot_name):
			(_tool_slot_nodes[slot_name] as ToolSlotUI).refresh(tool_type)


func _refresh_header() -> void:
	if _title_label == null:
		return
	var name_str: String = "Inventory"
	if _container_def != null and String(_container_def.display_name) != "":
		name_str = String(_container_def.display_name)
	var pct: float = 0.0
	if _inventory != null:
		var capacity: float = _inventory.get_capacity_size()
		if capacity > 0.0:
			pct = (_inventory.get_current_size() / capacity) * 100.0
	_title_label.text = "%s [%.1f%%]" % [name_str, pct]


# --- Layout / grid sizing ---

func _on_scroll_resized() -> void:
	if _grid_canvas != null:
		_grid_canvas._fit_to_width(_available_grid_width())
		_grid_canvas._update_size()
		_grid_canvas.queue_redraw()


## Width available to the grid canvas — viewport minus the always-on vertical
## scrollbar. Falls back to the scroll container's full size when the
## scrollbar node isn't available yet.
func _available_grid_width() -> int:
	if _scroll == null:
		return 0
	var vbar: VScrollBar = _scroll.get_v_scroll_bar()
	var bar_w: int = 0
	if vbar != null:
		bar_w = int(vbar.size.x)
	return max(0, int(_scroll.size.x) - bar_w)


# --- Grid click → consumable use ---

func _on_grid_item_clicked(type: StringName) -> void:
	_on_slot_tapped(type)


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
	# Toxicity is now driven by PropDef.health_restore (negative = toxic damage).
	# Catalog reference no longer required — but kept available for future filtering.
	var def: _PropDef = PropRegistry.get_def(type)
	if def == null:
		return false
	return def.is_consumable and def.health_restore < 0.0


# --- Inventory signal handlers ---

func _on_inventory_changed() -> void:
	if visible:
		_refresh_all()


func _on_tool_changed(slot: StringName, new_tool: StringName, _old_tool: StringName) -> void:
	if visible and _tool_slot_nodes.has(slot):
		(_tool_slot_nodes[slot] as ToolSlotUI).refresh(new_tool)


# ===========================================================================
# GridCanvas — inner class that renders the 2D grid via _draw()
# ===========================================================================

class GridCanvas extends Control:
	## Custom Control that renders the Tetris-style inventory grid.
	## Each cell is _cell_size × _cell_size pixels. Items are drawn as
	## colored silhouettes using their PropDef.placeholder_color.

	signal item_clicked(type: StringName)

	const _InnerPropDef = preload("res://scripts/data/prop_def.gd")
	const _InnerInventory = preload("res://scripts/inventory/inventory.gd")

	## Minimum pixel size for each cell so the grid stays tappable even when
	## the container is very wide.
	const MIN_CELL_SIZE: int = 24
	const FALLBACK_CELL_SIZE: int = 24

	var _cell_size: int = FALLBACK_CELL_SIZE
	var _inventory = null  # Inventory reference

	## Colors
	var _grid_line_color := Color(0.25, 0.25, 0.35, 0.4)
	var _grid_bg_color := Color(0.10, 0.10, 0.14, 0.6)


	func _init() -> void:
		mouse_filter = MOUSE_FILTER_PASS


	func set_inventory(inv) -> void:
		_inventory = inv
		_update_size()
		queue_redraw()


	## Pick the largest cell size that makes the grid exactly as wide as the
	## available panel width (minus the vertical scrollbar). Cells stay square,
	## so the grid's height scales with the same cell size.
	func _fit_to_width(available_width: int) -> void:
		if _inventory == null or _inventory.grid_width <= 0 or available_width <= 0:
			_cell_size = FALLBACK_CELL_SIZE
			return
		var computed: int = int(available_width / _inventory.grid_width)
		_cell_size = max(MIN_CELL_SIZE, computed)


	func _update_size() -> void:
		if _inventory == null:
			custom_minimum_size = Vector2.ZERO
			return
		custom_minimum_size = Vector2(
			_inventory.grid_width * _cell_size,
			_inventory.grid_height * _cell_size
		)


	func _draw() -> void:
		if _inventory == null:
			return

		var gw: int = _inventory.grid_width
		var gh: int = _inventory.grid_height
		var cs: int = _cell_size
		var total_w: int = gw * cs
		var total_h: int = gh * cs

		# 1. Background fill
		draw_rect(Rect2(0, 0, total_w, total_h), _grid_bg_color)

		# 2. Grid lines
		for x in gw + 1:
			draw_line(
				Vector2(x * cs, 0),
				Vector2(x * cs, total_h),
				_grid_line_color
			)
		for y in gh + 1:
			draw_line(
				Vector2(0, y * cs),
				Vector2(total_w, y * cs),
				_grid_line_color
			)

		# 3. Item shapes as colored silhouettes (via read-only API)
		var all_items: Dictionary = _inventory.get_all_items()
		for item_id: int in all_items:
			var item: Dictionary = all_items[item_id]
			var type: StringName = item["type"]
			var def: _InnerPropDef = PropRegistry.get_def(type)
			var color: Color = def.placeholder_color if def != null else Color.WHITE
			var origin: Vector2i = item["origin"]
			var rotation: int = item["rotation"]
			var rotated_shape: Array[Vector2i] = _InnerInventory.get_rotated_shape(
				item["shape"], rotation
			)
			for cell: Vector2i in rotated_shape:
				var px: int = (origin.x + cell.x) * cs
				var py: int = (origin.y + cell.y) * cs
				draw_rect(
					Rect2(px + 1, py + 1, cs - 2, cs - 2),
					color
				)


	func _gui_input(event: InputEvent) -> void:
		if _inventory == null:
			return

		var clicked: bool = false
		var click_pos: Vector2 = Vector2.ZERO

		if event is InputEventScreenTouch and event.pressed:
			clicked = true
			click_pos = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked = true
			click_pos = event.position

		if not clicked:
			return

		# Determine which grid cell was hit (floori handles negative positions)
		var cell_x: int = floori(click_pos.x / _cell_size)
		var cell_y: int = floori(click_pos.y / _cell_size)

		if cell_x < 0 or cell_x >= _inventory.grid_width:
			return
		if cell_y < 0 or cell_y >= _inventory.grid_height:
			return

		# Look up which item occupies that cell (via read-only API)
		var item_id: int = _inventory.get_grid_cell(cell_x, cell_y)
		if item_id == 0:
			return

		# Get the item type
		var item: Variant = _inventory.get_item(item_id)
		if item == null:
			return

		var type: StringName = item["type"]

		# Only act on consumables. We defer accept_event() until we know the
		# click will actually be consumed, so ScrollContainer drag/scroll
		# gestures starting on non-consumable items still work.
		var def: _InnerPropDef = PropRegistry.get_def(type)
		if def != null and def.is_consumable:
			accept_event()
			item_clicked.emit(type)
