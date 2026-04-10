class_name TestRecipeRuntime
extends GdUnitTestSuite

## Unit tests for RecipeRuntime (task-050).

const _RecipeRuntime = preload("res://scripts/recipes/recipe_runtime.gd")
const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
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


class FakePlayer extends Node3D:
	var inventory = null

	func get_inventory():
		return inventory


class FakeSurvivalSystem extends Node:
	var hp: float = 100.0
	var hunger: float = 50.0
	var thirst: float = 50.0


class FakeRegistry extends Node:
	func get_all_recipes() -> Array:
		return []


# A prop with dynamic instance state.
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


var _runtime: Node
var _discovery: FakeDiscovery
var _registry: FakeRegistry
## Deterministic random value for output probability tests.
var _mock_random_value: float = 0.0


func _mock_randf() -> float:
	return _mock_random_value


func _make_recipe(id: StringName, time: float = 0.0) -> _Recipe:
	var r := _Recipe.new()
	r.id = id
	r.kind = _Recipe.Kind.TRANSFORM
	r.duration = time
	return r


func _make_input(ref: StringName, count: int = 1, source: StringName = &"player_inventory", is_tag: bool = false) -> _RecipeInput:
	var inp := _RecipeInput.new()
	inp.ref_or_tag = ref
	inp.count = count
	inp.source = source
	inp.is_tag = is_tag
	return inp


func _make_output(ref: StringName, count: int = 1, prob: float = 1.0) -> _RecipeOutput:
	var out := _RecipeOutput.new()
	out.prop_ref = ref
	out.count = count
	out.prob = prob
	return out


func _make_effect(kind: StringName, params: Dictionary = {}) -> _RecipeEffect:
	var eff := _RecipeEffect.new()
	eff.kind = kind
	eff.params = params
	return eff


func _make_condition(p_kind: StringName, p_params: Dictionary = {}, sustain: bool = false) -> _RecipeCondition:
	var cond := _RecipeCondition.new()
	var pred := _Predicate.new()
	pred.kind = p_kind
	pred.params = p_params
	cond.predicate = pred
	cond.must_sustain = sustain
	return cond


func _make_ctx_with_inventory(items: Dictionary = {}) -> Array:
	## Returns [ctx, player] — caller must free player.
	var player := FakePlayer.new()
	player.inventory = _Inventory.new()
	add_child(player)
	for type: StringName in items:
		_ensure_prop_def(type)
		player.inventory.add_item(type, items[type])
	var ctx := _WorldContext.new()
	ctx.player = player
	return [ctx, player]


func _ensure_prop_def(id: StringName) -> void:
	if PropRegistry.get_def(id) != null:
		return
	var def := _PropDef.new()
	def.id = id
	def.max_stack = 99
	var cap := _PortableCap.new()
	cap.weight = 0.1
	def.portable = cap
	PropRegistry._defs[id] = def


func _cleanup_prop_defs(ids: Array) -> void:
	for id: StringName in ids:
		PropRegistry._defs.erase(id)


func before_test() -> void:
	_discovery = FakeDiscovery.new()
	add_child(_discovery)
	_registry = FakeRegistry.new()
	add_child(_registry)
	_runtime = _RecipeRuntime.new()
	_runtime._registry = _registry
	_runtime._discovery = _discovery
	_runtime._rng = Callable(self, "_mock_randf")
	_mock_random_value = 0.0
	add_child(_runtime)


func after_test() -> void:
	if is_instance_valid(_runtime):
		_runtime.queue_free()
	if is_instance_valid(_discovery):
		_discovery.queue_free()
	if is_instance_valid(_registry):
		_registry.queue_free()
	_cleanup_prop_defs([&"berry", &"wood", &"branch", &"raw_meat", &"cooked_meat", &"trap", &"fiber", &"ash", &"scroll"])


# ---------------------------------------------------------------------------
# Tests: instant recipe (time=0)
# ---------------------------------------------------------------------------


