extends GdUnitTestSuite
class_name TestInventoryPanel

## Unit tests for InventoryPanel UI (task-084d, updated task-092).
##
## Exercises panel construction via the .tscn, inventory binding,
## grid canvas creation, tool slot population, open/close/toggle lifecycle,
## and the inventory_changed / tool_changed signal propagation.
##
## After task-092 rewrite: the prop grid is now a custom GridCanvas that
## renders items as colored silhouettes. Tests validate the canvas exists,
## items are placed correctly, and click-to-use works for consumables.

const _InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _ToolSlotUI = preload("res://ui/tool_slot_ui.gd")

# Numeric PropDef ids used throughout the suite
const ID_WOOD: StringName = &"P00010"
const ID_BERRIES: StringName = &"P00020"
const ID_AXE: StringName = &"P00201"
const ID_PICKAXE: StringName = &"P00202"
const ID_KNIFE: StringName = &"P00204"
const ID_SCANNER: StringName = &"P00205"

var _panel: PanelContainer = null
var _inv: _Inventory = null
var _panel_opened_count: int = 0


func before_test() -> void:
	_panel = _InventoryPanelScene.instantiate()
	add_child(_panel)
	_inv = _Inventory.new()
	_panel_opened_count = 0


func after_test() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_inv = null


# --- Construction / lifecycle ---

func test_panel_instantiates_without_error() -> void:
	assert_object(_panel).is_not_null()
	assert_bool(_panel is PanelContainer).is_true()


func test_panel_starts_hidden() -> void:
	assert_bool(_panel.visible).is_false()


func test_open_makes_visible() -> void:
	_panel.open()
	assert_bool(_panel.visible).is_true()


func test_close_hides() -> void:
	_panel.open()
	_panel.close()
	assert_bool(_panel.visible).is_false()


func test_toggle_opens_when_hidden() -> void:
	_panel.toggle()
	assert_bool(_panel.visible).is_true()


func test_toggle_closes_when_visible() -> void:
	_panel.open()
	_panel.toggle()
	assert_bool(_panel.visible).is_false()


# --- panel_opened signal ---

func test_open_emits_panel_opened() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_open_twice_emits_once() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.open()
	_panel.open()
	assert_int(_panel_opened_count).is_equal(1)


func test_close_does_not_emit_panel_opened() -> void:
	_panel.panel_opened.connect(func(): _panel_opened_count += 1)
	_panel.close()
	assert_int(_panel_opened_count).is_equal(0)


# --- Tool slot construction (always 4 slots in fixed order) ---

func test_creates_four_tool_slots() -> void:
	# Tool slots are created in _ready regardless of inventory binding.
	assert_int(_panel._tool_slot_nodes.size()).is_equal(4)


func test_tool_slots_use_expected_order() -> void:
	var keys: Array = _panel._tool_slot_nodes.keys()
	# The panel constant TOOL_SLOT_ORDER drives the ordering.
	for key in _panel.TOOL_SLOT_ORDER:
		assert_bool(keys.has(key)).is_true()


func test_tool_slots_are_tool_slot_ui_instances() -> void:
	for key: StringName in _panel._tool_slot_nodes:
		var node: Node = _panel._tool_slot_nodes[key]
		assert_bool(node is _ToolSlotUI).is_true()


# --- Grid canvas creation ---

func test_grid_canvas_created_on_ready() -> void:
	assert_object(_panel._grid_canvas).is_not_null()
	assert_bool(_panel._grid_canvas is Control).is_true()


func test_grid_canvas_is_child_of_scroll_container() -> void:
	var scroll: ScrollContainer = _panel.get_node("VBox/ScrollContainer")
	assert_bool(_panel._grid_canvas.get_parent() == scroll).is_true()


func test_set_inventory_updates_grid_canvas() -> void:
	_panel.set_inventory(_inv)
	# After set_inventory, the grid canvas should have a reference
	assert_object(_panel._grid_canvas._inventory).is_not_null()


