class_name TestBuildingPlacement
extends GdUnitTestSuite

## Unit tests for BuildingSystem placement mode, input handling, and highlights
## (task-033).

const _BuildingSystem = preload("res://scripts/building/building_system.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _RecipeRuntime = preload("res://scripts/recipes/recipe_runtime.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")
const _PortableCap = preload("res://scripts/data/capabilities/portable_cap.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")


# ---------------------------------------------------------------------------
# Minimal fakes
# ---------------------------------------------------------------------------


class FakeDiscovery extends Node:
	var _known: Dictionary = {}

	func is_known(recipe_id: StringName) -> bool:
		return _known.get(recipe_id, false)

	func grant_recipe(recipe_id: StringName) -> void:
		_known[recipe_id] = true

	func set_known(recipe_id: StringName) -> void:
		_known[recipe_id] = true


class MockHexGrid extends Node:
	signal tile_entered(coords: Vector2i)
	signal tile_exited(coords: Vector2i)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)
	signal map_generated()

	var _tiles: Dictionary = {}

	func set_tile(coords: Vector2i, tile: Resource) -> void:
		_tiles[coords] = tile

	func get_tile(coords: Vector2i) -> Resource:
		return _tiles.get(coords, null)

	func get_all_tiles() -> Dictionary:
		return _tiles

	func has_tile(coords: Vector2i) -> bool:
		return _tiles.has(coords)

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		var dirs: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
		]
		var result: Array[Vector2i] = []
		for d: Vector2i in dirs:
			var n: Vector2i = coords + d
			if _tiles.has(n):
				result.append(n)
		return result

	func get_traversal(from: Vector2i, to: Vector2i) -> int:
		var tile_to: Resource = _tiles.get(to, null)
		if tile_to == null:
			return 3  # BLOCKED
		if tile_to.biome == _HexTile.Biome.WATER:
			return 3  # BLOCKED
		# Check if any structure prop has a collision shape (via STRUCTURE tag on wall type)
		for prop in tile_to.props:
			if PropRegistry.has_def(prop.type):
				var def = PropRegistry.get_def(prop.type)
				if def.has_tag(&"BLOCKS_MOVEMENT"):
					return 3  # BLOCKED
		return 0  # WALK

	func world_to_axial(_world_pos: Vector2) -> Vector2i:
		return Vector2i.ZERO

	func distance(a: Vector2i, b: Vector2i) -> int:
		var ca: Vector3i = _axial_to_cube(a)
		var cb: Vector3i = _axial_to_cube(b)
		return (abs(ca.x - cb.x) + abs(ca.y - cb.y) + abs(ca.z - cb.z)) / 2

	func _axial_to_cube(coords: Vector2i) -> Vector3i:
		return Vector3i(coords.x, -coords.x - coords.y, coords.y)


class MockPlayer extends Node3D:
	var inventory: _Inventory = null
	var current_tile: Vector2i = Vector2i.ZERO

	func get_inventory():
		return inventory


class MockRenderer extends Node:
	var highlighted_coords: Array[Vector2i] = []
	var highlight_color: Color = Color.TRANSPARENT
	var highlights_cleared: bool = false

	func highlight_tiles(coords: Array[Vector2i], color: Color) -> void:
		highlighted_coords = coords
		highlight_color = color
		highlights_cleared = false

	func clear_highlights() -> void:
		highlighted_coords = []
		highlight_color = Color.TRANSPARENT
		highlights_cleared = true


class MockHUD extends Node:
	var placement_label_visible: bool = false
	var placement_label_type: StringName = &""

	func show_placement_label(structure_type: StringName) -> void:
		placement_label_visible = true
		placement_label_type = structure_type

	func hide_placement_label() -> void:
		placement_label_visible = false
		placement_label_type = &""


class FakeRegistry extends Node:
	func get_all_recipes() -> Array:
		return []


# ---------------------------------------------------------------------------
# Prop IDs (matching data/props/*.tres)
# ---------------------------------------------------------------------------

const ID_WOOD: StringName = &"P00010"
const ID_ROCK: StringName = &"P00011"
const ID_FIBER: StringName = &"P00012"
const ID_CAMPFIRE: StringName = &"P00101"
const ID_WALL: StringName = &"P00106"
const ID_WORKBENCH: StringName = &"P00105"


