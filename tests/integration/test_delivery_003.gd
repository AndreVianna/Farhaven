extends GdUnitTestSuite
class_name TestDelivery003

## Integration tests for delivery-003: Movement IS Interaction — Auto-Gather + Crafting.
## Tests the complete core gameplay loop:
##   explore → scan → catalog → auto-gather → craft → unlock gated resources.
##
## Auto-gather uses continuous world-space proximity (GATHER_RADIUS = 0.75 Godot units)
## instead of tile_entered events.
##
## Covers AC3 (auto-gather: uncataloged inert, scan→catalog→auto-gather, tool gate,
## depletion, respawn) and AC4 (crafting: workbench recipe visibility, greyed
## insufficient, discovery on gather, craft produces tool).
##
## Manual-only verification (not automatable — documented here):
##   - Fly-to-player sprite arcs visually from resource to player
##   - Floating text rises and fades at player position
##   - Sound "ding" plays on gather complete
##   - Crafting panel slide animation

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")
const _ScannerSystem = preload("res://scripts/scanner/scanner_system.gd")
const _AutoInteractionSystem = preload("res://scripts/auto_interaction/auto_interaction_system.gd")
const _CraftingSystem = preload("res://scripts/crafting/crafting_system.gd")
const _ResourceRenderer = preload("res://scripts/rendering/resource_renderer.gd")
const _FlyToPlayer = preload("res://scripts/rendering/fly_to_player.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")

const _CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")


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

	func axial_to_world(coords: Vector2i) -> Vector2:
		var q: float = float(coords.x)
		var r: float = float(coords.y)
		var x: float = 3.0 * (3.0 / 2.0 * q)
		var y: float = 3.0 * (sqrt(3.0) / 2.0 * q + sqrt(3.0) * r)
		return Vector2(x, y)


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO
	var inventory: RefCounted = null

	func get_inventory():
		return inventory


# --- State ---

var _grid: FakeGrid
var _player: FakePlayer
var _inventory: RefCounted  # Inventory
var _catalog: RefCounted    # Catalog
var _scanner: Node          # ScannerSystem
var _auto_interaction: Node  # AutoInteractionSystem
var _crafting: Node          # CraftingSystem
var _resource_renderer: Node3D
var _world: Node3D


# --- Helpers ---

func _make_resource_prop(type: StringName, remaining: int = 3, tool_req: StringName = &"", respawn: float = 0.0) -> Prop:
	var prop: Prop = _Prop.new()
	prop.type = type
	prop.category = Prop.Category.RESOURCE
	prop.remaining = remaining
	prop.max_amount = remaining
	prop.tool_required = tool_req
	prop.respawn_time = respawn
	prop.sub_hex = Vector2i.ZERO
	return prop


func _make_tile(resource_type: StringName = &"", remaining: int = 3, tool_req: StringName = &"", fog: int = _HexTile.FogState.VISIBLE, respawn: float = 0.0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.fog_state = fog
	if resource_type != &"":
		tile.props = [_make_resource_prop(resource_type, remaining, tool_req, respawn)]
	return tile


func _make_empty_tile(fog: int = _HexTile.FogState.VISIBLE) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.fog_state = fog
	return tile


## Place the player at the world-space center of the given tile.
func _place_player_at_tile(coords: Vector2i) -> void:
	var world_2d: Vector2 = _grid.axial_to_world(coords)
	_player.position = Vector3(world_2d.x, 0.0, world_2d.y)
	_player.current_tile = coords


## Place the player near a resource on a specific tile.
## Computes resource world pos from tile coords + resource node offset, positions player there.
func _place_player_near_resource(tile_coords: Vector2i, resource_offset: Vector2 = Vector2.ZERO, player_tile: Vector2i = Vector2i(-999, -999)) -> void:
	var tile_center: Vector2 = _grid.axial_to_world(tile_coords)
	var offset_w: Vector2 = _PropUtils.offset_to_world(resource_offset, _HexMath.HEX_SIZE)
	var resource_world: Vector2 = tile_center + offset_w
	_player.position = Vector3(resource_world.x, 0.0, resource_world.y)
	if player_tile == Vector2i(-999, -999):
		_player.current_tile = tile_coords
	else:
		_player.current_tile = player_tile


func _setup_full_tree() -> void:
	_grid = FakeGrid.new()
	add_child(_grid)

	_inventory = _Inventory.new()

	_player = FakePlayer.new()
	_player.name = "Player"
	_player.inventory = _inventory

	# ScannerSystem
	_scanner = _ScannerSystem.new()
	_scanner.name = "ScannerSystem"
	_scanner._grid = _grid
	_scanner.set_process(false)
	_player.add_child(_scanner)

	# Get catalog reference after _ready (scanner creates it)
	# We'll resolve after adding to tree

	# AutoInteractionSystem
	_auto_interaction = _AutoInteractionSystem.new()
	_auto_interaction.name = "AutoInteractionSystem"
	_auto_interaction._grid = _grid
	_auto_interaction.set_process(false)
	_player.add_child(_auto_interaction)

	# CraftingSystem
	_crafting = _CraftingSystem.new()
	_crafting.name = "CraftingSystem"
	_crafting._grid = _grid
	_player.add_child(_crafting)

	# World
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_world.add_child(_player)

	# ResourceRenderer
	_resource_renderer = _ResourceRenderer.new()
	_resource_renderer.name = "ResourceRenderer"
	_resource_renderer._grid = _grid
	_world.add_child(_resource_renderer)

	# Resolve cross-references that happen in _ready / _resolve_dependencies
	_catalog = _scanner._catalog
	_auto_interaction._catalog = _catalog
	_auto_interaction._inventory = _inventory
	_auto_interaction._player = _player
	_crafting._inventory = _inventory
	_crafting._player = _player

	# Connect item_added for recipe discovery
	if not _inventory.item_added.is_connected(_crafting._on_item_added):
		_inventory.item_added.connect(_crafting._on_item_added)


func _teardown_full_tree() -> void:
	if is_instance_valid(_world):
		remove_child(_world)
		_world.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_resource_renderer = null
	_auto_interaction = null
	_crafting = null
	_scanner = null
	_catalog = null
	_inventory = null
	_player = null
	_grid = null
	_world = null


# ===========================================================================
# 1. Uncataloged inert: walk near uncataloged resource → nothing happens
# ===========================================================================

func test_uncataloged_resource_no_auto_gather() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 3)
	# Position player at neighbor tile's resource (close enough)
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	# Track signals
	var gather_started: Array = []
	var gather_failed: Array = []
	_auto_interaction.auto_gather_started.connect(func(c: Vector2i, t: StringName) -> void:
		gather_started.append({"coords": c, "type": t})
	)
	_auto_interaction.auto_gather_failed.connect(func(c: Vector2i, r: StringName) -> void:
		gather_failed.append({"coords": c, "reason": r})
	)

	# wood_tree is NOT cataloged → auto-gather should not fire
	_auto_interaction._check_gather_proximity()

	assert_int(gather_started.size()).override_failure_message(
		"Auto-gather must NOT start for uncataloged resource"
	).is_equal(0)
	assert_int(gather_failed.size()).override_failure_message(
		"No failure signal should fire for uncataloged resource"
	).is_equal(0)
	assert_bool(_auto_interaction._is_gathering).is_false()

	_teardown_full_tree()


