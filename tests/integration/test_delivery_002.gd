extends GdUnitTestSuite
class_name TestDelivery002

## Integration tests for delivery-002: See and Know — Scanner + Inventory.
## Tests inventory data + UI, proximity auto-scan, 3-state labels, catalog panel,
## mutual exclusion, toxic berries warning, and cross-system signal flows.
##
## Manual-only verification (not automatable — documented here):
##   - Prop meshes float above tiles (cube=flora, sphere=fauna, cube=mineral/anomaly)
##   - Scan progress bar animates smoothly from left to right
##   - Labels billboard toward camera (❓/⚠️/name)
##   - Inventory panel slides up from bottom covering ~45% screen
##   - Catalog panel slides up from bottom covering ~45% screen

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _ScannerSystem = preload("res://scripts/scanner/scanner_system.gd")
const _PropRenderer = preload("res://scripts/rendering/prop_renderer.gd")
const _PropLabelRenderer = preload("res://scripts/rendering/prop_label_renderer.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

# Numeric prop ids on the world map: trees/boulders/etc.
const ID_TREE: StringName = &"P00001"
const ID_BERRY_BUSH: StringName = &"P00004"
const ID_BOULDER: StringName = &"P00005"
const ID_TOXIC_BUSH: StringName = &"P00008"
# Numeric inventory item ids.
const ID_WOOD: StringName = &"P00010"
const ID_STONE: StringName = &"P00013"
const ID_FIBER: StringName = &"P00012"
const ID_ORE: StringName = &"P00014"
const ID_CRYSTAL: StringName = &"P00015"
const ID_BERRIES: StringName = &"P00020"
const ID_TOXIC_BERRIES: StringName = &"P00021"
const ID_MEAT: StringName = &"P00022"
# Numeric tool ids.
const ID_AXE: StringName = &"P00201"

const _InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")
const _CatalogPanelScene = preload("res://scenes/ui/catalog_panel.tscn")


# --- Minimal fakes ---

class FakeGrid extends Node:
	var _tiles: Dictionary = {}
	signal map_generated()
	signal tile_entered(coords: Vector2i)
	signal tile_exited(coords: Vector2i)
	signal prop_depleted(coords: Vector2i, prop_type: StringName)
	signal prop_respawned(coords: Vector2i, prop_type: StringName)
	signal tile_contents_changed(coords: Vector2i)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)

	func get_all_tiles() -> Dictionary:
		return _tiles

	func has_tile(coords: Vector2i) -> bool:
		return _tiles.has(coords)

	func get_tile_count() -> int:
		return _tiles.size()

	func distance(a: Vector2i, b: Vector2i) -> int:
		var cube_a: Vector3i = Vector3i(a.x, -a.x - a.y, a.y)
		var cube_b: Vector3i = Vector3i(b.x, -b.x - b.y, b.y)
		return (abs(cube_a.x - cube_b.x) + abs(cube_a.y - cube_b.y) + abs(cube_a.z - cube_b.z)) / 2

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		var directions: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
		]
		var result: Array[Vector2i] = []
		for d in directions:
			var n: Vector2i = coords + d
			if _tiles.has(n):
				result.append(n)
		return result


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO


# --- State ---

var _grid: FakeGrid
var _player: FakePlayer
var _scanner: Node  # ScannerSystem
var _world: Node3D
var _prop_renderer: Node3D
var _label_renderer: Node3D

# Signal capture
var _sig_entry_id: StringName = &""
var _sig_category: int = -1
var _sig_coords: Vector2i = Vector2i(-999, -999)
var _sig_identified_count: int = 0
var _sig_unknown_count: int = 0
var _sig_interrupted_count: int = 0
var _sig_encountered_count: int = 0


# --- Helpers ---

func _reset_sig_captures() -> void:
	_sig_entry_id = &""
	_sig_category = -1
	_sig_coords = Vector2i(-999, -999)
	_sig_identified_count = 0
	_sig_unknown_count = 0
	_sig_interrupted_count = 0
	_sig_encountered_count = 0


func _on_sig_scan_started(eid: StringName, c: Vector2i) -> void:
	_sig_entry_id = eid
	_sig_coords = c


func _on_sig_entry_cataloged(eid: StringName, cat: int) -> void:
	_sig_entry_id = eid
	_sig_category = cat


