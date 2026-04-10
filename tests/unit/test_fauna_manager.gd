extends GdUnitTestSuite

## Unit tests for FaunaManager (task-037: spawn, AI, contact, despawn).
## Wave 3 (delivery-006b): species config now lives on PropDef caps and is
## read through the injected PropRegistry — every test wires a P00108 def
## with the same numbers the legacy hardcoded FAUNA_CONFIG used.

const _FaunaManager = preload("res://scripts/fauna/fauna_manager.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _StationCap = preload("res://scripts/data/capabilities/station_cap.gd")
const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")
const _MovementCap = preload("res://scripts/data/capabilities/movement_cap.gd")
const _BehaviorCap = preload("res://scripts/data/capabilities/behavior_cap.gd")
const _SpawnableCap = preload("res://scripts/data/capabilities/spawnable_cap.gd")

## PropDef id of the live Chapter-1 fauna species under test.
const _THORNBACK_ID: StringName = &"P00108"

var _fm: Node
var _grid: MockHexGrid
var _dnc: MockDayNightCycle
var _lighting: MockLightingManager
var _player: MockPlayer
var _registry: MockPropRegistry


# === Mocks ===

class MockHexGrid extends Node:
	signal tile_entered(coords: Vector2i)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)
	var _tiles: Dictionary = {}

	func get_all_tiles() -> Dictionary:
		return _tiles

	func has_tile(coords: Vector2i) -> bool:
		return _tiles.has(coords)

	func get_tile(coords: Vector2i) -> Resource:
		return _tiles.get(coords, null)

	func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
		var all_n: Array[Vector2i] = HexMath.get_neighbors(coords)
		var result: Array[Vector2i] = []
		for n in all_n:
			if _tiles.has(n):
				result.append(n)
		return result

	func distance(a: Vector2i, b: Vector2i) -> int:
		return HexMath.distance(a, b)

	func get_traversal(from: Vector2i, to: Vector2i) -> int:
		var tile_to: Resource = _tiles.get(to, null)
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
		return 0  # WALK

	func get_elevation_diff(from: Vector2i, to: Vector2i) -> int:
		var tile_from: Resource = _tiles.get(from, null)
		var tile_to: Resource = _tiles.get(to, null)
		if tile_from == null or tile_to == null:
			return 999
		return abs(int(tile_to.elevation) - int(tile_from.elevation))


class MockDayNightCycle extends Node:
	signal night()
	signal dawn()
	signal phase_changed(old_phase: int, new_phase: int)
	var current_phase: int = 0
	var day_count: int = 1

	func set_night() -> void:
		current_phase = 2

	func set_day() -> void:
		current_phase = 0

	func set_dawn() -> void:
		current_phase = 3


class MockLightingManager extends Node:
	var _lights: Array[Dictionary] = []
	var _is_night: bool = false

	func get_active_lights() -> Array[Dictionary]:
		if not _is_night:
			return []
		return _lights

	func add_light(position: Vector2, radius: float) -> void:
		_lights.append({"position": position, "radius": radius, "color": Color.WHITE})

	func clear_lights() -> void:
		_lights.clear()


class MockPlayer extends Node:
	var current_tile: Vector2i = Vector2i.ZERO


class MockPropRegistry extends Node:
	var _defs: Dictionary = {}

	func add_def(def: Resource) -> void:
		_defs[def.id] = def

	func get_def(type: StringName) -> Resource:
		return _defs.get(type, null)

	func has_def(type: StringName) -> bool:
		return _defs.has(type)


# === Helpers ===

func _make_tile(coords: Vector2i, biome: int = 1, elevation: int = 0) -> Resource:
	var tile := _HexTile.new()
	tile.coords = coords
	tile.biome = biome
	tile.elevation = elevation
	return tile


func _add_tile(coords: Vector2i, biome: int = 1, elevation: int = 0) -> Resource:
	var tile := _make_tile(coords, biome, elevation)
	_grid._tiles[coords] = tile
	return tile


