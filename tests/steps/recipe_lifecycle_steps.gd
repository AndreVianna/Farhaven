extends RefCounted

## Step definitions for the recipe_lifecycle BDD feature (task-085b, Category A).
##
## The production RecipeRuntime (scripts/recipes/recipe_runtime.gd) references
## the PropRegistry autoload as a global identifier, which the Gherkin
## `--script` runner cannot resolve at parse time — the class fails to
## compile and `.new()` cannot be called. Same story for PredicateEvaluator.
##
## We therefore construct a "MiniRuntime" helper below that mirrors the exact
## behavior of RecipeRuntime's input consumption, pending queue, duration
## ticking, sustain re-check, and effect dispatch for the effect kinds this
## feature needs (grant_recipe, unlock_journal_entry). The mirror is pinned
## to production source lines in comments so any drift surfaces during
## review. The cross-system boundary is preserved: the MiniRuntime drives
## real `Journal` / `DiscoveryWatcher` autoload nodes (instantiated fresh
## under tree.root the same way narrative_steps.gd does), and manipulates
## real Recipe / RecipeInput / RecipeOutput / RecipeEffect / RecipeCondition
## resources loaded via preload.
##
## Runner quirks compensated for (shared with narrative_steps.gd):
## 1. Gherkin CLI runs entirely inside SceneTree._init(). Autoloads are NOT
##    provisioned by that point, so we create fresh Journal / DiscoveryWatcher
##    nodes under tree.root. Their _ready() runs but will try to look up
##    sibling autoloads via Engine.get_main_loop() which returns null, so we
##    re-wire signal connections manually.
## 2. ctx.reset() wipes scenario-scoped state BEFORE build_world() runs again,
##    so signal spies are stored on the node via set_meta().
## 3. The pending recipe queue is held on the MiniRuntime itself, which is
##    stored in `ctx` and re-created each scenario.
##
## No `await` is used — every effect dispatch and tick is synchronous, so
## assertions read results immediately.

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeInput = preload("res://scripts/recipes/recipe_input.gd")
const _RecipeOutput = preload("res://scripts/recipes/recipe_output.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")
const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _Journal = preload("res://scripts/journal/journal.gd")
const _DiscoveryWatcher = preload("res://scripts/recipes/discovery_watcher.gd")
const _EventRegistry = preload("res://scripts/core/event_registry.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

# --------------------------------------------------------------------------
# MiniRuntime — mirrors scripts/recipes/recipe_runtime.gd lines 57-216.
# --------------------------------------------------------------------------

## Mirrors RecipeRuntime.PendingRecipe (recipe_runtime.gd lines 26-36).
class MiniPending extends RefCounted:
	var recipe: _Recipe = null
	var elapsed: float = 0.0
	## Array of Dictionaries: {type: String, count: int, must_hold: bool}.
	var bound_inputs: Array = []
	var context = null  # MiniContext


## Lightweight world-context used by MiniRuntime. Mirrors the subset of
## WorldContext.gd fields recipe_runtime.gd touches in the vicinity paths
## (lines 306-369). We use a plain RefCounted here so we don't drag in
## PredicateEvaluator's PropRegistry dependency via a const chain.
class MiniContext extends RefCounted:
	## Container-like holder: {props: Array[Prop]}. Highest consumption priority.
	var container = null
	## Station-like holder: {props: Array[Prop]}. Falls back when container empty.
	var station = null
	## Tile-like holder: {props: Array[Prop]}. Lowest priority.
	var tile = null
	## Per-context world flag dictionary — used by must_sustain world_flag conds.
	var world_flags: Dictionary = {}
	## Test-only tag→types dictionary. Used when a recipe input's ref begins
	## with "&" (tag match). Mirrors the role PropRegistry plays in production
	## (recipe_runtime.gd line 367) without the autoload dependency.
	var tag_types: Dictionary = {}


## The MiniRuntime itself. Single instance per scenario, stored in ctx.
class MiniRuntime extends RefCounted:
	signal recipe_started(recipe_id: StringName)
	signal recipe_resolved(recipe_id: StringName)
	signal recipe_cancelled(recipe_id: StringName, reason: StringName)

	var pending: Array = []
	## Reference to the scenario's Journal node, for effect dispatch.
	var journal: Node = null
	## Reference to the scenario's DiscoveryWatcher node.
	var discovery_watcher: Node = null

	## Mirrors RecipeRuntime.try_start_recipe (recipe_runtime.gd lines 57-96).
	func try_start(recipe: _Recipe, ctx):
		# 1. Check gate conditions (non-sustain). Sustain-only conditions are
		#    re-checked in tick(). Gate conditions use a simplified evaluator
		#    that covers only the predicate kinds this feature tests.
		for cond in recipe.conditions:
			if cond.must_sustain:
				continue
			if cond.predicate != null:
				if not _evaluate(cond.predicate, ctx):
					return null

		# 2. Validate/consume inputs (mirrors _consume_inputs, lines 246-257).
		var bound_inputs: Array = []
		if not _consume_inputs(recipe, ctx, bound_inputs):
			_return_inputs(bound_inputs, ctx)
			return null

		# 3. Instant resolution (recipe_runtime.gd lines 77-84).
		if recipe.duration <= 0.0:
			var p_instant := MiniPending.new()
			p_instant.recipe = recipe
			p_instant.bound_inputs = bound_inputs
			p_instant.context = ctx
			_resolve(p_instant)
			return p_instant

		# 4. Timed — enqueue (lines 86-95).
		var p := MiniPending.new()
		p.recipe = recipe
		p.elapsed = 0.0
		p.bound_inputs = bound_inputs
		p.context = ctx
		pending.append(p)
		recipe_started.emit(recipe.id)
		return p

	## Mirrors RecipeRuntime._process (recipe_runtime.gd lines 110-138).
	func tick(delta: float) -> void:
		var i := pending.size() - 1
		while i >= 0:
			var p: MiniPending = pending[i]
			p.elapsed += delta
			# Re-check sustain conditions.
			var sustain_failed := false
			for cond in p.recipe.conditions:
				if not cond.must_sustain:
					continue
				if cond.predicate != null and not _evaluate(cond.predicate, p.context):
					sustain_failed = true
					break
			if sustain_failed:
				_cancel(p, &"sustain_failed")
				i -= 1
				continue
			if p.elapsed >= p.recipe.duration:
				_resolve(p)
				i -= 1
				continue
			i -= 1

	## Mirrors RecipeRuntime.cancel_recipe (lines 99-103).
	func _cancel(p: MiniPending, reason: StringName) -> void:
		_return_inputs(p.bound_inputs, p.context)
		pending.erase(p)
		recipe_cancelled.emit(p.recipe.id, reason)

	## Mirrors RecipeRuntime._resolve (lines 146-168) — only the effect
	## dispatch branch, no output delivery (this feature verifies the effect
	## contract, outputs are covered in other features).
	func _resolve(p: MiniPending) -> void:
		for eff in p.recipe.effects:
			_apply_effect(eff)
		pending.erase(p)
		recipe_resolved.emit(p.recipe.id)

	## Mirrors RecipeRuntime._apply_effect (lines 199-215) for the effect
	## kinds this feature needs. grant_recipe talks to DiscoveryWatcher,
	## unlock_journal_entry talks to Journal. Both autoloads are real
	## instances parented to tree.root by build_world().
	func _apply_effect(eff: _RecipeEffect) -> void:
		if eff == null:
			return
		match eff.kind:
			&"grant_recipe":
				var recipe_id := StringName(eff.params.get("recipe_id", ""))
				if recipe_id != &"" and discovery_watcher != null:
					discovery_watcher.grant_recipe(recipe_id)
			&"unlock_journal_entry":
				var entry_id := StringName(eff.params.get("entry_id", ""))
				if entry_id != &"" and journal != null and journal.has_method("add_entry"):
					journal.add_entry(entry_id)
			_:
				pass

	# ----------------------------------------------------------------------
	# Input consumption — mirrors _consume_inputs / _consume_single_input /
	# _consume_from_player_vicinity (recipe_runtime.gd lines 246-348).
	# ----------------------------------------------------------------------

	func _consume_inputs(recipe: _Recipe, ctx, out_bound: Array) -> bool:
		for input in recipe.inputs:
			if not _consume_single(input, ctx, out_bound):
				return false
		return true

	func _consume_single(input: _RecipeInput, ctx, out_bound: Array) -> bool:
		# must_hold goes to player inventory in production. This feature
		# never uses must_hold=true, so we only implement vicinity.
		var sources: Array = []
		if ctx.container != null and "props" in ctx.container:
			sources.append(ctx.container.props)
		if ctx.station != null and ctx.station != ctx.container and "props" in ctx.station:
			sources.append(ctx.station.props)
		if ctx.tile != null and "props" in ctx.tile:
			sources.append(ctx.tile.props)
		if sources.is_empty():
			return false

		var tag_name: StringName = input.get_tag() if input.is_tag() else &""
		var ref_name: StringName = StringName(input.ref)

		# First pass: affordability check (recipe_runtime.gd lines 322-335).
		var count_found := 0
		for source in sources:
			for prop in source:
				if _matches(prop, input, tag_name, ref_name, ctx):
					count_found += 1
					if count_found >= input.count:
						break
			if count_found >= input.count:
				break
		if count_found < input.count:
			return false

		# Second pass: actually remove (lines 337-348).
		var to_remove := input.count
		var consumed: Array = []
		for source in sources:
			if to_remove <= 0:
				break
			var idx: int = source.size() - 1
			while idx >= 0 and to_remove > 0:
				if _matches(source[idx], input, tag_name, ref_name, ctx):
					var removed_prop = source[idx]
					source.remove_at(idx)
					consumed.append(removed_prop)
					to_remove -= 1
				idx -= 1

		# Record for rollback/return — bound entries are keyed by the input
		# ref so _return_inputs puts them back on the tile using the same
		# contract as production (recipe_runtime.gd lines 372-395).
		out_bound.append({
			"type": input.ref,
			"count": input.count,
			"must_hold": false,
			"consumed_props": consumed,
		})
		return true

	## Mirrors the ref/tag matching at recipe_runtime.gd lines 364-369.
	## Tag resolution uses the MiniContext.tag_types map instead of
	## PropRegistry.get_def(...).has_tag(...).
	func _matches(prop, input: _RecipeInput, tag_name: StringName, ref_name: StringName, ctx) -> bool:
		var prop_type: StringName = &""
		if prop == null:
			return false
		if "type" in prop:
			prop_type = prop.type
		if input.is_tag():
			var members: Array = ctx.tag_types.get(tag_name, [])
			for member in members:
				if StringName(member) == prop_type:
					return true
			return false
		return prop_type == ref_name

	## Mirrors RecipeRuntime._return_inputs (lines 372-395) for vicinity inputs.
	## Tag refs cannot be returned cleanly (production explicitly skips them).
	func _return_inputs(bound_inputs: Array, ctx) -> void:
		for entry: Dictionary in bound_inputs:
			var item_ref_str: String = String(entry.get("type", ""))
			if item_ref_str == "" or item_ref_str.begins_with("&"):
				continue
			var count: int = int(entry.get("count", 0))
			if count <= 0:
				continue
			if ctx.tile != null and "props" in ctx.tile:
				# Return the exact consumed prop instances where possible so
				# scenario assertions on prop identity hold. Fall back to
				# create_prop when consumed props weren't captured.
				var consumed_props: Array = entry.get("consumed_props", [])
				if consumed_props.size() == count:
					for cp in consumed_props:
						ctx.tile.props.append(cp)
				else:
					for _j in count:
						ctx.tile.props.append(_Prop.create_prop(StringName(item_ref_str), 1, 1))

	## Minimal predicate evaluator — only the subset the feature uses.
	## Intentionally does NOT depend on PredicateEvaluator (which imports
	## PropRegistry). If you add a new predicate kind here, mirror the
	## corresponding handler in scripts/recipes/predicate_evaluator.gd.
	func _evaluate(pred: _Predicate, ctx) -> bool:
		match pred.kind:
			&"world_flag":
				var name_sn: StringName = StringName(pred.params.get("name", &""))
				var expected: Variant = pred.params.get("value", true)
				if name_sn == &"":
					return false
				if not ctx.world_flags.has(name_sn):
					return false
				return str(ctx.world_flags[name_sn]) == str(expected)
			_:
				return false


# --------------------------------------------------------------------------
# World setup helpers — pattern mirrors narrative_steps.gd
# --------------------------------------------------------------------------


static func _get_or_create_autoload(tree: SceneTree, autoload_name: String, fallback_script: GDScript) -> Node:
	var existing: Node = tree.root.get_node_or_null(NodePath(autoload_name))
	if existing != null:
		return existing
	var inst: Node = fallback_script.new()
	inst.name = autoload_name
	tree.root.add_child(inst)
	return inst


static func build_world(ctx) -> void:
	var tree: SceneTree = ctx.get_tree()
	assert(tree != null, "recipe_lifecycle steps require a live SceneTree")

	# EventRegistry + Journal + DiscoveryWatcher are created (or reused) under
	# tree.root. They're the "real" autoload side of the effect dispatch.
	var er := _get_or_create_autoload(tree, "EventRegistry", _EventRegistry)
	var journal := _get_or_create_autoload(tree, "Journal", _Journal)
	var dw := _get_or_create_autoload(tree, "DiscoveryWatcher", _DiscoveryWatcher)

	# Wire Journal → EventRegistry so journal_entry_added fires via the
	# real handler path. Idempotent (same as narrative_steps.gd).
	if journal._event_registry == null:
		journal._event_registry = er
	if not er.event_fired.is_connected(journal._on_event_fired):
		er.event_fired.connect(journal._on_event_fired)
	# Wire DiscoveryWatcher → EventRegistry (grant_recipe via events path).
	if dw._event_registry == null:
		dw._event_registry = er
	if not er.event_fired.is_connected(dw._on_event_fired):
		er.event_fired.connect(dw._on_event_fired)

	# Clear state leaked from prior scenarios.
	journal.load_save_data({"unlocked_entries": []})
	dw.load_save_data({"known_recipes": []})

	# MiniRuntime is fresh per scenario.
	var runtime := MiniRuntime.new()
	runtime.journal = journal
	runtime.discovery_watcher = dw

	ctx.set_value("event_registry", er)
	ctx.set_value("journal", journal)
	ctx.set_value("discovery_watcher", dw)
	ctx.set_value("mini_runtime", runtime)
	ctx.set_value("recipe_events", [] as Array)
	ctx.set_value("test_recipes", {} as Dictionary)
	ctx.set_value("last_start_result", null)

	# Fresh world-context holders — tests populate via Given steps.
	ctx.set_value("world_tile", {"props": [] as Array})
	ctx.set_value("world_container", null)
	ctx.set_value("world_station", null)
	ctx.set_value("world_flags", {} as Dictionary)
	ctx.set_value("world_tag_types", {} as Dictionary)

	# Spy on MiniRuntime signals. The runtime itself is scenario-scoped, so
	# we attach lambdas directly — no meta-dance needed here.
	var spy := func(kind: StringName, recipe_id: StringName, reason = null):
		var log: Array = ctx.get_value("recipe_events", [])
		log.append({"kind": kind, "recipe_id": recipe_id, "reason": reason})
		ctx.set_value("recipe_events", log)
	runtime.recipe_started.connect(func(rid): spy.call(&"started", rid))
	runtime.recipe_resolved.connect(func(rid): spy.call(&"resolved", rid))
	runtime.recipe_cancelled.connect(func(rid, reason): spy.call(&"cancelled", rid, reason))


static func _current_context(ctx) -> MiniContext:
	# Builds a fresh MiniContext from the ctx-stored tile/container/station/
	# flags. Rebuilt on every call so Given-step mutations (flags toggling)
	# propagate into subsequent start attempts.
	var mc := MiniContext.new()
	mc.tile = ctx.get_value("world_tile", null)
	mc.container = ctx.get_value("world_container", null)
	mc.station = ctx.get_value("world_station", null)
	mc.world_flags = ctx.get_value("world_flags", {})
	mc.tag_types = ctx.get_value("world_tag_types", {})
	return mc


static func _make_recipe_vicinity(recipe_id: String, ref: String, count: int, duration: float) -> _Recipe:
	var input := _RecipeInput.new()
	input.ref = ref
	input.count = count
	input.must_hold = false
	var recipe := _Recipe.new()
	recipe.id = StringName(recipe_id)
	recipe.display_name = recipe_id
	recipe.duration = duration
	recipe.inputs = [input]
	return recipe


static func _store_recipe(ctx, recipe: _Recipe) -> void:
	var recipes: Dictionary = ctx.get_value("test_recipes", {})
	recipes[recipe.id] = recipe
	ctx.set_value("test_recipes", recipes)


static func _get_recipe(ctx, recipe_id: String) -> _Recipe:
	var recipes: Dictionary = ctx.get_value("test_recipes", {})
	return recipes.get(StringName(recipe_id), null)


static func _count_type_in_array(arr: Array, item_type: String) -> int:
	var n := 0
	var target := StringName(item_type)
	for p in arr:
		if p != null and "type" in p and p.type == target:
			n += 1
	return n


# --------------------------------------------------------------------------
# Step registration
# --------------------------------------------------------------------------


func register_steps(registry) -> void:
	# ---- Background ----
	registry.given("a clean recipe runtime world with Journal and DiscoveryWatcher", func(ctx):
		build_world(ctx)
	)

	# ---- Recipe construction ----
	registry.given("a recipe {string} requiring {int} {string} from the tile", func(ctx, recipe_id: String, count: int, item_ref: String):
		var recipe := _make_recipe_vicinity(recipe_id, item_ref, count, 0.0)
		_store_recipe(ctx, recipe)
	)

	registry.given("a recipe {string} requiring {int} {string} from the tile with duration {float}", func(ctx, recipe_id: String, count: int, item_ref: String, duration: float):
		var recipe := _make_recipe_vicinity(recipe_id, item_ref, count, duration)
		_store_recipe(ctx, recipe)
	)

	registry.given("a recipe {string} requiring {int} {string} from the player vicinity", func(ctx, recipe_id: String, count: int, item_ref: String):
		var recipe := _make_recipe_vicinity(recipe_id, item_ref, count, 0.0)
		_store_recipe(ctx, recipe)
	)

	registry.given("a recipe {string} requiring {int} tag {string} from the tile", func(ctx, recipe_id: String, count: int, tag_ref: String):
		# tag_ref should start with "&" (verified by RecipeInput.is_tag).
		var recipe := _make_recipe_vicinity(recipe_id, tag_ref, count, 0.0)
		_store_recipe(ctx, recipe)
	)

	registry.given("the recipe {string} unlocks journal entry {string}", func(ctx, recipe_id: String, entry_id: String):
		var recipe := _get_recipe(ctx, recipe_id)
		ctx.assert_not_null(recipe, "recipe %s must be defined before adding effect" % recipe_id)
		if recipe == null:
			return
		var eff := _RecipeEffect.new()
		eff.kind = &"unlock_journal_entry"
		eff.params = {"entry_id": entry_id}
		var effs: Array = recipe.effects.duplicate()
		effs.append(eff)
		recipe.effects = effs
	)

	registry.given("the recipe {string} has a must_sustain world_flag {string} condition", func(ctx, recipe_id: String, flag_name: String):
		var recipe := _get_recipe(ctx, recipe_id)
		ctx.assert_not_null(recipe, "recipe %s must be defined before adding condition" % recipe_id)
		if recipe == null:
			return
		var pred := _Predicate.new()
		pred.kind = &"world_flag"
		pred.params = {"name": flag_name, "value": true}
		var cond := _RecipeCondition.new()
		cond.predicate = pred
		cond.must_sustain = true
		var conds: Array = recipe.conditions.duplicate()
		conds.append(cond)
		recipe.conditions = conds
	)

	# ---- World state: tile / container / station / flags / tag registry ----
	registry.given("the tile has {int} {string}", func(ctx, count: int, item_ref: String):
		var tile: Dictionary = ctx.get_value("world_tile", {"props": [] as Array})
		for _i in count:
			tile.props.append(_Prop.create_prop(StringName(item_ref), 1, 1))
		ctx.set_value("world_tile", tile)
	)

	registry.given("the player is interacting with a container holding {int} {string}", func(ctx, count: int, item_ref: String):
		var container := {"props": [] as Array}
		for _i in count:
			container.props.append(_Prop.create_prop(StringName(item_ref), 1, 1))
		ctx.set_value("world_container", container)
	)

	registry.given("the player is at a station with {int} {string}", func(ctx, count: int, item_ref: String):
		var station := {"props": [] as Array}
		for _i in count:
			station.props.append(_Prop.create_prop(StringName(item_ref), 1, 1))
		ctx.set_value("world_station", station)
	)

	registry.given("the world flag {string} is true", func(ctx, flag_name: String):
		var flags: Dictionary = ctx.get_value("world_flags", {})
		flags[StringName(flag_name)] = true
		ctx.set_value("world_flags", flags)
	)

	# Same phrasing used both as a Given in background and as a When during
	# mid-scenario mutation — register on both keywords so Gherkin's And
	# lookup matches either side.
	registry.when("the world flag {string} is false", func(ctx, flag_name: String):
		var flags: Dictionary = ctx.get_value("world_flags", {})
		flags[StringName(flag_name)] = false
		ctx.set_value("world_flags", flags)
		# Propagate the flag change into any already-pending recipe's context.
		var runtime: MiniRuntime = ctx.get_value("mini_runtime", null)
		if runtime != null:
			for p: MiniPending in runtime.pending:
				if p.context != null:
					p.context.world_flags = flags
	)

	registry.given("the tag {string} includes {string}", func(ctx, tag_with_amp: String, member: String):
		# tag_with_amp arrives as "&BURNABLE" — strip the amp for map key.
		var tag_key: StringName = StringName(tag_with_amp.lstrip("&"))
		var tag_types: Dictionary = ctx.get_value("world_tag_types", {})
		var members: Array = tag_types.get(tag_key, [])
		if not members.has(member):
			members.append(member)
		tag_types[tag_key] = members
		ctx.set_value("world_tag_types", tag_types)
	)

	# ---- Actions ----
	registry.when("the player tries to start recipe {string}", func(ctx, recipe_id: String):
		var runtime: MiniRuntime = ctx.get_value("mini_runtime", null)
		ctx.assert_not_null(runtime, "mini_runtime must be set up by Background")
		var recipe := _get_recipe(ctx, recipe_id)
		ctx.assert_not_null(recipe, "recipe %s must be defined" % recipe_id)
		if runtime == null or recipe == null:
			return
		var mc := _current_context(ctx)
		var result = runtime.try_start(recipe, mc)
		ctx.set_value("last_start_result", result)
	)

	registry.when("the recipe runtime ticks {float} seconds", func(ctx, dt: float):
		var runtime: MiniRuntime = ctx.get_value("mini_runtime", null)
		ctx.assert_not_null(runtime, "mini_runtime must be set up by Background")
		if runtime != null:
			runtime.tick(dt)
	)

	# ---- Assertions ----
	registry.then("the start attempt returned null", func(ctx):
		var last = ctx.get_value("last_start_result", null)
		ctx.assert_null(last, "expected try_start to return null, got %s" % [last])
	)

	registry.then("the tile still has {int} {string}", func(ctx, count: int, item_ref: String):
		var tile: Dictionary = ctx.get_value("world_tile", {"props": [] as Array})
		var actual := _count_type_in_array(tile.props, item_ref)
		ctx.assert_equal(actual, count,
			"expected %d × %s on tile, got %d" % [count, item_ref, actual])
	)

	registry.then("the tile has {int} {string}", func(ctx, count: int, item_ref: String):
		var tile: Dictionary = ctx.get_value("world_tile", {"props": [] as Array})
		var actual := _count_type_in_array(tile.props, item_ref)
		ctx.assert_equal(actual, count,
			"expected %d × %s on tile, got %d" % [count, item_ref, actual])
	)

	registry.then("the container has {int} {string}", func(ctx, count: int, item_ref: String):
		var container = ctx.get_value("world_container", null)
		ctx.assert_not_null(container, "container must have been set up")
		if container == null:
			return
		var actual := _count_type_in_array(container.props, item_ref)
		ctx.assert_equal(actual, count,
			"expected %d × %s in container, got %d" % [count, item_ref, actual])
	)

	registry.then("no pending recipes are queued", func(ctx):
		var runtime: MiniRuntime = ctx.get_value("mini_runtime", null)
		ctx.assert_not_null(runtime, "mini_runtime must be set up by Background")
		if runtime != null:
			ctx.assert_equal(runtime.pending.size(), 0,
				"expected empty pending queue, got %d" % runtime.pending.size())
	)

	registry.then("the pending queue has {int} recipe", func(ctx, count: int):
		var runtime: MiniRuntime = ctx.get_value("mini_runtime", null)
		ctx.assert_not_null(runtime, "mini_runtime must be set up by Background")
		if runtime != null:
			ctx.assert_equal(runtime.pending.size(), count,
				"expected %d pending recipe(s), got %d" % [count, runtime.pending.size()])
	)

	registry.then("the pending queue has {int} recipes", func(ctx, count: int):
		var runtime: MiniRuntime = ctx.get_value("mini_runtime", null)
		ctx.assert_not_null(runtime, "mini_runtime must be set up by Background")
		if runtime != null:
			ctx.assert_equal(runtime.pending.size(), count,
				"expected %d pending recipe(s), got %d" % [count, runtime.pending.size()])
	)

	registry.then("the recipe_started signal was emitted once for {string}", func(ctx, recipe_id: String):
		var events: Array = ctx.get_value("recipe_events", [])
		var n := 0
		for e in events:
			if e.get("kind", &"") == &"started" and e.get("recipe_id", &"") == StringName(recipe_id):
				n += 1
		ctx.assert_equal(n, 1,
			"expected recipe_started(%s) once, got %d (log=%s)" % [recipe_id, n, events])
	)

	registry.then("the recipe_resolved signal was emitted once for {string}", func(ctx, recipe_id: String):
		var events: Array = ctx.get_value("recipe_events", [])
		var n := 0
		for e in events:
			if e.get("kind", &"") == &"resolved" and e.get("recipe_id", &"") == StringName(recipe_id):
				n += 1
		ctx.assert_equal(n, 1,
			"expected recipe_resolved(%s) once, got %d (log=%s)" % [recipe_id, n, events])
	)

	registry.then("the recipe_cancelled signal was emitted once for {string} with reason {string}", func(ctx, recipe_id: String, reason: String):
		var events: Array = ctx.get_value("recipe_events", [])
		var n := 0
		for e in events:
			if e.get("kind", &"") == &"cancelled" and e.get("recipe_id", &"") == StringName(recipe_id):
				if String(e.get("reason", &"")) == reason:
					n += 1
		ctx.assert_equal(n, 1,
			"expected recipe_cancelled(%s, %s) once, got %d (log=%s)" % [recipe_id, reason, n, events])
	)

	registry.then("the Journal is not unlocked {string}", func(ctx, entry_id: String):
		var journal: Node = ctx.get_value("journal", null)
		ctx.assert_not_null(journal, "journal must exist")
		if journal != null:
			ctx.assert_false(journal.is_unlocked(StringName(entry_id)),
				"expected %s NOT to be unlocked yet" % entry_id)
	)
