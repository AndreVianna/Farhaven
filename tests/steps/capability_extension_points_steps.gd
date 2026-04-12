extends RefCounted

## Step definitions for capability_extension_points.feature.
##
## Goal: prove that the published extension points on capability classes
## (BehaviorCap.reactions, CombatCap.attacks/defenses, MovementCap.modes,
## EnduranceCap damage-tag arrays, CatalogableCap.show_as_anomaly) plug
## cleanly into real engine subsystems — EventRegistry, ResourceSaver, and
## the Catalog anomaly-bucket rule.
##
## Real dependencies (loaded as production code):
## - EventRegistry — adopted from tree.root when available, created fresh
##   otherwise. Same pattern as narrative_steps.gd.
## - PropDef + every Capability class — preloaded from scripts/data/**.
## - GameEvent — the real Resource with fire/can_fire/count state.
##
## Deferred / mirrored:
## - Catalog class itself cannot be preloaded under `--script` because
##   `scripts/scanner/catalog.gd` has a function-level `PropRegistry`
##   identifier (line 50) and Godot's parser errors out when the autoload
##   global isn't registered. We therefore mirror the one-liner rule from
##   `Catalog._resolve_display_bucket` (catalog.gd lines 181-186): if
##   `entry.catalogable.show_as_anomaly` is true, the display bucket is
##   `Catalog.ANOMALY_BUCKET` (= -1); otherwise it's `entry.prop_category`.
##   If production drifts, the rule is small enough that the mirror will
##   fail visibly the next time `_resolve_display_bucket` is touched.
## - Combat runtime is deferred to task-088. These scenarios prove the
##   schema + iteration contract — Array[GameEvent] round-trips through
##   EventRegistry.try_fire — not a live combat loop.
##
## Runner quirks (inherited from narrative_steps.gd):
## - `is_inside_tree()` lies under SceneTree._init(); walk parent chain.
## - Signal capture is synchronous via `set_meta` spies; no `await`.
## - TestContext.reset() wipes ctx state BEFORE Background re-runs, so
##   spy Callables are pinned to the Node via `set_meta`, not to ctx.
## - Common steps in common_steps.gd are reused read-only; no edits.

const _GameEvent = preload("res://scripts/core/event.gd")
const _EventRegistry = preload("res://scripts/core/event_registry.gd")
const _MovementCap = preload("res://scripts/data/capabilities/movement_cap.gd")
const _CombatCap = preload("res://scripts/data/capabilities/combat_cap.gd")
const _BehaviorCap = preload("res://scripts/data/capabilities/behavior_cap.gd")

## Mirror of `Catalog.ANOMALY_BUCKET` (scripts/scanner/catalog.gd line 12).
## Documented as a mirror because the Catalog class itself is not loadable
## under `--script` (see top-of-file note).
const ANOMALY_BUCKET: int = -1

const SPY_META_EVENTS := &"_capext_event_spy"


# --------------------------------------------------------------------------
# World setup
# --------------------------------------------------------------------------


## Adopts (or creates) the production EventRegistry under `tree.root` and
## wipes any leftover state from previous scenarios. Uses the same reuse
## strategy as narrative_steps.build_world — if Godot already provisioned
## a real autoload, we reuse it (resetting its counts) so subsequent
## production code that looks up `tree.root.get_node("EventRegistry")`
## still resolves.
static func _build_world(ctx) -> void:
	var tree: SceneTree = ctx.get_tree()
	assert(tree != null, "capability_extension_points requires a live SceneTree")

	var er: Node = tree.root.get_node_or_null(NodePath("EventRegistry"))
	if er == null:
		er = _EventRegistry.new()
		er.name = "EventRegistry"
		tree.root.add_child(er)

	# Reset per-event counts so prior scenarios don't pollute this one.
	# We only touch the events we registered — production events are left
	# alone in case autoloads preloaded real .tres data.
	var registered: Array = ctx.get_value("_capext_events", [])
	for ev in registered:
		if ev != null and ev is _GameEvent:
			ev.count = 0

	ctx.set_value("event_registry", er)

	# Per-scenario scratch state — cleared every Background.
	ctx.set_value("_capext_events", [] as Array)
	ctx.set_value("event_log", [] as Array)
	ctx.set_value("last_fire_accepted", false)

	# Wire a synchronous signal spy on event_fired so Then steps can read
	# the log without awaiting. Store the Callable on the Node via set_meta
	# so it survives TestContext.reset() between scenarios (same strategy
	# as narrative_steps.SPY_META_JOURNAL).
	_clear_spy(er)
	var spy := func(event_id: StringName, _event: Resource):
		var log: Array = ctx.get_value("event_log", [])
		log.append(event_id)
		ctx.set_value("event_log", log)
	er.event_fired.connect(spy)
	er.set_meta(SPY_META_EVENTS, spy)


