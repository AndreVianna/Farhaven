class_name TestPredicateEvaluator
extends GdUnitTestSuite

## Unit tests for PredicateEvaluator (task-048).
## Tests every predicate kind, both true and false branches.

const _PredicateEvaluator = preload("res://scripts/recipes/predicate_evaluator.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _StationCap = preload("res://scripts/data/capabilities/station_cap.gd")
const _ContainerCap = preload("res://scripts/data/capabilities/container_cap.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")


# ---------------------------------------------------------------------------
# Minimal fakes
# ---------------------------------------------------------------------------

class FakeGrid extends Node:
	var _tiles: Dictionary = {}
	signal map_generated()
	signal tile_entered(coords: Vector2i)
	signal tile_exited(coords: Vector2i)
	signal prop_depleted(coords: Vector2i, prop_type: StringName)
	signal prop_respawned(coords: Vector2i, prop_type: StringName)
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	func get_tile(coords: Vector2i):
		return _tiles.get(coords, null)

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
	var inventory = null

	func get_inventory():
		return inventory


class FakeSurvivalSystem extends Node:
	var hp: float = 100.0
	var hunger: float = 80.0
	var thirst: float = 60.0


class FakeDayNight extends Node:
	## 0=DAY, 1=DUSK, 2=NIGHT, 3=DAWN
	var current_phase: int = 0


class FakeCatalog extends RefCounted:
	var _cataloged: Dictionary = {}

	func catalog_entry(entry_id: StringName) -> void:
		_cataloged[entry_id] = true

	func is_cataloged(entry_id: StringName) -> bool:
		return _cataloged.get(entry_id, false)


## A prop with dynamic instance state (e.g. is_lit for fireplace).
class StatefulProp extends Resource:
	var type: StringName = &""
	var sub_hex: Vector2i = Vector2i.ZERO
	var category: int = 0
	var origin: int = 0
	var is_lit: bool = false
	var container_items: Array = []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_predicate(p_kind: StringName, p_params: Dictionary = {}) -> _Predicate:
	var pred := _Predicate.new()
	pred.kind = p_kind
	pred.params = p_params
	return pred


func _make_ctx() -> _WorldContext:
	return _WorldContext.new()


func _make_tile(biome: int = 1, coords: Vector2i = Vector2i.ZERO) -> _HexTile:
	var tile := _HexTile.new()
	tile.biome = biome
	tile.coords = coords
	return tile


func _make_player_with_inventory() -> FakePlayer:
	var player := FakePlayer.new()
	player.inventory = _Inventory.new()
	add_child(player)
	return player


func _register_fake_def(id: StringName, tool_slot: StringName = &"", tags: Array[StringName] = [], station_tags: Array[StringName] = []) -> void:
	var def := _PropDef.new()
	def.id = id
	def.tool_slot = tool_slot
	def.tags = tags
	if not station_tags.is_empty():
		var cap := _StationCap.new()
		cap.station_tags = station_tags
		def.station = cap
	PropRegistry._defs[id] = def


# ---------------------------------------------------------------------------
# has_tool tests
# ---------------------------------------------------------------------------

func test_has_tool_matching_slot() -> void:
	_register_fake_def(&"test_axe", &"axe")
	var player := _make_player_with_inventory()
	player.inventory.set_tool(&"axe", &"test_axe")
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"has_tool", {"tool": &"axe"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	player.queue_free()


func test_has_tool_matching_id() -> void:
	_register_fake_def(&"test_axe", &"axe")
	var player := _make_player_with_inventory()
	player.inventory.set_tool(&"axe", &"test_axe")
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"has_tool", {"tool": &"test_axe"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	player.queue_free()


func test_has_tool_wrong_tool() -> void:
	_register_fake_def(&"test_axe", &"axe")
	var player := _make_player_with_inventory()
	player.inventory.set_tool(&"axe", &"test_axe")
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"has_tool", {"tool": &"pickaxe"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()
	player.queue_free()


func test_has_tool_no_player() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"has_tool", {"tool": &"axe"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_has_tool_no_tool_equipped() -> void:
	var player := _make_player_with_inventory()
	player.inventory.set_tool(&"axe", &"")
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"has_tool", {"tool": &"axe"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()
	player.queue_free()


# ---------------------------------------------------------------------------
# at_station tests
# ---------------------------------------------------------------------------

func test_at_station_matching_tag() -> void:
	_register_fake_def(&"fireplace", &"", [], [&"cook", &"fire", &"light"])
	var station := _Prop.create_structure(&"fireplace")
	var ctx := _make_ctx()
	ctx.station = station
	var pred := _make_predicate(&"at_station", {"tag": &"cook"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_at_station_wrong_tag() -> void:
	_register_fake_def(&"fireplace", &"", [], [&"cook", &"fire", &"light"])
	var station := _Prop.create_structure(&"fireplace")
	var ctx := _make_ctx()
	ctx.station = station
	var pred := _make_predicate(&"at_station", {"tag": &"craft"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_at_station_no_station() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"at_station", {"tag": &"cook"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_at_station_no_station_cap() -> void:
	# A prop without StationCap
	_register_fake_def(&"log", &"", [], [])
	var station := _Prop.create_structure(&"log")
	var ctx := _make_ctx()
	ctx.station = station
	var pred := _make_predicate(&"at_station", {"tag": &"cook"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


# ---------------------------------------------------------------------------
# at_tile_type tests
# ---------------------------------------------------------------------------

func test_at_tile_type_matching() -> void:
	var tile := _make_tile(_HexTile.Biome.FOREST)
	var ctx := _make_ctx()
	ctx.tile = tile
	var pred := _make_predicate(&"at_tile_type", {"tag": &"forest"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_at_tile_type_wrong() -> void:
	var tile := _make_tile(_HexTile.Biome.GRASSLAND)
	var ctx := _make_ctx()
	ctx.tile = tile
	var pred := _make_predicate(&"at_tile_type", {"tag": &"forest"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_at_tile_type_no_tile() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"at_tile_type", {"tag": &"forest"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


# ---------------------------------------------------------------------------
# player_stat tests
# ---------------------------------------------------------------------------

func test_player_stat_ge_true() -> void:
	var player := FakePlayer.new()
	add_child(player)
	var survival := FakeSurvivalSystem.new()
	survival.hp = 50.0
	player.add_child(survival)
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"player_stat", {"stat": &"hp", "op": &"ge", "value": 20.0})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	player.queue_free()


func test_player_stat_ge_false() -> void:
	var player := FakePlayer.new()
	add_child(player)
	var survival := FakeSurvivalSystem.new()
	survival.hp = 10.0
	player.add_child(survival)
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"player_stat", {"stat": &"hp", "op": &"ge", "value": 20.0})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()
	player.queue_free()


func test_player_stat_lt_true() -> void:
	var player := FakePlayer.new()
	add_child(player)
	var survival := FakeSurvivalSystem.new()
	survival.hunger = 30.0
	player.add_child(survival)
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"player_stat", {"stat": &"hunger", "op": &"lt", "value": 50.0})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	player.queue_free()


func test_player_stat_no_player() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"player_stat", {"stat": &"hp", "op": &"ge", "value": 20.0})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_player_stat_unknown_stat() -> void:
	var player := FakePlayer.new()
	add_child(player)
	var survival := FakeSurvivalSystem.new()
	player.add_child(survival)
	var ctx := _make_ctx()
	ctx.player = player
	var pred := _make_predicate(&"player_stat", {"stat": &"mana", "op": &"ge", "value": 10.0})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()
	player.queue_free()


# ---------------------------------------------------------------------------
# player_skill tests (STUB)
# ---------------------------------------------------------------------------

func test_player_skill_stub_returns_false() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"player_skill", {"skill": &"mining", "op": &"ge", "value": 5.0})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


# ---------------------------------------------------------------------------
# player_knows_recipe tests (STUB — returns true)
# ---------------------------------------------------------------------------

func test_player_knows_recipe_stub_returns_true() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"player_knows_recipe", {"recipe_id": &"cook_meat"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


# ---------------------------------------------------------------------------
# time_of_day tests
# ---------------------------------------------------------------------------

func test_time_of_day_matching_phase() -> void:
	var day_night := FakeDayNight.new()
	day_night.current_phase = 2  # NIGHT
	add_child(day_night)
	var ctx := _make_ctx()
	ctx.day_night = day_night
	var pred := _make_predicate(&"time_of_day", {"phase": &"night"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	day_night.queue_free()


func test_time_of_day_wrong_phase() -> void:
	var day_night := FakeDayNight.new()
	day_night.current_phase = 0  # DAY
	add_child(day_night)
	var ctx := _make_ctx()
	ctx.day_night = day_night
	var pred := _make_predicate(&"time_of_day", {"phase": &"night"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()
	day_night.queue_free()


func test_time_of_day_no_day_night() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"time_of_day", {"phase": &"night"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_time_of_day_case_insensitive() -> void:
	var day_night := FakeDayNight.new()
	day_night.current_phase = 3  # DAWN
	add_child(day_night)
	var ctx := _make_ctx()
	ctx.day_night = day_night
	var pred := _make_predicate(&"time_of_day", {"phase": &"DAWN"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	day_night.queue_free()


# ---------------------------------------------------------------------------
# weather tests (STUB)
# ---------------------------------------------------------------------------

func test_weather_stub_returns_false() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"weather", {"type": &"rain"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


# ---------------------------------------------------------------------------
# biome tests
# ---------------------------------------------------------------------------

func test_biome_matching() -> void:
	var tile := _make_tile(_HexTile.Biome.ROCKY)
	var ctx := _make_ctx()
	ctx.tile = tile
	var pred := _make_predicate(&"biome", {"tag": &"rocky"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_biome_wrong() -> void:
	var tile := _make_tile(_HexTile.Biome.WATER)
	var ctx := _make_ctx()
	ctx.tile = tile
	var pred := _make_predicate(&"biome", {"tag": &"forest"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_biome_no_tile() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"biome", {"tag": &"forest"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_biome_case_insensitive() -> void:
	var tile := _make_tile(_HexTile.Biome.CRASH_SITE)
	var ctx := _make_ctx()
	ctx.tile = tile
	var pred := _make_predicate(&"biome", {"tag": &"CRASH_SITE"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


# ---------------------------------------------------------------------------
# adjacent_to tests
# ---------------------------------------------------------------------------

func test_adjacent_to_matching_biome() -> void:
	var grid := FakeGrid.new()
	add_child(grid)
	var center := _make_tile(_HexTile.Biome.GRASSLAND, Vector2i(0, 0))
	var neighbor := _make_tile(_HexTile.Biome.FOREST, Vector2i(1, 0))
	grid._tiles[Vector2i(0, 0)] = center
	grid._tiles[Vector2i(1, 0)] = neighbor
	var ctx := _make_ctx()
	ctx.tile = center
	ctx.grid = grid
	var pred := _make_predicate(&"adjacent_to", {"tag": &"forest", "count_ge": 1})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	grid.queue_free()


func test_adjacent_to_not_enough_matches() -> void:
	var grid := FakeGrid.new()
	add_child(grid)
	var center := _make_tile(_HexTile.Biome.GRASSLAND, Vector2i(0, 0))
	var neighbor := _make_tile(_HexTile.Biome.FOREST, Vector2i(1, 0))
	grid._tiles[Vector2i(0, 0)] = center
	grid._tiles[Vector2i(1, 0)] = neighbor
	var ctx := _make_ctx()
	ctx.tile = center
	ctx.grid = grid
	var pred := _make_predicate(&"adjacent_to", {"tag": &"forest", "count_ge": 3})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()
	grid.queue_free()


func test_adjacent_to_no_grid() -> void:
	var tile := _make_tile(_HexTile.Biome.GRASSLAND)
	var ctx := _make_ctx()
	ctx.tile = tile
	var pred := _make_predicate(&"adjacent_to", {"tag": &"forest", "count_ge": 1})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_adjacent_to_matching_prop_tag() -> void:
	_register_fake_def(&"big_tree", &"", [&"WOOD"])
	var grid := FakeGrid.new()
	add_child(grid)
	var center := _make_tile(_HexTile.Biome.GRASSLAND, Vector2i(0, 0))
	var neighbor := _make_tile(_HexTile.Biome.GRASSLAND, Vector2i(1, 0))
	neighbor.props = [_Prop.create_prop(&"big_tree", 1, 1)]
	grid._tiles[Vector2i(0, 0)] = center
	grid._tiles[Vector2i(1, 0)] = neighbor
	var ctx := _make_ctx()
	ctx.tile = center
	ctx.grid = grid
	var pred := _make_predicate(&"adjacent_to", {"tag": &"WOOD", "count_ge": 1})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()
	grid.queue_free()


# ---------------------------------------------------------------------------
# prop_state tests
# ---------------------------------------------------------------------------

func test_prop_state_is_lit_true() -> void:
	var fireplace := StatefulProp.new()
	fireplace.type = &"fireplace"
	fireplace.is_lit = true
	var tile := _make_tile()
	tile.props = [fireplace]
	var ctx := _make_ctx()
	ctx.tile = tile
	ctx.station = fireplace
	var pred := _make_predicate(&"prop_state", {
		"prop": &"fireplace", "field": &"is_lit", "op": &"eq", "value": true
	})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_prop_state_is_lit_false() -> void:
	var fireplace := StatefulProp.new()
	fireplace.type = &"fireplace"
	fireplace.is_lit = false
	var tile := _make_tile()
	tile.props = [fireplace]
	var ctx := _make_ctx()
	ctx.tile = tile
	ctx.station = fireplace
	var pred := _make_predicate(&"prop_state", {
		"prop": &"fireplace", "field": &"is_lit", "op": &"eq", "value": true
	})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_prop_state_no_matching_prop() -> void:
	var tile := _make_tile()
	tile.props = []
	var ctx := _make_ctx()
	ctx.tile = tile
	var pred := _make_predicate(&"prop_state", {
		"prop": &"fireplace", "field": &"is_lit", "op": &"eq", "value": true
	})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_prop_state_ne_operator() -> void:
	var fireplace := StatefulProp.new()
	fireplace.type = &"fireplace"
	fireplace.is_lit = false
	var tile := _make_tile()
	tile.props = [fireplace]
	var ctx := _make_ctx()
	ctx.tile = tile
	ctx.station = fireplace
	var pred := _make_predicate(&"prop_state", {
		"prop": &"fireplace", "field": &"is_lit", "op": &"ne", "value": true
	})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


# ---------------------------------------------------------------------------
# world_flag tests
# ---------------------------------------------------------------------------

func test_world_flag_matching() -> void:
	var ctx := _make_ctx()
	ctx.world_flags = {&"completed_quest_alpha": true}
	var pred := _make_predicate(&"world_flag", {"name": &"completed_quest_alpha", "value": true})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_world_flag_wrong_value() -> void:
	var ctx := _make_ctx()
	ctx.world_flags = {&"completed_quest_alpha": false}
	var pred := _make_predicate(&"world_flag", {"name": &"completed_quest_alpha", "value": true})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_world_flag_missing() -> void:
	var ctx := _make_ctx()
	ctx.world_flags = {}
	var pred := _make_predicate(&"world_flag", {"name": &"completed_quest_alpha", "value": true})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_world_flag_string_value() -> void:
	var ctx := _make_ctx()
	ctx.world_flags = {&"season": "winter"}
	var pred := _make_predicate(&"world_flag", {"name": &"season", "value": "winter"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


# ---------------------------------------------------------------------------
# animal_nearby tests (STUB)
# ---------------------------------------------------------------------------

func test_animal_nearby_stub_returns_false() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"animal_nearby", {"radius": 2, "filter": &"small_fauna"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


# ---------------------------------------------------------------------------
# container_has tests
# ---------------------------------------------------------------------------

func test_container_has_enough() -> void:
	_register_fake_def(&"log", &"", [&"BURNABLE.log"])
	var container := StatefulProp.new()
	container.type = &"container"
	container.container_items = [
		{"type": &"log", "quantity": 3},
	]
	var ctx := _make_ctx()
	ctx.container = container
	var pred := _make_predicate(&"container_has", {"ref_or_tag": &"log", "count_ge": 2})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_container_has_not_enough() -> void:
	_register_fake_def(&"log", &"", [&"BURNABLE.log"])
	var container := StatefulProp.new()
	container.type = &"container"
	container.container_items = [
		{"type": &"log", "quantity": 1},
	]
	var ctx := _make_ctx()
	ctx.container = container
	var pred := _make_predicate(&"container_has", {"ref_or_tag": &"log", "count_ge": 5})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_container_has_by_tag() -> void:
	_register_fake_def(&"log", &"", [&"BURNABLE"])
	var container := StatefulProp.new()
	container.type = &"container"
	container.container_items = [
		{"type": &"log", "quantity": 2},
	]
	var ctx := _make_ctx()
	ctx.container = container
	var pred := _make_predicate(&"container_has", {"ref_or_tag": &"BURNABLE", "count_ge": 1})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_container_has_empty_container() -> void:
	var container := StatefulProp.new()
	container.type = &"container"
	container.container_items = []
	var ctx := _make_ctx()
	ctx.container = container
	var pred := _make_predicate(&"container_has", {"ref_or_tag": &"log", "count_ge": 1})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_container_has_no_container() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"container_has", {"ref_or_tag": &"log", "count_ge": 1})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_container_has_via_station() -> void:
	_register_fake_def(&"log", &"", [&"BURNABLE.log"])
	var station := StatefulProp.new()
	station.type = &"fireplace"
	station.container_items = [
		{"type": &"log", "quantity": 2},
	]
	var ctx := _make_ctx()
	ctx.station = station
	# No explicit container — should fall back to station
	var pred := _make_predicate(&"container_has", {"ref_or_tag": &"log", "count_ge": 1})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


# ---------------------------------------------------------------------------
# cataloged tests
# ---------------------------------------------------------------------------

func test_cataloged_known_entry() -> void:
	var catalog := FakeCatalog.new()
	catalog.catalog_entry(&"berry")
	var ctx := _make_ctx()
	ctx.catalog = catalog
	var pred := _make_predicate(&"cataloged", {"prop": &"berry"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_true()


func test_cataloged_unknown_entry() -> void:
	var catalog := FakeCatalog.new()
	var ctx := _make_ctx()
	ctx.catalog = catalog
	var pred := _make_predicate(&"cataloged", {"prop": &"rare_mushroom"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


func test_cataloged_no_catalog() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"cataloged", {"prop": &"berry"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


# ---------------------------------------------------------------------------
# Unknown predicate kind
# ---------------------------------------------------------------------------

func test_unknown_kind_returns_false() -> void:
	var ctx := _make_ctx()
	var pred := _make_predicate(&"nonexistent_predicate", {"foo": "bar"})
	assert_bool(_PredicateEvaluator.evaluate(pred, ctx)).is_false()


# ---------------------------------------------------------------------------
# Cleanup: remove fake PropDefs we registered
# ---------------------------------------------------------------------------

func after_test() -> void:
	for key: StringName in [&"test_axe", &"fireplace", &"log", &"big_tree"]:
		PropRegistry._defs.erase(key)