# ---------------------------------------------------------------------------
# Test state
# ---------------------------------------------------------------------------

var _building: Node
var _grid: MockHexGrid
var _runtime: Node
var _discovery: FakeDiscovery
var _registry: FakeRegistry
var _player: MockPlayer
var _renderer: MockRenderer
var _hud: MockHUD
var _registered_defs: Array[StringName] = []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _ensure_prop_def(id: StringName, tags: Array[StringName] = [],
		placeable: _PlaceableCap = null, weight: float = 0.1) -> void:
	if PropRegistry.get_def(id) != null:
		return
	var def := _PropDef.new()
	def.id = id
	def.display_name = String(id)
	def.tags = tags
	def.placeable = placeable
	def.max_stack = 99
	var cap := _PortableCap.new()
	cap.size = weight
	def.portable = cap
	PropRegistry._defs[id] = def
	_registered_defs.append(id)


func _ensure_structure_def(id: StringName) -> void:
	var pcap := _PlaceableCap.new()
	var tags: Array[StringName] = [&"STRUCTURE"]
	_ensure_prop_def(id, tags, pcap, 1.0)


func _make_build_recipe(id: StringName, inputs_spec: Array,
		output_ref: StringName, time: float = 0.0) -> _Recipe:
	var r := _Recipe.new()
	r.id = id
	r.kind = _Recipe.Kind.ASSEMBLE
	r.duration = time
	r.actions = [&"build"]
	for spec: Dictionary in inputs_spec:
		var inp := _RecipeInput.new()
		inp.ref_or_tag = spec["ref"]
		inp.count = spec["count"]
		inp.source = &"player_inventory"
		r.inputs.append(inp)
	var out := _RecipeOutput.new()
	out.prop_ref = output_ref
	out.count = 1
	out.prob = 1.0
	r.outputs.append(out)
	var cond := _RecipeCondition.new()
	var pred := _Predicate.new()
	pred.kind = &"at_tile_type"
	pred.params = {"tag": "buildable"}
	cond.predicate = pred
	cond.must_sustain = false
	r.conditions.append(cond)
	return r


func _make_grassland_tile(coords: Vector2i = Vector2i.ZERO) -> Resource:
	var tile := _HexTile.new()
	tile.coords = coords
	tile.biome = _HexTile.Biome.GRASSLAND
	tile.elevation = 0
	return tile


func _make_water_tile(coords: Vector2i = Vector2i.ZERO) -> Resource:
	var tile := _HexTile.new()
	tile.coords = coords
	tile.biome = _HexTile.Biome.WATER
	tile.elevation = 0
	return tile


## Set up the standard test grid: player at (0,0) with 6 grassland neighbors.
func _setup_standard_grid() -> void:
	_grid.set_tile(Vector2i.ZERO, _make_grassland_tile(Vector2i.ZERO))
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	for d: Vector2i in dirs:
		_grid.set_tile(d, _make_grassland_tile(d))


# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------


func before_test() -> void:
	_registered_defs.clear()

	# Ensure item defs exist for materials.
	_ensure_prop_def(ID_WOOD)
	_ensure_prop_def(ID_ROCK)
	_ensure_prop_def(ID_FIBER)

	# Ensure structure defs exist.
	_ensure_structure_def(ID_CAMPFIRE)
	_ensure_structure_def(ID_WALL)
	_ensure_structure_def(ID_WORKBENCH)

	# Create grid.
	_grid = MockHexGrid.new()
	add_child(_grid)

	# Create discovery.
	_discovery = FakeDiscovery.new()
	add_child(_discovery)

	# Create registry.
	_registry = FakeRegistry.new()
	add_child(_registry)

	# Create runtime.
	_runtime = _RecipeRuntime.new()
	_runtime._registry = _registry
	_runtime._discovery = _discovery
	_runtime._rng = Callable(self, "_mock_randf")
	add_child(_runtime)

	# Create renderer mock.
	_renderer = MockRenderer.new()
	add_child(_renderer)

	# Create HUD mock.
	_hud = MockHUD.new()
	add_child(_hud)

	# Create player.
	_player = MockPlayer.new()
	_player.inventory = _Inventory.new()
	_player.current_tile = Vector2i.ZERO
	add_child(_player)

	# Create building system as child of player.
	_building = _BuildingSystem.new()
	_building._grid = _grid
	_building._runtime = _runtime
	_building._renderer = _renderer
	_building._hud = _hud
	_player.add_child(_building)