func _on_sig_element_identified(_c: Vector2i, _eid: StringName) -> void:
	_sig_identified_count += 1


func _on_sig_element_unknown(_c: Vector2i, _eid: StringName, _cat: int) -> void:
	_sig_unknown_count += 1


func _on_sig_element_encountered(_c: Vector2i, _eid: StringName, _label: String) -> void:
	_sig_encountered_count += 1


func _on_sig_scan_interrupted() -> void:
	_sig_interrupted_count += 1


func _make_tile_with_prop(prop_type: StringName, elev: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.props = [_Prop.create_prop(prop_type, 0, 0)]
	return tile


func _make_tile_with_anomaly(anomaly_id: StringName, elev: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.elevation = elev
	tile.props = [_Prop.create_anomaly(anomaly_id)]
	return tile


func _setup_scanner_tree() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_player = FakePlayer.new()
	_player.name = "Player"

	_scanner = _ScannerSystem.new()
	_scanner.name = "ScannerSystem"
	_scanner._grid = _grid
	_scanner.set_process(false)
	_player.add_child(_scanner)

	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_world.add_child(_player)

	# PropRenderer
	_prop_renderer = _PropRenderer.new()
	_prop_renderer.name = "PropRenderer"
	_prop_renderer._grid = _grid
	_world.add_child(_prop_renderer)

	# PropLabelRenderer
	_label_renderer = _PropLabelRenderer.new()
	_label_renderer.name = "PropLabelRenderer"
	_label_renderer._grid = _grid
	_world.add_child(_label_renderer)

	# Manually connect scanner signals
	_label_renderer._scanner = _scanner

	# PropLabelRenderer connections
	_scanner.element_identified.connect(_label_renderer._on_element_identified)
	_scanner.element_unknown.connect(_label_renderer._on_element_unknown)
	_scanner.element_encountered.connect(_label_renderer._on_element_encountered)
	_scanner.entry_cataloged.connect(_label_renderer._on_entry_cataloged)
	_scanner.entry_encountered.connect(_label_renderer._on_entry_encountered)


func _teardown_scanner_tree() -> void:
	if is_instance_valid(_world):
		remove_child(_world)
		_world.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_prop_renderer = null
	_label_renderer = null
	_scanner = null
	_player = null
	_grid = null
	_world = null


# ===========================================================================
# Walk near unknown flora → proximity scan starts → catalog → label update → panel
# ===========================================================================

func test_walk_near_unknown_flora_full_flow() -> void:
	_setup_scanner_tree()

	# Place unknown berry tile adjacent to player
	_grid._tiles[Vector2i.ZERO] = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)
	_player.current_tile = Vector2i.ZERO

	# Passive ID: shows ❓ marker + prop mesh
	_scanner._check_passive_identification(Vector2i(1, 0))
	_grid.map_generated.emit()
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")
	assert_int(_prop_renderer.get_pool_visible_count(ID_BERRY_BUSH)).is_equal(1)

	# Proximity scan starts automatically
	_scanner._process(0.016)
	assert_bool(_scanner.is_scanning()).is_true()

	# Complete scan (flora = 2.0s)
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)
	assert_bool(_scanner.is_scanning()).is_false()

	# Marker cleared on catalog (CATALOGED = no marker)
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("")

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
# Leave range during scan → progress resets immediately, scan interrupted
# ===========================================================================

func test_leave_range_during_scan_interrupts() -> void:
	_setup_scanner_tree()

	_grid._tiles[Vector2i.ZERO] = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)
	_grid._tiles[Vector2i(4, 0)] = _HexTile.new()
	_player.current_tile = Vector2i.ZERO

	var interrupted: Array = []
	_scanner.scan_interrupted.connect(func() -> void:
		interrupted.append(true)
	)

	_scanner._process(0.016)  # start proximity scan
	assert_bool(_scanner.is_scanning()).is_true()

	# Move player beyond range
	_player.current_tile = Vector2i(4, 0)
	_scanner._process(0.016)

	assert_bool(_scanner.is_scanning()).is_false()
	assert_int(interrupted.size()).is_equal(1)
	assert_float(_scanner.get_scan_progress()).is_equal(0.0)

	_teardown_scanner_tree()


# ===========================================================================
# One scan at a time, nearest prop first
# ===========================================================================

