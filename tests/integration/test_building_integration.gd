extends GdUnitTestSuite
class_name TestBuildingIntegration

## Integration tests for delivery-005b: Building cross-feature effects.
## Verifies that placing structures triggers the correct downstream effects
## across Inventory, LightingManager, CraftingSystem, HexGrid traversal,
## and the StructureRenderer.
##
## Covers all task-036 criteria:
##   - Storage Chest → inventory capacity_weight +50.0
##   - Shelter → STATION(respawn) prop query
##   - Torch → LightingManager registers light at night
##   - Workbench → CraftingSystem station proximity
##   - Wall → blocks_movement = true (only blocking structure)
##   - Walkable structures → blocks_movement = false
##   - Footprint overlap rejection
##   - Placement cancel → no material loss
##   - Materials consumed by RecipeRuntime
##   - Recipe-driven end-to-end build flow
##
## Manual-only verification (not automatable — documented here):
##   - Structure placeholder meshes render at correct tile positions
##   - Build panel shows 6 entries with correct ingredient costs
##   - Highlight tiles turn cyan during placement mode
##   - Panel mutual exclusion animation

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _BuildingSystem = preload("res://scripts/building/building_system.gd")
const _CraftingSystem = preload("res://scripts/crafting/crafting_system.gd")
const _LightingManager = preload("res://scripts/lighting/lighting_manager.gd")
const _StructureRenderer = preload("res://scripts/building/structure_renderer.gd")
const _RecipeRuntime = preload("res://scripts/recipes/recipe_runtime.gd")
const _DiscoveryWatcher = preload("res://scripts/recipes/discovery_watcher.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _DayNightCycle = preload("res://scripts/day_night/day_night_cycle.gd")

# Prop IDs (structures)
const ID_CAMPFIRE: StringName = &"P00101"
const ID_SHELTER: StringName = &"P00102"
const ID_TORCH: StringName = &"P00103"
const ID_STORAGE_CHEST: StringName = &"P00104"
const ID_WORKBENCH: StringName = &"P00105"
const ID_WALL: StringName = &"P00106"

# Item IDs (materials)
const ID_WOOD: StringName = &"P00010"
const ID_ROCK: StringName = &"P00011"
const ID_FIBER: StringName = &"P00012"

# Recipe IDs (build recipes)
const RID_CAMPFIRE: StringName = &"P00019"
const RID_WORKBENCH: StringName = &"P00021"
const RID_STORAGE_CHEST: StringName = &"P00022"
const RID_SHELTER: StringName = &"P00023"
const RID_WALL: StringName = &"P00024"
const RID_TORCH: StringName = &"P00025"

# Tile coordinates
const PLAYER_TILE: Vector2i = Vector2i(0, 0)
const ADJACENT_TILE: Vector2i = Vector2i(1, 0)
const ADJACENT_TILE_2: Vector2i = Vector2i(0, 1)


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

	func get_terrain_y(_wx: float, _wz: float) -> float:
		return 0.0

	func has_structure(coords: Vector2i, type: StringName) -> bool:
		var tile = _tiles.get(coords, null)
		if tile == null:
			return false
		for prop in tile.props:
			if prop.type == type:
				return true
		return false

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

	func get_traversal(from: Vector2i, to: Vector2i) -> int:
		var tile_to = _tiles.get(to, null)
		if tile_to == null:
			return 3  # BLOCKED
		if tile_to.biome == _HexTile.Biome.WATER:
			return 3  # BLOCKED
		# Collision shapes handle blocking; check Wall type via PropDef tag.
		for prop in tile_to.props:
			if PropRegistry.has_def(prop.type):
				var def = PropRegistry.get_def(prop.type)
				if def.has_tag(&"BLOCKS_MOVEMENT"):
					return 3  # BLOCKED
		var tile_from = _tiles.get(from, null)
		if tile_from == null:
			return 3
		var diff: int = abs(int(tile_to.elevation) - int(tile_from.elevation))
		if diff <= 2:
			return 0  # WALK
		if diff <= 4:
			if int(tile_to.elevation) > int(tile_from.elevation):
				return 1  # JUMP
			return 2  # DROP
		return 3  # BLOCKED

	func axial_to_world(coords: Vector2i) -> Vector2:
		var q: float = float(coords.x)
		var r: float = float(coords.y)
		var x: float = 3.0 * (3.0 / 2.0 * q)
		var y: float = 3.0 * (sqrt(3.0) / 2.0 * q + sqrt(3.0) * r)
		return Vector2(x, y)

	func world_to_axial(_world_pos: Vector2) -> Vector2i:
		return Vector2i.ZERO


class FakeDayNightCycle extends Node:
	signal phase_changed(old_phase: int, new_phase: int)
	signal dawn()
	signal dusk()
	signal night()
	signal day_started()
	var current_phase: int = 0  # DAY
	var day_count: int = 1
	var phase_elapsed: float = 0.0
	var is_daytime: bool = true

	func set_night() -> void:
		current_phase = 2  # NIGHT
		is_daytime = false

	func set_day() -> void:
		current_phase = 0  # DAY
		is_daytime = true

	func set_dusk() -> void:
		current_phase = 1  # DUSK
		is_daytime = false


class FakeRecipeRegistry extends Node:
	var _recipes: Dictionary = {}

	func get_all_recipes() -> Array:
		return _recipes.values()

	func get_recipe(recipe_id: StringName) -> _Recipe:
		return _recipes.get(recipe_id, null)

	func has_recipe(recipe_id: StringName) -> bool:
		return _recipes.has(recipe_id)


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO
	var inventory: RefCounted = null

	func get_inventory():
		return inventory


# --- State ---

var _grid: FakeGrid
var _player: FakePlayer
var _inventory: RefCounted
var _building: Node
var _runtime: Node
var _discovery: Node
var _crafting: Node
var _lighting: Node
var _renderer: Node3D
var _dnc: FakeDayNightCycle
var _recipe_registry: FakeRecipeRegistry
var _world: Node3D

# Signal capture
var _structure_placed_events: Array = []
var _build_failed_events: Array = []
var _placement_entered_events: Array = []
var _placement_exited_count: int = 0


# --- Setup / Teardown ---

func before_test() -> void:
	_setup_full_environment()


func after_test() -> void:
	_teardown_full_environment()


# --- Test helpers ---

func _make_tile(biome: int = _HexTile.Biome.GRASSLAND, elevation: int = 0) -> HexTile:
	var tile: HexTile = _HexTile.new()
	tile.biome = biome
	tile.elevation = elevation
	return tile


func _make_build_recipe(recipe_id: StringName, display_name: String,
		inputs: Array[Dictionary], output_id: StringName,
		time: float = 0.0) -> _Recipe:
	var recipe := _Recipe.new()
	recipe.id = recipe_id
	recipe.display_name = display_name
	recipe.kind = _Recipe.Kind.ASSEMBLE
	recipe.actions = [&"build"]
	recipe.duration = time

	# Inputs
	var recipe_inputs: Array[Resource] = []
	for input_def: Dictionary in inputs:
		var ri := _RecipeInput.new()
		ri.ref_or_tag = input_def["type"]
		ri.count = input_def["count"]
		ri.source = &"player_inventory"
		recipe_inputs.append(ri)
	recipe.inputs = recipe_inputs

	# Output
	var ro := _RecipeOutput.new()
	ro.prop_ref = output_id
	ro.count = 1
	ro.prob = 1.0
	recipe.outputs = [ro]

	# Condition: at_tile_type buildable (non-water)
	var pred := _Predicate.new()
	pred.kind = &"at_tile_type"
	pred.params = { "tag": "buildable" }
	var cond := _RecipeCondition.new()
	cond.predicate = pred
	cond.must_sustain = false
	recipe.conditions = [cond]

	return recipe


func _add_materials(wood: int = 0, rock: int = 0, fiber: int = 0) -> void:
	if wood > 0:
		_inventory.add_item(ID_WOOD, wood)
	if rock > 0:
		_inventory.add_item(ID_ROCK, rock)
	if fiber > 0:
		_inventory.add_item(ID_FIBER, fiber)


func _get_wood_count() -> int:
	return _inventory.get_count(ID_WOOD)


func _get_rock_count() -> int:
	return _inventory.get_count(ID_ROCK)


func _get_fiber_count() -> int:
	return _inventory.get_count(ID_FIBER)


## Simulate a full build: enter placement mode, call try_place_at on an adjacent tile.
## Returns true if structure was placed successfully.
func _do_build(recipe_id: StringName, target_tile: Vector2i = ADJACENT_TILE,
		sub_hex: Vector2i = Vector2i.ZERO) -> bool:
	var recipe: _Recipe = _recipe_registry.get_recipe(recipe_id)
	if recipe == null:
		return false
	_building.enter_placement_mode(recipe)
	return _building.try_place_at(target_tile, sub_hex)


func _tile_has_prop_type(coords: Vector2i, prop_type: StringName) -> bool:
	var tile = _grid.get_tile(coords)
	if tile == null:
		return false
	for prop in tile.props:
		if prop.type == prop_type:
			return true
	return false


func _get_prop_on_tile(coords: Vector2i, prop_type: StringName):
	var tile = _grid.get_tile(coords)
	if tile == null:
		return null
	for prop in tile.props:
		if prop.type == prop_type:
			return prop
	return null


func _setup_full_environment() -> void:
	_structure_placed_events.clear()
	_build_failed_events.clear()
	_placement_entered_events.clear()
	_placement_exited_count = 0

	# Grid
	_grid = FakeGrid.new()
	_grid.name = "FakeGrid"
	add_child(_grid)

	# Tiles: player tile + adjacent tiles
	var player_tile := _make_tile()
	player_tile.coords = PLAYER_TILE
	_grid._tiles[PLAYER_TILE] = player_tile

	var adj_tile := _make_tile()
	adj_tile.coords = ADJACENT_TILE
	_grid._tiles[ADJACENT_TILE] = adj_tile

	var adj_tile_2 := _make_tile()
	adj_tile_2.coords = ADJACENT_TILE_2
	_grid._tiles[ADJACENT_TILE_2] = adj_tile_2

	# Additional neighbors for fuller testing
	for d: Vector2i in [Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1)]:
		var t := _make_tile()
		t.coords = PLAYER_TILE + d
		_grid._tiles[t.coords] = t

	# DayNightCycle
	_dnc = FakeDayNightCycle.new()
	_dnc.name = "FakeDNC"
	add_child(_dnc)

	# Recipe registry
	_recipe_registry = FakeRecipeRegistry.new()
	_recipe_registry.name = "FakeRecipeRegistry"
	_register_build_recipes()

	# Discovery watcher (mark all recipes as known)
	_discovery = _DiscoveryWatcher.new()
	_discovery.name = "FakeDiscoveryWatcher"
	_discovery._registry = _recipe_registry
	add_child(_discovery)

	# RecipeRuntime
	_runtime = _RecipeRuntime.new()
	_runtime.name = "FakeRuntime"
	_runtime._registry = _recipe_registry
	_runtime._discovery = _discovery
	# Deterministic random: always produce outputs
	_runtime._rng = func() -> float: return 0.0
	add_child(_runtime)

	# Inventory
	_inventory = _Inventory.new()

	# Player
	_player = FakePlayer.new()
	_player.name = "Player"
	_player.current_tile = PLAYER_TILE
	_player.inventory = _inventory

	# BuildingSystem
	_building = _BuildingSystem.new()
	_building.name = "BuildingSystem"
	_building._grid = _grid
	_building._runtime = _runtime
	_player.add_child(_building)

	# CraftingSystem
	_crafting = _CraftingSystem.new()
	_crafting.name = "CraftingSystem"
	_crafting._grid = _grid
	_crafting._inventory = _inventory
	_crafting._player = _player
	_player.add_child(_crafting)

	# World with player
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_world.add_child(_player)

	# LightingManager
	_lighting = _LightingManager.new()
	_lighting.name = "FakeLighting"
	_lighting._grid = _grid
	_lighting._dnc = _dnc
	_lighting._registry = PropRegistry
	add_child(_lighting)

	# StructureRenderer
	_renderer = _StructureRenderer.new()
	_renderer.name = "StructureRenderer"
	_renderer._grid = _grid
	_world.add_child(_renderer)

	# Wire signals for capture
	_grid.structure_placed.connect(_on_structure_placed)
	_building.structure_build_failed.connect(_on_build_failed)
	_building.placement_mode_entered.connect(_on_placement_entered)
	_building.placement_mode_exited.connect(_on_placement_exited)