static func _clear_spy(er: Node) -> void:
	if er == null:
		return
	if er.has_meta(SPY_META_EVENTS):
		var old: Callable = er.get_meta(SPY_META_EVENTS)
		if old.is_valid() and er.event_fired.is_connected(old):
			er.event_fired.disconnect(old)
		er.remove_meta(SPY_META_EVENTS)


# --------------------------------------------------------------------------
# Builders (re-used from multi_capability path)
# --------------------------------------------------------------------------


## NOTE: `_build_prop_def` lives in multi_capability_prop_steps.gd and its
## shared step "a new PropDef {string} is built with capabilities {string}"
## populates ctx.prop_def. Scenarios here reuse that via the global registry.


static func _make_event(event_id: StringName, max_count: int) -> Resource:
	var e: Resource = _GameEvent.new()
	e.id = event_id
	e.display_name = String(event_id)
	e.max_count = max_count
	e.count = 0
	return e


## Mirrors Catalog._resolve_display_bucket (scripts/scanner/catalog.gd L181-186).
## See top-of-file note for why we can't call the real method directly.
static func _resolve_display_bucket(def: Resource) -> int:
	if def == null:
		return 0
	if def.catalogable != null and def.catalogable.show_as_anomaly:
		return ANOMALY_BUCKET
	return def.prop_category


# --------------------------------------------------------------------------
# Step registration
# --------------------------------------------------------------------------