func after_test() -> void:
	if is_instance_valid(_building):
		_player.remove_child(_building)
		_building.queue_free()
	if is_instance_valid(_player):
		remove_child(_player)
		_player.queue_free()
	if is_instance_valid(_runtime):
		remove_child(_runtime)
		_runtime.queue_free()
	if is_instance_valid(_discovery):
		remove_child(_discovery)
		_discovery.queue_free()
	if is_instance_valid(_registry):
		remove_child(_registry)
		_registry.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	if is_instance_valid(_renderer):
		remove_child(_renderer)
		_renderer.queue_free()
	if is_instance_valid(_hud):
		remove_child(_hud)
		_hud.queue_free()
	for id: StringName in _registered_defs:
		PropRegistry._defs.erase(id)


var _mock_random_value: float = 0.0

func _mock_randf() -> float:
	return _mock_random_value


# ---------------------------------------------------------------------------
# Tests: Highlights shown on enter_placement_mode
# ---------------------------------------------------------------------------


func test_highlights_shown_on_enter() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_a", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	assert_bool(_renderer.highlighted_coords.size() > 0).is_true()
	assert_object(_renderer.highlight_color).is_equal(Color.CYAN)


func test_highlights_include_all_passable_neighbors() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_b", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	# All 6 neighbors are grassland, passable — all should be highlighted.
	assert_int(_renderer.highlighted_coords.size()).is_equal(6)


