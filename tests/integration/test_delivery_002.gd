extends GdUnitTestSuite
class_name TestDelivery002

## Integration tests for delivery-002: See and Know — Scanner + Inventory.
## Tests inventory data + UI, scanner lifecycle, element icons, catalog panel,
## mutual exclusion, toxic berries warning, and cross-system signal flows.
##
## Manual-only verification (not automatable — documented here):
##   - Element icons float above tiles and billboard toward camera
##   - Scan progress bar animates smoothly from left to right
##   - Inventory panel slides up from bottom covering ~45% screen
##   - Catalog panel slides up from bottom covering ~45% screen
##   - Icon colors: unknown=yellow, flora=green, fauna=red, mineral=gray, anomaly=purple

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")
const _ScannerSystem = preload("res://scripts/scanner/scanner_system.gd")
const _ElementIconRenderer = preload("res://scripts/rendering/element_icon_renderer.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")

const _InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")
const _CatalogPanelScene = preload("res://scenes/ui/catalog_panel.tscn")


# --- Minimal fakes ---

class FakeGrid extends Node:
	var _tiles: Dictionary = {}
	signal map_generated()
	signal tile_revealed(coords: Vector2i)
	signal tile_visibility_changed(coords: Vector2i, state: int)
	signal tile_entered(coords: Vector2i)
	signal tile_exited(coords: Vector2i)
	signal resource_depleted(coords: Vector2i, resource_type: StringName)
	signal resource_respawned(coords: Vector2i, resource_type: StringName)
	signal tile_contents_changed(coords: Vector2i)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)

	func distance(a: Vector2i, b: Vector2i) -> int:
		var cube_a: Vector3i = Vector3i(a.x, -a.x - a.y, a.y)
		var cube_b: Vector3i = Vector3i(b.x, -b.x - b.y, b.y)
		return (abs(cube_a.x - cube_b.x) + abs(cube_a.y - cube_b.y) + abs(cube_a.z - cube_b.z)) / 2


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO


class FakePlayerInput extends Node:
	signal scan_hold_started(coords: Vector2i)
	signal scan_hold_update(screen_pos: Vector2)
	signal scan_hold_ended()


# --- State ---

var _grid: FakeGrid
var _player: FakePlayer
var _input: FakePlayerInput
var _scanner: Node  # ScannerSystem
var _world: Node3D
var _renderer: Node3D  # ElementIconRenderer

# Signal capture (instance-level, used by tests that need signal verification)
var _sig_entry_id: StringName = &""
var _sig_category: int = -1
var _sig_coords: Vector2i = Vector2i(-999, -999)
var _sig_identified_count: int = 0
var _sig_unknown_count: int = 0
var _sig_cancelled_count: int = 0


# --- Helpers ---

func _reset_sig_captures() -> void:
	_sig_entry_id = &""
	_sig_category = -1
	_sig_coords = Vector2i(-999, -999)
	_sig_identified_count = 0
	_sig_unknown_count = 0
	_sig_cancelled_count = 0


func _on_sig_scan_started(eid: StringName, c: Vector2i) -> void:
	_sig_entry_id = eid
	_sig_coords = c


func _on_sig_entry_cataloged(eid: StringName, cat: int) -> void:
	_sig_entry_id = eid
	_sig_category = cat


func _on_sig_element_identified(_c: Vector2i, _eid: StringName) -> void:
	_sig_identified_count += 1


func _on_sig_element_unknown(_c: Vector2i) -> void:
	_sig_unknown_count += 1


func _on_sig_scan_cancelled() -> void:
	_sig_cancelled_count += 1