func _make_shelter_def() -> Resource:
	var def := _PropDef.new()
	def.id = &"P00102"
	def.display_name = "Shelter"
	var station := _StationCap.new()
	station.station_tags = [&"respawn"]
	def.station = station
	return def


## Live Chapter-1 fauna PropDef used by FaunaManager tests.
## Mirrors data/props/P00108.tres so tests assert against the same numbers
## that the real game ships with — but is rebuilt in code so tests stay
## isolated from the .tres file.
func _make_thornback_def() -> Resource:
	var def := _PropDef.new()
	def.id = _THORNBACK_ID
	def.display_name = "Thornback"
	var endurance := _EnduranceCap.new()
	endurance.hp = 20
	def.endurance = endurance
	var movement := _MovementCap.new()
	movement.move_cooldown = 1.0
	movement.max_jump = 1
	def.movement = movement
	var behavior := _BehaviorCap.new()
	behavior.detection_range = 2
	def.behavior = behavior
	var spawnable := _SpawnableCap.new()
	spawnable.spawn_min = 1
	spawnable.spawn_max = 3
	spawnable.first_spawn_day = 4
	spawnable.spawn_min_distance = 3
	def.spawnable = spawnable
	return def


## Builds a grid around the origin with far tiles for spawn candidates.
## Player at (0,0), spawn-eligible tiles at distance >= 3.
func _setup_spawn_grid() -> void:
	# Player area (distance 0-2 from origin)
	for q in range(-2, 3):
		for r in range(-2, 3):
			if HexMath.distance(Vector2i.ZERO, Vector2i(q, r)) <= 2:
				_add_tile(Vector2i(q, r))
	# Far tiles (distance 3-5)
	for q in range(-5, 6):
		for r in range(-5, 6):
			var coords := Vector2i(q, r)
			var dist := HexMath.distance(Vector2i.ZERO, coords)
			if dist >= 3 and dist <= 5:
				if not _grid._tiles.has(coords):
					_add_tile(coords)


# === Setup / Teardown ===

func before_test() -> void:
	_grid = MockHexGrid.new()
	add_child(_grid)
	_dnc = MockDayNightCycle.new()
	add_child(_dnc)
	_lighting = MockLightingManager.new()
	add_child(_lighting)
	_player = MockPlayer.new()
	add_child(_player)
	_registry = MockPropRegistry.new()
	add_child(_registry)

	# Register shelter + thornback defs so FaunaManager can read shelter
	# tags and per-species spawn/movement/behavior config from PropRegistry.
	_registry.add_def(_make_shelter_def())
	_registry.add_def(_make_thornback_def())

	_fm = _FaunaManager.new()
	_fm._grid = _grid
	_fm._dnc = _dnc
	_fm._lighting = _lighting
	_fm._registry = _registry
	_fm._player = _player
	_player.add_child(_fm)


func after_test() -> void:
	_player.remove_child(_fm)
	_fm.queue_free()
	remove_child(_player)
	_player.queue_free()
	remove_child(_grid)
	_grid.queue_free()
	remove_child(_dnc)
	_dnc.queue_free()
	remove_child(_lighting)
	_lighting.queue_free()
	remove_child(_registry)
	_registry.queue_free()


# =========================================================================
# SPAWN VALIDATION TESTS
# =========================================================================

func test_no_spawn_before_day_4() -> void:
	_setup_spawn_grid()
	_dnc.day_count = 3
	_dnc.set_night()
	_dnc.night.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_spawn_on_day_4() -> void:
	_setup_spawn_grid()
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	assert_bool(fauna.size() >= 1 and fauna.size() <= 3).is_true()


func test_spawn_on_day_5_plus() -> void:
	_setup_spawn_grid()
	_dnc.day_count = 10
	_dnc.set_night()
	_dnc.night.emit()
	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	assert_bool(fauna.size() >= 1 and fauna.size() <= 3).is_true()