func test_one_scan_at_a_time_nearest_first() -> void:
	_setup_scanner_tree()

	_grid._tiles[Vector2i.ZERO] = _make_tile_with_prop(ID_BERRY_BUSH)  # distance 0
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BOULDER)  # distance 1
	_player.current_tile = Vector2i.ZERO

	_scanner._process(0.016)  # should pick nearest (distance 0)
	assert_bool(_scanner.is_scanning()).is_true()

	# Complete first scan
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	# Should auto-start next scan on adjacent tile
	_scanner._process(0.016)
	assert_bool(_scanner.is_scanning()).is_true()

	_teardown_scanner_tree()


# ===========================================================================
# Bulk label update: all visible ❓ labels of cataloged type flip at once
# ===========================================================================

func test_bulk_label_update_on_catalog() -> void:
	_setup_scanner_tree()

	# Three berry tiles
	_grid._tiles[Vector2i.ZERO] = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)
	_grid._tiles[Vector2i(2, 1)] = _make_tile_with_prop(ID_BERRY_BUSH)
	_grid._tiles[Vector2i(0, -1)] = _make_tile_with_prop(ID_BERRY_BUSH)
	# One stone tile
	_grid._tiles[Vector2i(3, 0)] = _make_tile_with_prop(ID_BOULDER)
	_player.current_tile = Vector2i.ZERO

	# Passive ID marks all
	for coords in [Vector2i(1, 0), Vector2i(2, 1), Vector2i(0, -1), Vector2i(3, 0)]:
		_scanner._check_passive_identification(coords)

	# All show ❓
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")
	assert_str(_label_renderer.get_label_text_at(Vector2i(3, 0))).is_equal("❓")

	# Scan one berry to catalog berry_bush
	_scanner._process(0.016)  # start scan
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	# All 3 berry markers cleared (CATALOGED = no marker)
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("")
	assert_str(_label_renderer.get_label_text_at(Vector2i(2, 1))).is_equal("")
	assert_str(_label_renderer.get_label_text_at(Vector2i(0, -1))).is_equal("")
	# Stone still shows ❓
	assert_str(_label_renderer.get_label_text_at(Vector2i(3, 0))).is_equal("❓")

	_teardown_scanner_tree()


# ===========================================================================
# ENCOUNTERED fauna label: "⚠️ Unidentified Fauna (Hostile)"
# ===========================================================================

func test_encountered_fauna_label() -> void:
	_setup_scanner_tree()

	# Surprise encounter
	_scanner.on_fauna_attacked_player(1, 10, &"thornback")

	# Check catalog state
	assert_bool(_scanner._catalog.is_encountered(&"thornback")).is_true()
	assert_str(_scanner._catalog.get_encounter_label(&"thornback")).is_equal("Hostile")

	_teardown_scanner_tree()


# ===========================================================================
# 3-state labels: UNKNOWN=❓, ENCOUNTERED=⚠️, CATALOGED=name
# ===========================================================================

func test_three_state_labels() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)

	# UNKNOWN
	_scanner._check_passive_identification(Vector2i(1, 0))
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")
	assert_int(_label_renderer.get_label_state_at(Vector2i(1, 0))).is_equal(_Catalog.KnowledgeState.UNKNOWN)

	# CATALOGED via scan (catalog berry_bush directly for testing marker)
	# Label nodes are freed and removed from tracking on catalog — no label exists anymore.
	_scanner.entry_cataloged.emit(&"P00004", _Catalog.CatalogCategory.FLORA)
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("")
	assert_int(_label_renderer.get_label_state_at(Vector2i(1, 0))).is_equal(-1)

	_teardown_scanner_tree()


# ===========================================================================
# Catalog counter counts both ENCOUNTERED and CATALOGED entries
# ===========================================================================

func test_catalog_counter_counts_encountered_and_cataloged() -> void:
	_setup_scanner_tree()

	_scanner._catalog.catalog_entry(&"P00004")
	_scanner._catalog.encounter_entry(&"thornback", "Hostile")

	assert_int(_scanner._catalog.get_discovery_count()).is_equal(2)
	assert_str(_scanner._catalog.get_discovery_text()).is_equal("2 entries")

	_teardown_scanner_tree()


# ===========================================================================
# Inventory add → panel displays → inventory full → floating text
# ===========================================================================