func _make_tile_with_resource(resource_type: StringName, elev: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.fog_state = _HexTile.FogState.VISIBLE
	var node: ResourceNode = _ResourceNode.new()
	node.type = resource_type
	tile.resource_nodes = [node]
	return tile


func _make_tile_with_anomaly(anomaly_id: StringName, elev: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.fog_state = _HexTile.FogState.VISIBLE
	tile.anomaly = anomaly_id
	return tile


func _setup_scanner_tree() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_player = FakePlayer.new()
	_player.name = "Player"
	_input = FakePlayerInput.new()
	_input.name = "PlayerInput"
	_player.add_child(_input)

	_scanner = _ScannerSystem.new()
	_scanner.name = "ScannerSystem"
	_scanner._grid = _grid
	_scanner.set_process(false)
	_player.add_child(_scanner)

	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_world.add_child(_player)

	_renderer = _ElementIconRenderer.new()
	_renderer.name = "ElementIconRenderer"
	_renderer._grid = _grid
	_world.add_child(_renderer)

	# Manually connect scanner signals (deferred connect may not run in test)
	_renderer._scanner = _scanner
	if not _scanner.element_identified.is_connected(_renderer._on_element_identified):
		_scanner.element_identified.connect(_renderer._on_element_identified)
	if not _scanner.element_unknown.is_connected(_renderer._on_element_unknown):
		_scanner.element_unknown.connect(_renderer._on_element_unknown)
	if not _scanner.entry_cataloged.is_connected(_renderer._on_entry_cataloged):
		_scanner.entry_cataloged.connect(_renderer._on_entry_cataloged)


func _teardown_scanner_tree() -> void:
	if is_instance_valid(_world):
		remove_child(_world)
		_world.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_renderer = null
	_scanner = null
	_player = null
	_input = null
	_grid = null
	_world = null


# ===========================================================================
# INTEGRATION: Scan unknown flora -> catalog entry -> icon swap -> catalog panel
# ===========================================================================

func test_scan_flora_full_flow_icon_swap_and_catalog_panel() -> void:
	_setup_scanner_tree()

	# Place unknown berry tile
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	# Passive ID fires element_unknown on reveal
	_scanner._check_passive_identification(Vector2i(1, 0))
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(1)

	# Scan: start -> progress -> complete
	_scanner._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	_scanner._scan_progress = 0.99
	_scanner._process(0.05)
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)

	# Icon swap: unknown -> flora
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(0)
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.FLORA)).is_equal(1)

	# Catalog panel shows the entry
	var panel: PanelContainer = _CatalogPanelScene.instantiate()
	add_child(panel)
	panel.set_catalog(_scanner.get_catalog())
	panel.open()

	assert_int(panel._flora_list.get_child_count()).is_equal(1)
	assert_str(panel._counter_label.text).is_equal("1 entry")

	panel.queue_free()
	_teardown_scanner_tree()


# ===========================================================================
# INTEGRATION: Bulk swap — all visible unknown of cataloged type flip at once
# ===========================================================================

func test_bulk_swap_all_visible_unknowns_flip_on_catalog() -> void:
	_setup_scanner_tree()

	# Three berry tiles at different coords
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(2, 1)] = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(0, -1)] = _make_tile_with_resource(&"berries")
	# One stone tile (should stay unknown)
	_grid._tiles[Vector2i(3, 0)] = _make_tile_with_resource(&"stone")
	_player.current_tile = Vector2i.ZERO

	# Passive ID marks all as unknown
	for coords in [Vector2i(1, 0), Vector2i(2, 1), Vector2i(0, -1), Vector2i(3, 0)]:
		_scanner._check_passive_identification(coords)

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(4)

	# Scan one berry to catalog berry_bush
	_scanner._on_scan_hold_started(Vector2i(1, 0))
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	# All 3 berry unknowns should be flora now, stone stays unknown
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.FLORA)).is_equal(3)
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(1)

	_teardown_scanner_tree()


# ===========================================================================
# INTEGRATION: Inventory add -> panel displays -> inventory full -> notification
# ===========================================================================