func test_spawn_not_on_water() -> void:
	# All tiles at distance 3+ are water
	for q in range(-2, 3):
		for r in range(-2, 3):
			if HexMath.distance(Vector2i.ZERO, Vector2i(q, r)) <= 2:
				_add_tile(Vector2i(q, r))
	for q in range(-5, 6):
		for r in range(-5, 6):
			var coords := Vector2i(q, r)
			var dist := HexMath.distance(Vector2i.ZERO, coords)
			if dist >= 3 and dist <= 5:
				if not _grid._tiles.has(coords):
					_add_tile(coords, _HexTile.Biome.WATER)
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_spawn_not_on_tile_with_structure() -> void:
	_setup_spawn_grid()
	# Add a structure tag to all far tiles
	for coords: Vector2i in _grid._tiles:
		if HexMath.distance(Vector2i.ZERO, coords) >= 3:
			var tile: Resource = _grid._tiles[coords]
			var structure := _Prop.create_structure(&"P00106")
			tile.props.append(structure)
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_spawn_not_within_min_distance() -> void:
	# Only tiles at distance 1-2 (no tiles at distance 3+)
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(0, 1))
	_add_tile(Vector2i(2, 0))
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_spawn_not_in_lit_area() -> void:
	_setup_spawn_grid()
	_lighting._is_night = true
	# Place a light at origin with huge radius covering all tiles
	_lighting.add_light(Vector2.ZERO, 100.0)
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_spawn_outside_lit_area() -> void:
	_setup_spawn_grid()
	_lighting._is_night = true
	# Small light that only covers origin area (radius ~4 world units)
	_lighting.add_light(Vector2.ZERO, 4.0)
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	# Some fauna should spawn in dark tiles far from origin
	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	assert_bool(fauna.size() >= 1).is_true()


func test_spawn_emits_signal() -> void:
	_setup_spawn_grid()
	var spawned: Array = []
	_fm.fauna_spawned.connect(func(id: int, coords: Vector2i, species: StringName) -> void:
		spawned.append({"id": id, "coords": coords, "species": species})
	)
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	assert_bool(spawned.size() >= 1).is_true()
	assert_str(str(spawned[0]["species"])).is_equal("P00108")


func test_spawn_fauna_have_correct_hp() -> void:
	_setup_spawn_grid()
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	for f: Dictionary in fauna:
		assert_int(f["hp"]).is_equal(20)


func test_spawn_fauna_species_is_p00108() -> void:
	_setup_spawn_grid()
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	for f: Dictionary in fauna:
		assert_str(str(f["species_type"])).is_equal("P00108")


# =========================================================================
# AI MOVEMENT TESTS
# =========================================================================

func test_movement_toward_player() -> void:
	# Create a line of tiles: player at (0,0), fauna at (2,0)
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_player.current_tile = Vector2i(0, 0)

	# Manually inject fauna at (2,0) — within detection range 2
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.set_night()
	# Process with enough delta to trigger movement
	_fm._process(1.0)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	assert_int(fauna.size()).is_equal(1)
	# Should have moved closer (to distance 1 from player)
	var dist: int = HexMath.distance(fauna[0]["coords"], Vector2i(0, 0))
	assert_int(dist).is_equal(1)


func test_movement_blocked_by_wall() -> void:
	_add_tile(Vector2i(0, 0))
	var wall_tile := _add_tile(Vector2i(1, 0))
	var wall := _Prop.create_structure(&"P00106")
	wall_tile.props.append(wall)
	_add_tile(Vector2i(2, 0))
	# Add alternative path tiles
	_add_tile(Vector2i(1, -1))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.set_night()
	_fm._process(1.0)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	# Should NOT have moved to (1,0) because wall blocks
	assert_bool(fauna[0]["coords"] != Vector2i(1, 0)).is_true()