func _teardown_full_environment() -> void:
	if is_instance_valid(_lighting):
		remove_child(_lighting)
		_lighting.queue_free()
	if is_instance_valid(_world):
		remove_child(_world)
		_world.queue_free()
	if is_instance_valid(_discovery):
		remove_child(_discovery)
		_discovery.queue_free()
	if is_instance_valid(_runtime):
		remove_child(_runtime)
		_runtime.queue_free()
	if is_instance_valid(_dnc):
		remove_child(_dnc)
		_dnc.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_lighting = null
	_renderer = null
	_building = null
	_crafting = null
	_runtime = null
	_discovery = null
	_player = null
	_inventory = null
	_grid = null
	_world = null
	_dnc = null
	_recipe_registry = null


func _register_build_recipes() -> void:
	# Campfire: 3 wood + 2 fiber → 00101
	_recipe_registry._recipes[RID_CAMPFIRE] = _make_build_recipe(
		RID_CAMPFIRE, "Build Campfire",
		[{"type": ID_WOOD, "count": 3}, {"type": ID_FIBER, "count": 2}],
		ID_CAMPFIRE)
	# Workbench: 5 wood + 3 rock → 00105
	_recipe_registry._recipes[RID_WORKBENCH] = _make_build_recipe(
		RID_WORKBENCH, "Build Workbench",
		[{"type": ID_WOOD, "count": 5}, {"type": ID_ROCK, "count": 3}],
		ID_WORKBENCH)
	# Storage Chest: 8 wood + 4 rock → 00104
	_recipe_registry._recipes[RID_STORAGE_CHEST] = _make_build_recipe(
		RID_STORAGE_CHEST, "Build Storage Chest",
		[{"type": ID_WOOD, "count": 8}, {"type": ID_ROCK, "count": 4}],
		ID_STORAGE_CHEST)
	# Shelter: 10 wood + 5 rock + 3 fiber → 00102
	_recipe_registry._recipes[RID_SHELTER] = _make_build_recipe(
		RID_SHELTER, "Build Shelter",
		[{"type": ID_WOOD, "count": 10}, {"type": ID_ROCK, "count": 5}, {"type": ID_FIBER, "count": 3}],
		ID_SHELTER)
	# Wall: 3 wood → 00106
	_recipe_registry._recipes[RID_WALL] = _make_build_recipe(
		RID_WALL, "Build Wall",
		[{"type": ID_WOOD, "count": 3}],
		ID_WALL)
	# Torch: 2 wood + 1 fiber → 00103
	_recipe_registry._recipes[RID_TORCH] = _make_build_recipe(
		RID_TORCH, "Build Torch",
		[{"type": ID_WOOD, "count": 2}, {"type": ID_FIBER, "count": 1}],
		ID_TORCH)