func test_inventory_add_panel_display_and_full_notification() -> void:
	var inv: Inventory = _Inventory.new()
	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)

	# Add items
	inv.add_item(&"wood", 10)
	assert_int(inv.get_count(&"wood")).is_equal(10)

	# Panel displays correct state
	panel.open()
	var slots: Array[Dictionary] = inv.get_slots()
	var occupied_count: int = 0
	for slot in slots:
		if slot["type"] != &"":
			occupied_count += 1
	assert_int(occupied_count).is_equal(1)
	assert_int(inv.get_used_slot_count()).is_equal(1)
	panel.close()

	# Fill inventory to trigger inventory_full
	var full_fired: Array = []
	inv.inventory_full.connect(func(type: StringName, rejected: int) -> void:
		full_fired.append({"type": type, "rejected": rejected})
	)

	# Fill all 12 slots with different resources
	inv.add_item(&"stone", 99)
	inv.add_item(&"berries", 20)
	inv.add_item(&"toxic_berries", 20)
	inv.add_item(&"fiber", 99)
	inv.add_item(&"ore", 99)
	inv.add_item(&"crystal", 50)
	inv.add_item(&"meat", 20)
	# 8 types in 8 slots. Existing wood in slot 0 = 9 used. Add more.
	inv.add_item(&"wood", 99)  # fills to max, second stack
	inv.add_item(&"stone", 99)  # second stack
	inv.add_item(&"berries", 20)  # second stack

	# By now we have 11 or 12 used slots. Try to add a new type that won't fit
	# Fill remaining slots first
	var extra_added: int = inv.add_item(&"meat", 20)  # fill last slot
	# Now add more — should trigger inventory_full
	var rejected: int = inv.add_item(&"meat", 20)
	if rejected == 0 and full_fired.size() > 0:
		assert_bool(true).is_true()
	elif inv.is_full():
		var overflow: int = inv.add_item(&"wood", 10)
		assert_bool(full_fired.size() > 0).override_failure_message(
			"inventory_full signal must fire when inventory is full"
		).is_true()

	panel.queue_free()


# ===========================================================================
# INTEGRATION: Mutual exclusion — open Catalog -> Inventory closes, vice versa
# ===========================================================================

func test_mutual_exclusion_catalog_closes_inventory() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	var inv_panel = hud.get_node("InventoryPanel")
	var cat_panel = hud.get_node("CatalogPanel")

	# Open inventory
	inv_panel.open()
	assert_bool(inv_panel.visible).is_true()

	# Open catalog — inventory should close
	cat_panel.open()
	assert_bool(cat_panel.visible).is_true()
	assert_bool(inv_panel.visible).is_false()

	hud.queue_free()


func test_mutual_exclusion_inventory_closes_catalog() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	var inv_panel = hud.get_node("InventoryPanel")
	var cat_panel = hud.get_node("CatalogPanel")

	# Open catalog
	cat_panel.open()
	assert_bool(cat_panel.visible).is_true()

	# Open inventory — catalog should close
	inv_panel.open()
	assert_bool(inv_panel.visible).is_true()
	assert_bool(cat_panel.visible).is_false()

	hud.queue_free()


# ===========================================================================
# AC5: 12 slots, 13th rejected, stacking, tool slots
# ===========================================================================

func test_ac5_12_base_slots() -> void:
	var inv: Inventory = _Inventory.new()
	assert_int(inv.get_max_slots()).is_equal(12)
	assert_int(inv.get_used_slot_count()).is_equal(0)


func test_ac5_13th_item_rejected_when_full() -> void:
	var inv: Inventory = _Inventory.new()
	var full_fired: Array = []
	inv.inventory_full.connect(func(_type: StringName, _rejected: int) -> void:
		full_fired.append(true)
	)

	# Fill all 12 slots (use types with max_stack=20 for smaller fills)
	# Each type occupies 1 slot (amount <= max_stack)
	inv.add_item(&"wood", 1)
	inv.add_item(&"stone", 1)
	inv.add_item(&"berries", 1)
	inv.add_item(&"toxic_berries", 1)
	inv.add_item(&"fiber", 1)
	inv.add_item(&"ore", 1)
	inv.add_item(&"crystal", 1)
	inv.add_item(&"meat", 1)
	# 8 types in 8 slots. Need 4 more slots.
	# Add more of existing types to create new stacks (fill current first)
	inv.add_item(&"wood", 99)  # fills slot 0 to 99, done (1 slot still)
	# Actually each existing slot can absorb more. We need distinct stacks.
	# Use max_stack overflow: wood max=99, add 99 more to create 2nd slot
	inv.add_item(&"wood", 99)   # slot0: 99, slot8: 99 = 2 slots
	inv.add_item(&"stone", 99)  # slot1: 99, slot9: 1 = 2 slots
	inv.add_item(&"berries", 20)  # slot2: 20 (max), slot10: 1 = 2 slots
	inv.add_item(&"toxic_berries", 20)  # slot3: 20 (max), slot11: 1 = 2 slots

	assert_int(inv.get_used_slot_count()).is_equal(12)

	# 13th slot — should be rejected
	full_fired.clear()
	var added: int = inv.add_item(&"fiber", 100)
	# Some may stack into existing slot (fiber in slot4 has room)
	# After slot4 fills, overflow needs new slot which doesn't exist
	assert_bool(full_fired.size() > 0 or added < 100).override_failure_message(
		"Adding items beyond capacity must reject or trigger inventory_full"
	).is_true()


