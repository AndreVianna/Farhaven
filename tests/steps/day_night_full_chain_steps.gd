extends RefCounted

## Step definitions for the day/night full-chain BDD feature (task-085e).
##
## These scenarios exercise the REAL `DayNightCycle`, `LightingManager`, and
## `FaunaManager` code — not simulacra — to cover the cross-system wiring that
## delivery-007 content authoring will depend on. Every scenario crosses at
## least two systems (day/night <-> lighting, day/night <-> fauna, or
## lighting <-> inventory/player).
##
## Runner quirks this file compensates for (see narrative_steps.gd for the
## definitive write-up of the Gherkin CLI's `SceneTree._init()` behaviour):
##
## 1. **Autoloads do not materialise until a frame has been processed.** The
##    Gherkin CLI runs entirely inside `SceneTree._init()`, and `_load_steps`
##    runs synchronously before any `await tree.process_frame`. As a result,
##    `root.get_node_or_null("DayNightCycle")` returns null at step-file load
##    time, and preloading day_night_cycle.gd / lighting_manager.gd /
##    fauna_manager.gd from the class body would fail with "Identifier not
##    found: HexGrid" / "PropRegistry" (the compiler does not see the
##    autoload globals either). Instead, the Background step returns
##    `tree.process_frame` as its Signal, which `scenario_executor` awaits
##    (see scenario_executor.gd `_execute_step`). After that yield, the
##    autoloads exist under `tree.root` and every subsequent `load()` of
##    their source scripts compiles cleanly.
##
## 2. **`Node.is_inside_tree()` still reports false** because the tree's
##    "started" flag never gets set — we do not rely on it anywhere in this
##    file.
##
## 3. **`ctx.reset()` wipes scenario-scoped state BEFORE the Background step
##    re-runs**, so any spy Callables we hang off the context are gone by
##    the time the second scenario runs its setup. We store spy callables on
##    the nodes themselves via `set_meta()` and disconnect them before
##    reconnecting — same trick narrative_steps.gd uses.
##
## Signal capture is synchronous: spies connect to real signals, and the
## producers (`_advance_phase`, `dawn.emit`, `night.emit`) emit in the same
## stack frame so the Then steps read captured values without any `await`.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _LightCap = preload("res://scripts/data/capabilities/light_cap.gd")

# Phase name <-> TimePhase int mapping (mirrors day_night_steps.gd for parity).
const PHASE_FROM_NAME: Dictionary = {
	"DAY": 0,
	"DUSK": 1,
	"NIGHT": 2,
	"DAWN": 3,
}
const PHASE_TO_NAME: Dictionary = {
	0: "DAY",
	1: "DUSK",
	2: "NIGHT",
	3: "DAWN",
}

# Meta keys used to pin spies on autoload nodes across scenario resets.
const _SPY_PHASE_CHANGED := &"_day_night_full_chain_phase_spy"
const _SPY_FAUNA_DESPAWNED := &"_day_night_full_chain_fauna_despawned_spy"


# --------------------------------------------------------------------------
# World setup helpers
# --------------------------------------------------------------------------