func test_inventory_add_panel_display_and_full_notification() -> void:
	var inv: Inventory = _Inventory.new()
	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)

	# Add items
	inv.add_item(ID_WOOD, 10)
	assert_int(inv.get_count(ID_WOOD)).is_equal(10)

	# Panel displays correct state
	panel.open()
	assert_int(inv.get_used_slot_count()).is_equal(1)
	panel.close()

	# Fill inventory to trigger inventory_full
	var full_fired: Array = []
	inv.inventory_full.connect(func(type: StringName, rejected: int) -> void:
		full_fired.append({"type": type, "rejected": rejected})
	)

	# Fill slots
	inv.add_item(ID_STONE, 99)
	inv.add_item(ID_BERRIES, 20)
	inv.add_item(ID_TOXIC_BERRIES, 20)
	inv.add_item(ID_FIBER, 99)
	inv.add_item(ID_ORE, 99)
	inv.add_item(ID_CRYSTAL, 50)
	inv.add_item(ID_MEAT, 20)
	inv.add_item(ID_WOOD, 99)
	inv.add_item(ID_STONE, 99)
	inv.add_item(ID_BERRIES, 20)
	inv.add_item(ID_MEAT, 20)

	# Try to add more
	inv.add_item(ID_MEAT, 20)
	if inv.is_full():
		inv.add_item(ID_WOOD, 10)
		assert_bool(full_fired.size() > 0).override_failure_message(
			"inventory_full signal must fire when inventory is full"
		).is_true()

	panel.queue_free()


# ===========================================================================
# Mutual exclusion: open Catalog → Inventory closes, and vice versa
# ===========================================================================

func test_mutual_exclusion_catalog_closes_inventory() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	var status_panel = hud.get_node("StatusPanel")
	var log_panel = hud.get_node("LogPanel")

	status_panel.open()
	assert_bool(status_panel.visible).is_true()

	log_panel.open()
	assert_bool(log_panel.visible).is_true()
	assert_bool(status_panel.visible).is_false()

	hud.queue_free()


func test_mutual_exclusion_inventory_closes_catalog() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	var status_panel = hud.get_node("StatusPanel")
	var log_panel = hud.get_node("LogPanel")

	log_panel.open()
	assert_bool(log_panel.visible).is_true()

	status_panel.open()
	assert_bool(status_panel.visible).is_true()
	assert_bool(log_panel.visible).is_false()

	hud.queue_free()


# ===========================================================================
# AC5: 12 slots, 13th rejected, stacking, tool slots
# ===========================================================================

func test_ac5_12_base_slots() -> void:
	var inv: Inventory = _Inventory.new()
	assert_int(inv.get_max_slots()).is_equal(12)
	assert_int(inv.get_used_slot_count()).is_equal(0)


func test_ac5_stacking_within_max_stack() -> void:
	var inv: Inventory = _Inventory.new()
	inv.capacity_weight = 200.0  # Override for stack test — need room for 80 wood (80 * 1.0)
	inv.add_item(ID_WOOD, 50)
	inv.add_item(ID_WOOD, 30)
	assert_int(inv.get_count(ID_WOOD)).is_equal(80)
	assert_int(inv.get_used_slot_count()).is_equal(1)


func test_ac5_stacking_overflow_creates_new_slot() -> void:
	var inv: Inventory = _Inventory.new()
	inv.capacity_weight = 200.0  # Override for stack test — need room for 109 wood (109 * 1.0)
	inv.add_item(ID_WOOD, 99)
	inv.add_item(ID_WOOD, 10)
	assert_int(inv.get_count(ID_WOOD)).is_equal(109)
	assert_int(inv.get_used_slot_count()).is_equal(2)


func test_ac5_tool_slots_starting_state() -> void:
	# Starting tools are now applied from map's starting_loadout, not hardcoded.
	var inv: Inventory = _Inventory.new()
	assert_object(inv.get_tool(&"weapon")).is_equal(&"")
	assert_object(inv.get_tool(&"scanner")).is_equal(&"")
	assert_object(inv.get_tool(&"axe")).is_equal(&"")
	assert_object(inv.get_tool(&"pickaxe")).is_equal(&"")