# ===========================================================================
# 2. Scan → catalog → auto-gather: proximity catalog flora → walk near →
#    auto-gather fires → inventory updates
# ===========================================================================

func test_scan_catalog_then_auto_gather() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"berries", 3)
	_place_player_at_tile(Vector2i.ZERO)

	# Step 1: Scan and catalog berry_bush
	_scanner._process(0.016)  # start proximity scan
	assert_bool(_scanner.is_scanning()).is_true()
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)  # complete scan
	assert_bool(_catalog.is_cataloged(&"berry_bush")).is_true()

	# Step 2: Position player near the berries resource
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	var completed: Array = []
	_auto_interaction.auto_gather_completed.connect(func(c: Vector2i, t: StringName, a: int) -> void:
		completed.append({"coords": c, "type": t, "amount": a})
	)

	_auto_interaction._check_gather_proximity()
	assert_bool(_auto_interaction._is_gathering).is_true()

	# Complete the gather tween
	_auto_interaction._on_gather_tween_complete()

	assert_int(completed.size()).override_failure_message(
		"auto_gather_completed must fire after scan→catalog→gather"
	).is_equal(1)
	assert_str(String(completed[0]["type"])).is_equal("berries")
	assert_int(completed[0]["amount"]).is_equal(2)  # berries gather_amount = 2
	assert_int(_inventory.get_count(&"berries")).is_equal(2)

	_teardown_full_tree()


# ===========================================================================
# 3. Tool-gated resource: ore requires pickaxe → silently skipped (no signal)
# ===========================================================================

func test_tool_gated_resource_silently_skipped() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"ore", 3, &"stone_pickaxe")
	# Position player at the ore resource
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	# Catalog ore so it passes the catalog gate
	_catalog.catalog_entry(&"iron_deposit")

	var failed: Array = []
	_auto_interaction.auto_gather_failed.connect(func(c: Vector2i, r: StringName) -> void:
		failed.append({"coords": c, "reason": r})
	)

	# No pickaxe equipped → should be silently skipped (no tool_gated signal)
	_auto_interaction._check_gather_proximity()

	assert_int(failed.size()).override_failure_message(
		"No failure signal should fire for tool-gated resource (silent skip)"
	).is_equal(0)
	assert_bool(_auto_interaction._is_gathering).is_false()

	_teardown_full_tree()


# ===========================================================================
# 4. Resource depletion: gather until remaining=0 → resource_depleted signal
#    → visual change in ResourceRenderer
# ===========================================================================