func _on_structure_placed(coords: Vector2i, structure_type: StringName) -> void:
	_structure_placed_events.append({"coords": coords, "type": structure_type})


func _on_build_failed(reason: StringName) -> void:
	_build_failed_events.append(reason)


func _on_placement_entered(recipe_id: StringName) -> void:
	_placement_entered_events.append(recipe_id)


func _on_placement_exited() -> void:
	_placement_exited_count += 1


# ===========================================================================
# 1. Storage Chest → Inventory.capacity_weight increases by 50.0
# ===========================================================================

func test_storage_chest_increases_capacity_weight() -> void:
	_add_materials(8, 4, 0)
	var initial_capacity: float = _inventory.capacity_weight
	assert_float(initial_capacity).is_equal(50.0)

	var ok: bool = _do_build(RID_STORAGE_CHEST)
	assert_bool(ok).override_failure_message("Storage chest build should succeed").is_true()

	assert_float(_inventory.capacity_weight).is_equal(100.0)


func test_storage_chest_capacity_is_additive() -> void:
	_add_materials(16, 8, 0)

	_do_build(RID_STORAGE_CHEST, ADJACENT_TILE)
	assert_float(_inventory.capacity_weight).is_equal(100.0)

	_do_build(RID_STORAGE_CHEST, ADJACENT_TILE_2)
	assert_float(_inventory.capacity_weight).is_equal(150.0)


