extends RefCounted

## Step definitions for the discovery_chain BDD feature (task-085b, Category A).
##
## Exercises the end-to-end plumbing from a scanner-catalog signal through
## DiscoveryWatcher, EventRegistry, and Journal. The chain in production is:
##
##   ScannerSystem.entry_cataloged
##     → DiscoveryWatcher._on_entry_cataloged
##     → DiscoveryWatcher.check_unlocks(ctx)
##     → EventRegistry.try_fire(event)
##     → EventRegistry.event_fired
##     → DiscoveryWatcher._on_event_fired    (grant_recipe effect)
##     → Journal._on_event_fired             (unlock_journal_entry effect)
##
## Scanner is not instantiable under --script mode (scanner_system.gd
## references HexGrid / PropRegistry globals), and PredicateEvaluator
## cannot be used from the step file itself for the same reason. We
## therefore:
##   1. Use a minimal scanner spy that emits entry_cataloged → connected
##      directly into DiscoveryWatcher's public _on_entry_cataloged slot.
##   2. Build each discovery GameEvent with its conditions list EMPTY — the
##      "impossible condition" scenario instead sets max_count to 1 and
##      pre-increments count so event.can_fire() returns false. That is
##      operationally indistinguishable from a predicate gating the event
##      in the `_all_conditions_met` path (both paths end up NOT calling
##      EventRegistry.try_fire for that event).
##   3. When the real DW._on_entry_cataloged is called, it reconstructs a
##      WorldContext via _build_current_context() and calls check_unlocks.
##      With no conditions, _all_conditions_met returns true for still-
##      fireable events and the try_fire cascade runs for real — hitting
##      real Journal and real DW handlers.
##
## This gives us end-to-end coverage of the discovery chain without
## dragging in the PropRegistry-dependent predicate evaluator.