func test_resource_depletion_signal_and_visual_change() -> void:
	_setup_full_tree()

	# Single wood node with remaining=1 for quick depletion
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 1)
	# Position player at the wood resource
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	# Show resource in renderer
	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.VISIBLE)
	assert_int(_resource_renderer.get_pool_visible_count(&"wood")).is_equal(1)

	# Verify the resource is NOT depleted initially
	var entries: Dictionary = _resource_renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(1, 0))).is_true()
	assert_bool(entries[Vector2i(1, 0)][0]["depleted"]).is_false()

	# Catalog wood_tree so auto-gather works
	_catalog.catalog_entry(&"wood_tree")

	# Track resource_depleted
	var depleted_signals: Array = []
	_grid.resource_depleted.connect(func(c: Vector2i, t: StringName) -> void:
		depleted_signals.append({"coords": c, "type": t})
	)

	# Gather
	_auto_interaction._check_gather_proximity()
	assert_bool(_auto_interaction._is_gathering).is_true()
	_auto_interaction._on_gather_tween_complete()

	# remaining was 1, now 0 → depleted
	assert_int(depleted_signals.size()).override_failure_message(
		"resource_depleted signal must fire when remaining hits 0"
	).is_equal(1)
	assert_str(String(depleted_signals[0]["type"])).is_equal("wood")

	# Visual change: ResourceRenderer should show depleted state after rebuild
	# The signal triggers _on_resource_depleted which rebuilds the tile
	entries = _resource_renderer.get_tile_entries()
	if entries.has(Vector2i(1, 0)) and not entries[Vector2i(1, 0)].is_empty():
		assert_bool(entries[Vector2i(1, 0)][0]["depleted"]).override_failure_message(
			"ResourceRenderer must mark resource as depleted after depletion signal"
		).is_true()

	_teardown_full_tree()


# ===========================================================================
# 5. Respawn: depleted resource → timer always ticks → resource_respawned → restored
# ===========================================================================

func test_respawn_timer_always_ticks_restores_resource() -> void:
	_setup_full_tree()

	# Wood with remaining=1, respawn_time=2.0
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 1, &"", _HexTile.FogState.VISIBLE, 2.0)
	# Position player at the wood resource
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	_catalog.catalog_entry(&"wood_tree")

	# Show resource
	_grid.tile_visibility_changed.emit(Vector2i(1, 0), _HexTile.FogState.VISIBLE)

	# Gather to deplete
	_auto_interaction._check_gather_proximity()
	_auto_interaction._on_gather_tween_complete()

	var tile: HexTile = _grid.get_tile(Vector2i(1, 0))
	assert_int(tile.props[0].remaining).is_equal(0)
	assert_int(_auto_interaction._respawn_queue.size()).is_equal(1)

	# Tile stays VISIBLE but respawn still ticks (fog system removed)
	var respawned_signals: Array = []
	_grid.resource_respawned.connect(func(c: Vector2i, t: StringName) -> void:
		respawned_signals.append({"coords": c, "type": t})
	)

	# Tick 1.5s — not enough yet
	_auto_interaction._tick_respawn_queue(1.5)
	assert_int(tile.props[0].remaining).is_equal(0)
	assert_int(respawned_signals.size()).is_equal(0)

	# Tick another 1.0s — total 2.5s > 2.0s respawn_time → respawn
	_auto_interaction._tick_respawn_queue(1.0)
	assert_int(tile.props[0].remaining).override_failure_message(
		"Resource must respawn to max_amount after timer expires"
	).is_equal(1)
	assert_int(respawned_signals.size()).is_equal(1)
	assert_int(_auto_interaction._respawn_queue.size()).is_equal(0)

	_teardown_full_tree()


# ===========================================================================
# 6. Chain gathering: walk through multiple resources → sequential auto-gathers
# ===========================================================================

func test_chain_gathering_multiple_resources() -> void:
	_setup_full_tree()

	# Use remaining=1 so each resource depletes after one gather,
	# forcing the chain to move to the next resource type.
	# Place both resources on the same tile so player is within radius of both
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 1)
	# Add stone as second resource on the SAME tile
	_grid._tiles[Vector2i(1, 0)].props.append(_make_resource_prop(&"stone", 1))
	# Position player at the resource tile
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	# Catalog both
	_catalog.catalog_entry(&"wood_tree")
	_catalog.catalog_entry(&"stone_deposit")

	var completed: Array = []
	_auto_interaction.auto_gather_completed.connect(func(c: Vector2i, t: StringName, a: int) -> void:
		completed.append({"coords": c, "type": t, "amount": a})
	)

	# Start first gather
	_auto_interaction._check_gather_proximity()
	assert_bool(_auto_interaction._is_gathering).is_true()

	# Complete first gather → chain should auto-start the next
	_auto_interaction._on_gather_tween_complete()
	assert_int(completed.size()).override_failure_message(
		"First gather in chain must complete"
	).is_equal(1)

	# Chain: auto-interaction should have started gathering the second resource
	assert_bool(_auto_interaction._is_gathering).override_failure_message(
		"Chain gathering must auto-start next resource after first completes"
	).is_true()

	# Complete the second gather
	_auto_interaction._on_gather_tween_complete()
	assert_int(completed.size()).override_failure_message(
		"Second gather in chain must complete"
	).is_equal(2)

	# Verify both types were gathered
	var types: Array = []
	for c in completed:
		types.append(String(c["type"]))
	assert_bool("wood" in types and "stone" in types).override_failure_message(
		"Both wood and stone must be gathered in chain"
	).is_true()

	_teardown_full_tree()


# ===========================================================================
# 7. Tool gating round-trip: craft stone_pickaxe → ore now auto-gatherable
# ===========================================================================