# ===========================================================================
# 2. Shelter → respawn point (STATION(respawn) capability on tile prop)
# ===========================================================================

func test_shelter_has_respawn_station_tag() -> void:
	_add_materials(10, 5, 3)
	_do_build(RID_SHELTER)

	# Verify the shelter prop is on the tile.
	assert_bool(_tile_has_prop_type(ADJACENT_TILE, ID_SHELTER)).is_true()

	# Verify PropDef for shelter has STATION with "respawn" tag.
	var def = PropRegistry.get_def(ID_SHELTER)
	assert_bool(def != null).override_failure_message("Shelter PropDef must exist").is_true()
	assert_bool(def.station != null).override_failure_message("Shelter must have STATION cap").is_true()
	assert_bool(def.station.station_tags.has(&"respawn")).override_failure_message(
		"Shelter station must have 'respawn' tag"
	).is_true()


func test_shelter_prop_is_respawn_point() -> void:
	_add_materials(10, 5, 3)
	_do_build(RID_SHELTER)

	# Check via legacy field for backward compat.
	var def = PropRegistry.get_def(ID_SHELTER)
	assert_bool(def.is_respawn_point).override_failure_message(
		"Shelter PropDef.is_respawn_point should be true"
	).is_true()


# ===========================================================================
# 3. Torch → LightingManager registers light during NIGHT
# ===========================================================================