func register_steps(registry) -> void:
	# ---- Background ----
	registry.given("a capability extension test world", func(ctx):
		_build_world(ctx)
	)

	# ---- PropDef sources ----
	# NOTE: "a PropDef loaded from {string}" and
	# "a new PropDef {string} is built with capabilities {string}" are
	# defined in multi_capability_prop_steps.gd and shared via the global
	# step registry. We do not redefine them here.

	# ---- BehaviorCap.reactions attachment ----
	registry.given(
		"a GameEvent {string} with max_count {int} is attached to behavior.reactions",
		func(ctx, event_id: String, max_count: int):
			var def: Resource = ctx.get_value("prop_def", null)
			ctx.assert_not_null(def, "prop_def must exist")
			if def == null:
				return
			# Ensure the cap exists — load from disk usually already has one,
			# programmatic builds may not.
			if def.behavior == null:
				def.behavior = _BehaviorCap.new()
			var ev: Resource = _make_event(StringName(event_id), max_count)
			def.behavior.reactions.append(ev)
			var registered: Array = ctx.get_value("_capext_events", [])
			registered.append(ev)
			ctx.set_value("_capext_events", registered)
	)

	# ---- CombatCap.attacks / defenses attachment ----
	registry.given(
		"GameEvents {string} with max_count {int} are attached to combat.attacks",
		func(ctx, event_csv: String, max_count: int):
			_attach_combat_events(ctx, event_csv, max_count, "attacks")
	)

	registry.given(
		"GameEvents {string} with max_count {int} are attached to combat.defenses",
		func(ctx, event_csv: String, max_count: int):
			_attach_combat_events(ctx, event_csv, max_count, "defenses")
	)

	# ---- Capability field setters ----
	registry.given(
		"the PropDef movement modes are set to {string}",
		func(ctx, modes_spec: String):
			var def: Resource = ctx.get_value("prop_def", null)
			ctx.assert_not_null(def, "prop_def must exist")
			if def == null or def.movement == null:
				ctx.fail("movement cap missing")
				return
			def.movement.modes = _parse_modes_spec(modes_spec)
	)

	registry.given(
		"the PropDef endurance vulnerabilities are {string}",
		func(ctx, csv: String):
			var def: Resource = ctx.get_value("prop_def", null)
			if def == null or def.endurance == null:
				ctx.fail("endurance cap missing")
				return
			def.endurance.vulnerabilities = _csv_to_stringnames(csv)
	)

	registry.given(
		"the PropDef endurance resistances are {string}",
		func(ctx, csv: String):
			var def: Resource = ctx.get_value("prop_def", null)
			if def == null or def.endurance == null:
				ctx.fail("endurance cap missing")
				return
			def.endurance.resistances = _csv_to_stringnames(csv)
	)

	registry.given(
		"the PropDef endurance immunities are {string}",
		func(ctx, csv: String):
			var def: Resource = ctx.get_value("prop_def", null)
			if def == null or def.endurance == null:
				ctx.fail("endurance cap missing")
				return
			def.endurance.immunities = _csv_to_stringnames(csv)
	)

	registry.given(
		"the PropDef catalogable show_as_anomaly is true",
		func(ctx):
			var def: Resource = ctx.get_value("prop_def", null)
			if def == null or def.catalogable == null:
				ctx.fail("catalogable cap missing")
				return
			def.catalogable.show_as_anomaly = true
	)

	# ---- Firing events through EventRegistry ----
	registry.when("the first behavior reaction event is fired through EventRegistry", func(ctx):
		var def: Resource = ctx.get_value("prop_def", null)
		var er: Node = ctx.get_value("event_registry", null)
		ctx.assert_not_null(def, "prop_def must exist")
		ctx.assert_not_null(er, "event_registry must exist")
		if def == null or er == null:
			return
		if def.behavior == null or def.behavior.reactions.is_empty():
			ctx.fail("behavior.reactions is empty")
			return
		var ev: Resource = def.behavior.reactions[0]
		var accepted: bool = er.try_fire(ev)
		ctx.set_value("last_fire_accepted", accepted)
	)

	registry.when("every combat attack event is fired through EventRegistry", func(ctx):
		_fire_cap_list(ctx, "attacks")
	)

	registry.when("every combat defense event is fired through EventRegistry", func(ctx):
		_fire_cap_list(ctx, "defenses")
	)

	# ---- Save / reload round-trip ----
	# NOTE: "the PropDef is saved to disk and loaded back" is defined in
	# multi_capability_prop_steps.gd and shared via the global step
	# registry.

	# ---- Fire-result assertions ----
	registry.then("the fired event was accepted", func(ctx):
		var accepted: bool = ctx.get_value("last_fire_accepted", false)
		ctx.assert_true(accepted, "EventRegistry.try_fire should have returned true")
	)

	registry.then("the GameEvent {string} count is {int}", func(ctx, event_id: String, expected: int):
		var registered: Array = ctx.get_value("_capext_events", [])
		var found: Resource = null
		for ev in registered:
			if ev != null and ev.id == StringName(event_id):
				found = ev
				break
		ctx.assert_not_null(found, "registered GameEvent %s must be found" % event_id)
		if found != null:
			ctx.assert_equal(found.count, expected,
				"GameEvent %s count mismatch (log=%s)" % [event_id, ctx.get_value("event_log", [])])
	)

	# ---- Reloaded MovementCap field assertions ----
	registry.then(
		"the reloaded PropDef movement mode {int} has normal speed {float}",
		func(ctx, mode: int, expected: float):
			var def: Resource = ctx.get_value("reloaded_prop_def", null)
			if def == null or def.movement == null:
				ctx.fail("reloaded movement cap missing")
				return
			var pair = def.movement.modes.get(mode, null)
			ctx.assert_not_null(pair, "reloaded movement.modes[%d] missing" % mode)
			if pair != null:
				ctx.assert_equal(float(pair[0]), expected,
					"reloaded movement.modes[%d] normal speed mismatch" % mode)
	)

	registry.then(
		"the reloaded PropDef movement mode {int} has max speed {float}",
		func(ctx, mode: int, expected: float):
			var def: Resource = ctx.get_value("reloaded_prop_def", null)
			if def == null or def.movement == null:
				ctx.fail("reloaded movement cap missing")
				return
			var pair = def.movement.modes.get(mode, null)
			ctx.assert_not_null(pair, "reloaded movement.modes[%d] missing" % mode)
			if pair != null and pair.size() >= 2:
				ctx.assert_equal(float(pair[1]), expected,
					"reloaded movement.modes[%d] max speed mismatch" % mode)
	)

	# ---- Reloaded EnduranceCap tag membership assertions ----
	registry.then("the reloaded PropDef endurance is vulnerable to {string}", func(ctx, tag: String):
		var def: Resource = ctx.get_value("reloaded_prop_def", null)
		if def == null or def.endurance == null:
			ctx.fail("reloaded endurance cap missing")
			return
		ctx.assert_true(def.endurance.vulnerabilities.has(StringName(tag)),
			"vulnerabilities should contain %s (got %s)" % [tag, def.endurance.vulnerabilities])
	)

	registry.then(
		"the reloaded PropDef endurance is not vulnerable to {string}",
		func(ctx, tag: String):
			var def: Resource = ctx.get_value("reloaded_prop_def", null)
			if def == null or def.endurance == null:
				ctx.fail("reloaded endurance cap missing")
				return
			ctx.assert_false(def.endurance.vulnerabilities.has(StringName(tag)),
				"vulnerabilities should NOT contain %s" % tag)
	)

	registry.then("the reloaded PropDef endurance resists {string}", func(ctx, tag: String):
		var def: Resource = ctx.get_value("reloaded_prop_def", null)
		if def == null or def.endurance == null:
			ctx.fail("reloaded endurance cap missing")
			return
		ctx.assert_true(def.endurance.resistances.has(StringName(tag)),
			"resistances should contain %s (got %s)" % [tag, def.endurance.resistances])
	)

	registry.then("the reloaded PropDef endurance is immune to {string}", func(ctx, tag: String):
		var def: Resource = ctx.get_value("reloaded_prop_def", null)
		if def == null or def.endurance == null:
			ctx.fail("reloaded endurance cap missing")
			return
		ctx.assert_true(def.endurance.immunities.has(StringName(tag)),
			"immunities should contain %s (got %s)" % [tag, def.endurance.immunities])
	)

	# ---- CatalogableCap anomaly-bucket resolution ----
	registry.then("the PropDef resolves to the ANOMALY_BUCKET display bucket", func(ctx):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null:
			ctx.assert_equal(_resolve_display_bucket(def), ANOMALY_BUCKET,
				"show_as_anomaly override should route to ANOMALY_BUCKET")
	)

	registry.then(
		"a PropDef loaded from {string} resolves to its prop_category display bucket",
		func(ctx, tres_path: String):
			var def: Resource = load(tres_path)
			ctx.assert_not_null(def, "PropDef must load from %s" % tres_path)
			if def != null:
				var bucket: int = _resolve_display_bucket(def)
				ctx.assert_equal(bucket, def.prop_category,
					"fauna without anomaly override should route to its prop_category")
				ctx.assert_not_equal(bucket, ANOMALY_BUCKET,
					"fauna without anomaly override must NOT be in ANOMALY_BUCKET")
	)


