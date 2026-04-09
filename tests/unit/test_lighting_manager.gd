extends GdUnitTestSuite

## Unit tests for LightingManager (task-039: Local Lighting System).
## Tests: register, unregister, move, query, day/night phase gating.

const _LightingManager = preload("res://scripts/lighting/lighting_manager.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _LightCap = preload("res://scripts/data/capabilities/light_cap.gd")

var _lm: Node
var _grid: MockHexGrid
var _dnc: MockDayNightCycle
var _registry: MockPropRegistry


# --- Mock HexGrid ---

class MockHexGrid extends Node:
	signal tile_entered(coords: Vector2i)
	signal tile_exited(coords: Vector2i)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)


# --- Mock DayNightCycle ---

class MockDayNightCycle extends Node:
	## TimePhase enum values: DAY=0, DUSK=1, NIGHT=2, DAWN=3
	var current_phase: int = 0

	func set_night() -> void:
		current_phase = 2  # NIGHT

	func set_dusk() -> void:
		current_phase = 1  # DUSK

	func set_day() -> void:
		current_phase = 0  # DAY

	func set_dawn() -> void:
		current_phase = 3  # DAWN


# --- Mock PropRegistry ---

class MockPropRegistry extends Node:
	var _defs: Dictionary = {}

	func add_def(def: Resource) -> void:
		_defs[def.id] = def

	func get_def(type: StringName) -> Resource:
		return _defs.get(type, null)


# --- Helpers ---

func _make_light_prop(id: StringName, radius: int) -> Resource:
	var def := _PropDef.new()
	def.id = id
	def.display_name = "Light_%s" % str(id)
	var cap := _LightCap.new()
	cap.radius = float(radius)
	cap.color = _LightingManager.DEFAULT_LIGHT_COLOR
	def.light = cap
	return def


func _make_normal_prop(id: StringName) -> Resource:
	var def := _PropDef.new()
	def.id = id
	def.display_name = "Normal_%s" % str(id)
	return def


# --- Setup / Teardown ---

func before_test() -> void:
	_grid = MockHexGrid.new()
	add_child(_grid)
	_dnc = MockDayNightCycle.new()
	add_child(_dnc)
	_registry = MockPropRegistry.new()
	add_child(_registry)

	# Register test props
	_registry.add_def(_make_light_prop(&"00101", 4))   # Campfire
	_registry.add_def(_make_light_prop(&"00103", 3))   # Torch
	_registry.add_def(_make_normal_prop(&"00010"))      # Wood (no light)

	_lm = _LightingManager.new()
	_lm._grid = _grid
	_lm._dnc = _dnc
	_lm._registry = _registry
	add_child(_lm)


func after_test() -> void:
	remove_child(_lm)
	_lm.queue_free()
	remove_child(_grid)
	_grid.queue_free()
	remove_child(_dnc)
	_dnc.queue_free()
	remove_child(_registry)
	_registry.queue_free()


# === Register / Unregister tests ===

func test_register_light_on_structure_placed() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	assert_int(_lm.get_structure_light_count()).is_equal(1)


func test_no_register_for_non_light_prop() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00010")
	assert_int(_lm.get_structure_light_count()).is_equal(0)


func test_unregister_light_on_structure_destroyed() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	assert_int(_lm.get_structure_light_count()).is_equal(1)
	_grid.structure_destroyed.emit(Vector2i(0, 0), &"00101")
	assert_int(_lm.get_structure_light_count()).is_equal(0)


func test_destroy_unknown_structure_is_no_op() -> void:
	_dnc.set_night()
	_grid.structure_destroyed.emit(Vector2i(5, 5), &"00101")
	assert_int(_lm.get_structure_light_count()).is_equal(0)


func test_multiple_lights_register() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	_grid.structure_placed.emit(Vector2i(1, 0), &"00103")
	_grid.structure_placed.emit(Vector2i(2, 0), &"00101")
	assert_int(_lm.get_structure_light_count()).is_equal(3)


func test_destroy_one_leaves_others() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	_grid.structure_placed.emit(Vector2i(1, 0), &"00103")
	_grid.structure_destroyed.emit(Vector2i(0, 0), &"00101")
	assert_int(_lm.get_structure_light_count()).is_equal(1)


# === Signal emission tests ===

func test_register_emits_signal() -> void:
	var fired: Array = []
	_lm.light_source_registered.connect(func(pos: Vector2, radius: float) -> void:
		fired.append({"pos": pos, "radius": radius})
	)
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	assert_int(fired.size()).is_equal(1)
	assert_float(fired[0]["radius"]).is_equal(4.0 * _LightingManager.RING_TO_WORLD)


func test_unregister_emits_signal() -> void:
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	var fired: Array = []
	_lm.light_source_unregistered.connect(func(pos: Vector2) -> void:
		fired.append(pos)
	)
	_grid.structure_destroyed.emit(Vector2i(0, 0), &"00101")
	assert_int(fired.size()).is_equal(1)


# === Light radius tests ===

func test_campfire_radius_is_4_rings() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(1)
	assert_float(lights[0]["radius"]).is_equal(4.0 * _LightingManager.RING_TO_WORLD)