func test_torch_registers_light_on_placement() -> void:
	_add_materials(2, 0, 1)

	# During day: no active lights.
	_dnc.set_day()
	var lights_before: Array = _lighting.get_active_lights()
	assert_int(lights_before.size()).is_equal(0)

	# Build torch.
	_do_build(RID_TORCH)
	assert_bool(_tile_has_prop_type(ADJACENT_TILE, ID_TORCH)).is_true()

	# The structure light should be registered (even during day — just not returned).
	assert_int(_lighting.get_structure_light_count()).is_equal(1)


func test_torch_light_visible_at_night() -> void:
	_add_materials(2, 0, 1)
	_do_build(RID_TORCH)

	# Switch to night — active lights should include the torch.
	_dnc.set_night()
	var lights: Array = _lighting.get_active_lights()
	assert_int(lights.size()).override_failure_message(
		"Expected 1 active light from torch at night"
	).is_equal(1)
	assert_float(lights[0]["radius"]).is_greater(0.0)


func test_torch_destroy_removes_light() -> void:
	_add_materials(2, 0, 1)
	_do_build(RID_TORCH)
	assert_int(_lighting.get_structure_light_count()).is_equal(1)

	# Simulate structure destruction.
	_grid.structure_destroyed.emit(ADJACENT_TILE, ID_TORCH)
	assert_int(_lighting.get_structure_light_count()).is_equal(0)

	_dnc.set_night()
	var lights: Array = _lighting.get_active_lights()
	assert_int(lights.size()).is_equal(0)


# ===========================================================================
# 4. Workbench → CraftingSystem station proximity
# ===========================================================================

func test_workbench_enables_crafting_station_proximity() -> void:
	_add_materials(5, 3, 0)

	# Before placing workbench: no station near player.
	assert_bool(_crafting._tile_has_crafting_station(ADJACENT_TILE)).is_false()

	# Place workbench on adjacent tile.
	_do_build(RID_WORKBENCH)
	assert_bool(_tile_has_prop_type(ADJACENT_TILE, ID_WORKBENCH)).is_true()

	# Workbench PropDef has is_crafting_station = true.
	var def = PropRegistry.get_def(ID_WORKBENCH)
	assert_bool(def.is_crafting_station).override_failure_message(
		"Workbench must have is_crafting_station = true"
	).is_true()

	# CraftingSystem should detect station on that tile.
	assert_bool(_crafting._tile_has_crafting_station(ADJACENT_TILE)).override_failure_message(
		"CraftingSystem should detect workbench as crafting station"
	).is_true()


func test_workbench_has_craft_station_tag() -> void:
	var def = PropRegistry.get_def(ID_WORKBENCH)
	assert_bool(def != null).is_true()
	assert_bool(def.station != null).override_failure_message(
		"Workbench must have STATION cap"
	).is_true()
	assert_bool(def.station.station_tags.has(&"craft")).override_failure_message(
		"Workbench station must have 'craft' tag"
	).is_true()


# ===========================================================================
# 5. Wall blocks movement — only blocking structure
# ===========================================================================

func test_wall_placed_on_tile() -> void:
	_add_materials(3, 0, 0)
	_do_build(RID_WALL)

	var wall_prop = _get_prop_on_tile(ADJACENT_TILE, ID_WALL)
	assert_bool(wall_prop != null).override_failure_message("Wall prop must exist on tile").is_true()
	assert_int(wall_prop.category).override_failure_message(
		"Wall prop must have STRUCTURE category"
	).is_equal(_Prop.Category.STRUCTURE)