# --------------------------------------------------------------------------
# Helpers used by step callables
# --------------------------------------------------------------------------


## Attaches GameEvents to either combat.attacks or combat.defenses,
## tracking them in ctx so Then steps can look up their count.
static func _attach_combat_events(ctx, event_csv: String, max_count: int, which: String) -> void:
	var def: Resource = ctx.get_value("prop_def", null)
	if def == null:
		ctx.fail("prop_def must exist before attaching combat events")
		return
	if def.combat == null:
		def.combat = _CombatCap.new()
	var target: Array = def.combat.attacks if which == "attacks" else def.combat.defenses
	var registered: Array = ctx.get_value("_capext_events", [])
	for token in event_csv.split(","):
		var id := StringName(token.strip_edges())
		var ev: Resource = _make_event(id, max_count)
		target.append(ev)
		registered.append(ev)
	if which == "attacks":
		def.combat.attacks = target
	else:
		def.combat.defenses = target
	ctx.set_value("_capext_events", registered)


## Fires every event in combat.attacks (or combat.defenses) through the
## real EventRegistry, exercising the Array[GameEvent] iteration contract.
static func _fire_cap_list(ctx, which: String) -> void:
	var def: Resource = ctx.get_value("prop_def", null)
	var er: Node = ctx.get_value("event_registry", null)
	if def == null or er == null or def.combat == null:
		ctx.fail("combat cap or event_registry missing")
		return
	var list: Array = def.combat.attacks if which == "attacks" else def.combat.defenses
	for ev in list:
		er.try_fire(ev)


## Parses "WALK=1.0,1.5;SWIM=0.8,1.2" into a Dictionary matching
## MovementCap.modes format: { Mode enum int → [normal, max] }.
## Uses MovementCap.Mode enum values so the round-trip preserves keys.
static func _parse_modes_spec(spec: String) -> Dictionary:
	var result: Dictionary = {}
	for entry in spec.split(";"):
		var clean := entry.strip_edges()
		if clean.is_empty():
			continue
		var eq_idx := clean.find("=")
		if eq_idx < 0:
			continue
		var mode_name := clean.substr(0, eq_idx).strip_edges().to_upper()
		var speeds := clean.substr(eq_idx + 1).strip_edges()
		var parts := speeds.split(",")
		if parts.size() < 2:
			continue
		var key: int = _mode_name_to_int(mode_name)
		if key < 0:
			continue
		result[key] = [float(parts[0]), float(parts[1])]
	return result


static func _mode_name_to_int(mode_name: String) -> int:
	# Mirror of MovementCap.Mode enum ordering (walk=0, swim=1, fly=2, ...)
	match mode_name:
		"WALK": return _MovementCap.Mode.WALK
		"SWIM": return _MovementCap.Mode.SWIM
		"FLY": return _MovementCap.Mode.FLY
		"BURROW": return _MovementCap.Mode.BURROW
		"CLIMB": return _MovementCap.Mode.CLIMB
		"JUMP": return _MovementCap.Mode.JUMP
	return -1


static func _csv_to_stringnames(csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for token in csv.split(","):
		var trimmed := token.strip_edges()
		if not trimmed.is_empty():
			out.append(StringName(trimmed))
	return out