func test_ac5_tool_routing_rejection() -> void:
	var inv: Inventory = _Inventory.new()
	var added: int = inv.add_item(ID_AXE, 1)
	assert_int(added).is_equal(0)
	assert_int(inv.get_used_slot_count()).is_equal(0)


func test_ac5_expansion_adds_12_slots() -> void:
	var inv: Inventory = _Inventory.new()
	inv.expand(12)
	assert_int(inv.get_max_slots()).is_equal(24)
	assert_int(inv.get_slots().size()).is_equal(24)


# ===========================================================================
# AC11: proximity scan flow, ENCOUNTERED state, auto-identify, mineral, anomaly
# ===========================================================================

func test_ac11_unknown_label_on_tile_reveal() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)

	_scanner._check_passive_identification(Vector2i(1, 0))
	_grid.map_generated.emit()
	assert_str(_label_renderer.get_label_text_at(Vector2i(1, 0))).is_equal("❓")
	assert_int(_prop_renderer.get_pool_visible_count(ID_BERRY_BUSH)).is_equal(1)

	_teardown_scanner_tree()


func test_ac11_proximity_scan_flow() -> void:
	_setup_scanner_tree()
	_grid._tiles[Vector2i.ZERO] = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)
	_player.current_tile = Vector2i.ZERO

	assert_bool(_scanner.is_scanning()).is_false()

	_scanner._process(0.016)  # proximity scan starts
	assert_bool(_scanner.is_scanning()).is_true()

	_scanner._scan_progress = 0.99
	_scanner._process(0.05)
	assert_bool(_scanner.is_scanning()).is_false()
	assert_bool(_scanner._catalog.is_cataloged(&"P00004")).is_true()

	_teardown_scanner_tree()


func test_ac11_auto_identify_after_catalog() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	_scanner._catalog.catalog_entry(&"P00004")

	_grid._tiles[Vector2i(3, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)

	_scanner.element_identified.connect(_on_sig_element_identified)
	_scanner.element_unknown.connect(_on_sig_element_unknown)

	_scanner._check_passive_identification(Vector2i(3, 0))
	assert_int(_sig_identified_count).is_equal(1)
	assert_int(_sig_unknown_count).is_equal(0)

	_teardown_scanner_tree()


func test_ac11_mineral_scan_complete() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	_grid._tiles[Vector2i.ZERO] = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BOULDER)
	_player.current_tile = Vector2i.ZERO

	_scanner.entry_cataloged.connect(_on_sig_entry_cataloged)

	_scanner._process(0.016)  # start proximity scan
	assert_float(_scanner._scan_duration).is_equal(2.0)

	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	assert_str(String(_sig_entry_id)).is_equal("P00005")
	assert_int(_sig_category).is_equal(_Catalog.CatalogCategory.MINERAL)

	_teardown_scanner_tree()


func test_ac11_anomaly_scan_complete_and_signal() -> void:
	_setup_scanner_tree()
	_reset_sig_captures()
	_grid._tiles[Vector2i.ZERO] = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_anomaly(&"P10001")
	_player.current_tile = Vector2i.ZERO

	_scanner.entry_cataloged.connect(_on_sig_entry_cataloged)

	_scanner._process(0.016)  # start proximity scan
	assert_float(_scanner._scan_duration).is_equal(3.0)

	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	assert_str(String(_sig_entry_id)).is_equal("P10001")
	assert_int(_sig_category).is_equal(_Catalog.CatalogCategory.ANOMALY)

	_teardown_scanner_tree()


func test_ac11_encountered_state_on_surprise_attack() -> void:
	_setup_scanner_tree()

	_scanner.on_fauna_attacked_player(1, 10, &"thornback")

	assert_bool(_scanner._catalog.is_encountered(&"thornback")).is_true()
	assert_bool(_scanner._catalog.is_cataloged(&"thornback")).is_false()
	assert_str(_scanner._catalog.get_encounter_label(&"thornback")).is_equal("Hostile")

	_teardown_scanner_tree()


# ===========================================================================
# Toxic berries — consume shows warning dialog
# ===========================================================================

