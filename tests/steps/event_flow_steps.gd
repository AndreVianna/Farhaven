extends RefCounted

## Step definitions for the event_flow BDD feature (task-085b, Category A).
##
## Drives real EventRegistry / DiscoveryWatcher / Journal autoload nodes
## (mirrored under tree.root via _get_or_create_autoload) so scenarios
## exercise the full signal chain rather than an in-memory simulacrum.
## Every scenario crosses at least two system boundaries:
##   - EventRegistry.event_fired → Journal._on_event_fired    (journal unlock)
##   - EventRegistry.event_fired → DiscoveryWatcher._on_event_fired (grant_recipe)
##   - EventRegistry.get_save_data / load_save_data           (persistence)
##
## Preconditions that need to "fail" are modeled through GameEvent.max_count
## being already saturated before try_fire is called — RecipeRuntime/
## DiscoveryWatcher never call into EventRegistry with pre-conditions, so
## mirroring a predicate-gate here would require the full PredicateEvaluator,
## which we cannot load under --script mode (depends on PropRegistry global).
## The effective semantic — "event did not emit because fire() refused" —
## is identical for both paths.

const _GameEvent = preload("res://scripts/core/event.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _EventRegistry = preload("res://scripts/core/event_registry.gd")
const _Journal = preload("res://scripts/journal/journal.gd")

# discovery_watcher.gd → predicate_evaluator.gd → hex_tile.gd references the
# `PropRegistry` autoload as a bare identifier. Under the --script runner,
# that identifier is not registered when step files parse, so `const`
# preloads fail with "Identifier not found: PropRegistry". Lazy-load after
# autoloads bootstrap.
const _DISCOVERY_WATCHER_PATH: String = "res://scripts/recipes/discovery_watcher.gd"
static var _DiscoveryWatcher: GDScript = null


const SPY_META_EVENT := &"_event_flow_event_spy"


static func _ensure_runtime_preloads() -> void:
	if _DiscoveryWatcher == null:
		_DiscoveryWatcher = load(_DISCOVERY_WATCHER_PATH)


static func _get_or_create_autoload(tree: SceneTree, autoload_name: String, fallback_script) -> Node:
	var existing: Node = tree.root.get_node_or_null(NodePath(autoload_name))
	if existing != null:
		return existing
	var inst: Node = fallback_script.new()
	inst.name = autoload_name
	tree.root.add_child(inst)
	return inst


static func _clear_event_spy(er: Node) -> void:
	if er.has_meta(SPY_META_EVENT):
		var old: Callable = er.get_meta(SPY_META_EVENT)
		if old.is_valid() and er.event_fired.is_connected(old):
			er.event_fired.disconnect(old)
		er.remove_meta(SPY_META_EVENT)


static func build_world(ctx) -> void:
	var tree: SceneTree = ctx.get_tree()
	assert(tree != null, "event_flow steps require a live SceneTree")
	_ensure_runtime_preloads()

	var er := _get_or_create_autoload(tree, "EventRegistry", _EventRegistry)
	var journal := _get_or_create_autoload(tree, "Journal", _Journal)
	var dw := _get_or_create_autoload(tree, "DiscoveryWatcher", _DiscoveryWatcher)

	# Force-wire the subscriber handlers (idempotent — mirrors what Journal
	# and DiscoveryWatcher _ready() does when real autoloads are in play).
	if journal._event_registry == null:
		journal._event_registry = er
	if not er.event_fired.is_connected(journal._on_event_fired):
		er.event_fired.connect(journal._on_event_fired)
	if dw._event_registry == null:
		dw._event_registry = er
	if not er.event_fired.is_connected(dw._on_event_fired):
		er.event_fired.connect(dw._on_event_fired)

	# Clean state leaked across scenarios. Each scenario expects a blank
	# journal and blank known-recipes list.
	journal.load_save_data({"unlocked_entries": []})
	dw.load_save_data({"known_recipes": []})

	# Clear EventRegistry's loaded events map so scenario-built events with
	# the same id don't collide with real autoload scans.
	er._events.clear()

	# Scrub previous scenario's event spy before hanging a new one. We store
	# the callable as meta on the EventRegistry node itself so it survives
	# TestContext.reset(), same pattern as narrative_steps.gd.
	_clear_event_spy(er)
	var spy := func(event_id: StringName, event: Resource):
		var log: Array = ctx.get_value("event_fired_log", [])
		log.append({"id": event_id, "count": event.count if event != null else -1})
		ctx.set_value("event_fired_log", log)
	er.event_fired.connect(spy)
	er.set_meta(SPY_META_EVENT, spy)

	ctx.set_value("event_registry", er)
	ctx.set_value("journal", journal)
	ctx.set_value("discovery_watcher", dw)
	ctx.set_value("event_fired_log", [] as Array)
	ctx.set_value("test_events", {} as Dictionary)


static func _build_event(event_id: String, max_count: int, effects: Array = []) -> _GameEvent:
	var ev := _GameEvent.new()
	ev.id = StringName(event_id)
	ev.display_name = event_id
	ev.max_count = max_count
	# GameEvent.effects is typed Array[Resource]; convert explicitly so
	# Godot doesn't reject the generic Array parameter assignment.
	var typed_effects: Array[Resource] = []
	for eff in effects:
		if eff is Resource:
			typed_effects.append(eff)
	ev.effects = typed_effects
	return ev


static func _store_event(ctx, event: _GameEvent) -> void:
	var events: Dictionary = ctx.get_value("test_events", {})
	events[event.id] = event
	ctx.set_value("test_events", events)
	# Also register the event in EventRegistry's internal map so scenario
	# code can address it by id via get_event/is_active.
	var er: Node = ctx.get_value("event_registry", null)
	if er != null:
		er._events[event.id] = event


static func _get_event(ctx, event_id: String) -> _GameEvent:
	var events: Dictionary = ctx.get_value("test_events", {})
	return events.get(StringName(event_id), null)


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


func register_steps(registry) -> void:
	# ---- Background ----
	registry.given("a clean event world with EventRegistry, DiscoveryWatcher and Journal", func(ctx):
		build_world(ctx)
	)

	# ---- Event construction ----
	registry.given("an unlimited GameEvent {string}", func(ctx, event_id: String):
		var ev := _build_event(event_id, 0, [])
		_store_event(ctx, ev)
	)

	registry.given("a one-shot GameEvent {string}", func(ctx, event_id: String):
		var ev := _build_event(event_id, 1, [])
		_store_event(ctx, ev)
	)

	registry.given("a GameEvent {string} with max_count {int}", func(ctx, event_id: String, mc: int):
		var ev := _build_event(event_id, mc, [])
		_store_event(ctx, ev)
	)

	# Saturated event: count == max_count, so GameEvent.fire() returns false.
	# EventRegistry/GameEvent do NOT evaluate predicate conditions — try_fire
	# only gates on max_count via GameEvent.fire(). This scenario exercises the
	# max_count gate, not a predicate gate. True predicate-gated flows live in
	# the recipe_lifecycle / discovery_chain features where PredicateEvaluator
	# is in the path.
	registry.given("a GameEvent {string} already at max_count", func(ctx, event_id: String):
		var ev := _build_event(event_id, 1, [])
		ev.count = 1  # Already saturated — fire() will return false.
		_store_event(ctx, ev)
	)

	registry.given("an unlimited GameEvent {string} with a grant_recipe effect for {string}", func(ctx, event_id: String, recipe_id: String):
		var ev := _build_event(event_id, 0, [_make_grant_recipe_effect(recipe_id)])
		_store_event(ctx, ev)
	)

	registry.given("an unlimited GameEvent {string} with an unlock_journal_entry effect for {string}", func(ctx, event_id: String, entry_id: String):
		var ev := _build_event(event_id, 0, [_make_unlock_journal_effect(entry_id)])
		_store_event(ctx, ev)
	)

	registry.given("the event_fired spy is clean", func(ctx):
		ctx.set_value("event_fired_log", [] as Array)
	)

	# ---- Actions ----
	registry.when("EventRegistry attempts to fire {string}", func(ctx, event_id: String):
		var er: Node = ctx.get_value("event_registry", null)
		var event := _get_event(ctx, event_id)
		ctx.assert_not_null(er, "event_registry must exist")
		ctx.assert_not_null(event, "event %s must be defined" % event_id)
		if er == null or event == null:
			return
		er.try_fire(event)
	)

	registry.when("the EventRegistry save data is captured, reset, and loaded back", func(ctx):
		var er: Node = ctx.get_value("event_registry", null)
		ctx.assert_not_null(er, "event_registry must exist")
		if er == null:
			return
		# Capture count snapshot before resetting.
		var snapshot: Dictionary = er.get_save_data()
		# Reset: walk test events and zero each count. This is what a fresh
		# session would show before load_save_data runs.
		var events: Dictionary = ctx.get_value("test_events", {})
		for id in events:
			events[id].count = 0
		# Apply the snapshot back.
		er.load_save_data(snapshot)
	)

	# ---- Assertions ----
	registry.then("the event_fired spy has {int} entries", func(ctx, expected: int):
		var log: Array = ctx.get_value("event_fired_log", [])
		ctx.assert_equal(log.size(), expected,
			"expected %d spy entries, got %d (log=%s)" % [expected, log.size(), log])
	)

	registry.then("the event_fired spy recorded {string} once", func(ctx, event_id: String):
		var log: Array = ctx.get_value("event_fired_log", [])
		var n := 0
		for e in log:
			if e.get("id", &"") == StringName(event_id):
				n += 1
		ctx.assert_equal(n, 1,
			"expected event_fired(%s) once, got %d (log=%s)" % [event_id, n, log])
	)

	registry.then("the event_fired spy recorded {string} {int} times", func(ctx, event_id: String, expected: int):
		var log: Array = ctx.get_value("event_fired_log", [])
		var n := 0
		for e in log:
			if e.get("id", &"") == StringName(event_id):
				n += 1
		ctx.assert_equal(n, expected,
			"expected event_fired(%s) %d times, got %d (log=%s)" % [event_id, expected, n, log])
	)

	registry.then("the event {string} count is {int}", func(ctx, event_id: String, expected: int):
		var event := _get_event(ctx, event_id)
		ctx.assert_not_null(event, "event %s must be defined" % event_id)
		if event != null:
			ctx.assert_equal(event.count, expected,
				"expected event %s count %d, got %d" % [event_id, expected, event.count])
	)

	registry.then("the event {string} cannot fire again", func(ctx, event_id: String):
		var event := _get_event(ctx, event_id)
		ctx.assert_not_null(event, "event %s must be defined" % event_id)
		if event != null:
			ctx.assert_false(event.can_fire(),
				"expected event %s to be unable to fire again" % event_id)
	)

	registry.then("DiscoveryWatcher knows recipe {string}", func(ctx, recipe_id: String):
		var dw: Node = ctx.get_value("discovery_watcher", null)
		ctx.assert_not_null(dw, "discovery_watcher must exist")
		if dw != null:
			ctx.assert_true(dw.is_known(StringName(recipe_id)),
				"expected %s to be known after event fired" % recipe_id)
	)
