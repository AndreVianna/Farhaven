extends Node

## Executes recipes — matches them against the world, manages pending
## recipes (in-progress cooking/growing/rotting), and resolves them.
## Autoload registered AFTER DiscoveryWatcher.

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _PredicateEvaluator = preload("res://scripts/recipes/predicate_evaluator.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

signal recipe_started(recipe_id: StringName)
signal recipe_resolved(recipe_id: StringName, outputs: Array, effects: Array)
signal recipe_cancelled(recipe_id: StringName, reason: StringName)
## Emitted for effects that other systems handle (stat_delta, sound, fx, etc.).
signal effect_requested(effect: Resource)


## Pending recipe data. Tracks bound inputs so they can be returned on cancel.
class PendingRecipe extends RefCounted:
	var recipe: _Recipe = null
	var start_time: float = 0.0
	var elapsed: float = 0.0
	## Array of Dictionaries: {type: StringName, count: int, must_hold: bool}
	var bound_inputs: Array = []
	var context: _WorldContext = null


var _pending: Array = []

## Injectable dependencies for testing.
var _registry: Node = null
var _discovery: Node = null

## Injectable random number generator (for output probability rolls).
## If null, uses randf(). Tests can replace with a deterministic source.
var _rng: Callable = Callable()


func _ready() -> void:
	if _registry == null:
		_registry = _get_autoload(&"RecipeRegistry")
	if _discovery == null:
		_discovery = _get_autoload(&"DiscoveryWatcher")


## Try to start a recipe. Returns PendingRecipe on success, null on failure.
func try_start_recipe(recipe: _Recipe, ctx: _WorldContext) -> PendingRecipe:
	# 1. Check recipe is known.
	if _discovery != null and not _discovery.is_known(recipe.id):
		return null

	# 2. Check all conditions (gate + sustain) pass.
	for cond in recipe.conditions:
		if cond.predicate != null:
			if not _PredicateEvaluator.evaluate(cond.predicate, ctx):
				return null

	# 3. Validate inputs are available and consume them.
	var bound_inputs: Array = []
	var consumed_ok := _consume_inputs(recipe, ctx, bound_inputs)
	if not consumed_ok:
		# Rollback any partially consumed inputs.
		_return_inputs(bound_inputs, ctx)
		return null

	# 4. Instant resolution (duration == 0).
	if recipe.duration <= 0.0:
		var pending := PendingRecipe.new()
		pending.recipe = recipe
		pending.start_time = Time.get_ticks_msec() / 1000.0
		pending.bound_inputs = bound_inputs
		pending.context = ctx
		_resolve(pending)
		return pending

	# 5. Timed recipe — enqueue.
	var pending := PendingRecipe.new()
	pending.recipe = recipe
	pending.start_time = Time.get_ticks_msec() / 1000.0
	pending.elapsed = 0.0
	pending.bound_inputs = bound_inputs
	pending.context = ctx
	_pending.append(pending)
	recipe_started.emit(recipe.id)
	return pending


## Cancel a pending recipe, returning inputs to their sources.
func cancel_recipe(pending: PendingRecipe, reason: StringName = &"cancelled") -> void:
	_return_inputs(pending.bound_inputs, pending.context)
	_pending.erase(pending)
	recipe_cancelled.emit(pending.recipe.id, reason)


## Returns the current pending recipe queue (read-only snapshot).
func get_pending() -> Array:
	return _pending.duplicate()


func _process(delta: float) -> void:
	# Iterate backward so removal during iteration is safe.
	var i := _pending.size() - 1
	while i >= 0:
		var pending: PendingRecipe = _pending[i]
		pending.elapsed += delta

		# Re-check sustain conditions.
		var sustain_failed := false
		for cond in pending.recipe.conditions:
			if not cond.must_sustain:
				continue
			if cond.predicate != null:
				if not _PredicateEvaluator.evaluate(cond.predicate, pending.context):
					sustain_failed = true
					break

		if sustain_failed:
			cancel_recipe(pending, &"sustain_failed")
			i -= 1
			continue

		# Check if duration is up.
		if pending.elapsed >= pending.recipe.duration:
			_resolve(pending)
			i -= 1
			continue

		i -= 1


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------


func _resolve(pending: PendingRecipe) -> void:
	var produced_outputs: Array = []
	var applied_effects: Array = []

	# 1. Produce outputs (each rolls independently against prob).
	for output in pending.recipe.outputs:
		var roll: float = _roll_random()
		if roll > output.prob:
			continue
		# Produce the output.
		var result := {"prop_ref": output.prop_ref, "count": output.count}
		produced_outputs.append(result)
		# Determine where to place output based on input source context.
		_deliver_output(output, pending)

	# 2. Apply effects.
	for eff in pending.recipe.effects:
		applied_effects.append(eff)
		_apply_effect(eff, pending)

	# 3. Remove from pending queue and emit signal.
	_pending.erase(pending)
	recipe_resolved.emit(pending.recipe.id, produced_outputs, applied_effects)


func _deliver_output(output: _RecipeOutput, pending: PendingRecipe) -> void:
	var ctx := pending.context
	# 1. Try player inventory first.
	if ctx.player != null:
		var inv = _get_player_inventory(ctx.player)
		if inv != null:
			var added: int = inv.add_item(output.prop_ref, output.count)
			if added >= output.count:
				return
			# Partial add — remaining overflow below.
			var remaining: int = output.count - added
			# 2. Try world_tile: spawn remaining on tile.
			if ctx.tile != null:
				for _j in remaining:
					ctx.tile.props.append(_Prop.create_prop(output.prop_ref, 1, 1))
				return
			# 3. Overflow — emit signal for other systems to handle.
			push_warning("RecipeRuntime: could not deliver %d × %s — inventory full, no tile context" % [remaining, output.prop_ref])
			return
	# No player — try world tile directly.
	if ctx.tile != null:
		for _j in output.count:
			ctx.tile.props.append(_Prop.create_prop(output.prop_ref, 1, 1))
		return
	# Fallback: emit signal for other systems to handle output placement.
	push_warning("RecipeRuntime: could not deliver %d × %s — no player or tile" % [output.count, output.prop_ref])


func _apply_effect(eff: _RecipeEffect, pending: PendingRecipe) -> void:
	match eff.kind:
		&"stat_delta":
			_apply_stat_delta(eff, pending)
		&"grant_recipe":
			var recipe_id := StringName(eff.params.get("recipe_id", ""))
			if recipe_id != &"" and _discovery != null:
				_discovery.grant_recipe(recipe_id)
		_:
			# Emit signal for sound, fx, emit_light, spawn_heat, world_change, etc.
			effect_requested.emit(eff)


func _apply_stat_delta(eff: _RecipeEffect, pending: PendingRecipe) -> void:
	var ctx := pending.context
	if ctx.player == null:
		effect_requested.emit(eff)
		return
	var stat_name: StringName = StringName(eff.params.get("stat", ""))
	var value: float = float(eff.params.get("value", 0.0))
	# Try to find SurvivalSystem on the player.
	var survival: Node = _get_survival_system(ctx.player)
	if survival == null:
		effect_requested.emit(eff)
		return
	match stat_name:
		&"hunger":
			survival.hunger = clampf(survival.hunger + value, 0.0, 100.0)
		&"thirst":
			survival.thirst = clampf(survival.thirst + value, 0.0, 100.0)
		&"health", &"hp":
			survival.hp = clampf(survival.hp + value, 0.0, 100.0)
		_:
			effect_requested.emit(eff)


# ---------------------------------------------------------------------------
# Input consumption and return
# ---------------------------------------------------------------------------


func _consume_inputs(recipe: _Recipe, ctx: _WorldContext, out_bound: Array) -> bool:
	for input in recipe.inputs:
		var consumed := _consume_single_input(input, ctx)
		if not consumed:
			return false
		out_bound.append({
			"type": input.ref,
			"count": input.count,
			"must_hold": input.must_hold,
		})
	return true


func _consume_single_input(input: _RecipeInput, ctx: _WorldContext) -> bool:
	if input.must_hold:
		return _consume_from_inventory(input, ctx)
	return _consume_from_player_vicinity(input, ctx)


func _consume_from_inventory(input: _RecipeInput, ctx: _WorldContext) -> bool:
	if ctx.player == null:
		return false
	var inv = _get_player_inventory(ctx.player)
	if inv == null:
		return false
	if input.is_tag():
		return _consume_tag_from_inventory(input, inv)
	# Direct ref: check and remove.
	var ref_name: StringName = StringName(input.ref)
	if not inv.has_item(ref_name, input.count):
		return false
	inv.remove_item(ref_name, input.count)
	return true


func _consume_tag_from_inventory(input: _RecipeInput, inv: _Inventory) -> bool:
	# Find any item matching the tag in inventory.
	var tag_name: StringName = input.get_tag()
	var remaining := input.count
	var slots: Array = inv.get_slots()
	for slot in slots:
		if slot["type"] == &"":
			continue
		var def = PropRegistry.get_def(slot["type"])
		if def != null and def.has_tag(tag_name):
			var available: int = slot["quantity"]
			var to_remove: int = mini(available, remaining)
			inv.remove_item(slot["type"], to_remove)
			remaining -= to_remove
			if remaining <= 0:
				return true
	return remaining <= 0


## Consumes an input from the player's vicinity (current tile, and later —
## potentially adjacent tiles). For now this looks at props on ctx.tile.
func _consume_from_player_vicinity(input: _RecipeInput, ctx: _WorldContext) -> bool:
	if ctx.tile == null:
		return false
	# Check presence on the tile.
	var tag_name: StringName = input.get_tag() if input.is_tag() else &""
	var ref_name: StringName = StringName(input.ref)
	var count_found := 0
	for prop in ctx.tile.props:
		var prop_type: StringName = prop.type if "type" in prop else &""
		if input.is_tag():
			var def = PropRegistry.get_def(prop_type)
			if def != null and def.has_tag(tag_name):
				count_found += 1
		else:
			if prop_type == ref_name:
				count_found += 1
		if count_found >= input.count:
			break
	if count_found < input.count:
		return false
	# Remove props from tile.
	var to_remove := input.count
	var idx: int = ctx.tile.props.size() - 1
	while idx >= 0 and to_remove > 0:
		var prop = ctx.tile.props[idx]
		var prop_type: StringName = prop.type if "type" in prop else &""
		var matches := false
		if input.is_tag():
			var def = PropRegistry.get_def(prop_type)
			matches = def != null and def.has_tag(tag_name)
		else:
			matches = prop_type == ref_name
		if matches:
			ctx.tile.props.remove_at(idx)
			to_remove -= 1
		idx -= 1
	return true


func _return_inputs(bound_inputs: Array, ctx: _WorldContext) -> void:
	for entry: Dictionary in bound_inputs:
		var must_hold: bool = bool(entry.get("must_hold", false))
		var item_ref_str: String = String(entry.get("type", ""))
		var item_type: StringName = StringName(item_ref_str)
		var count: int = int(entry.get("count", 0))
		if item_ref_str == "" or count <= 0:
			continue
		# Tag inputs can't be returned cleanly — we stored the tag ref, not the actual prop.
		# Only return non-tag refs.
		var is_tag_ref: bool = item_ref_str.begins_with("&")
		if is_tag_ref:
			continue
		if must_hold:
			if ctx.player != null:
				var inv = _get_player_inventory(ctx.player)
				if inv != null:
					inv.add_item(item_type, count)
		else:
			if ctx.tile != null:
				# Re-add props to tile.
				for _j in count:
					ctx.tile.props.append(_Prop.create_prop(item_type, 1, 1))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _get_player_inventory(player: Node):
	if player.has_method("get_inventory"):
		return player.get_inventory()
	if "inventory" in player:
		return player.inventory
	return null


func _get_survival_system(player: Node) -> Node:
	for child in player.get_children():
		if "hp" in child and "hunger" in child and "thirst" in child:
			return child
	return null


func _roll_random() -> float:
	if _rng.is_valid():
		return _rng.call()
	return randf()


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