func test_wall_blocks_traversal() -> void:
	_add_materials(3, 0, 0)
	_do_build(RID_WALL)

	# HexGrid.get_traversal should return BLOCKED for tiles with wall.
	var traversal: int = _grid.get_traversal(PLAYER_TILE, ADJACENT_TILE)
	assert_int(traversal).override_failure_message(
		"Traversal to tile with wall should be BLOCKED (3)"
	).is_equal(3)


func test_wall_propdef_has_structure_tag() -> void:
	var def = PropRegistry.get_def(ID_WALL)
	assert_bool(def != null).is_true()
	assert_bool(def.placeable != null).is_true()
	assert_bool(def.has_tag(&"STRUCTURE")).override_failure_message(
		"Wall PropDef must have STRUCTURE tag"
	).is_true()


func test_all_structures_have_placeable_cap() -> void:
	# Verify all structures have a placeable capability.
	var structure_ids: Array[StringName] = [ID_CAMPFIRE, ID_SHELTER, ID_TORCH, ID_STORAGE_CHEST, ID_WORKBENCH, ID_WALL]
	for prop_id: StringName in structure_ids:
		var def = PropRegistry.get_def(prop_id)
		assert_bool(def != null).override_failure_message(
			"PropDef for %s must exist" % prop_id
		).is_true()
		assert_bool(def.placeable != null).override_failure_message(
			"PropDef %s must have placeable cap" % prop_id
		).is_true()


func test_campfire_does_not_block_traversal() -> void:
	_add_materials(3, 0, 2)
	_do_build(RID_CAMPFIRE)

	var traversal: int = _grid.get_traversal(PLAYER_TILE, ADJACENT_TILE)
	assert_int(traversal).override_failure_message(
		"Traversal to tile with campfire should be WALK (0), not blocked"
	).is_equal(0)


# ===========================================================================
# 6. Sub-hex overlap rejection
# ===========================================================================

func test_sub_hex_overlap_rejected() -> void:
	_add_materials(6, 0, 4)

	# Place first campfire at (1,0) sub-hex (0,0)
	var ok1: bool = _do_build(RID_CAMPFIRE, ADJACENT_TILE, Vector2i.ZERO)
	assert_bool(ok1).override_failure_message("First campfire should succeed").is_true()

	# Try to place second campfire at same tile, same sub-hex.
	var ok2: bool = _do_build(RID_CAMPFIRE, ADJACENT_TILE, Vector2i.ZERO)
	assert_bool(ok2).override_failure_message(
		"Second build at same sub-hex should be rejected"
	).is_false()
	assert_bool(_build_failed_events.has(&"sub_hex_occupied")).override_failure_message(
		"Failure reason must be sub_hex_occupied"
	).is_true()


func test_different_sub_hex_allows_second_structure() -> void:
	_add_materials(6, 0, 4)

	# Place first campfire at sub-hex (0,0)
	var ok1: bool = _do_build(RID_CAMPFIRE, ADJACENT_TILE, Vector2i.ZERO)
	assert_bool(ok1).is_true()

	# Place second campfire at sub-hex (1,0) — different position, should succeed.
	var ok2: bool = _do_build(RID_CAMPFIRE, ADJACENT_TILE, Vector2i(1, 0))
	assert_bool(ok2).override_failure_message(
		"Build at different sub-hex should succeed"
	).is_true()


# ===========================================================================
# 7. Placement cancel → no material loss
# ===========================================================================

func test_placement_cancel_no_material_loss() -> void:
	_add_materials(5, 3, 0)
	var wood_before: int = _get_wood_count()
	var rock_before: int = _get_rock_count()

	# Enter placement mode.
	var recipe: _Recipe = _recipe_registry.get_recipe(RID_WORKBENCH)
	_building.enter_placement_mode(recipe)
	assert_bool(_building.is_placing()).is_true()

	# Cancel without placing.
	_building.exit_placement_mode()
	assert_bool(_building.is_placing()).is_false()

	# Materials unchanged.
	assert_int(_get_wood_count()).override_failure_message(
		"Wood count must be unchanged after cancel"
	).is_equal(wood_before)
	assert_int(_get_rock_count()).override_failure_message(
		"Rock count must be unchanged after cancel"
	).is_equal(rock_before)