func test_instant_recipe_resolves_immediately() -> void:
	var recipe := _make_recipe(&"eat_berry")
	recipe.inputs.append(_make_input(&"berry"))
	recipe.effects.append(_make_effect(&"stat_delta", {"stat": "hunger", "value": 5}))
	_discovery.set_known(&"eat_berry")

	var pair := _make_ctx_with_inventory({&"berry": 3})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()
	# Should resolve immediately — pending queue should be empty.
	assert_int(_runtime.get_pending().size()).is_equal(0)
	# Berry consumed.
	assert_int(player.inventory.get_count(&"berry")).is_equal(2)

	player.queue_free()


func test_instant_recipe_produces_outputs() -> void:
	_mock_random_value = 0.0  # Always pass prob check.
	var recipe := _make_recipe(&"craft_thing")
	recipe.inputs.append(_make_input(&"branch", 2))
	recipe.outputs.append(_make_output(&"trap", 1, 1.0))
	_discovery.set_known(&"craft_thing")

	_ensure_prop_def(&"trap")
	var pair := _make_ctx_with_inventory({&"branch": 5})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()
	# Inputs consumed.
	assert_int(player.inventory.get_count(&"branch")).is_equal(3)
	# Output added.
	assert_int(player.inventory.get_count(&"trap")).is_equal(1)

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: timed recipe enters pending queue
# ---------------------------------------------------------------------------


func test_timed_recipe_enters_pending_queue() -> void:
	var recipe := _make_recipe(&"cook_meat", 15.0)
	recipe.inputs.append(_make_input(&"raw_meat"))
	recipe.outputs.append(_make_output(&"cooked_meat"))
	_discovery.set_known(&"cook_meat")

	var pair := _make_ctx_with_inventory({&"raw_meat": 2})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()
	# Should be in pending queue.
	assert_int(_runtime.get_pending().size()).is_equal(1)
	# Input consumed immediately.
	assert_int(player.inventory.get_count(&"raw_meat")).is_equal(1)
	# Output NOT yet produced.
	assert_int(player.inventory.get_count(&"cooked_meat")).is_equal(0)

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: pending recipe resolves after time elapsed
# ---------------------------------------------------------------------------


func test_pending_recipe_resolves_after_time() -> void:
	_mock_random_value = 0.0
	var recipe := _make_recipe(&"cook_meat", 2.0)
	recipe.inputs.append(_make_input(&"raw_meat"))
	recipe.outputs.append(_make_output(&"cooked_meat"))
	_discovery.set_known(&"cook_meat")

	_ensure_prop_def(&"cooked_meat")
	var pair := _make_ctx_with_inventory({&"raw_meat": 1})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var _pending = _runtime.try_start_recipe(recipe, ctx)
	assert_int(_runtime.get_pending().size()).is_equal(1)

	# Simulate time passing.
	_runtime._process(1.0)
	assert_int(_runtime.get_pending().size()).is_equal(1)  # Not yet.
	assert_int(player.inventory.get_count(&"cooked_meat")).is_equal(0)

	_runtime._process(1.5)  # Total: 2.5 > 2.0.
	assert_int(_runtime.get_pending().size()).is_equal(0)  # Resolved.
	assert_int(player.inventory.get_count(&"cooked_meat")).is_equal(1)

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: sustain condition failure cancels
# ---------------------------------------------------------------------------


func test_sustain_failure_cancels_and_returns_inputs() -> void:
	var recipe := _make_recipe(&"cook_on_fire", 10.0)
	recipe.inputs.append(_make_input(&"raw_meat"))

	# Sustain condition: prop_state fireplace.is_lit == true.
	var fireplace := StatefulProp.new()
	fireplace.type = &"fireplace"
	fireplace.is_lit = true
	recipe.conditions.append(_make_condition(&"prop_state", {
		"prop": &"fireplace", "field": &"is_lit", "op": &"eq", "value": true
	}, true))

	_discovery.set_known(&"cook_on_fire")

	# Register fireplace def.
	_ensure_prop_def(&"fireplace")
	var tile := _HexTile.new()
	tile.biome = 1
	tile.props = [fireplace]

	var pair := _make_ctx_with_inventory({&"raw_meat": 1})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]
	ctx.tile = tile
	ctx.station = fireplace

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()
	assert_int(_runtime.get_pending().size()).is_equal(1)
	assert_int(player.inventory.get_count(&"raw_meat")).is_equal(0)

	# Now extinguish the fire.
	fireplace.is_lit = false
	_runtime._process(0.5)

	# Should be cancelled — inputs returned.
	assert_int(_runtime.get_pending().size()).is_equal(0)
	assert_int(player.inventory.get_count(&"raw_meat")).is_equal(1)

	_cleanup_prop_defs([&"fireplace"])
	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: output probability