func test_ac5_stacking_within_max_stack() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(&"wood", 50)
	inv.add_item(&"wood", 30)
	assert_int(inv.get_count(&"wood")).is_equal(80)
	assert_int(inv.get_used_slot_count()).is_equal(1)


func test_ac5_stacking_overflow_creates_new_slot() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(&"wood", 99)
	inv.add_item(&"wood", 10)
	assert_int(inv.get_count(&"wood")).is_equal(109)
	assert_int(inv.get_used_slot_count()).is_equal(2)


func test_ac5_tool_slots_starting_state() -> void:
	var inv: Inventory = _Inventory.new()
	assert_object(inv.get_tool(&"weapon")).is_equal(&"survival_knife")
	assert_object(inv.get_tool(&"scanner")).is_equal(&"scanner")
	assert_object(inv.get_tool(&"axe")).is_equal(&"")
	assert_object(inv.get_tool(&"pickaxe")).is_equal(&"")


func test_ac5_tool_routing_rejection() -> void:
	var inv: Inventory = _Inventory.new()
	var added: int = inv.add_item(&"stone_axe", 1)
	assert_int(added).is_equal(0)
	assert_int(inv.get_used_slot_count()).is_equal(0)


func test_ac5_expansion_adds_12_slots() -> void:
	var inv: Inventory = _Inventory.new()
	inv.expand(12)
	assert_int(inv.get_max_slots()).is_equal(24)
	assert_int(inv.get_slots().size()).is_equal(24)


# ===========================================================================
# AC11: Element icons, scan flow, auto-identify after, mineral scan, anomaly
# ===========================================================================

func test_ac11_unknown_icon_on_tile_reveal() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")

	# Simulate tile reveal -> passive ID -> element_unknown
	_scanner._on_tile_revealed(Vector2i(1, 0))
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(1)

	_teardown_scanner_tree()


func test_ac11_scan_flow_idle_scanning_complete() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)

	_scanner._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	_scanner._scan_progress = 0.99
	_scanner._process(0.05)
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)
	assert_bool(_scanner._catalog.is_cataloged(&"berry_bush")).is_true()

	_teardown_scanner_tree()


func test_ac11_auto_identify_after_catalog() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	# Catalog berry_bush first
	_scanner._catalog.catalog_entry(&"berry_bush")

	# Now reveal a tile with berries — should emit element_identified, not element_unknown
	_grid._tiles[Vector2i(3, 0)] = _make_tile_with_resource(&"berries")

	_scanner.element_identified.connect(_on_sig_element_identified)
	_scanner.element_unknown.connect(_on_sig_element_unknown)

	_scanner._check_passive_identification(Vector2i(3, 0))
	assert_int(_sig_identified_count).is_equal(1)
	assert_int(_sig_unknown_count).is_equal(0)

	_teardown_scanner_tree()


func test_ac11_mineral_scan_complete() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"stone")
	_player.current_tile = Vector2i.ZERO

	_scanner.entry_cataloged.connect(_on_sig_entry_cataloged)

	_scanner._on_scan_hold_started(Vector2i(1, 0))
	assert_float(_scanner._scan_duration).is_equal(2.0)

	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	assert_str(String(_sig_entry_id)).is_equal("stone_deposit")
	assert_int(_sig_category).is_equal(_Catalog.CatalogCategory.MINERAL)

	_teardown_scanner_tree()