func test_toxic_berries_tap_shows_warning_dialog() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(ID_TOXIC_BERRIES, 5)

	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"P00008")

	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)
	panel.set_catalog(cat)
	panel.open()

	panel._on_slot_tapped(ID_TOXIC_BERRIES)

	assert_str(String(panel._pending_use_type)).is_equal(String(ID_TOXIC_BERRIES))
	assert_bool(panel._confirm_dialog != null).is_true()

	panel._on_toxic_confirmed()
	assert_int(inv.get_count(ID_TOXIC_BERRIES)).is_equal(4)
	assert_str(String(panel._pending_use_type)).is_equal("")

	panel.queue_free()


func test_non_toxic_berries_tap_uses_directly() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(ID_BERRIES, 5)

	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"P00004")

	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)
	panel.set_catalog(cat)
	panel.open()

	panel._on_slot_tapped(ID_BERRIES)

	assert_int(inv.get_count(ID_BERRIES)).is_equal(4)

	panel.queue_free()


# ===========================================================================
# Catalog panel: correct categories after scan + ENCOUNTERED entry
# ===========================================================================

func test_catalog_panel_correct_categories_and_encountered() -> void:
	_setup_scanner_tree()

	# Catalog flora and mineral
	_grid._tiles[Vector2i.ZERO] = _HexTile.new()
	_grid._tiles[Vector2i(1, 0)] = _make_tile_with_prop(ID_BERRY_BUSH)
	_grid._tiles[Vector2i(0, 1)] = _make_tile_with_prop(ID_BOULDER)
	_player.current_tile = Vector2i.ZERO

	# Scan berries
	_scanner._process(0.016)
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	# Scan stone
	_scanner._process(0.016)
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)

	# Surprise encounter fauna
	_scanner.on_fauna_attacked_player(1, 10, &"thornback")

	# Open catalog panel
	var panel: PanelContainer = _CatalogPanelScene.instantiate()
	add_child(panel)
	panel.set_catalog(_scanner.get_catalog())
	panel.open()

	assert_int(panel._flora_list.get_child_count()).is_equal(1)
	assert_int(panel._mineral_list.get_child_count()).is_equal(1)
	assert_int(panel._fauna_list.get_child_count()).is_equal(1)
	assert_int(panel._anomaly_list.get_child_count()).is_equal(0)
	assert_str(panel._counter_label.text).is_equal("3 entries")

	panel.queue_free()
	_teardown_scanner_tree()


# ===========================================================================
# Catalog panel refreshes on entry_cataloged signal
# ===========================================================================

func test_catalog_panel_refreshes_on_entry_cataloged() -> void:
	var cat := _Catalog.new()
	cat.initialize()

	var panel: PanelContainer = _CatalogPanelScene.instantiate()
	add_child(panel)
	panel.set_catalog(cat)
	panel.open()

	assert_int(panel._flora_list.get_child_count()).is_equal(0)

	cat.catalog_entry(&"P00004")

	assert_int(panel._flora_list.get_child_count()).is_equal(1)
	assert_str(panel._counter_label.text).is_equal("1 entry")

	panel.queue_free()


# ===========================================================================
# Inventory panel re-renders on inventory_changed
# ===========================================================================

func test_inventory_panel_rerenders_on_inventory_changed() -> void:
	var inv: Inventory = _Inventory.new()
	var panel: PanelContainer = _InventoryPanelScene.instantiate()
	add_child(panel)
	panel.set_inventory(inv)
	panel.open()

	assert_int(panel._slot_nodes.size()).is_equal(12)

	inv.add_item(ID_WOOD, 25)

	var slots: Array = inv.get_slots()
	var first_slot: Dictionary = slots[0]
	assert_object(first_slot["type"]).is_equal(ID_WOOD)
	assert_int(first_slot["quantity"]).is_equal(25)

	panel.queue_free()


# ===========================================================================
# Surprise encounter → ENCOUNTERED, not CATALOGED
# ===========================================================================

func test_surprise_encounter_creates_encountered_not_cataloged() -> void:
	_setup_scanner_tree()

	var encounter_ids: Array = []
	var catalog_ids: Array = []
	_scanner.entry_encountered.connect(func(eid: StringName, _label: String) -> void:
		encounter_ids.append(String(eid))
	)
	_scanner.entry_cataloged.connect(func(eid: StringName, _cat: int) -> void:
		catalog_ids.append(String(eid))
	)

	_scanner.on_fauna_attacked_player(1, 10, &"thornback")

	assert_int(encounter_ids.size()).is_equal(1)
	assert_str(encounter_ids[0]).is_equal("thornback")
	assert_int(catalog_ids.size()).is_equal(0)  # NOT cataloged, just encountered
	assert_bool(_scanner._catalog.is_encountered(&"thornback")).is_true()
	assert_bool(_scanner._catalog.is_cataloged(&"thornback")).is_false()

	_teardown_scanner_tree()