# ---------------------------------------------------------------------------


func test_output_prob_zero_produces_nothing() -> void:
	_mock_random_value = 0.5  # Roll = 0.5, prob = 0.0 → 0.5 > 0.0, skip.
	var recipe := _make_recipe(&"lucky_craft")
	recipe.outputs.append(_make_output(&"wood", 1, 0.0))
	_discovery.set_known(&"lucky_craft")

	_ensure_prop_def(&"wood")
	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	_runtime.try_start_recipe(recipe, ctx)
	assert_int(player.inventory.get_count(&"wood")).is_equal(0)

	player.queue_free()


func test_output_prob_one_always_produces() -> void:
	_mock_random_value = 0.99  # Roll = 0.99, prob = 1.0 → 0.99 <= 1.0, produce.
	var recipe := _make_recipe(&"sure_craft")
	recipe.outputs.append(_make_output(&"wood", 3, 1.0))
	_discovery.set_known(&"sure_craft")

	_ensure_prop_def(&"wood")
	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	_runtime.try_start_recipe(recipe, ctx)
	assert_int(player.inventory.get_count(&"wood")).is_equal(3)

	player.queue_free()


func test_output_prob_partial() -> void:
	_mock_random_value = 0.5  # Roll = 0.5.
	var recipe := _make_recipe(&"partial_craft")
	recipe.outputs.append(_make_output(&"wood", 2, 0.8))   # 0.5 <= 0.8 → produce.
	recipe.outputs.append(_make_output(&"branch", 1, 0.3))  # 0.5 > 0.3 → skip.
	_discovery.set_known(&"partial_craft")

	_ensure_prop_def(&"wood")
	_ensure_prop_def(&"branch")
	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	_runtime.try_start_recipe(recipe, ctx)
	assert_int(player.inventory.get_count(&"wood")).is_equal(2)
	assert_int(player.inventory.get_count(&"branch")).is_equal(0)

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: effects applied (stat_delta)
# ---------------------------------------------------------------------------


func test_stat_delta_effect_modifies_player_stats() -> void:
	var recipe := _make_recipe(&"eat_berry")
	recipe.inputs.append(_make_input(&"berry"))
	recipe.effects.append(_make_effect(&"stat_delta", {"stat": "hunger", "value": 10}))
	recipe.effects.append(_make_effect(&"stat_delta", {"stat": "health", "value": -5}))
	_discovery.set_known(&"eat_berry")

	var pair := _make_ctx_with_inventory({&"berry": 1})
	var ctx: _WorldContext = pair[0]
	var player: FakePlayer = pair[1]

	var survival := FakeSurvivalSystem.new()
	survival.hunger = 50.0
	survival.hp = 100.0
	player.add_child(survival)

	_runtime.try_start_recipe(recipe, ctx)

	assert_float(survival.hunger).is_equal(60.0)
	assert_float(survival.hp).is_equal(95.0)

	player.queue_free()


func test_stat_delta_clamps_to_bounds() -> void:
	var recipe := _make_recipe(&"heal_lots")
	recipe.effects.append(_make_effect(&"stat_delta", {"stat": "hp", "value": 200}))
	_discovery.set_known(&"heal_lots")

	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: FakePlayer = pair[1]

	var survival := FakeSurvivalSystem.new()
	survival.hp = 80.0
	player.add_child(survival)

	_runtime.try_start_recipe(recipe, ctx)

	assert_float(survival.hp).is_equal(100.0)  # Clamped at 100.

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: unknown recipe rejected
# ---------------------------------------------------------------------------