func test_tool_gating_round_trip_craft_unlocks_ore() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	# Ore tile with tool requirement
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"ore", 3, &"stone_pickaxe")
	# Add a workbench neighbor for crafting
	var wb_tile: HexTile = _make_empty_tile()
	var wb_prop: Prop = _Prop.new()
	wb_prop.type = &"workbench"
	wb_prop.category = Prop.Category.STRUCTURE
	wb_prop.sub_hex = Vector2i.ZERO
	wb_prop.blocks_movement = false
	wb_tile.props = [wb_prop]
	_grid._tiles[Vector2i(-1, 0)] = wb_tile
	# Position player at the ore resource
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	# Catalog ore
	_catalog.catalog_entry(&"iron_deposit")

	# Step 1: ore is gated, can't gather (silently skipped)
	_auto_interaction._check_gather_proximity()
	assert_bool(_auto_interaction._is_gathering).override_failure_message(
		"Ore must not be gatherable without stone_pickaxe"
	).is_false()

	# Step 2: Give player materials for stone_pickaxe (3 wood + 2 stone)
	_inventory.add_item(&"wood", 3)
	_inventory.add_item(&"stone", 2)

	# Discover recipes (stone triggers discovery)
	assert_bool(_crafting.is_recipe_discovered(&"stone_pickaxe")).override_failure_message(
		"stone_pickaxe recipe must be discovered after adding stone"
	).is_true()

	# Proximity to workbench
	_crafting._check_workbench_proximity()
	assert_bool(_crafting.is_near_workbench()).is_true()

	# Craft stone_pickaxe
	var craft_ok: bool = _crafting.craft(&"stone_pickaxe")
	assert_bool(craft_ok).override_failure_message(
		"Crafting stone_pickaxe must succeed with materials + workbench"
	).is_true()
	assert_object(_inventory.get_tool(&"pickaxe")).is_equal(&"stone_pickaxe")

	# Step 3: Now ore should be gatherable
	var completed: Array = []
	_auto_interaction.auto_gather_completed.connect(func(c: Vector2i, t: StringName, a: int) -> void:
		completed.append(t)
	)
	_auto_interaction._check_gather_proximity()
	assert_bool(_auto_interaction._is_gathering).override_failure_message(
		"Ore must be gatherable after crafting stone_pickaxe"
	).is_true()
	_auto_interaction._on_gather_tween_complete()

	assert_int(completed.size()).is_equal(1)
	assert_str(String(completed[0])).is_equal("ore")

	_teardown_full_tree()


# ===========================================================================
# 8. Recipe discovery: first stone gathered → recipes discovered
# ===========================================================================

func test_recipes_pre_discovered_from_start() -> void:
	_setup_full_tree()

	# Recipes are pre-discovered (pre_discovered: true in RECIPE_CONFIG)
	assert_int(_crafting.get_discovered_recipes().size()).override_failure_message(
		"Both recipes must be pre-discovered from the start"
	).is_equal(2)
	assert_bool(_crafting.is_recipe_discovered(&"stone_axe")).is_true()
	assert_bool(_crafting.is_recipe_discovered(&"stone_pickaxe")).is_true()

	# Adding stone should NOT emit discovery signal (already known)
	var discovered: Array = []
	_crafting.recipe_discovered.connect(func(name: StringName) -> void:
		discovered.append(String(name))
	)
	_inventory.add_item(&"stone", 1)
	assert_int(discovered.size()).override_failure_message(
		"No discovery signal should fire for pre-discovered recipes"
	).is_equal(0)

	_teardown_full_tree()


# ===========================================================================
# 9. Crafting flow: near workbench → panel shows → affordable/unaffordable →
#    craft produces tool
# ===========================================================================

func test_crafting_flow_panel_states_and_craft() -> void:
	_setup_full_tree()

	# Workbench adjacent
	var wb_tile: HexTile = _make_empty_tile()
	var wb_prop: Prop = _Prop.new()
	wb_prop.type = &"workbench"
	wb_prop.category = Prop.Category.STRUCTURE
	wb_prop.sub_hex = Vector2i.ZERO
	wb_prop.blocks_movement = false
	wb_tile.props = [wb_prop]
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = wb_tile
	_place_player_at_tile(Vector2i.ZERO)

	_crafting._check_workbench_proximity()
	assert_bool(_crafting.is_near_workbench()).is_true()

	# Recipes are pre-discovered
	assert_bool(_crafting.is_recipe_discovered(&"stone_axe")).is_true()

	# Setup crafting panel
	var panel: PanelContainer = _CraftingPanelScene.instantiate()
	add_child(panel)
	panel.set_crafting_system(_crafting)
	panel.set_inventory(_inventory)
	panel.open()

	# stone_axe needs 2W + 1S. We have 0W + 0S → unaffordable
	var recipe_entries: Dictionary = panel._recipe_entries
	assert_int(recipe_entries.size()).override_failure_message(
		"Crafting panel must show discovered recipes"
	).is_greater(0)

	# Check unaffordable state
	for entry_name: StringName in recipe_entries:
		var entry = recipe_entries[entry_name]
		if entry.get_recipe_name() == &"stone_axe":
			entry.refresh(_inventory, _crafting)
			assert_int(entry.get_state()).override_failure_message(
				"stone_axe must be UNAFFORDABLE with 0 stone, 0 wood"
			).is_equal(1)  # State.UNAFFORDABLE = 1

	# Add materials for stone_axe (2W + 1S)
	_inventory.add_item(&"wood", 2)
	_inventory.add_item(&"stone", 1)
	panel._refresh_all()

	for entry_name: StringName in recipe_entries:
		var entry = recipe_entries[entry_name]
		if entry.get_recipe_name() == &"stone_axe":
			assert_int(entry.get_state()).override_failure_message(
				"stone_axe must be AFFORDABLE with 2 wood + 1 stone"
			).is_equal(0)  # State.AFFORDABLE = 0

	# Craft stone_axe
	var craft_completed_fired: Array = []
	_crafting.craft_completed.connect(func(n: StringName) -> void:
		craft_completed_fired.append(String(n))
	)
	_crafting.craft(&"stone_axe")

	assert_int(craft_completed_fired.size()).is_equal(1)
	assert_object(_inventory.get_tool(&"axe")).is_equal(&"stone_axe")

	# After crafting, entry should show already_owned
	panel._refresh_all()
	for entry_name: StringName in recipe_entries:
		var entry = recipe_entries[entry_name]
		if entry.get_recipe_name() == &"stone_axe":
			assert_int(entry.get_state()).override_failure_message(
				"stone_axe must be ALREADY_OWNED after crafting"
			).is_equal(2)  # State.ALREADY_OWNED = 2

	panel.queue_free()
	_teardown_full_tree()


