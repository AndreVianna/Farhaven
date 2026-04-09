class_name TestBuildingSystem
extends GdUnitTestSuite

## Unit tests for BuildingSystem (task-032).

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


class MockPlayer extends Node3D:
	var inventory: _Inventory = null

	func get_inventory():
		return inventory


class FakeRegistry extends Node:
	func get_all_recipes() -> Array:
		return []


# ---------------------------------------------------------------------------
# Prop IDs (matching data/props/*.tres)
# ---------------------------------------------------------------------------

const ID_WOOD: StringName = &"00010"
const ID_ROCK: StringName = &"00011"
const ID_FIBER: StringName = &"00012"
const ID_CAMPFIRE: StringName = &"00101"
const ID_SHELTER: StringName = &"00102"
const ID_TORCH: StringName = &"00103"
const ID_STORAGE_CHEST: StringName = &"00104"
const ID_WORKBENCH: StringName = &"00105"
const ID_WALL: StringName = &"00106"


# ---------------------------------------------------------------------------
# Test state
# ---------------------------------------------------------------------------

var _building: Node
var _grid: MockHexGrid
var _runtime: Node
var _discovery: FakeDiscovery
var _registry: FakeRegistry
var _player: MockPlayer
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
	cap.weight = weight
	def.portable = cap
	PropRegistry._defs[id] = def
	_registered_defs.append(id)


func _ensure_structure_def(id: StringName, blocks_movement: bool = false,
		footprint: Array[Vector2i] = [Vector2i(0, 0)]) -> void:
	var pcap := _PlaceableCap.new()
	pcap.footprint = footprint
	pcap.blocks_movement = blocks_movement
	var tags: Array[StringName] = [&"STRUCTURE"]
	_ensure_prop_def(id, tags, pcap, 1.0)


func _make_build_recipe(id: StringName, inputs_spec: Array,
		output_ref: StringName, time: float = 0.0) -> _Recipe:
	var r := _Recipe.new()
	r.id = id
	r.kind = _Recipe.Kind.ASSEMBLE
	r.time = time
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
	# Add at_tile_type: buildable condition.
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
	_ensure_structure_def(ID_CAMPFIRE, false)
	_ensure_structure_def(ID_SHELTER, false, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)])
	_ensure_structure_def(ID_TORCH, false)
	_ensure_structure_def(ID_STORAGE_CHEST, false)
	_ensure_structure_def(ID_WORKBENCH, false, [Vector2i(0, 0), Vector2i(1, 0)])
	_ensure_structure_def(ID_WALL, true)

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

	# Create player.
	_player = MockPlayer.new()
	_player.inventory = _Inventory.new()
	add_child(_player)

	# Create building system as child of player.
	_building = _BuildingSystem.new()
	_building._grid = _grid
	_building._runtime = _runtime
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
	# Clean up registered prop defs.
	for id: StringName in _registered_defs:
		PropRegistry._defs.erase(id)


var _mock_random_value: float = 0.0

func _mock_randf() -> float:
	return _mock_random_value


# ---------------------------------------------------------------------------
# Tests: Placement mode
# ---------------------------------------------------------------------------


func test_enter_placement_mode_sets_recipe() -> void:
	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	assert_bool(_building.is_placing()).is_true()
	assert_that(_building.get_selected_recipe()).is_same(recipe)


func test_exit_placement_mode_clears_recipe() -> void:
	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	_building.exit_placement_mode()
	assert_bool(_building.is_placing()).is_false()
	assert_that(_building.get_selected_recipe()).is_null()


func test_placement_mode_entered_signal() -> void:
	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	var monitor := monitor_signals(_building)
	_building.enter_placement_mode(recipe)
	verify(monitor, 1).emit_signal("placement_mode_entered", &"00024")


func test_placement_mode_exited_signal() -> void:
	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_building.enter_placement_mode(recipe)
	var monitor := monitor_signals(_building)
	_building.exit_placement_mode()
	verify(monitor, 1).emit_signal("placement_mode_exited")


# ---------------------------------------------------------------------------
# Tests: Validation — no recipe selected
# ---------------------------------------------------------------------------


func test_try_place_without_recipe_fails() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	var monitor := monitor_signals(_building)
	var result: bool = _building.try_place_at(Vector2i.ZERO)
	assert_bool(result).is_false()
	verify(monitor, 1).emit_signal("structure_build_failed", &"no_recipe_selected")


# ---------------------------------------------------------------------------
# Tests: Validation — invalid tile
# ---------------------------------------------------------------------------


func test_try_place_at_missing_tile_fails() -> void:
	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	var monitor := monitor_signals(_building)
	var result: bool = _building.try_place_at(Vector2i(99, 99))
	assert_bool(result).is_false()
	verify(monitor, 1).emit_signal("structure_build_failed", &"invalid_tile")