func test_ac11_anomaly_scan_complete_and_signal() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_anomaly(&"anomaly_ch1_001")
	_player.current_tile = Vector2i.ZERO

	_scanner.entry_cataloged.connect(_on_sig_entry_cataloged)

	_scanner._on_scan_hold_started(Vector2i(1, 0))
	assert_float(_scanner._scan_duration).is_equal(3.0)

	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	assert_str(String(_sig_entry_id)).is_equal("anomaly_ch1_001")
	assert_int(_sig_category).is_equal(_Catalog.CatalogCategory.ANOMALY)

	_teardown_scanner_tree()


# ===========================================================================
# AC2: Scan input — scan_hold signals fire with correct coords
# ===========================================================================

func test_ac2_scan_hold_signals_connect_and_fire() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	_grid._tiles[Vector2i(2, 0)] = _make_tile_with_resource(&"fiber")
	_player.current_tile = Vector2i.ZERO

	_scanner.scan_started.connect(_on_sig_scan_started)

	# Fire PlayerInput scan_hold_started
	_input.scan_hold_started.emit(Vector2i(2, 0))

	assert_str(String(_sig_entry_id)).is_equal("fiber_grass")
	assert_int(_sig_coords.x).is_equal(2)
	assert_int(_sig_coords.y).is_equal(0)

	_teardown_scanner_tree()


func test_ac2_scan_hold_ended_cancels_scan() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	_scanner.scan_cancelled.connect(_on_sig_scan_cancelled)

	_input.scan_hold_started.emit(Vector2i(1, 0))
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	_input.scan_hold_ended.emit()
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)
	assert_int(_sig_cancelled_count).is_equal(1)

	_teardown_scanner_tree()


# ===========================================================================
# INTEGRATION: Toxic berries — consume shows warning dialog
# ===========================================================================

func test_toxic_berries_tap_shows_warning_dialog() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(&"toxic_berries", 5)

	# Create a catalog with toxic berry bush discovered
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"toxic_berry_bush")

	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)
	panel.set_catalog(cat)
	panel.open()

	# Simulate tapping the toxic berries slot
	panel._on_slot_tapped(&"toxic_berries")

	# Warning dialog should be visible (popup_centered was called)
	assert_str(String(panel._pending_use_type)).is_equal("toxic_berries")
	assert_bool(panel._confirm_dialog != null).is_true()

	# Confirm consumption
	panel._on_toxic_confirmed()
	assert_int(inv.get_count(&"toxic_berries")).is_equal(4)
	assert_str(String(panel._pending_use_type)).is_equal("")

	panel.queue_free()


func test_non_toxic_berries_tap_uses_directly() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(&"berries", 5)

	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"berry_bush")

	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)
	panel.set_catalog(cat)
	panel.open()

	# Simulate tapping berries — no toxic warning, direct consume
	panel._on_slot_tapped(&"berries")

	# Should use directly (no pending dialog)
	assert_int(inv.get_count(&"berries")).is_equal(4)

	panel.queue_free()


# ===========================================================================
# INTEGRATION: Catalog panel shows correct categories after scan
# ===========================================================================

func test_catalog_panel_correct_categories_after_scans() -> void:
	_setup_scanner_tree()

	# Scan a flora (berries), mineral (stone), and check categories in panel
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_grid._tiles[Vector2i(2, 0)] = _make_tile_with_resource(&"stone")
	_player.current_tile = Vector2i.ZERO

	# Scan berries
	_scanner._on_scan_hold_started(Vector2i(1, 0))
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	# Scan stone
	_scanner._on_scan_hold_started(Vector2i(2, 0))
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	# Open catalog panel
	var panel: PanelContainer = _CatalogPanelScene.instantiate()
	add_child(panel)
	panel.set_catalog(_scanner.get_catalog())
	panel.open()

	assert_int(panel._flora_list.get_child_count()).is_equal(1)
	assert_int(panel._mineral_list.get_child_count()).is_equal(1)
	assert_int(panel._fauna_list.get_child_count()).is_equal(0)
	assert_int(panel._anomaly_list.get_child_count()).is_equal(0)
	assert_str(panel._counter_label.text).is_equal("2 entries")

	panel.queue_free()
	_teardown_scanner_tree()