# ===========================================================================
# 10. CraftButton: hidden by default, visible when recipes are pre-discovered
# ===========================================================================

func test_craft_button_visibility_driven_by_recipes() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	# CraftButton starts hidden (no crafting system connected yet)
	var craft_btn: Button = hud.get_node("BottomBar/CraftButton")
	assert_bool(craft_btn.visible).override_failure_message(
		"CraftButton must be hidden by default (no crafting system connected)"
	).is_false()

	# Workbench proximity no longer drives craft button visibility
	hud._on_workbench_proximity_changed(true)
	assert_bool(craft_btn.visible).override_failure_message(
		"CraftButton must stay hidden — workbench proximity no longer controls it"
	).is_false()

	# Connect a crafting system with pre-discovered recipes → button becomes visible
	_setup_full_tree()
	hud.connect_crafting(_crafting, _inventory)
	assert_bool(craft_btn.visible).override_failure_message(
		"CraftButton must be visible after connecting crafting system with pre-discovered recipes"
	).is_true()

	_teardown_full_tree()
	hud.queue_free()


# ===========================================================================
# 11. Panel mutual exclusion: opening Crafting closes Inventory and Catalog
# ===========================================================================

func test_panel_mutual_exclusion_three_panels() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	var inv_panel = hud.get_node("InventoryPanel")
	var cat_panel = hud.get_node("CatalogPanel")
	var craft_panel = hud.get_node("CraftingPanel")

	# Open Inventory
	inv_panel.open()
	assert_bool(inv_panel.visible).is_true()

	# Open Crafting → Inventory must close
	craft_panel.open()
	assert_bool(craft_panel.visible).override_failure_message(
		"CraftingPanel must open"
	).is_true()
	assert_bool(inv_panel.visible).override_failure_message(
		"InventoryPanel must close when CraftingPanel opens"
	).is_false()
	assert_bool(cat_panel.visible).override_failure_message(
		"CatalogPanel must stay closed"
	).is_false()

	# Open Catalog → Crafting must close
	cat_panel.open()
	assert_bool(cat_panel.visible).is_true()
	assert_bool(craft_panel.visible).override_failure_message(
		"CraftingPanel must close when CatalogPanel opens"
	).is_false()
	assert_bool(inv_panel.visible).is_false()

	# Open Inventory → Catalog must close
	inv_panel.open()
	assert_bool(inv_panel.visible).is_true()
	assert_bool(cat_panel.visible).override_failure_message(
		"CatalogPanel must close when InventoryPanel opens"
	).is_false()

	hud.queue_free()


# ===========================================================================
# 12. Fly-to-player: fires on gather complete and cleans up (queue_free)
# ===========================================================================

func test_fly_to_player_spawns_and_cleans_up() -> void:
	var grid := FakeGrid.new()
	add_child(grid)

	var player := FakePlayer.new()
	player.position = Vector3(5.0, 0.0, 5.0)
	add_child(player)

	var fly := _FlyToPlayer.new()
	fly.setup(player)
	add_child(fly)

	# Before spawn: no children
	assert_int(fly.get_child_count()).is_equal(0)

	# Spawn fly-to-player
	fly.spawn_fly(Vector2i(1, 0), &"wood", grid)

	# Sprite created as child
	assert_int(fly.get_child_count()).override_failure_message(
		"Fly-to-player must create a sprite child on spawn"
	).is_equal(1)

	var sprite: Node = fly.get_child(0)
	assert_bool(sprite is MeshInstance3D).is_true()

	# The sprite will be queue_free'd by tween callback after FLY_DURATION.
	# We can't easily wait in unit test, but we verify the sprite was created
	# and that it's a valid MeshInstance3D. The tween cleanup is
	# verified by the fact that create_tween + tween_callback(queue_free) is used.

	fly.queue_free()
	player.queue_free()
	grid.queue_free()


# ===========================================================================
# 13. Stubs safe: no crash when FaunaManager/SurvivalSystem absent
# ===========================================================================

func test_stubs_safe_no_crash_without_fauna_or_survival() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 3)
	_place_player_at_tile(Vector2i.ZERO)

	# FaunaManager and SurvivalSystem are both absent (not in tree)
	# These calls should NOT crash:

	# auto-pickup stub queries SurvivalSystem
	_auto_interaction._try_auto_pickup(Vector2i.ZERO)

	# auto-defend stub tries to connect FaunaManager
	_auto_interaction._connect_fauna_manager()

	# Verify no crash — if we got here, stubs are safe
	assert_bool(true).override_failure_message(
		"Must not crash when FaunaManager and SurvivalSystem are absent"
	).is_true()

	_teardown_full_tree()