# ---------------------------------------------------------------------------
# Tests: Validation — water tile
# ---------------------------------------------------------------------------


func test_try_place_on_water_fails() -> void:
	var tile := _make_water_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	var monitor := monitor_signals(_building)
	var result: bool = _building.try_place_at(Vector2i.ZERO)
	assert_bool(result).is_false()
	verify(monitor, 1).emit_signal("structure_build_failed", &"water_tile")


# ---------------------------------------------------------------------------
# Tests: Validation — footprint overlap
# ---------------------------------------------------------------------------


func test_try_place_with_footprint_overlap_fails() -> void:
	var tile := _make_grassland_tile()
	# Add an existing prop at sub-hex (0, 0).
	var existing := _Prop.create_structure(ID_CAMPFIRE, false, Vector2i.ZERO, [Vector2i.ZERO])
	tile.props.append(existing)
	_grid.set_tile(Vector2i.ZERO, tile)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	var monitor := monitor_signals(_building)
	var result: bool = _building.try_place_at(Vector2i.ZERO, Vector2i.ZERO)
	assert_bool(result).is_false()
	verify(monitor, 1).emit_signal("structure_build_failed", &"footprint_overlap")


func test_try_place_non_overlapping_sub_hex_succeeds() -> void:
	var tile := _make_grassland_tile()
	# Existing prop at sub-hex (0, 0).
	var existing := _Prop.create_structure(ID_CAMPFIRE, false, Vector2i.ZERO, [Vector2i.ZERO])
	tile.props.append(existing)
	_grid.set_tile(Vector2i.ZERO, tile)

	# Give player enough wood.
	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	# Place at sub-hex (1, 0) — no overlap.
	var result: bool = _building.try_place_at(Vector2i.ZERO, Vector2i(1, 0))
	assert_bool(result).is_true()


# ---------------------------------------------------------------------------
# Tests: Validation — insufficient materials
# ---------------------------------------------------------------------------


func test_try_place_insufficient_materials_fails() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	# Give player only 1 wood (need 3).
	_player.inventory.add_item(ID_WOOD, 1)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	var monitor := monitor_signals(_building)
	var result: bool = _building.try_place_at(Vector2i.ZERO)
	assert_bool(result).is_false()
	verify(monitor, 1).emit_signal("structure_build_failed", &"recipe_failed")


# ---------------------------------------------------------------------------
# Tests: Successful instant build
# ---------------------------------------------------------------------------


func test_successful_wall_build_places_structure_on_tile() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	# Give player enough wood.
	_player.inventory.add_item(ID_WOOD, 5)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	var result: bool = _building.try_place_at(Vector2i.ZERO)
	assert_bool(result).is_true()

	# Materials consumed.
	assert_int(_player.inventory.get_count(ID_WOOD)).is_equal(2)

	# Structure placed on tile.
	var structures: Array = []
	for prop in tile.props:
		if prop.type == ID_WALL:
			structures.append(prop)
	assert_int(structures.size()).is_equal(1)
	assert_bool(structures[0].blocks_movement).is_true()


func test_successful_build_emits_structure_placed() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	var monitor := monitor_signals(_grid)
	_building.try_place_at(Vector2i.ZERO)
	verify(monitor, 1).emit_signal("structure_placed", Vector2i.ZERO, ID_WALL)


func test_wall_has_blocks_movement_true() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	# Wall should block movement.
	var wall_prop = tile.props[0]
	assert_bool(wall_prop.blocks_movement).is_true()


func test_campfire_does_not_block_movement() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)
	_player.inventory.add_item(ID_FIBER, 2)

	var recipe := _make_build_recipe(&"00019",
		[{"ref": ID_WOOD, "count": 3}, {"ref": ID_FIBER, "count": 2}],
		ID_CAMPFIRE)
	_discovery.set_known(&"00019")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	var campfire_prop = tile.props[0]
	assert_bool(campfire_prop.blocks_movement).is_false()


# ---------------------------------------------------------------------------
# Tests: Storage Chest effect
# ---------------------------------------------------------------------------


func test_storage_chest_increases_inventory_capacity() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 8)
	_player.inventory.add_item(ID_ROCK, 4)

	var initial_capacity: float = _player.inventory.capacity_weight

	var recipe := _make_build_recipe(&"00022",
		[{"ref": ID_WOOD, "count": 8}, {"ref": ID_ROCK, "count": 4}],
		ID_STORAGE_CHEST)
	_discovery.set_known(&"00022")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	# Capacity should increase by 50.
	assert_float(_player.inventory.capacity_weight).is_equal(initial_capacity + 50.0)