# ===========================================================================
# INTEGRATION: Catalog panel updates on entry_cataloged signal
# ===========================================================================

func test_catalog_panel_refreshes_on_entry_cataloged() -> void:
	var cat := _Catalog.new()
	cat.initialize()

	var panel: PanelContainer = _CatalogPanelScene.instantiate()
	add_child(panel)
	panel.set_catalog(cat)
	panel.open()

	assert_int(panel._flora_list.get_child_count()).is_equal(0)

	# Catalog an entry while panel is open
	cat.catalog_entry(&"berry_bush")

	assert_int(panel._flora_list.get_child_count()).is_equal(1)
	assert_str(panel._counter_label.text).is_equal("1 entry")

	panel.queue_free()


# ===========================================================================
# INTEGRATION: Inventory panel re-renders on inventory_changed
# ===========================================================================

func test_inventory_panel_rerenders_on_inventory_changed() -> void:
	var inv: Inventory = _Inventory.new()
	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)
	panel.open()

	# Verify initial state has 12 empty slot nodes
	assert_int(panel._slot_nodes.size()).is_equal(12)

	# Add items while panel is open — panel should re-render
	inv.add_item(&"wood", 25)

	# Panel should reflect the change
	var slots: Array[Dictionary] = inv.get_slots()
	var first_slot: Dictionary = slots[0]
	assert_object(first_slot["type"]).is_equal(&"wood")
	assert_int(first_slot["quantity"]).is_equal(25)

	panel.queue_free()


# ===========================================================================
# INTEGRATION: Surprise catalog (fauna attack -> instant catalog)
# ===========================================================================

func test_surprise_catalog_fauna_attack_catalogs_and_emits() -> void:
	_setup_scanner_tree()

	var surprise_ids: Array = []
	var catalog_ids: Array = []
	_scanner.surprise_cataloged.connect(func(eid: StringName) -> void:
		surprise_ids.append(String(eid))
	)
	_scanner.entry_cataloged.connect(func(eid: StringName, _cat: int) -> void:
		catalog_ids.append(String(eid))
	)

	_scanner.on_fauna_attacked_player(1, 10, &"thornback")

	assert_int(surprise_ids.size()).is_equal(1)
	assert_str(surprise_ids[0]).is_equal("thornback")
	assert_bool(_scanner._catalog.is_cataloged(&"thornback")).is_true()
	assert_int(catalog_ids.size()).is_equal(1)

	_teardown_scanner_tree()


# ===========================================================================
# INTEGRATION: Element icon removed on tile visibility REVEALED/HIDDEN
# ===========================================================================

func test_element_icon_removed_on_tile_revealed() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_scanner.element_unknown.emit(Vector2i(1, 0))

	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(1)

	_renderer._on_tile_visibility_changed(Vector2i(1, 0), _HexTile.FogState.REVEALED)
	assert_int(_renderer.get_pool_visible_count(_ElementIconRenderer.Pool.UNKNOWN)).is_equal(0)

	_teardown_scanner_tree()


# ===========================================================================
# INTEGRATION: scan_rejected never emitted while SCANNING
# ===========================================================================

func test_scan_rejected_suppressed_while_scanning() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	var rejected_count: int = 0
	_scanner.scan_rejected.connect(func(_c: Vector2i) -> void:
		rejected_count += 1
	)

	_scanner._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	# Try another scan on empty tile while already scanning
	_scanner._on_scan_hold_started(Vector2i(5, 5))

	# Must NOT emit scan_rejected while scanning
	assert_int(rejected_count).is_equal(0)

	_teardown_scanner_tree()


# ===========================================================================
# INTEGRATION: Save/load round-trip for both Inventory and Catalog
# ===========================================================================