func test_unknown_recipe_rejected() -> void:
	var recipe := _make_recipe(&"secret_recipe")
	recipe.inputs.append(_make_input(&"berry"))
	# NOT in known list.

	var pair := _make_ctx_with_inventory({&"berry": 5})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_null()
	# Berry should NOT have been consumed.
	assert_int(player.inventory.get_count(&"berry")).is_equal(5)

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: cancel_recipe returns inputs
# ---------------------------------------------------------------------------


func test_cancel_recipe_returns_inputs() -> void:
	var recipe := _make_recipe(&"slow_cook", 60.0)
	recipe.inputs.append(_make_input(&"raw_meat", 2))
	_discovery.set_known(&"slow_cook")

	var pair := _make_ctx_with_inventory({&"raw_meat": 3})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()
	assert_int(player.inventory.get_count(&"raw_meat")).is_equal(1)

	_runtime.cancel_recipe(pending, &"player_cancelled")
	assert_int(player.inventory.get_count(&"raw_meat")).is_equal(3)
	assert_int(_runtime.get_pending().size()).is_equal(0)

	player.queue_free()


func test_cancel_recipe_emits_signal() -> void:
	var recipe := _make_recipe(&"slow_cook", 60.0)
	_discovery.set_known(&"slow_cook")

	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()

	var monitor := monitor_signals(_runtime)
	_runtime.cancel_recipe(pending, &"test_reason")
	await assert_signal(monitor).is_emitted("recipe_cancelled", [&"slow_cook", &"test_reason"])

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: conditions block start
# ---------------------------------------------------------------------------


func test_gate_condition_blocks_start() -> void:
	var recipe := _make_recipe(&"gated_recipe")
	recipe.inputs.append(_make_input(&"berry"))
	recipe.conditions.append(_make_condition(&"has_tool", {"tool": &"knife"}, false))
	_discovery.set_known(&"gated_recipe")

	var pair := _make_ctx_with_inventory({&"berry": 3})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	# No knife equipped → gate condition fails.
	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_null()
	# Berry not consumed.
	assert_int(player.inventory.get_count(&"berry")).is_equal(3)

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: insufficient inputs
# ---------------------------------------------------------------------------


func test_insufficient_inputs_rejected() -> void:
	var recipe := _make_recipe(&"need_many")
	recipe.inputs.append(_make_input(&"berry", 5))
	_discovery.set_known(&"need_many")

	var pair := _make_ctx_with_inventory({&"berry": 2})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_null()
	# Should not consume any berries.
	assert_int(player.inventory.get_count(&"berry")).is_equal(2)

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: world_tile input source
# ---------------------------------------------------------------------------


func test_world_tile_input_consumed() -> void:
	_mock_random_value = 0.0
	var recipe := _make_recipe(&"chop_tree")
	recipe.inputs.append(_make_input(&"small_tree", 1, &"world_tile"))
	recipe.outputs.append(_make_output(&"wood", 3, 1.0))
	_discovery.set_known(&"chop_tree")

	_ensure_prop_def(&"small_tree")
	_ensure_prop_def(&"wood")
	var tile := _HexTile.new()
	tile.biome = 1
	tile.props = [_Prop.create_prop(&"small_tree", 1, 1)]

	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]
	ctx.tile = tile

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()
	# Tree removed from tile.
	assert_int(tile.props.size()).is_equal(0)
	# Wood added to inventory.
	assert_int(player.inventory.get_count(&"wood")).is_equal(3)

	_cleanup_prop_defs([&"small_tree"])
	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: container input source
# ---------------------------------------------------------------------------


func test_container_input_consumed() -> void:
	_mock_random_value = 0.0
	var recipe := _make_recipe(&"burn_log", 60.0)
	recipe.inputs.append(_make_input(&"log", 1, &"container"))
	recipe.outputs.append(_make_output(&"ash", 1, 1.0))
	_discovery.set_known(&"burn_log")

	_ensure_prop_def(&"log")
	_ensure_prop_def(&"ash")
	var station := StatefulProp.new()
	station.type = &"fireplace"
	station.container_items = [{"type": &"log", "quantity": 3}]

	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]
	ctx.station = station

	var pending = _runtime.try_start_recipe(recipe, ctx)
	assert_that(pending).is_not_null()
	# Log consumed from container.
	assert_int(station.container_items[0]["quantity"]).is_equal(2)

	_cleanup_prop_defs([&"log"])
	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: grant_recipe effect