static func _get_dnc(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null(NodePath("DayNightCycle"))


static func _get_lm(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null(NodePath("LightingManager"))


## Sweeps the phase_changed spy attached by a previous scenario's Background.
static func _clear_dnc_spy(dnc: Node) -> void:
	if dnc.has_meta(_SPY_PHASE_CHANGED):
		var old: Callable = dnc.get_meta(_SPY_PHASE_CHANGED)
		if old.is_valid() and dnc.phase_changed.is_connected(old):
			dnc.phase_changed.disconnect(old)
		dnc.remove_meta(_SPY_PHASE_CHANGED)


## Reset DayNightCycle state to a known-good baseline for every scenario.
## Safe to call repeatedly — no side effects on the tween system because
## `_env`/`_sun` are null under BDD (no scene-registered WorldEnvironment).
static func _reset_dnc(dnc: Node) -> void:
	dnc.current_phase = 0  # TimePhase.DAY
	dnc.phase_elapsed = 0.0
	dnc.day_count = 1
	dnc.is_daytime = true


## Reset LightingManager state for every scenario.
static func _reset_lm(lm: Node) -> void:
	lm._structure_lights.clear()
	lm._player_light = {}
	lm._player_world_pos = Vector2.ZERO


## Load the FaunaManager script at runtime. We cannot preload it at class
## body because its `_is_fauna_passable` references `PropRegistry` as a
## global identifier, which would fail to compile at step-file load time
## (before autoloads materialise). After the Background `await`, the load
## succeeds.
static func _load_fauna_manager_script() -> GDScript:
	return load("res://scripts/fauna/fauna_manager.gd") as GDScript


## Build a FaunaManager instance for fauna scenarios. We always create a
## fresh one because FaunaManager is a per-player scene-graph node in
## production (not an autoload) and every scenario wants an empty fauna list.
static func _build_fresh_fauna(tree: SceneTree, dnc: Node, lm: Node) -> Node:
	var fm_script := _load_fauna_manager_script()
	assert(fm_script != null and fm_script.can_instantiate(),
		"fauna_manager.gd must be instantiable after autoload materialisation")
	var fm: Node = fm_script.new()
	fm.name = "TestFaunaManager_%d" % Time.get_ticks_usec()
	# Inject deps BEFORE _ready runs via add_child. FaunaManager._connect_signals
	# then wires _on_night / _on_dawn onto the real DayNightCycle so our emit()
	# calls exercise production wiring.
	fm._dnc = dnc
	fm._lighting = lm
	tree.root.add_child(fm)
	return fm


# --------------------------------------------------------------------------
# Lazy setup — called at the top of every non-background step to guarantee
# `dnc` / `lm` are present in the context. Safe to call repeatedly.
# --------------------------------------------------------------------------


static func _ensure_world_ready(ctx) -> void:
	if ctx.get_value("dnc", null) != null:
		return
	var tree: SceneTree = ctx.get_tree()
	if tree == null:
		return
	var dnc := _get_dnc(tree)
	var lm := _get_lm(tree)
	if dnc == null or lm == null:
		return
	_reset_dnc(dnc)
	_reset_lm(lm)
	_clear_dnc_spy(dnc)
	ctx.set_value("dnc", dnc)
	ctx.set_value("lm", lm)
	ctx.set_value("phase_changed_log", [] as Array)
	var spy := func(old_phase, new_phase):
		var log: Array = ctx.get_value("phase_changed_log", [])
		log.append({"old": old_phase, "new": new_phase})
		ctx.set_value("phase_changed_log", log)
	dnc.phase_changed.connect(spy)
	dnc.set_meta(_SPY_PHASE_CHANGED, spy)


# --------------------------------------------------------------------------
# Step registration
# --------------------------------------------------------------------------


func register_steps(registry) -> void:
	# ---- Background ----
	#
	# Returning a Signal from the lambda causes scenario_executor to `await`
	# it (see scenario_executor.gd `_execute_step`). That yield lets Godot
	# run one process frame, which is enough for the engine to materialise
	# the project autoloads (`DayNightCycle`, `LightingManager`,
	# `HexGrid`, `PropRegistry`, ...) under `tree.root`. After the await
	# returns, subsequent steps can look them up and touch production code
	# without the "Identifier not found" compile trap.
	registry.given("a clean day-night world wired to LightingManager and FaunaManager",
		func(ctx):
			var tree: SceneTree = ctx.get_tree()
			ctx.assert_not_null(tree, "SceneTree required for day/night full-chain BDD")
			if tree == null:
				return
			# Kick off the "materialise autoloads" yield. The lazy
			# `_ensure_world_ready` call inside every Given/When/Then below
			# finishes context setup once the autoloads are alive.
			return tree.process_frame
	)

	# ---- Given: DayNightCycle state ----
	registry.given("the DayNightCycle phase is {word}", func(ctx, phase_name: String):
		_ensure_world_ready(ctx)
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc == null:
			return
		var phase_int: int = PHASE_FROM_NAME.get(phase_name, 0)
		dnc.current_phase = phase_int
		dnc.is_daytime = phase_int == 0 or phase_int == 3
		# Clear any spy noise left over so only scenario-owned transitions
		# count toward assertions.
		ctx.set_value("phase_changed_log", [] as Array)
	)

	registry.given("the DayNightCycle day count is {int}", func(ctx, day: int):
		_ensure_world_ready(ctx)
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc != null:
			dnc.day_count = day
	)

	# ---- Given: LightingManager state ----
	registry.given(
		"a registered structure light {string} at position {int},{int} radius {int}",
		func(ctx, key: String, px: int, py: int, radius: int):
			_ensure_world_ready(ctx)
			var lm: Node = ctx.get_value("lm", null)
			ctx.assert_not_null(lm, "LightingManager must exist")
			if lm != null:
				lm.register_light(key, Vector2(float(px), float(py)), float(radius))
	)

	registry.given("LightingManager reports no active lights", func(ctx):
		_ensure_world_ready(ctx)
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm != null:
			var lights: Array[Dictionary] = lm.get_active_lights()
			ctx.assert_equal(
				lights.size(), 0,
				"expected 0 active lights at baseline, got %d" % lights.size()
			)
	)

	registry.given("LightingManager reports 1 active lights", func(ctx):
		_ensure_world_ready(ctx)
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm != null:
			var lights: Array[Dictionary] = lm.get_active_lights()
			ctx.assert_equal(
				lights.size(), 1,
				"expected 1 active light at setup, got %d" % lights.size()
			)
	)

	# ---- Given: Player torch / inventory stubs ----
	registry.given("the player is carrying a scanner tool with a LightCap", func(ctx):
		_ensure_world_ready(ctx)
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm == null:
			return
		var tool_id := StringName("TEST_TORCH_001")
		var light := _LightCap.new()
		light.radius = 4.0
		light.color = Color(1.0, 0.7, 0.3)
		var def: _PropDef = _PropDef.new()
		def.id = tool_id
		def.display_name = "Test Torch"
		def.light = light
		ctx.set_value("torch_def", def)
		ctx.set_value("torch_id", tool_id)

		# Inject a stub PropRegistry on LightingManager so the tool id
		# resolves to our test def instead of the real PropRegistry.
		# LightingManager._update_torch_from_player only calls `get_def`.
		var stub_registry := _StubRegistry.new()
		stub_registry.init_with_defs({tool_id: def})
		lm._registry = stub_registry
		var player := _StubPlayer.new()
		player.inventory = _StubInventory.new()
		player.inventory.tools[&"scanner"] = tool_id
		player.current_tile = Vector2i(0, 0)
		ctx.set_value("stub_player", player)
		lm._player_world_pos = Vector2(0.0, 0.0)
	)

	registry.given("the player has no tool equipped in the scanner slot", func(ctx):
		_ensure_world_ready(ctx)
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm == null:
			return
		var stub_registry := _StubRegistry.new()
		stub_registry.init_with_defs({})
		lm._registry = stub_registry
		var player := _StubPlayer.new()
		player.inventory = _StubInventory.new()  # all slots empty
		player.current_tile = Vector2i(0, 0)
		ctx.set_value("stub_player", player)
		lm._player_world_pos = Vector2(0.0, 0.0)
	)

	# ---- Given: FaunaManager wiring ----
	registry.given("a FaunaManager wired to the DayNightCycle", func(ctx):
		_ensure_world_ready(ctx)
		var tree: SceneTree = ctx.get_tree()
		var dnc: Node = ctx.get_value("dnc", null)
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(tree, "SceneTree required")
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if tree == null or dnc == null:
			return
		var fm := _build_fresh_fauna(tree, dnc, lm)
		ctx.set_value("fauna_manager", fm)
		ctx.set_value("despawn_log", [] as Array)
		var despawn_spy := func(id, coords, species):
			var log: Array = ctx.get_value("despawn_log", [])
			log.append({"id": id, "coords": coords, "species": species})
			ctx.set_value("despawn_log", log)
		fm.fauna_despawned.connect(despawn_spy)
		fm.set_meta(_SPY_FAUNA_DESPAWNED, despawn_spy)
	)

	registry.given("the FaunaManager has a seeded fauna entry at {int},{int}",
		func(ctx, fx: int, fy: int):
			var fm: Node = ctx.get_value("fauna_manager", null)
			ctx.assert_not_null(fm, "FaunaManager must exist")
			if fm == null:
				return
			# Seed a minimal fauna dictionary matching the real shape. We
			# bypass the spawnable/dependency-heavy `_spawn_species` flow so
			# the scenario exercises the dawn-despawn code path cleanly.
			fm._fauna.append({
				"id": 42,
				"species_type": StringName("P00108"),
				"coords": Vector2i(fx, fy),
				"hp": 10,
				"move_cooldown": 1.0,
				"cooldown_remaining": 1.0,
				"was_in_light": false,
			})
	)

	registry.given("the FaunaManager is registered to the night signal", func(ctx):
		var fm: Node = ctx.get_value("fauna_manager", null)
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(fm, "FaunaManager must exist")
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if fm == null or dnc == null:
			return
		# The production wiring in FaunaManager._connect_signals already
		# connects _on_night / _on_dawn in _ready(). Verify that contract.
		ctx.assert_true(
			dnc.night.is_connected(fm._on_night),
			"FaunaManager._on_night should be connected to DayNightCycle.night"
		)
		ctx.assert_true(
			dnc.dawn.is_connected(fm._on_dawn),
			"FaunaManager._on_dawn should be connected to DayNightCycle.dawn"
		)
		ctx.set_value("fauna_night_received", false)
	)

	# ---- When: DayNightCycle transitions ----
	registry.when("the DayNightCycle phase advances", func(ctx):
		_ensure_world_ready(ctx)
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc != null:
			dnc._advance_phase()
	)

	registry.when("the DayNightCycle phase is forced to {word}", func(ctx, phase_name: String):
		_ensure_world_ready(ctx)
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc == null:
			return
		var target: int = PHASE_FROM_NAME.get(phase_name, 0)
		dnc.current_phase = target
		dnc.is_daytime = target == 0 or target == 3
	)

	registry.when("the DayNightCycle emits the dawn signal", func(ctx):
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc != null:
			dnc.dawn.emit()
	)

	registry.when("the DayNightCycle emits the night signal", func(ctx):
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc == null:
			return
		# Install a one-shot probe BEFORE emit so we can assert the signal
		# was reachable on the FaunaManager side. emit is synchronous, so
		# when control returns the flag reflects whether the signal fired.
		var fm: Node = ctx.get_value("fauna_manager", null)
		if fm != null:
			var probe := func():
				ctx.set_value("fauna_night_received", true)
			dnc.night.connect(probe, CONNECT_ONE_SHOT)
		dnc.night.emit()
	)

	# ---- When: LightingManager player torch ----
	registry.when("LightingManager updates the player torch from inventory", func(ctx):
		var lm: Node = ctx.get_value("lm", null)
		var player = ctx.get_value("stub_player", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		ctx.assert_not_null(player, "stub player must exist")
		if lm == null or player == null:
			return
		# Drive the same code path `update_player_torch` uses once it has
		# located the player. We skip `_find_player()` because our stub is
		# not in the `player` group.
		lm._update_torch_from_player(player)
	)

	# ---- Then: phase + signals ----
	registry.then("the DayNightCycle current phase is {string}", func(ctx, expected: String):
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc != null:
			var actual: String = PHASE_TO_NAME.get(int(dnc.current_phase), "?")
			ctx.assert_equal(
				actual, expected,
				"expected current phase %s, got %s" % [expected, actual]
			)
	)

	registry.then("the DayNightCycle day count is {int}", func(ctx, expected: int):
		var dnc: Node = ctx.get_value("dnc", null)
		ctx.assert_not_null(dnc, "DayNightCycle must exist")
		if dnc != null:
			ctx.assert_equal(
				dnc.day_count, expected,
				"expected day_count=%d, got %d" % [expected, dnc.day_count]
			)
	)

	registry.then("the phase_changed signal was emitted with new phase {string}",
		func(ctx, expected_phase: String):
			var log: Array = ctx.get_value("phase_changed_log", [])
			ctx.assert_greater(
				log.size(), 0,
				"expected at least one phase_changed emission, got none"
			)
			if log.is_empty():
				return
			var found := false
			for entry in log:
				var new_phase_int: int = int(entry.get("new", -1))
				var new_phase_name: String = PHASE_TO_NAME.get(new_phase_int, "?")
				if new_phase_name == expected_phase:
					found = true
					break
			ctx.assert_true(
				found,
				"expected phase_changed with new=%s in log=%s" % [expected_phase, log]
			)
	)

	# ---- Then: LightingManager ----
	registry.then("LightingManager reports {int} active lights", func(ctx, expected: int):
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm != null:
			var lights: Array[Dictionary] = lm.get_active_lights()
			ctx.assert_equal(
				lights.size(), expected,
				"expected %d active lights, got %d" % [expected, lights.size()]
			)
	)

	registry.then("LightingManager reports no active lights", func(ctx):
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm != null:
			var lights: Array[Dictionary] = lm.get_active_lights()
			ctx.assert_equal(
				lights.size(), 0,
				"expected 0 active lights, got %d" % lights.size()
			)
	)

	registry.then("LightingManager light at index {int} has radius {int}",
		func(ctx, index: int, expected_radius: int):
			var lm: Node = ctx.get_value("lm", null)
			ctx.assert_not_null(lm, "LightingManager must exist")
			if lm == null:
				return
			var lights: Array[Dictionary] = lm.get_active_lights()
			ctx.assert_greater(
				lights.size(), index,
				"expected > %d active lights, got %d" % [index, lights.size()]
			)
			if index < lights.size():
				var actual: float = float(lights[index].get("radius", -1.0))
				ctx.assert_equal(
					actual, float(expected_radius),
					"light[%d] radius mismatch: expected %d, got %.2f"
						% [index, expected_radius, actual]
				)
	)

	registry.then("LightingManager has a player torch light registered", func(ctx):
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm != null:
			ctx.assert_false(
				lm._player_light.is_empty(),
				"expected a player torch light registered, got empty dict"
			)
	)

	registry.then("LightingManager has no player torch light", func(ctx):
		var lm: Node = ctx.get_value("lm", null)
		ctx.assert_not_null(lm, "LightingManager must exist")
		if lm != null:
			ctx.assert_true(
				lm._player_light.is_empty(),
				"expected no player torch light, got %s" % [lm._player_light]
			)
	)

	# ---- Then: FaunaManager ----
	registry.then("the FaunaManager has {int} fauna entries", func(ctx, expected: int):
		var fm: Node = ctx.get_value("fauna_manager", null)
		ctx.assert_not_null(fm, "FaunaManager must exist")
		if fm != null:
			ctx.assert_equal(
				fm._fauna.size(), expected,
				"expected %d fauna entries, got %d" % [expected, fm._fauna.size()]
			)
	)

	registry.then("the fauna_despawned signal was emitted once", func(ctx):
		var log: Array = ctx.get_value("despawn_log", [])
		ctx.assert_equal(
			log.size(), 1,
			"expected exactly one fauna_despawned emission, got %d (log=%s)"
				% [log.size(), log]
		)
	)

	registry.then("the FaunaManager received the night wake-up", func(ctx):
		var received: bool = ctx.get_value("fauna_night_received", false)
		ctx.assert_true(
			received,
			"expected FaunaManager-side night signal path to be reachable"
		)
		var fm: Node = ctx.get_value("fauna_manager", null)
		var dnc: Node = ctx.get_value("dnc", null)
		if fm != null and dnc != null:
			ctx.assert_true(
				dnc.night.is_connected(fm._on_night),
				"FaunaManager._on_night should remain connected after emit"
			)
	)


# --------------------------------------------------------------------------
# Stub helpers
# --------------------------------------------------------------------------


## Minimal PropRegistry shim that LightingManager._update_torch_from_player
## will query for tool -> PropDef lookup. Only `get_def` / `has_def` are
## exercised. Extends Node (could also be RefCounted now that _registry is untyped).
class _StubRegistry extends Node:
	var _defs: Dictionary

	func init_with_defs(defs: Dictionary) -> void:
		_defs = defs

	func get_def(id: StringName):
		return _defs.get(id, null)

	func has_def(id: StringName) -> bool:
		return _defs.has(id)


## Minimal inventory shim that mimics the real `Inventory.get_tool` contract
## without pulling PropRegistry into the test parse graph.
class _StubInventory extends RefCounted:
	var tools: Dictionary = {
		&"axe": &"",
		&"pickaxe": &"",
		&"weapon": &"",
		&"scanner": &"",
	}

	func get_tool(slot: StringName) -> StringName:
		return tools.get(slot, &"")


## Minimal player shim. LightingManager._update_torch_from_player types its
## argument as `Node`, so our stub must extend Node. The real Player is a
## CharacterBody3D — we do not need its physics footprint, only the
## `get_inventory()` + `current_tile` contract.
class _StubPlayer extends Node:
	var inventory: _StubInventory = null
	var current_tile: Vector2i = Vector2i.ZERO

	func get_inventory() -> RefCounted:
		return inventory