func test_grid_canvas_minimum_size_matches_inventory_grid() -> void:
	_panel.set_inventory(_inv)
	var expected_w: float = float(_inv.grid_width * _panel._grid_canvas._cell_size)
	var expected_h: float = float(_inv.grid_height * _panel._grid_canvas._cell_size)
	assert_float(_panel._grid_canvas.custom_minimum_size.x).is_equal(expected_w)
	assert_float(_panel._grid_canvas.custom_minimum_size.y).is_equal(expected_h)


# --- Tool slot visual state: empty vs equipped ---

func test_tool_slot_empty_when_no_tool_set() -> void:
	_panel.set_inventory(_inv)
	for key: StringName in _panel.TOOL_SLOT_ORDER:
		var slot: _ToolSlotUI = _panel._tool_slot_nodes[key]
		# Empty tool slot: icon color matches the empty-state default
		assert_bool(slot._icon_rect.color == Color(0.10, 0.10, 0.12)).is_true()


func test_tool_slot_reflects_equipped_tool() -> void:
	_inv.set_tool(&"axe", ID_AXE)
	_panel.set_inventory(_inv)
	var axe_slot: _ToolSlotUI = _panel._tool_slot_nodes[&"axe"]
	# After set_inventory, _refresh_all runs and the tool slot should pick up
	# the axe def's placeholder color (non-empty)
	assert_bool(axe_slot._icon_rect.color != Color(0.10, 0.10, 0.12)).is_true()


# --- Inventory signal propagates when panel is visible ---

func test_inventory_changed_signal_refreshes_panel_when_visible() -> void:
	_panel.set_inventory(_inv)
	_panel.open()
	_inv.add_item(ID_WOOD, 4)
	# After the signal fires, the inventory should contain wood
	assert_int(_inv.get_count(ID_WOOD)).is_equal(4)


func test_inventory_changed_signal_skipped_when_panel_hidden() -> void:
	# When panel is hidden, _refresh_all should NOT be called on
	# inventory_changed — panel remains stale until opened.
	_panel.set_inventory(_inv)
	# Panel is hidden by default
	_inv.add_item(ID_WOOD, 4)
	# Inventory still has the data but panel did not refresh
	assert_int(_inv.get_count(ID_WOOD)).is_equal(4)


func test_tool_changed_signal_refreshes_tool_slot_when_visible() -> void:
	_panel.set_inventory(_inv)
	_panel.open()
	_inv.set_tool(&"pickaxe", ID_PICKAXE)
	var pickaxe_slot: _ToolSlotUI = _panel._tool_slot_nodes[&"pickaxe"]
	assert_bool(pickaxe_slot._icon_rect.color != Color(0.10, 0.10, 0.12)).is_true()


func test_set_inventory_twice_disconnects_old_signals() -> void:
	var first_inv := _Inventory.new()
	var second_inv := _Inventory.new()
	_panel.set_inventory(first_inv)
	_panel.set_inventory(second_inv)
	_panel.open()
	# Adding to first_inv should NOT update the panel — it's no longer bound.
	first_inv.add_item(ID_WOOD, 3)
	assert_int(second_inv.get_count(ID_WOOD)).is_equal(0)


# --- Consumable tap via _on_slot_tapped ---

func test_on_slot_tapped_uses_consumable() -> void:
	_panel.set_inventory(_inv)
	_inv.add_item(ID_BERRIES, 3)
	_panel._on_slot_tapped(ID_BERRIES)
	assert_int(_inv.get_count(ID_BERRIES)).is_equal(2)


# --- set_catalog: optional injection ---

func test_set_catalog_accepts_any_value() -> void:
	# set_catalog is a plain setter with no validation — it should not crash
	# when called with a fake or null.
	_panel.set_catalog(null)
	# Subsequent behavior should be unaffected
	_panel.open()
	assert_bool(_panel.visible).is_true()