func test_highlights_exclude_water_tiles() -> void:
	_grid.set_tile(Vector2i.ZERO, _make_grassland_tile(Vector2i.ZERO))
	# 5 grassland + 1 water neighbor.
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	for i: int in range(5):
		_grid.set_tile(dirs[i], _make_grassland_tile(dirs[i]))
	_grid.set_tile(dirs[5], _make_water_tile(dirs[5]))

	var recipe := _make_build_recipe(&"t033_c", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	assert_int(_renderer.highlighted_coords.size()).is_equal(5)
	assert_bool(_renderer.highlighted_coords.has(dirs[5])).is_false()


func test_highlights_exclude_blocked_tiles() -> void:
	_grid.set_tile(Vector2i.ZERO, _make_grassland_tile(Vector2i.ZERO))
	# Neighbor with a wall (blocks movement).
	var blocked_coord := Vector2i(1, 0)
	var blocked_tile := _make_grassland_tile(blocked_coord)
	var wall_prop := _Prop.create_structure(ID_WALL, Vector2i.ZERO)
	blocked_tile.props.append(wall_prop)
	_grid.set_tile(blocked_coord, blocked_tile)
	# Other neighbors.
	_grid.set_tile(Vector2i(1, -1), _make_grassland_tile(Vector2i(1, -1)))
	_grid.set_tile(Vector2i(0, -1), _make_grassland_tile(Vector2i(0, -1)))
	_grid.set_tile(Vector2i(-1, 0), _make_grassland_tile(Vector2i(-1, 0)))
	_grid.set_tile(Vector2i(-1, 1), _make_grassland_tile(Vector2i(-1, 1)))
	_grid.set_tile(Vector2i(0, 1), _make_grassland_tile(Vector2i(0, 1)))

	var recipe := _make_build_recipe(&"t033_d", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	assert_int(_renderer.highlighted_coords.size()).is_equal(5)
	assert_bool(_renderer.highlighted_coords.has(blocked_coord)).is_false()


# ---------------------------------------------------------------------------
# Tests: Highlights cleared on exit_placement_mode
# ---------------------------------------------------------------------------


func test_highlights_cleared_on_exit() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_e", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	assert_bool(_renderer.highlights_cleared).is_false()
	_building.exit_placement_mode()
	assert_bool(_renderer.highlights_cleared).is_true()


func test_highlights_cleared_after_successful_build() -> void:
	_setup_standard_grid()
	_player.inventory.add_item(ID_WOOD, 3)
	_discovery.set_known(&"t033_f")

	var recipe := _make_build_recipe(&"t033_f", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i(1, 0))
	# try_place_at calls exit_placement_mode internally.
	assert_bool(_renderer.highlights_cleared).is_true()


# ---------------------------------------------------------------------------
# Tests: Highlights recalculate on tile_entered
# ---------------------------------------------------------------------------


func test_highlights_recalculate_on_tile_entered() -> void:
	_setup_standard_grid()
	# Also add tiles around (1, 0) so moving there has neighbors.
	_grid.set_tile(Vector2i(2, 0), _make_grassland_tile(Vector2i(2, 0)))
	_grid.set_tile(Vector2i(2, -1), _make_grassland_tile(Vector2i(2, -1)))

	var recipe := _make_build_recipe(&"t033_g", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	var initial_highlights: Array[Vector2i] = _renderer.highlighted_coords.duplicate()

	# Simulate player moving to (1, 0).
	_player.current_tile = Vector2i(1, 0)
	_grid.tile_entered.emit(Vector2i(1, 0))

	# Highlights should have been recalculated (different set of neighbors).
	var new_highlights: Array[Vector2i] = _renderer.highlighted_coords.duplicate()
	# New highlights include (2, 0) and (2, -1) which weren't neighbors of (0, 0).
	assert_bool(new_highlights.has(Vector2i(2, 0))).is_true()
	assert_bool(new_highlights.has(Vector2i(2, -1))).is_true()


func test_tile_entered_ignored_when_not_placing() -> void:
	_setup_standard_grid()
	# Not in placement mode — tile_entered should not trigger highlights.
	_grid.tile_entered.emit(Vector2i(1, 0))
	assert_int(_renderer.highlighted_coords.size()).is_equal(0)
	assert_bool(_renderer.highlights_cleared).is_false()


# ---------------------------------------------------------------------------
# Tests: Placement label via HUD
# ---------------------------------------------------------------------------


func test_placement_label_shown_on_enter() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_h", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	assert_bool(_hud.placement_label_visible).is_true()
	assert_str(_hud.placement_label_type).is_equal(String(ID_WALL))


func test_placement_label_hidden_on_exit() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_i", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	_building.exit_placement_mode()
	assert_bool(_hud.placement_label_visible).is_false()


func test_placement_label_hidden_after_build() -> void:
	_setup_standard_grid()
	_player.inventory.add_item(ID_WOOD, 3)
	_discovery.set_known(&"t033_j")

	var recipe := _make_build_recipe(&"t033_j", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i(1, 0))
	assert_bool(_hud.placement_label_visible).is_false()


# ---------------------------------------------------------------------------
# Tests: Signals emitted correctly
# ---------------------------------------------------------------------------


func test_placement_mode_entered_signal_emitted() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_k", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	var monitor := monitor_signals(_building)
	_building.enter_placement_mode(recipe)
	verify(monitor, 1).emit_signal("placement_mode_entered", &"t033_k")


func test_placement_mode_exited_signal_emitted() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_l", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	var monitor := monitor_signals(_building)
	_building.exit_placement_mode()
	verify(monitor, 1).emit_signal("placement_mode_exited")


func test_placement_mode_exited_on_cancel_via_invalid_tile() -> void:
	_setup_standard_grid()
	_discovery.set_known(&"t033_m")
	var recipe := _make_build_recipe(&"t033_m", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)

	var monitor := monitor_signals(_building)
	# try_place_at a nonexistent tile triggers exit.
	_building.try_place_at(Vector2i(99, 99))
	verify(monitor, 1).emit_signal("placement_mode_exited")


# ---------------------------------------------------------------------------
# Tests: get_valid_placement_tiles
# ---------------------------------------------------------------------------


func test_valid_tiles_all_neighbors() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_n", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	var valid: Array[Vector2i] = _building.get_valid_placement_tiles()
	assert_int(valid.size()).is_equal(6)


func test_valid_tiles_excludes_missing() -> void:
	# Only player tile + 2 neighbors.
	_grid.set_tile(Vector2i.ZERO, _make_grassland_tile(Vector2i.ZERO))
	_grid.set_tile(Vector2i(1, 0), _make_grassland_tile(Vector2i(1, 0)))
	_grid.set_tile(Vector2i(-1, 0), _make_grassland_tile(Vector2i(-1, 0)))

	var recipe := _make_build_recipe(&"t033_o", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	var valid: Array[Vector2i] = _building.get_valid_placement_tiles()
	assert_int(valid.size()).is_equal(2)


func test_valid_tiles_excludes_water() -> void:
	_grid.set_tile(Vector2i.ZERO, _make_grassland_tile(Vector2i.ZERO))
	_grid.set_tile(Vector2i(1, 0), _make_water_tile(Vector2i(1, 0)))
	_grid.set_tile(Vector2i(-1, 0), _make_grassland_tile(Vector2i(-1, 0)))

	var recipe := _make_build_recipe(&"t033_p", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	var valid: Array[Vector2i] = _building.get_valid_placement_tiles()
	assert_int(valid.size()).is_equal(1)
	assert_bool(valid.has(Vector2i(-1, 0))).is_true()


# ---------------------------------------------------------------------------
# Tests: Tap on highlighted tile places structure
# ---------------------------------------------------------------------------


func test_tap_valid_tile_places_structure() -> void:
	_setup_standard_grid()
	_player.inventory.add_item(ID_WOOD, 3)
	_discovery.set_known(&"t033_q")

	var recipe := _make_build_recipe(&"t033_q", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)

	var target := Vector2i(1, 0)
	var result: bool = _building.try_place_at(target)
	assert_bool(result).is_true()

	# Structure should be on the tile.
	var tile: Resource = _grid.get_tile(target)
	var found: bool = false
	for prop in tile.props:
		if prop.type == ID_WALL:
			found = true
			break
	assert_bool(found).is_true()

	# Placement mode exited.
	assert_bool(_building.is_placing()).is_false()


# ---------------------------------------------------------------------------
# Tests: Tap non-valid tile cancels (no materials consumed)
# ---------------------------------------------------------------------------


func test_tap_nonvalid_cancels_no_materials() -> void:
	_setup_standard_grid()
	_player.inventory.add_item(ID_WOOD, 3)
	_discovery.set_known(&"t033_r")

	var recipe := _make_build_recipe(&"t033_r", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)

	# Tap on a tile that doesn't exist (non-valid).
	_building.try_place_at(Vector2i(99, 99))

	# Materials NOT consumed.
	assert_int(_player.inventory.get_count(ID_WOOD)).is_equal(3)
	# Placement mode exited.
	assert_bool(_building.is_placing()).is_false()


# ---------------------------------------------------------------------------
# Tests: process_priority is lowest
# ---------------------------------------------------------------------------


func test_process_priority_is_negative() -> void:
	# BuildingSystem should have a very low process_priority to claim input first.
	assert_int(_building.process_priority).is_less(-1)


# ---------------------------------------------------------------------------
# Tests: is_placing state
# ---------------------------------------------------------------------------


func test_is_placing_false_initially() -> void:
	assert_bool(_building.is_placing()).is_false()


func test_is_placing_true_during_placement() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_s", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	assert_bool(_building.is_placing()).is_true()


func test_is_placing_false_after_exit() -> void:
	_setup_standard_grid()
	var recipe := _make_build_recipe(&"t033_t", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	_building.exit_placement_mode()
	assert_bool(_building.is_placing()).is_false()


# ---------------------------------------------------------------------------
# Tests: tile_entered signal connection
# ---------------------------------------------------------------------------


func test_tile_entered_connected_to_grid() -> void:
	# The grid's tile_entered signal should be connected by _ready / manual setup.
	assert_bool(_grid.is_connected("tile_entered", _building._on_tile_entered)).is_true()


# ---------------------------------------------------------------------------
# Tests: No highlight update when not placing
# ---------------------------------------------------------------------------


func test_no_highlight_when_not_placing() -> void:
	_setup_standard_grid()
	# Manually call _update_highlights when not placing — should do nothing.
	_building._update_highlights()
	assert_int(_renderer.highlighted_coords.size()).is_equal(0)