func test_non_storage_chest_does_not_change_capacity() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var initial_capacity: float = _player.inventory.capacity_weight

	var recipe := _make_build_recipe(&"00024",
		[{"ref": ID_WOOD, "count": 3}],
		ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	# Capacity should remain unchanged.
	assert_float(_player.inventory.capacity_weight).is_equal(initial_capacity)


# ---------------------------------------------------------------------------
# Tests: Structure not in inventory after build
# ---------------------------------------------------------------------------


func test_structure_not_in_inventory_after_build() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	# Structure should NOT be in inventory.
	assert_int(_player.inventory.get_count(ID_WALL)).is_equal(0)


# ---------------------------------------------------------------------------
# Tests: Exits placement mode after build
# ---------------------------------------------------------------------------


func test_exits_placement_mode_after_successful_build() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	assert_bool(_building.is_placing()).is_false()


func test_exits_placement_mode_after_failed_build() -> void:
	# No materials.
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	assert_bool(_building.is_placing()).is_false()


# ---------------------------------------------------------------------------
# Tests: Timed build
# ---------------------------------------------------------------------------


func test_timed_build_places_structure_after_time() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024",
		[{"ref": ID_WOOD, "count": 3}], ID_WALL, 2.0)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)

	var result: bool = _building.try_place_at(Vector2i.ZERO)
	assert_bool(result).is_true()

	# Materials consumed immediately.
	assert_int(_player.inventory.get_count(ID_WOOD)).is_equal(0)

	# Structure NOT yet placed (recipe still pending).
	var wall_count := 0
	for prop in tile.props:
		if prop.type == ID_WALL:
			wall_count += 1
	assert_int(wall_count).is_equal(0)

	# Simulate time passing.
	_runtime._process(2.5)

	# Structure should now be placed.
	wall_count = 0
	for prop in tile.props:
		if prop.type == ID_WALL:
			wall_count += 1
	assert_int(wall_count).is_equal(1)


# ---------------------------------------------------------------------------
# Tests: Multi-hex footprint
# ---------------------------------------------------------------------------


func test_workbench_footprint_placed_correctly() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 5)
	_player.inventory.add_item(ID_ROCK, 3)

	var recipe := _make_build_recipe(&"00021",
		[{"ref": ID_WOOD, "count": 5}, {"ref": ID_ROCK, "count": 3}],
		ID_WORKBENCH)
	_discovery.set_known(&"00021")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	# Workbench placed with correct 2-cell footprint.
	var wb_props: Array = []
	for prop in tile.props:
		if prop.type == ID_WORKBENCH:
			wb_props.append(prop)
	assert_int(wb_props.size()).is_equal(1)
	assert_int(wb_props[0].footprint.size()).is_equal(2)


# ---------------------------------------------------------------------------
# Tests: Sub-hex position
# ---------------------------------------------------------------------------


func test_structure_placed_at_specified_sub_hex() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO, Vector2i(2, 1))

	var wall_prop = tile.props[0]
	assert_object(wall_prop.sub_hex).is_equal(Vector2i(2, 1))


# ---------------------------------------------------------------------------
# Tests: Only wall blocks movement
# ---------------------------------------------------------------------------


func test_shelter_does_not_block_movement() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 10)
	_player.inventory.add_item(ID_ROCK, 5)
	_player.inventory.add_item(ID_FIBER, 3)

	var recipe := _make_build_recipe(&"00023",
		[{"ref": ID_WOOD, "count": 10}, {"ref": ID_ROCK, "count": 5}, {"ref": ID_FIBER, "count": 3}],
		ID_SHELTER)
	_discovery.set_known(&"00023")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	var shelter_prop = tile.props[0]
	assert_bool(shelter_prop.blocks_movement).is_false()


func test_torch_does_not_block_movement() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 2)
	_player.inventory.add_item(ID_FIBER, 1)

	var recipe := _make_build_recipe(&"00025",
		[{"ref": ID_WOOD, "count": 2}, {"ref": ID_FIBER, "count": 1}],
		ID_TORCH)
	_discovery.set_known(&"00025")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	var torch_prop = tile.props[0]
	assert_bool(torch_prop.blocks_movement).is_false()


# ---------------------------------------------------------------------------
# Tests: Structure has CRAFTED origin
# ---------------------------------------------------------------------------


func test_placed_structure_has_crafted_origin() -> void:
	var tile := _make_grassland_tile()
	_grid.set_tile(Vector2i.ZERO, tile)

	_player.inventory.add_item(ID_WOOD, 3)

	var recipe := _make_build_recipe(&"00024", [{"ref": ID_WOOD, "count": 3}], ID_WALL)
	_discovery.set_known(&"00024")
	_building.enter_placement_mode(recipe)
	_building.try_place_at(Vector2i.ZERO)

	var wall_prop = tile.props[0]
	assert_int(wall_prop.origin).is_equal(_Prop.Origin.CRAFTED)