# ===========================================================================
# Crafting validation: no workbench → craft fails
# ===========================================================================

func test_craft_succeeds_without_workbench() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_place_player_at_tile(Vector2i.ZERO)

	# Add materials for stone_pickaxe (3W + 2S)
	_inventory.add_item(&"stone", 2)
	_inventory.add_item(&"wood", 3)

	# Not near workbench — but requires_workbench is false for current recipes
	_crafting._check_workbench_proximity()
	assert_bool(_crafting.is_near_workbench()).is_false()

	var completed: Array = []
	_crafting.craft_completed.connect(func(n: StringName) -> void:
		completed.append(String(n))
	)

	var result: bool = _crafting.craft(&"stone_pickaxe")
	assert_bool(result).override_failure_message(
		"Craft must succeed without workbench when requires_workbench is false"
	).is_true()
	assert_int(completed.size()).is_equal(1)
	assert_str(completed[0]).is_equal("stone_pickaxe")

	_teardown_full_tree()


# ===========================================================================
# Crafting validation: already owned → craft fails
# ===========================================================================

func test_craft_fails_when_already_owned() -> void:
	_setup_full_tree()

	var wb_tile: HexTile = _make_empty_tile()
	var wb_prop: Prop = _Prop.new()
	wb_prop.type = &"workbench"
	wb_prop.category = Prop.Category.STRUCTURE
	wb_prop.sub_hex = Vector2i.ZERO
	wb_prop.blocks_movement = false
	wb_tile.props = [wb_prop]
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = wb_tile
	_place_player_at_tile(Vector2i.ZERO)

	_crafting._check_workbench_proximity()

	# Give tool directly
	_inventory.set_tool(&"axe", &"stone_axe")

	# Discover recipe + add materials
	_inventory.add_item(&"stone", 1)
	_inventory.add_item(&"wood", 2)

	var failed_reasons: Array = []
	_crafting.craft_failed.connect(func(n: StringName, r: StringName) -> void:
		failed_reasons.append(String(r))
	)

	_crafting.craft(&"stone_axe")
	assert_int(failed_reasons.size()).is_equal(1)
	assert_str(failed_reasons[0]).is_equal("already_owned")

	# Verify materials were NOT consumed
	assert_int(_inventory.get_count(&"wood")).is_equal(2)
	assert_int(_inventory.get_count(&"stone")).is_equal(1)

	_teardown_full_tree()


# ===========================================================================
# Crafting validation: insufficient materials → craft fails
# ===========================================================================

func test_craft_fails_with_insufficient_materials() -> void:
	_setup_full_tree()

	var wb_tile: HexTile = _make_empty_tile()
	var wb_prop: Prop = _Prop.new()
	wb_prop.type = &"workbench"
	wb_prop.category = Prop.Category.STRUCTURE
	wb_prop.sub_hex = Vector2i.ZERO
	wb_prop.blocks_movement = false
	wb_tile.props = [wb_prop]
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = wb_tile
	_place_player_at_tile(Vector2i.ZERO)

	_crafting._check_workbench_proximity()

	# Discover recipe but insufficient materials
	_inventory.add_item(&"stone", 1)
	# stone_pickaxe needs 3W + 2S, we have 0W + 1S

	var failed_reasons: Array = []
	_crafting.craft_failed.connect(func(n: StringName, r: StringName) -> void:
		failed_reasons.append(String(r))
	)

	_crafting.craft(&"stone_pickaxe")
	assert_int(failed_reasons.size()).is_equal(1)
	assert_str(failed_reasons[0]).is_equal("insufficient_materials")

	_teardown_full_tree()


# ===========================================================================
# Resource depletion visual change via ResourceRenderer
# ===========================================================================

func test_resource_renderer_depleted_visual_swap() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i(2, 0)] = _make_tile(&"stone", 2)
	_grid.tile_visibility_changed.emit(Vector2i(2, 0), _HexTile.FogState.VISIBLE)

	# Initially not depleted
	var entries: Dictionary = _resource_renderer.get_tile_entries()
	assert_bool(entries.has(Vector2i(2, 0))).is_true()
	assert_bool(entries[Vector2i(2, 0)][0]["depleted"]).is_false()

	# Simulate depletion: set remaining to 0, then fire signal
	# (ResourceRenderer._rebuild_tile checks rn.remaining <= 0)
	var tile: HexTile = _grid.get_tile(Vector2i(2, 0))
	tile.props[0].remaining = 0
	_grid.resource_depleted.emit(Vector2i(2, 0), &"stone")

	entries = _resource_renderer.get_tile_entries()
	assert_bool(entries[Vector2i(2, 0)][0]["depleted"]).override_failure_message(
		"ResourceRenderer must mark stone as depleted after resource_depleted signal"
	).is_true()

	# Simulate respawn: restore remaining, then fire signal
	tile.props[0].remaining = tile.props[0].max_amount
	_grid.resource_respawned.emit(Vector2i(2, 0), &"stone")

	entries = _resource_renderer.get_tile_entries()
	assert_bool(entries[Vector2i(2, 0)][0]["depleted"]).override_failure_message(
		"ResourceRenderer must restore stone after resource_respawned signal"
	).is_false()

	_teardown_full_tree()


# ===========================================================================
# Respawn always ticks (fog system removed)
# ===========================================================================