func test_placement_signals_on_cancel() -> void:
	var recipe: _Recipe = _recipe_registry.get_recipe(RID_WALL)
	_building.enter_placement_mode(recipe)
	assert_int(_placement_entered_events.size()).is_equal(1)

	_building.exit_placement_mode()
	assert_int(_placement_exited_count).is_equal(1)

	# No structure_placed events.
	assert_int(_structure_placed_events.size()).is_equal(0)


# ===========================================================================
# 8. Materials consumed by RecipeRuntime on successful build
# ===========================================================================

func test_campfire_consumes_materials() -> void:
	_add_materials(10, 0, 5)
	_do_build(RID_CAMPFIRE)

	# Campfire costs: 3 wood + 2 fiber
	assert_int(_get_wood_count()).is_equal(7)
	assert_int(_get_fiber_count()).is_equal(3)


func test_wall_consumes_materials() -> void:
	_add_materials(10, 0, 0)
	_do_build(RID_WALL)

	# Wall costs: 3 wood
	assert_int(_get_wood_count()).is_equal(7)


func test_shelter_consumes_materials() -> void:
	_add_materials(15, 10, 5)
	_do_build(RID_SHELTER)

	# Shelter costs: 10 wood + 5 rock + 3 fiber
	assert_int(_get_wood_count()).is_equal(5)
	assert_int(_get_rock_count()).is_equal(5)
	assert_int(_get_fiber_count()).is_equal(2)


func test_insufficient_materials_rejects_build() -> void:
	_add_materials(1, 0, 0)  # Need 3 for wall
	var ok: bool = _do_build(RID_WALL)
	assert_bool(ok).override_failure_message(
		"Build with insufficient materials should fail"
	).is_false()
	# Verify no materials were consumed.
	assert_int(_get_wood_count()).is_equal(1)


# ===========================================================================
# 9. Structure_placed signal emitted correctly
# ===========================================================================

func test_structure_placed_signal_emitted() -> void:
	_add_materials(3, 0, 0)
	_do_build(RID_WALL)

	assert_int(_structure_placed_events.size()).override_failure_message(
		"structure_placed signal must fire once"
	).is_equal(1)
	assert_int(_structure_placed_events[0]["coords"].x).is_equal(ADJACENT_TILE.x)
	assert_int(_structure_placed_events[0]["coords"].y).is_equal(ADJACENT_TILE.y)
	assert_str(String(_structure_placed_events[0]["type"])).is_equal(String(ID_WALL))


# ===========================================================================
# 10. End-to-end recipe-driven build flow
# ===========================================================================

func test_end_to_end_torch_build() -> void:
	# Add materials.
	_add_materials(2, 0, 1)

	# Open build panel → select recipe → enter placement → place on valid tile.
	var recipe: _Recipe = _recipe_registry.get_recipe(RID_TORCH)
	_building.enter_placement_mode(recipe)
	assert_bool(_building.is_placing()).is_true()
	assert_int(_placement_entered_events.size()).is_equal(1)

	# Place at adjacent tile.
	var ok: bool = _building.try_place_at(ADJACENT_TILE)
	assert_bool(ok).is_true()

	# Verify: placement mode exited.
	assert_bool(_building.is_placing()).is_false()

	# Verify: structure appears on tile.
	assert_bool(_tile_has_prop_type(ADJACENT_TILE, ID_TORCH)).override_failure_message(
		"Torch must appear on tile after build"
	).is_true()

	# Verify: materials consumed (2 wood + 1 fiber).
	assert_int(_get_wood_count()).is_equal(0)
	assert_int(_get_fiber_count()).is_equal(0)

	# Verify: structure_placed signal emitted.
	assert_int(_structure_placed_events.size()).is_equal(1)
	assert_str(String(_structure_placed_events[0]["type"])).is_equal(String(ID_TORCH))

	# Verify: LightingManager registered the light.
	assert_int(_lighting.get_structure_light_count()).is_equal(1)


func test_end_to_end_workbench_build() -> void:
	_add_materials(5, 3, 0)

	_do_build(RID_WORKBENCH)

	# Structure on tile.
	assert_bool(_tile_has_prop_type(ADJACENT_TILE, ID_WORKBENCH)).is_true()

	# Materials consumed.
	assert_int(_get_wood_count()).is_equal(0)
	assert_int(_get_rock_count()).is_equal(0)

	# CraftingSystem detects station.
	assert_bool(_crafting._tile_has_crafting_station(ADJACENT_TILE)).is_true()

	# Signal emitted.
	assert_int(_structure_placed_events.size()).is_equal(1)