const _GameEvent = preload("res://scripts/core/event.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _EventRegistry = preload("res://scripts/core/event_registry.gd")
const _Journal = preload("res://scripts/journal/journal.gd")
# NOTE: discovery_watcher.gd transitively preloads predicate_evaluator.gd,
# which preloads hex_tile.gd, which references the `PropRegistry` autoload
# as an identifier. Under the gherkin --script runner, autoload identifiers
# are not in scope at the time step files are parsed, so `const` preloads
# here would fail with "Identifier not found: PropRegistry". We defer the
# load to runtime (inside build_world) via `load()`, after autoloads are
# registered in the SceneTree.
# Similar reason for _WorldContext (uses the same chain).
const _DISCOVERY_WATCHER_PATH: String = "res://scripts/recipes/discovery_watcher.gd"
const _WORLD_CONTEXT_PATH: String = "res://scripts/recipes/world_context.gd"
static var _DiscoveryWatcher: GDScript = null
static var _WorldContext: GDScript = null


static func _ensure_runtime_preloads() -> void:
	if _DiscoveryWatcher == null:
		_DiscoveryWatcher = load(_DISCOVERY_WATCHER_PATH)
	if _WorldContext == null:
		_WorldContext = load(_WORLD_CONTEXT_PATH)


## Minimal scanner stand-in: emits `entry_cataloged` with the same signal
## shape ScannerSystem uses. DiscoveryWatcher's `_on_entry_cataloged` handler
## accepts (entry_id: StringName, category: int) — we pass PLANT (=0) as a
## neutral bucket for the test (real scanner would pass the prop's category
## or Catalog.ANOMALY_BUCKET for anomalies).
class FakeScanner extends RefCounted:
	signal entry_cataloged(entry_id: StringName, bucket: int)
	func catalog(entry_id: StringName) -> void:
		entry_cataloged.emit(entry_id, 0)


static func _get_or_create_autoload(tree: SceneTree, autoload_name: String, fallback_script) -> Node:
	var existing: Node = tree.root.get_node_or_null(NodePath(autoload_name))
	if existing != null:
		return existing
	var inst: Node = fallback_script.new()
	inst.name = autoload_name
	tree.root.add_child(inst)
	return inst


static func build_world(ctx) -> void:
	var tree: SceneTree = ctx.get_tree()
	assert(tree != null, "discovery_chain steps require a live SceneTree")
	_ensure_runtime_preloads()

	var er := _get_or_create_autoload(tree, "EventRegistry", _EventRegistry)
	var journal := _get_or_create_autoload(tree, "Journal", _Journal)
	var dw := _get_or_create_autoload(tree, "DiscoveryWatcher", _DiscoveryWatcher)

	# Wire subscribers (idempotent).
	if journal._event_registry == null:
		journal._event_registry = er
	if not er.event_fired.is_connected(journal._on_event_fired):
		er.event_fired.connect(journal._on_event_fired)
	if dw._event_registry == null:
		dw._event_registry = er
	if not er.event_fired.is_connected(dw._on_event_fired):
		er.event_fired.connect(dw._on_event_fired)

	# Start each scenario blank.
	journal.load_save_data({"unlocked_entries": []})
	dw.load_save_data({"known_recipes": []})
	er._events.clear()
	dw._discovery_events.clear()

	# Fake scanner per scenario — wired into DiscoveryWatcher's public
	# entry_cataloged handler.
	var scanner := FakeScanner.new()
	scanner.entry_cataloged.connect(dw._on_entry_cataloged)
	# Hang it on ctx so catalog mutations persist for the scenario.
	ctx.set_value("fake_scanner", scanner)
	# Simple in-process catalog substitute: a dict that the scenario updates
	# on each catalog signal. Used by assertions on "what is cataloged".
	ctx.set_value("cataloged_set", {} as Dictionary)

	ctx.set_value("event_registry", er)
	ctx.set_value("journal", journal)
	ctx.set_value("discovery_watcher", dw)
	ctx.set_value("test_events", {} as Dictionary)


static func _make_grant_recipe_effect(recipe_id: String) -> _RecipeEffect:
	var eff := _RecipeEffect.new()
	eff.kind = &"grant_recipe"
	eff.params = {"recipe_id": recipe_id}
	return eff


static func _make_unlock_journal_effect(entry_id: String) -> _RecipeEffect:
	var eff := _RecipeEffect.new()
	eff.kind = &"unlock_journal_entry"
	eff.params = {"entry_id": entry_id}
	return eff


static func _build_discovery_event(event_id: String, recipe_id: String, entry_id: String = "") -> _GameEvent:
	# GameEvent.effects is typed Array[Resource] — start with the typed
	# array to satisfy the assignment below.
	var effects: Array[Resource] = []
	effects.append(_make_grant_recipe_effect(recipe_id))
	if entry_id != "":
		effects.append(_make_unlock_journal_effect(entry_id))
	var ev := _GameEvent.new()
	ev.id = StringName(event_id)
	ev.display_name = event_id
	ev.max_count = 1
	ev.effects = effects
	return ev


static func _store_event(ctx, event: _GameEvent) -> void:
	var events: Dictionary = ctx.get_value("test_events", {})
	events[event.id] = event
	ctx.set_value("test_events", events)


static func _get_event(ctx, event_id: String) -> _GameEvent:
	var events: Dictionary = ctx.get_value("test_events", {})
	return events.get(StringName(event_id), null)


func register_steps(registry) -> void:
	# ---- Background ----
	registry.given("a clean discovery chain world", func(ctx):
		build_world(ctx)
	)

	registry.given("a discovery GameEvent {string} that grants recipe {string} and unlocks entry {string}",
		func(ctx, event_id: String, recipe_id: String, entry_id: String):
			var ev := _build_discovery_event(event_id, recipe_id, entry_id)
			_store_event(ctx, ev)
	)

	registry.given("a discovery GameEvent {string} that grants recipe {string}",
		func(ctx, event_id: String, recipe_id: String):
			var ev := _build_discovery_event(event_id, recipe_id, "")
			_store_event(ctx, ev)
	)

	# "Impossible" cataloged condition: we cannot instantiate PredicateEvaluator
	# under --script mode, so the condition shape cannot actually execute. The
	# effective observable — event NEVER fires regardless of how many times
	# catalog signals arrive — is modeled by pre-saturating max_count. See
	# top-of-file note for why this is semantically equivalent.
	registry.given("the event {string} has an impossible cataloged condition for {string}",
		func(ctx, event_id: String, _prop_id: String):
			var event := _get_event(ctx, event_id)
			ctx.assert_not_null(event, "event %s must be defined first" % event_id)
			if event == null:
				return
			# Pre-saturate — event.fire() will always return false from now on,
			# same as a predicate gate would.
			event.count = event.max_count
	)

	registry.given("the event {string} is registered on EventRegistry",
		func(ctx, event_id: String):
			var event := _get_event(ctx, event_id)
			var er: Node = ctx.get_value("event_registry", null)
			var dw: Node = ctx.get_value("discovery_watcher", null)
			ctx.assert_not_null(event, "event %s must be defined first" % event_id)
			ctx.assert_not_null(er, "EventRegistry must exist")
			ctx.assert_not_null(dw, "DiscoveryWatcher must exist")
			if event == null or er == null or dw == null:
				return
			er._events[event.id] = event
			# Manually build the discovery-events index entry for this event.
			# Production's _index_discovery_events() runs during DW._ready(),
			# before any test-supplied events are registered — so we have to
			# backfill the index ourselves.
			for eff in event.effects:
				if eff.kind == &"grant_recipe":
					var recipe_id := StringName(eff.params.get("recipe_id", ""))
					if recipe_id != &"":
						dw._discovery_events[recipe_id] = event
	)

	registry.given("the journal starts empty", func(ctx):
		var journal: Node = ctx.get_value("journal", null)
		ctx.assert_not_null(journal, "journal must exist")
		if journal != null:
			journal.load_save_data({"unlocked_entries": []})
	)

	registry.when("the scanner signals entry_cataloged for {string}",
		func(ctx, prop_id: String):
			var scanner: FakeScanner = ctx.get_value("fake_scanner", null)
			ctx.assert_not_null(scanner, "fake scanner must exist")
			if scanner != null:
				scanner.catalog(StringName(prop_id))
			# Record the catalog fact for later assertions.
			var set_dict: Dictionary = ctx.get_value("cataloged_set", {})
			set_dict[StringName(prop_id)] = true
			ctx.set_value("cataloged_set", set_dict)
	)

	# Manually drive DW.check_unlocks with an empty WorldContext. DW's own
	# `_on_entry_cataloged` handler does this internally via
	# `_build_current_context`, but that handler runs `PredicateEvaluator`
	# when there are conditions — which blows up under `--script` mode.
	# With no conditions on the test events, the evaluator is never invoked,
	# and a minimal context suffices. Keeping this step explicit makes the
	# chain visible in the feature file.
	registry.when("DiscoveryWatcher runs check_unlocks with catalog tracking {string}",
		func(ctx, _prop_id: String):
			var dw: Node = ctx.get_value("discovery_watcher", null)
			ctx.assert_not_null(dw, "DiscoveryWatcher must exist")
			if dw == null:
				return
			# Build a minimal WorldContext. We avoid preloading WorldContext
			# directly (its class_name registration depends on a long chain
			# that also imports PredicateEvaluator indirectly in the general
			# project, but the plain WorldContext resource itself is safe —
			# still, we use a plain RefCounted with the same duck-typed
			# fields to keep the preload surface minimal).
			var minimal_ctx = _build_minimal_ctx()
			dw.check_unlocks(minimal_ctx)
	)

	registry.then("DiscoveryWatcher knows recipe {string}",
		func(ctx, recipe_id: String):
			var dw: Node = ctx.get_value("discovery_watcher", null)
			ctx.assert_not_null(dw, "discovery_watcher must exist")
			if dw != null:
				ctx.assert_true(dw.is_known(StringName(recipe_id)),
					"expected %s to be known via discovery chain" % recipe_id)
	)

	registry.then("DiscoveryWatcher does not know recipe {string}",
		func(ctx, recipe_id: String):
			var dw: Node = ctx.get_value("discovery_watcher", null)
			ctx.assert_not_null(dw, "discovery_watcher must exist")
			if dw != null:
				ctx.assert_false(dw.is_known(StringName(recipe_id)),
					"expected %s NOT to be known" % recipe_id)
	)


static func _build_minimal_ctx():
	# Minimal WorldContext stand-in. DiscoveryWatcher.check_unlocks reads
	# only `_all_conditions_met(event, ctx)`, which iterates `event.conditions`
	# — empty for our test events — so the ctx is never actually dereferenced
	# for field access. But its signature types the parameter to WorldContext,
	# so we instantiate the real class to satisfy that.
	_ensure_runtime_preloads()
	return _WorldContext.new()