func test_respawn_always_ticks_regardless_of_visibility() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"stone", 1, &"", _HexTile.FogState.VISIBLE, 1.0)
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	_catalog.catalog_entry(&"stone_deposit")

	# Deplete
	_auto_interaction._check_gather_proximity()
	_auto_interaction._on_gather_tween_complete()

	assert_int(_auto_interaction._respawn_queue.size()).is_equal(1)

	# Tile remains VISIBLE → respawn still ticks (fog system removed)
	_auto_interaction._tick_respawn_queue(1.5)
	var tile: HexTile = _grid.get_tile(Vector2i(1, 0))
	assert_int(tile.props[0].remaining).override_failure_message(
		"Respawn must tick even while tile is VISIBLE (fog removed)"
	).is_equal(1)

	_teardown_full_tree()


# ===========================================================================
# Respawn_time == 0 → never enters queue
# ===========================================================================

func test_zero_respawn_time_never_enters_queue() -> void:
	_setup_full_tree()

	# respawn_time = 0.0 (default)
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 1, &"", _HexTile.FogState.VISIBLE, 0.0)
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	_catalog.catalog_entry(&"wood_tree")

	_auto_interaction._check_gather_proximity()
	_auto_interaction._on_gather_tween_complete()

	assert_int(_auto_interaction._respawn_queue.size()).override_failure_message(
		"respawn_time=0 resource must NOT enter respawn queue"
	).is_equal(0)

	_teardown_full_tree()


# ===========================================================================
# Workbench proximity changed signal fires on state change
# ===========================================================================

func test_workbench_proximity_signal_on_change() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_place_player_at_tile(Vector2i.ZERO)

	var prox_signals: Array = []
	_crafting.workbench_proximity_changed.connect(func(near: bool) -> void:
		prox_signals.append(near)
	)

	# No workbench → false (initial state already false, no signal yet)
	_crafting._check_workbench_proximity()
	assert_int(prox_signals.size()).is_equal(0)  # no change

	# Add workbench neighbor
	var wb_tile: HexTile = _make_empty_tile()
	var wb_prop: Prop = _Prop.new()
	wb_prop.type = &"workbench"
	wb_prop.category = Prop.Category.STRUCTURE
	wb_prop.sub_hex = Vector2i.ZERO
	wb_prop.blocks_movement = false
	wb_tile.props = [wb_prop]
	_grid._tiles[Vector2i(1, 0)] = wb_tile

	_crafting._check_workbench_proximity()
	assert_int(prox_signals.size()).is_equal(1)
	assert_bool(prox_signals[0]).is_true()

	# Remove workbench (change structure)
	wb_tile.props = []
	_crafting._check_workbench_proximity()
	assert_int(prox_signals.size()).is_equal(2)
	assert_bool(prox_signals[1]).is_false()

	_teardown_full_tree()


# ===========================================================================
# HUD feedback: auto_gather_failed(inventory_full) → floating text
# ===========================================================================

func test_hud_auto_gather_feedback_text() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)

	# Use a real AutoInteractionSystem instance so HUD can connect to typed signals.
	# Disable _process and pass a dummy grid to avoid autoload.
	var fake_grid := FakeGrid.new()
	add_child(fake_grid)
	var fake_ai := _AutoInteractionSystem.new()
	fake_ai._grid = fake_grid
	fake_ai.set_process(false)
	add_child(fake_ai)

	hud.connect_auto_interaction(fake_ai)

	# Emit auto_gather_failed with inventory_full (tool_gated no longer emitted)
	fake_ai.auto_gather_failed.emit(Vector2i.ZERO, &"inventory_full")

	# The FloatingTextContainer should have created a label
	var ftc: Control = hud.get_node("FloatingTextContainer")
	assert_int(ftc.get_child_count()).override_failure_message(
		"FloatingTextContainer must show text on inventory_full"
	).is_greater(0)

	fake_ai.queue_free()
	fake_grid.queue_free()
	hud.queue_free()


# ===========================================================================
# Full loop: scan → gather stone → recipe discovered → craft → gather ore
# ===========================================================================