func test_movement_avoids_lit_tiles() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_add_tile(Vector2i(1, -1))
	_player.current_tile = Vector2i(0, 0)

	# Light covers tile (1,0) — the direct path
	_lighting._is_night = true
	var world_pos := HexMath.axial_to_world(Vector2i(1, 0))
	_lighting.add_light(world_pos, 1.0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.set_night()
	_fm._process(1.0)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	# Should NOT be on the lit tile (1,0)
	assert_bool(fauna[0]["coords"] != Vector2i(1, 0)).is_true()


func test_no_stacking_on_same_tile() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_add_tile(Vector2i(1, -1))
	_player.current_tile = Vector2i(0, 0)

	# Two fauna at distance 2
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})
	_fm._fauna.append({
		"id": 1, "species_type": _THORNBACK_ID, "coords": Vector2i(1, -1),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.set_night()
	_fm._process(1.0)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	# No two fauna on the same tile
	var coords_set: Dictionary = {}
	for f: Dictionary in fauna:
		assert_bool(coords_set.has(f["coords"])).is_false()
		coords_set[f["coords"]] = true


func test_movement_only_during_night() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.set_day()
	_fm._process(1.0)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	# Should NOT have moved during day
	assert_bool(fauna[0]["coords"] == Vector2i(2, 0)).is_true()


func test_movement_respects_cooldown() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.5,
		"was_in_light": false,
	})

	_dnc.set_night()
	# Process with small delta (not enough to trigger move)
	_fm._process(0.3)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	assert_bool(fauna[0]["coords"] == Vector2i(2, 0)).is_true()


func test_movement_outside_detection_range_no_move() -> void:
	# Create tiles with fauna at distance 3 (outside detection_range of 2)
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_add_tile(Vector2i(3, 0))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.set_night()
	_fm._process(1.0)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	assert_bool(fauna[0]["coords"] == Vector2i(3, 0)).is_true()


func test_movement_emits_signal() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var moved: Array = []
	_fm.fauna_moved.connect(func(id: int, old_c: Vector2i, new_c: Vector2i, species: StringName) -> void:
		moved.append({"id": id, "old": old_c, "new": new_c, "species": species})
	)

	_dnc.set_night()
	_fm._process(1.0)

	assert_int(moved.size()).is_equal(1)
	assert_bool(moved[0]["old"] == Vector2i(2, 0)).is_true()


func test_elevation_diff_blocks_fauna() -> void:
	_add_tile(Vector2i(0, 0), _HexTile.Biome.GRASSLAND, 0)
	_add_tile(Vector2i(1, 0), _HexTile.Biome.GRASSLAND, 3)  # elevation diff = 3 > max_jump 1
	_add_tile(Vector2i(2, 0), _HexTile.Biome.GRASSLAND, 0)
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.set_night()
	_fm._process(1.0)

	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	# (1,0) has elevation diff 3 from (2,0), so fauna can't move there
	assert_bool(fauna[0]["coords"] != Vector2i(1, 0)).is_true()


# =========================================================================
# CONTACT DAMAGE TESTS
# =========================================================================