func test_end_to_end_storage_chest_build() -> void:
	_add_materials(8, 4, 0)

	_do_build(RID_STORAGE_CHEST)

	# Structure on tile.
	assert_bool(_tile_has_prop_type(ADJACENT_TILE, ID_STORAGE_CHEST)).is_true()

	# Capacity increased.
	assert_float(_inventory.capacity_weight).is_equal(100.0)

	# Materials consumed.
	assert_int(_get_wood_count()).is_equal(0)
	assert_int(_get_rock_count()).is_equal(0)


# ===========================================================================
# 11. StructureRenderer signal-driven updates
# ===========================================================================

func test_structure_renderer_adds_on_placed() -> void:
	_add_materials(3, 0, 0)
	_do_build(RID_WALL)

	assert_bool(_renderer.has_instance(ADJACENT_TILE, ID_WALL)).override_failure_message(
		"StructureRenderer must have instance after structure_placed"
	).is_true()
	assert_int(_renderer.get_instance_count()).is_equal(1)


func test_structure_renderer_removes_on_destroyed() -> void:
	_add_materials(3, 0, 0)
	_do_build(RID_WALL)
	assert_int(_renderer.get_instance_count()).is_equal(1)

	_grid.structure_destroyed.emit(ADJACENT_TILE, ID_WALL)
	assert_int(_renderer.get_instance_count()).override_failure_message(
		"StructureRenderer must remove instance on structure_destroyed"
	).is_equal(0)


# ===========================================================================
# 12. Water tile rejection
# ===========================================================================

func test_water_tile_rejects_build() -> void:
	var water_coords := Vector2i(-1, 0)
	var water_tile := _make_tile(_HexTile.Biome.WATER)
	water_tile.coords = water_coords
	_grid._tiles[water_coords] = water_tile

	_add_materials(3, 0, 0)
	var ok: bool = _do_build(RID_WALL, water_coords)
	assert_bool(ok).is_false()
	assert_bool(_build_failed_events.has(&"water_tile")).override_failure_message(
		"Build on water must fail with 'water_tile' reason"
	).is_true()
	# Materials not consumed.
	assert_int(_get_wood_count()).is_equal(3)


# ===========================================================================
# 13. Prop origin is CRAFTED for placed structures
# ===========================================================================

func test_placed_structure_has_crafted_origin() -> void:
	_add_materials(3, 0, 2)
	_do_build(RID_CAMPFIRE)

	var prop = _get_prop_on_tile(ADJACENT_TILE, ID_CAMPFIRE)
	assert_bool(prop != null).is_true()
	assert_int(prop.origin).override_failure_message(
		"Placed structure must have Origin.CRAFTED (1)"
	).is_equal(_Prop.Origin.CRAFTED)


# ===========================================================================
# 14. Campfire has light capability
# ===========================================================================

func test_campfire_registers_light() -> void:
	_add_materials(3, 0, 2)
	_do_build(RID_CAMPFIRE)

	assert_int(_lighting.get_structure_light_count()).override_failure_message(
		"Campfire should register a light source"
	).is_equal(1)

	_dnc.set_night()
	var lights: Array = _lighting.get_active_lights()
	assert_int(lights.size()).is_equal(1)


# ===========================================================================
# 15. All structure PropDefs have STRUCTURE tag
# ===========================================================================

func test_all_structures_have_structure_tag() -> void:
	var structure_ids: Array[StringName] = [
		ID_CAMPFIRE, ID_SHELTER, ID_TORCH, ID_STORAGE_CHEST, ID_WORKBENCH, ID_WALL
	]
	for sid: StringName in structure_ids:
		var def = PropRegistry.get_def(sid)
		assert_bool(def != null).override_failure_message(
			"PropDef %s must exist" % sid
		).is_true()
		assert_bool(def.has_tag(&"STRUCTURE")).override_failure_message(
			"PropDef %s must have STRUCTURE tag" % sid
		).is_true()


# ===========================================================================
# 16. Multiple structures render correctly
# ===========================================================================

func test_multiple_structures_render() -> void:
	_add_materials(6, 0, 4)

	_do_build(RID_CAMPFIRE, ADJACENT_TILE)
	_do_build(RID_CAMPFIRE, ADJACENT_TILE_2)

	assert_int(_renderer.get_instance_count()).override_failure_message(
		"Two structures should create two renderer instances"
	).is_equal(2)