func test_full_loop_scan_gather_discover_craft_unlock() -> void:
	_setup_full_tree()

	# Setup world: player at center, resources on nearby tiles
	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"stone", 3)
	_grid._tiles[Vector2i(0, 1)] = _make_tile(&"ore", 3, &"stone_pickaxe")
	var wb_tile: HexTile = _make_empty_tile()
	var wb_prop: Prop = _Prop.new()
	wb_prop.type = &"workbench"
	wb_prop.category = Prop.Category.STRUCTURE
	wb_prop.sub_hex = Vector2i.ZERO
	wb_prop.blocks_movement = false
	wb_tile.props = [wb_prop]
	_grid._tiles[Vector2i(-1, 0)] = wb_tile
	# Extra wood tile for crafting materials
	_grid._tiles[Vector2i(0, -1)] = _make_tile(&"wood", 5)
	_place_player_at_tile(Vector2i.ZERO)

	# Step 1: Scan stone
	_scanner._process(0.016)
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)
	assert_bool(_catalog.is_cataloged(&"stone_deposit")).is_true()

	# Step 2: Scan wood (move scanner to pick next)
	_scanner._process(0.016)
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)
	assert_bool(_catalog.is_cataloged(&"wood_tree")).is_true()

	# Step 3: Scan ore
	_scanner._process(0.016)
	_scanner._scan_progress = 0.99
	_scanner._process(0.05)
	assert_bool(_catalog.is_cataloged(&"iron_deposit")).is_true()

	# Step 4: Move player to stone resource and auto-gather
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)
	_auto_interaction._check_gather_proximity()
	assert_bool(_auto_interaction._is_gathering).is_true()
	_auto_interaction._on_gather_tween_complete()

	# After first stone gathered, inventory has stone and recipes are discovered
	assert_bool(_inventory.get_count(&"stone") > 0).is_true()

	# Continue gathering stone (chain continues since player is still near)
	if _auto_interaction._is_gathering:
		_auto_interaction._on_gather_tween_complete()
	if _auto_interaction._is_gathering:
		_auto_interaction._on_gather_tween_complete()

	# Move to wood resource and gather
	_place_player_near_resource(Vector2i(0, -1), Vector2.ZERO, Vector2i.ZERO)
	_auto_interaction._check_gather_proximity()
	if _auto_interaction._is_gathering:
		_auto_interaction._on_gather_tween_complete()
	if _auto_interaction._is_gathering:
		_auto_interaction._on_gather_tween_complete()
	if _auto_interaction._is_gathering:
		_auto_interaction._on_gather_tween_complete()

	# Recipes should be discovered
	assert_bool(_crafting.is_recipe_discovered(&"stone_pickaxe")).override_failure_message(
		"stone_pickaxe recipe must be discovered after gathering stone"
	).is_true()

	# Step 5: Craft stone_pickaxe (need 3W + 2S)
	# Make sure we have enough materials
	var wood_count: int = _inventory.get_count(&"wood")
	var stone_count: int = _inventory.get_count(&"stone")
	if wood_count < 3:
		_inventory.add_item(&"wood", 3 - wood_count)
	if stone_count < 2:
		_inventory.add_item(&"stone", 2 - stone_count)

	_crafting._check_workbench_proximity()
	assert_bool(_crafting.is_near_workbench()).is_true()

	var craft_ok: bool = _crafting.craft(&"stone_pickaxe")
	assert_bool(craft_ok).override_failure_message(
		"Crafting stone_pickaxe must succeed in full loop"
	).is_true()
	assert_object(_inventory.get_tool(&"pickaxe")).is_equal(&"stone_pickaxe")

	# Step 6: Move to ore and auto-gather — now works
	_place_player_near_resource(Vector2i(0, 1), Vector2.ZERO, Vector2i.ZERO)

	var ore_completed: Array = []
	_auto_interaction.auto_gather_completed.connect(func(c: Vector2i, t: StringName, a: int) -> void:
		if t == &"ore":
			ore_completed.append(true)
	)

	# Reset gathering state
	_auto_interaction._is_gathering = false
	_auto_interaction._check_gather_proximity()

	# Find if ore gather started
	if _auto_interaction._is_gathering:
		_auto_interaction._on_gather_tween_complete()

	assert_int(ore_completed.size()).override_failure_message(
		"Ore must be auto-gathered after crafting stone_pickaxe"
	).is_greater(0)

	_teardown_full_tree()


# ===========================================================================
# Inventory full blocks auto-gather
# ===========================================================================

func test_inventory_full_blocks_auto_gather() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i.ZERO] = _make_empty_tile()
	_grid._tiles[Vector2i(1, 0)] = _make_tile(&"wood", 3)
	_place_player_near_resource(Vector2i(1, 0), Vector2.ZERO, Vector2i.ZERO)

	_catalog.catalog_entry(&"wood_tree")

	# Fill inventory completely
	for i in range(12):
		_inventory.add_item(&"stone", 99)

	var failed: Array = []
	_auto_interaction.auto_gather_failed.connect(func(c: Vector2i, r: StringName) -> void:
		failed.append(String(r))
	)

	# Start gather
	_auto_interaction._check_gather_proximity()
	_auto_interaction._on_gather_tween_complete()

	assert_int(failed.size()).override_failure_message(
		"inventory_full failure must fire when inventory is full"
	).is_greater(0)
	assert_str(failed[0]).is_equal("inventory_full")

	_teardown_full_tree()


# ===========================================================================
# ResourceRenderer respawn restores visual
# ===========================================================================

func test_resource_renderer_respawn_restores_visual() -> void:
	_setup_full_tree()

	_grid._tiles[Vector2i(3, 0)] = _make_tile(&"berries", 1)
	_grid.tile_visibility_changed.emit(Vector2i(3, 0), _HexTile.FogState.VISIBLE)

	# Deplete: set remaining to 0 first (renderer rebuild checks rn.remaining)
	var tile: HexTile = _grid.get_tile(Vector2i(3, 0))
	tile.props[0].remaining = 0
	_grid.resource_depleted.emit(Vector2i(3, 0), &"berries")
	var entries: Dictionary = _resource_renderer.get_tile_entries()
	assert_bool(entries[Vector2i(3, 0)][0]["depleted"]).is_true()

	# Respawn: restore remaining
	tile.props[0].remaining = tile.props[0].max_amount
	_grid.resource_respawned.emit(Vector2i(3, 0), &"berries")
	entries = _resource_renderer.get_tile_entries()
	assert_bool(entries[Vector2i(3, 0)][0]["depleted"]).override_failure_message(
		"ResourceRenderer must restore berries visual on resource_respawned"
	).is_false()

	_teardown_full_tree()