func test_contact_damage_when_adjacent() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(1, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var attacks: Array = []
	_fm.fauna_attacked_player.connect(func(id: int, damage: int, species: StringName) -> void:
		attacks.append({"id": id, "damage": damage, "species": species})
	)

	_dnc.set_night()
	_fm._process(1.0)

	assert_bool(attacks.size() >= 1).is_true()
	assert_int(attacks[0]["damage"]).is_equal(10)


func test_shelter_immunity() -> void:
	var player_tile := _add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_player.current_tile = Vector2i(0, 0)

	# Place shelter prop on player tile
	var shelter := _Prop.create_structure(&"P00102")
	player_tile.props.append(shelter)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(1, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var attacks: Array = []
	_fm.fauna_attacked_player.connect(func(id: int, damage: int, species: StringName) -> void:
		attacks.append({"id": id, "damage": damage, "species": species})
	)

	_dnc.set_night()
	_fm._process(1.0)

	# Signal still fires but damage is 0
	assert_bool(attacks.size() >= 1).is_true()
	assert_int(attacks[0]["damage"]).is_equal(0)


func test_contact_damage_is_move_only() -> void:
	# Fauna already adjacent but cooldown not expired — no contact damage yet
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(1, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.5,
		"was_in_light": false,
	})

	var attacks: Array = []
	_fm.fauna_attacked_player.connect(func(id: int, damage: int, species: StringName) -> void:
		attacks.append({"id": id, "damage": damage, "species": species})
	)

	_dnc.set_night()
	# Small delta — cooldown won't expire, so no processing of movement happens
	_fm._process(0.3)
	assert_int(attacks.size()).is_equal(0)


func test_contact_damage_signal_includes_species() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_player.current_tile = Vector2i(0, 0)

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(1, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var attacks: Array = []
	_fm.fauna_attacked_player.connect(func(id: int, damage: int, species: StringName) -> void:
		attacks.append({"species": species})
	)

	_dnc.set_night()
	_fm._process(1.0)

	assert_bool(attacks.size() >= 1).is_true()
	assert_str(str(attacks[0]["species"])).is_equal("P00108")


# =========================================================================
# APPLY DAMAGE + DEATH TESTS
# =========================================================================

func test_apply_damage_reduces_hp() -> void:
	_add_tile(Vector2i(3, 3))

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_fm.apply_damage(0, 5)
	var fauna: Array[Dictionary] = _fm.get_all_fauna()
	assert_int(fauna[0]["hp"]).is_equal(15)


func test_apply_damage_death_at_zero() -> void:
	_add_tile(Vector2i(3, 3))

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_fm.apply_damage(0, 20)
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_apply_damage_death_below_zero() -> void:
	_add_tile(Vector2i(3, 3))

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_fm.apply_damage(0, 30)
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_death_emits_fauna_killed() -> void:
	_add_tile(Vector2i(3, 3))

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var killed: Array = []
	_fm.fauna_killed.connect(func(id: int, coords: Vector2i, species: StringName) -> void:
		killed.append({"id": id, "coords": coords, "species": species})
	)

	_fm.apply_damage(0, 20)
	assert_int(killed.size()).is_equal(1)
	assert_int(killed[0]["id"]).is_equal(0)
	assert_bool(killed[0]["coords"] == Vector2i(3, 3)).is_true()
	assert_str(str(killed[0]["species"])).is_equal("P00108")


func test_death_places_corpse_prop() -> void:
	var tile := _add_tile(Vector2i(3, 3))

	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var props_before: int = tile.props.size()
	_fm.apply_damage(0, 20)
	assert_int(tile.props.size()).is_equal(props_before + 1)
	assert_str(str(tile.props[tile.props.size() - 1].type)).is_equal("P00107")


func test_apply_damage_invalid_id() -> void:
	_fm.apply_damage(999, 10)
	# Should not crash — no-op for invalid id
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


# =========================================================================
# DESPAWN TESTS
# =========================================================================

func test_despawn_on_dawn() -> void:
	_setup_spawn_grid()
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	var count_before: int = _fm.get_all_fauna().size()
	assert_bool(count_before >= 1).is_true()

	_dnc.dawn.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_despawn_emits_signal_per_fauna() -> void:
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})
	_fm._fauna.append({
		"id": 1, "species_type": _THORNBACK_ID, "coords": Vector2i(4, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var despawned: Array = []
	_fm.fauna_despawned.connect(func(id: int, coords: Vector2i, species: StringName) -> void:
		despawned.append({"id": id, "coords": coords, "species": species})
	)

	_dnc.dawn.emit()
	assert_int(despawned.size()).is_equal(2)


func test_despawn_clears_all_fauna() -> void:
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})
	_fm._fauna.append({
		"id": 1, "species_type": _THORNBACK_ID, "coords": Vector2i(4, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	_dnc.dawn.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


# =========================================================================
# PUBLIC QUERY API TESTS
# =========================================================================

func test_get_fauna_at_returns_correct() -> void:
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})
	_fm._fauna.append({
		"id": 1, "species_type": _THORNBACK_ID, "coords": Vector2i(4, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var at_3_3: Array[Dictionary] = _fm.get_fauna_at(Vector2i(3, 3))
	assert_int(at_3_3.size()).is_equal(1)
	assert_int(at_3_3[0]["id"]).is_equal(0)


func test_get_fauna_at_empty() -> void:
	var result: Array[Dictionary] = _fm.get_fauna_at(Vector2i(99, 99))
	assert_int(result.size()).is_equal(0)


func test_get_fauna_adjacent_to() -> void:
	# Fauna at (1,0) is adjacent to (0,0)
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(1, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})
	# Fauna at (3,0) is NOT adjacent to (0,0)
	_fm._fauna.append({
		"id": 1, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var adjacent: Array[Dictionary] = _fm.get_fauna_adjacent_to(Vector2i(0, 0))
	assert_int(adjacent.size()).is_equal(1)
	assert_int(adjacent[0]["id"]).is_equal(0)


func test_get_all_fauna_returns_copies() -> void:
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var all: Array[Dictionary] = _fm.get_all_fauna()
	all[0]["hp"] = 999
	# Original should not be modified
	assert_int(_fm._fauna[0]["hp"]).is_equal(20)


func test_get_all_fauna_size() -> void:
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(3, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})
	_fm._fauna.append({
		"id": 1, "species_type": _THORNBACK_ID, "coords": Vector2i(4, 3),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	assert_int(_fm.get_all_fauna().size()).is_equal(2)


# =========================================================================
# SURPRISE ENCOUNTER TESTS
# =========================================================================

func test_surprise_encounter_from_darkness() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_player.current_tile = Vector2i(0, 0)

	# No lights — fauna approaches from total darkness
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": false,
	})

	var surprises: Array = []
	_fm.fauna_surprise_encounter.connect(func(id: int, coords: Vector2i, species: StringName) -> void:
		surprises.append({"id": id, "coords": coords, "species": species})
	)

	_dnc.set_night()
	_fm._process(1.0)

	assert_int(surprises.size()).is_equal(1)
	assert_str(str(surprises[0]["species"])).is_equal("P00108")


func test_no_surprise_when_was_in_light() -> void:
	_add_tile(Vector2i(0, 0))
	_add_tile(Vector2i(1, 0))
	_add_tile(Vector2i(2, 0))
	_player.current_tile = Vector2i(0, 0)

	# Fauna was already in light (visible to player)
	_fm._fauna.append({
		"id": 0, "species_type": _THORNBACK_ID, "coords": Vector2i(2, 0),
		"hp": 20, "move_cooldown": 1.0, "cooldown_remaining": 0.0,
		"was_in_light": true,
	})

	var surprises: Array = []
	_fm.fauna_surprise_encounter.connect(func(id: int, coords: Vector2i, species: StringName) -> void:
		surprises.append({"id": id})
	)

	_dnc.set_night()
	_fm._process(1.0)

	assert_int(surprises.size()).is_equal(0)


# =========================================================================
# EDGE CASES
# =========================================================================

func test_empty_grid_no_crash() -> void:
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_process_with_no_fauna_no_crash() -> void:
	_dnc.set_night()
	_fm._process(1.0)
	assert_int(_fm.get_all_fauna().size()).is_equal(0)


func test_multiple_spawn_cycles() -> void:
	_setup_spawn_grid()
	_dnc.day_count = 4
	_dnc.set_night()
	_dnc.night.emit()
	var first_count: int = _fm.get_all_fauna().size()
	assert_bool(first_count >= 1).is_true()

	# Dawn clears them
	_dnc.dawn.emit()
	assert_int(_fm.get_all_fauna().size()).is_equal(0)

	# Next night spawns fresh
	_dnc.day_count = 5
	_dnc.night.emit()
	assert_bool(_fm.get_all_fauna().size() >= 1).is_true()