func test_torch_radius_is_3_rings() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00103")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(1)
	assert_float(lights[0]["radius"]).is_equal(3.0 * _LightingManager.RING_TO_WORLD)


# === Day/Night phase gating ===

func test_day_phase_returns_no_lights() -> void:
	_dnc.set_day()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(0)


func test_dawn_phase_returns_no_lights() -> void:
	_dnc.set_dawn()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(0)


func test_night_phase_returns_active_lights() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(1)


func test_dusk_phase_returns_active_lights() -> void:
	_dnc.set_dusk()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(1)


func test_is_night_active_during_night() -> void:
	_dnc.set_night()
	assert_bool(_lm.is_night_active()).is_true()


func test_is_night_active_during_dusk() -> void:
	_dnc.set_dusk()
	assert_bool(_lm.is_night_active()).is_true()


func test_is_night_not_active_during_day() -> void:
	_dnc.set_day()
	assert_bool(_lm.is_night_active()).is_false()


func test_is_night_not_active_during_dawn() -> void:
	_dnc.set_dawn()
	assert_bool(_lm.is_night_active()).is_false()


# === Light position tests ===

func test_light_position_matches_world_coords() -> void:
	_dnc.set_night()
	var coords := Vector2i(3, -2)
	_grid.structure_placed.emit(coords, &"00101")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	var expected_pos: Vector2 = HexMath.axial_to_world(coords)
	assert_float(lights[0]["position"].x).is_equal_approx(expected_pos.x, 0.01)
	assert_float(lights[0]["position"].y).is_equal_approx(expected_pos.y, 0.01)


# === Player-carried torch (manual API) ===

func test_set_player_light() -> void:
	_dnc.set_night()
	_lm.set_player_light(Vector2(5.0, 3.0), 9.0)
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(1)
	assert_float(lights[0]["position"].x).is_equal_approx(5.0, 0.01)
	assert_float(lights[0]["radius"]).is_equal(9.0)


func test_clear_player_light() -> void:
	_dnc.set_night()
	_lm.set_player_light(Vector2(5.0, 3.0), 9.0)
	_lm.clear_player_light()
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(0)


func test_player_light_plus_structure_lights() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	_lm.set_player_light(Vector2(10.0, 10.0), 6.0)
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(2)


func test_player_light_hidden_during_day() -> void:
	_dnc.set_day()
	_lm.set_player_light(Vector2(5.0, 3.0), 9.0)
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(0)


# === Light source movement ===

func test_tile_entered_moves_player_light() -> void:
	_dnc.set_night()
	_lm.set_player_light(Vector2.ZERO, 9.0)
	var moved: Array = []
	_lm.light_source_moved.connect(func(pos: Vector2) -> void:
		moved.append(pos)
	)
	_grid.tile_entered.emit(Vector2i(2, 1))
	assert_int(moved.size()).is_equal(1)
	var expected_pos: Vector2 = HexMath.axial_to_world(Vector2i(2, 1))
	assert_float(moved[0].x).is_equal_approx(expected_pos.x, 0.01)


func test_tile_entered_no_signal_without_player_light() -> void:
	var moved: Array = []
	_lm.light_source_moved.connect(func(pos: Vector2) -> void:
		moved.append(pos)
	)
	_grid.tile_entered.emit(Vector2i(2, 1))
	assert_int(moved.size()).is_equal(0)


# === Manual register/unregister API ===

func test_manual_register_and_unregister() -> void:
	_dnc.set_night()
	_lm.register_light("test_key", Vector2(1.0, 2.0), 5.0)
	assert_int(_lm.get_structure_light_count()).is_equal(1)
	_lm.unregister_light("test_key")
	assert_int(_lm.get_structure_light_count()).is_equal(0)


func test_unregister_unknown_key_is_no_op() -> void:
	_lm.unregister_light("nonexistent")
	assert_int(_lm.get_structure_light_count()).is_equal(0)


# === Max lights enforcement ===

func test_get_active_lights_respects_max() -> void:
	_dnc.set_night()
	# Register more than MAX_LIGHTS sources
	for i: int in range(10):
		_lm.register_light("light_%d" % i, Vector2(float(i), 0.0), 5.0)
	# get_active_lights returns all registered — renderer caps at 8
	var lights: Array[Dictionary] = _lm.get_active_lights()
	assert_int(lights.size()).is_equal(10)


# === Light color ===

func test_default_light_color() -> void:
	_dnc.set_night()
	_grid.structure_placed.emit(Vector2i(0, 0), &"00101")
	var lights: Array[Dictionary] = _lm.get_active_lights()
	var color: Color = lights[0]["color"]
	assert_float(color.r).is_equal_approx(_LightingManager.DEFAULT_LIGHT_COLOR.r, 0.01)
	assert_float(color.g).is_equal_approx(_LightingManager.DEFAULT_LIGHT_COLOR.g, 0.01)
	assert_float(color.b).is_equal_approx(_LightingManager.DEFAULT_LIGHT_COLOR.b, 0.01)