# ---------------------------------------------------------------------------


func test_grant_recipe_effect() -> void:
	var recipe := _make_recipe(&"read_scroll")
	recipe.inputs.append(_make_input(&"scroll"))
	recipe.effects.append(_make_effect(&"grant_recipe", {"recipe_id": "advanced_craft"}))
	_discovery.set_known(&"read_scroll")

	var pair := _make_ctx_with_inventory({&"scroll": 1})
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	assert_bool(_discovery.is_known(&"advanced_craft")).is_false()
	_runtime.try_start_recipe(recipe, ctx)
	assert_bool(_discovery.is_known(&"advanced_craft")).is_true()

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: recipe_started signal
# ---------------------------------------------------------------------------


func test_timed_recipe_emits_started_signal() -> void:
	var recipe := _make_recipe(&"slow_craft", 5.0)
	_discovery.set_known(&"slow_craft")

	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var monitor := monitor_signals(_runtime)
	_runtime.try_start_recipe(recipe, ctx)
	await assert_signal(monitor).is_emitted("recipe_started", [&"slow_craft"])

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: recipe_resolved signal
# ---------------------------------------------------------------------------


func test_resolved_signal_emitted() -> void:
	_mock_random_value = 0.0
	var recipe := _make_recipe(&"make_thing")
	recipe.outputs.append(_make_output(&"wood", 1, 1.0))
	_discovery.set_known(&"make_thing")

	_ensure_prop_def(&"wood")
	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var result: Array = []
	var _on_resolved := func(id: StringName, outputs: Array, effects: Array) -> void:
		result.append({"id": id, "outputs": outputs, "effects": effects})
	_runtime.recipe_resolved.connect(_on_resolved)
	_runtime.try_start_recipe(recipe, ctx)
	assert_int(result.size()).is_equal(1)
	assert_str(str(result[0]["id"])).is_equal("make_thing")

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: effect_requested for unhandled effects
# ---------------------------------------------------------------------------


func test_sound_effect_emits_effect_requested() -> void:
	var recipe := _make_recipe(&"noisy_thing")
	recipe.effects.append(_make_effect(&"sound", {"sound_id": "crunch"}))
	_discovery.set_known(&"noisy_thing")

	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	var received_effects: Array = []
	var _on_effect := func(eff: Resource) -> void:
		received_effects.append(eff)
	_runtime.effect_requested.connect(_on_effect)
	_runtime.try_start_recipe(recipe, ctx)
	assert_int(received_effects.size()).is_equal(1)
	assert_str(String(received_effects[0].kind)).is_equal("sound")

	player.queue_free()


# ---------------------------------------------------------------------------
# Tests: multiple pending recipes
# ---------------------------------------------------------------------------


func test_multiple_pending_recipes() -> void:
	var recipe_a := _make_recipe(&"cook_a", 5.0)
	var recipe_b := _make_recipe(&"cook_b", 3.0)
	_discovery.set_known(&"cook_a")
	_discovery.set_known(&"cook_b")

	var pair := _make_ctx_with_inventory()
	var ctx: _WorldContext = pair[0]
	var player: Node = pair[1]

	_runtime.try_start_recipe(recipe_a, ctx)
	_runtime.try_start_recipe(recipe_b, ctx)
	assert_int(_runtime.get_pending().size()).is_equal(2)

	# Advance 3.5 seconds — recipe_b resolves, recipe_a still pending.
	_runtime._process(3.5)
	assert_int(_runtime.get_pending().size()).is_equal(1)

	# Advance 2 more seconds — recipe_a resolves.
	_runtime._process(2.0)
	assert_int(_runtime.get_pending().size()).is_equal(0)

	player.queue_free()