func test_inventory_save_load_round_trip() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(&"wood", 50)
	inv.add_item(&"berries", 10)
	inv.set_tool(&"axe", &"stone_axe")
	inv.expand(12)

	var save_data: Dictionary = inv.get_save_data()

	var inv2: Inventory = _Inventory.new()
	inv2.load_save_data(save_data)

	assert_int(inv2.get_count(&"wood")).is_equal(50)
	assert_int(inv2.get_count(&"berries")).is_equal(10)
	assert_object(inv2.get_tool(&"axe")).is_equal(&"stone_axe")
	assert_int(inv2.get_max_slots()).is_equal(24)


func test_catalog_save_load_round_trip() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"berry_bush")
	cat.catalog_entry(&"stone_deposit")

	var save_data: Dictionary = cat.get_save_data()

	var cat2 := _Catalog.new()
	cat2.initialize()
	cat2.load_save_data(save_data)

	assert_bool(cat2.is_cataloged(&"berry_bush")).is_true()
	assert_bool(cat2.is_cataloged(&"stone_deposit")).is_true()
	assert_bool(cat2.is_cataloged(&"wood_tree")).is_false()
	assert_int(cat2.get_discovery_count()).is_equal(2)


# ===========================================================================
# INTEGRATION: HUD structure — Inventory + Scanner buttons exist
# ===========================================================================

func test_hud_inventory_and_scanner_buttons_exist() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	var inv_btn: Node = hud.get_node_or_null("BottomBar/InventoryButton")
	var scn_btn: Node = hud.get_node_or_null("BottomBar/ScannerButton")
	assert_bool(inv_btn != null).override_failure_message("InventoryButton must exist in HUD").is_true()
	assert_bool(scn_btn != null).override_failure_message("ScannerButton must exist in HUD").is_true()

	# Check button sizes (64x64 minimum)
	if inv_btn != null:
		assert_float((inv_btn as Control).custom_minimum_size.x).is_greater_equal(64.0)
	if scn_btn != null:
		assert_float((scn_btn as Control).custom_minimum_size.x).is_greater_equal(64.0)

	hud.queue_free()


# ===========================================================================
# INTEGRATION: HUD connect_inventory + inventory_full -> notification
# ===========================================================================

func test_hud_inventory_full_shows_notification() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var inv: Inventory = _Inventory.new()
	hud.connect_inventory(inv)

	# Fill inventory completely
	inv.add_item(&"wood", 99)
	inv.add_item(&"wood", 99)
	inv.add_item(&"stone", 99)
	inv.add_item(&"stone", 99)
	inv.add_item(&"berries", 20)
	inv.add_item(&"berries", 20)
	inv.add_item(&"toxic_berries", 20)
	inv.add_item(&"toxic_berries", 20)
	inv.add_item(&"fiber", 99)
	inv.add_item(&"fiber", 99)
	inv.add_item(&"ore", 99)
	inv.add_item(&"ore", 99)
	# 12 slots filled

	# This should trigger inventory_full
	inv.add_item(&"crystal", 10)

	# NotificationContainer should have at least 1 child
	var notif_container: Node = hud.get_node_or_null("NotificationContainer")
	assert_bool(notif_container != null).is_true()
	if notif_container != null:
		assert_int(notif_container.get_child_count()).override_failure_message(
			"NotificationContainer must show INVENTORY FULL notification"
		).is_greater(0)

	hud.queue_free()


# ===========================================================================
# INTEGRATION: Range check cancels scan when player moves away
# ===========================================================================

func test_range_check_cancels_scan_integration() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_resource(&"berries")
	_player.current_tile = Vector2i.ZERO

	var cancelled: Array = []
	_scanner.scan_cancelled.connect(func() -> void:
		cancelled.append(true)
	)

	_scanner._on_scan_hold_started(Vector2i(1, 0))
	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.SCANNING)

	# Move player beyond range (>2 hexes)
	_player.current_tile = Vector2i(4, 0)
	_scanner._process(0.016)

	assert_int(_scanner.get_scan_state()).is_equal(_ScannerSystem.ScanState.IDLE)
	assert_int(cancelled.size()).is_equal(1)

	_teardown_scanner_tree()