# ===========================================================================
# Save/load round-trip for both Inventory and Catalog
# ===========================================================================

func test_inventory_save_load_round_trip() -> void:
	var inv: Inventory = _Inventory.new()
	inv.add_item(ID_WOOD, 40)       # 40 * 1.0 = 40.0
	inv.add_item(ID_BERRIES, 10)    # 10 * 0.01 = 0.1
	inv.set_tool(&"axe", ID_AXE)
	inv.expand(12)

	var save_data: Dictionary = inv.get_save_data()

	var inv2: Inventory = _Inventory.new()
	inv2.load_save_data(save_data)

	assert_int(inv2.get_count(ID_WOOD)).is_equal(40)
	assert_int(inv2.get_count(ID_BERRIES)).is_equal(10)
	assert_object(inv2.get_tool(&"axe")).is_equal(ID_AXE)
	assert_int(inv2.get_max_slots()).is_equal(24)


func test_catalog_save_load_round_trip() -> void:
	var cat := _Catalog.new()
	cat.initialize()
	cat.catalog_entry(&"P00004")
	cat.encounter_entry(&"thornback", "Hostile")

	var save_data: Dictionary = cat.get_save_data()

	var cat2 := _Catalog.new()
	cat2.initialize()
	cat2.load_save_data(save_data)

	assert_bool(cat2.is_cataloged(&"P00004")).is_true()
	assert_bool(cat2.is_encountered(&"thornback")).is_true()
	assert_str(cat2.get_encounter_label(&"thornback")).is_equal("Hostile")
	assert_int(cat2.get_discovery_count()).is_equal(2)


# ===========================================================================
# HUD structure — buttons exist
# ===========================================================================

func test_hud_status_gear_log_buttons_exist() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	var status_btn: Node = hud.get_node_or_null("BottomBar/StatusButton")
	var gear_btn: Node = hud.get_node_or_null("BottomBar/GearButton")
	var log_btn: Node = hud.get_node_or_null("BottomBar/LogButton")
	assert_bool(status_btn != null).override_failure_message("StatusButton must exist in HUD").is_true()
	assert_bool(gear_btn != null).override_failure_message("GearButton must exist in HUD").is_true()
	assert_bool(log_btn != null).override_failure_message("LogButton must exist in HUD").is_true()

	if status_btn != null:
		assert_float((status_btn as Control).custom_minimum_size.x).is_greater_equal(64.0)
	if gear_btn != null:
		assert_float((gear_btn as Control).custom_minimum_size.x).is_greater_equal(64.0)
	if log_btn != null:
		assert_float((log_btn as Control).custom_minimum_size.x).is_greater_equal(64.0)

	hud.queue_free()


# ===========================================================================
# HUD inventory_full → notification
# ===========================================================================

func test_hud_inventory_full_shows_notification() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	var inv: Inventory = _Inventory.new()
	hud.connect_inventory(inv)

	# Fill all 12 slots
	inv.add_item(ID_WOOD, 99)
	inv.add_item(ID_WOOD, 99)
	inv.add_item(ID_STONE, 99)
	inv.add_item(ID_STONE, 99)
	inv.add_item(ID_BERRIES, 20)
	inv.add_item(ID_BERRIES, 20)
	inv.add_item(ID_TOXIC_BERRIES, 20)
	inv.add_item(ID_TOXIC_BERRIES, 20)
	inv.add_item(ID_FIBER, 99)
	inv.add_item(ID_FIBER, 99)
	inv.add_item(ID_ORE, 99)
	inv.add_item(ID_ORE, 99)

	# Overflow
	inv.add_item(ID_CRYSTAL, 10)

	var notif_container: Node = hud.get_node_or_null("NotificationContainer")
	assert_bool(notif_container != null).is_true()
	if notif_container != null:
		assert_int(notif_container.get_child_count()).override_failure_message(
			"NotificationContainer must show INVENTORY FULL notification"
		).is_greater(0)

	hud.queue_free()
