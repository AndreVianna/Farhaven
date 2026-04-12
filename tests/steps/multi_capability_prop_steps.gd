extends RefCounted

## Step definitions for multi_capability_prop.feature.
##
## These scenarios exercise real PropDef instances — either loaded from
## committed .tres fixtures or built programmatically from the real
## capability Resource classes. No shallow mocks: every capability under
## test is the production class defined under scripts/data/capabilities/.
##
## Save/load round-trip uses Godot's ResourceSaver + ResourceLoader on
## `user://` so we don't touch the repo. Each scenario writes to a unique
## temp path and cleans up on completion; a scenario that crashes mid-way
## leaves a stray file in user:// but that's harmless (user:// is ephemeral
## for the CI runner).
##
## Runner quirks (same as narrative_steps.gd):
## 1. BDD runs inside SceneTree._init(); some identifiers (PropRegistry,
##    HexGrid) are unavailable because autoloads resolve lazily. We avoid
##    preloading any script that references them at the function level —
##    that's why we don't touch the Catalog class here. The value the
##    Catalog consumes (PropDef + CatalogableCap.show_as_anomaly) is fully
##    exercised by capability_extension_points_steps.gd via the documented
##    fallback that mirrors Catalog._resolve_display_bucket.
## 2. Common steps in common_steps.gd are reused read-only; no edits.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _PortableCap = preload("res://scripts/data/capabilities/portable_cap.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")
const _ContainerCap = preload("res://scripts/data/capabilities/container_cap.gd")
const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")
const _MovementCap = preload("res://scripts/data/capabilities/movement_cap.gd")
const _CombatCap = preload("res://scripts/data/capabilities/combat_cap.gd")
const _BehaviorCap = preload("res://scripts/data/capabilities/behavior_cap.gd")
const _SpawnableCap = preload("res://scripts/data/capabilities/spawnable_cap.gd")
const _CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")
const _LightCap = preload("res://scripts/data/capabilities/light_cap.gd")


# --------------------------------------------------------------------------
# Builders — programmatic PropDef assembly
# --------------------------------------------------------------------------


## Builds a fresh PropDef with the requested subset of capabilities. Each
## capability is instantiated from its real class so scenarios test the
## production composition contract, not a simulacrum.
static func _build_prop_def(prop_id: StringName, cap_names: Array) -> Resource:
	var def: Resource = _PropDef.new()
	def.id = prop_id
	def.display_name = String(prop_id)
	for cap_name in cap_names:
		var cap: StringName = StringName(String(cap_name).strip_edges())
		match cap:
			&"portable": def.portable = _PortableCap.new()
			&"placeable": def.placeable = _PlaceableCap.new()
			&"container": def.container = _ContainerCap.new()
			&"light": def.light = _LightCap.new()
			&"endurance": def.endurance = _EnduranceCap.new()
			&"movement": def.movement = _MovementCap.new()
			&"combat": def.combat = _CombatCap.new()
			&"behavior": def.behavior = _BehaviorCap.new()
			&"spawnable": def.spawnable = _SpawnableCap.new()
			&"catalogable": def.catalogable = _CatalogableCap.new()
			_: push_warning("multi_capability_prop_steps: unknown cap name '%s'" % cap_name)
	return def


## Writes the given PropDef to a user:// temp file, loads it back, and
## returns the freshly-loaded Resource. Proves that ResourceSaver and
## ResourceLoader preserve every nested capability sub-resource. The temp
## file is cleaned up inside this helper to keep user:// tidy.
static func _save_and_reload(def: Resource) -> Resource:
	var temp_path: String = "user://test_propdef_%d.tres" % Time.get_ticks_usec()
	var save_err: int = ResourceSaver.save(def, temp_path)
	if save_err != OK:
		push_error("ResourceSaver.save failed with code %d at %s" % [save_err, temp_path])
		return null
	# CACHE_MODE_IGNORE forces a fresh parse — otherwise Godot would hand
	# back the in-memory instance we just saved, defeating the round-trip.
	var reloaded: Resource = ResourceLoader.load(
		temp_path, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	# Clean up eagerly. If the Resource kept a reference to the file it'd
	# already be loaded into memory, so removing the temp is safe.
	var da: DirAccess = DirAccess.open("user://")
	if da != null:
		da.remove(temp_path.trim_prefix("user://"))
	return reloaded


# --------------------------------------------------------------------------
# Step registration
# --------------------------------------------------------------------------


func register_steps(registry) -> void:
	# ---- Load a PropDef from disk fixture ----
	registry.given("a PropDef loaded from {string}", func(ctx, tres_path: String):
		var def: Resource = load(tres_path)
		ctx.assert_not_null(def, "PropDef must load from %s" % tres_path)
		ctx.set_value("prop_def", def)
	)

	# ---- Build a fresh PropDef programmatically ----
	registry.given(
		"a new PropDef {string} is built with capabilities {string}",
		func(ctx, prop_id: String, cap_csv: String):
			var cap_names: Array = []
			for token in cap_csv.split(","):
				cap_names.append(StringName(token.strip_edges()))
			var def: Resource = _build_prop_def(StringName(prop_id), cap_names)
			ctx.assert_not_null(def, "programmatic PropDef must not be null")
			ctx.set_value("prop_def", def)
	)

	# ---- Configure nested capability fields ----
	registry.given("the PropDef container has capacity_size {float}", func(ctx, cap_size: float):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		ctx.assert_not_null(def.container, "container cap must be present")
		if def != null and def.container != null:
			def.container.capacity_size = cap_size
	)

	registry.given("the PropDef portable has size {float}", func(ctx, size: float):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		ctx.assert_not_null(def.portable, "portable cap must be present")
		if def != null and def.portable != null:
			def.portable.size = size
	)

	# ---- Save / reload round-trip ----
	registry.when("the PropDef is saved to disk and loaded back", func(ctx):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist before save/load")
		if def == null:
			return
		var reloaded: Resource = _save_and_reload(def)
		ctx.assert_not_null(reloaded, "PropDef must round-trip through ResourceSaver/Loader")
		ctx.set_value("reloaded_prop_def", reloaded)
	)

	# ---- Runtime cap mutation ----
	registry.when(
		"an EnduranceCap with hp {int} is assigned to the PropDef at runtime",
		func(ctx, hp: int):
			var def: Resource = ctx.get_value("prop_def", null)
			ctx.assert_not_null(def, "prop_def must exist")
			if def == null:
				return
			var cap: Resource = _EnduranceCap.new()
			cap.hp = hp
			def.endurance = cap
	)

	# ---- Capability presence / absence (works against the "current" def) ----
	registry.then("the PropDef has capability {string}", func(ctx, cap_name: String):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null:
			ctx.assert_true(
				def.has_capability(StringName(cap_name)),
				"PropDef %s should have capability %s" % [def.id, cap_name]
			)
	)

	registry.then("the PropDef does not have capability {string}", func(ctx, cap_name: String):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null:
			ctx.assert_false(
				def.has_capability(StringName(cap_name)),
				"PropDef %s should NOT have capability %s" % [def.id, cap_name]
			)
	)

	registry.then("the reloaded PropDef has capability {string}", func(ctx, cap_name: String):
		var def: Resource = ctx.get_value("reloaded_prop_def", null)
		ctx.assert_not_null(def, "reloaded_prop_def must exist")
		if def != null:
			ctx.assert_true(
				def.has_capability(StringName(cap_name)),
				"Reloaded PropDef %s should have capability %s" % [def.id, cap_name]
			)
	)

	registry.then(
		"the reloaded PropDef does not have capability {string}",
		func(ctx, cap_name: String):
			var def: Resource = ctx.get_value("reloaded_prop_def", null)
			ctx.assert_not_null(def, "reloaded_prop_def must exist")
			if def != null:
				ctx.assert_false(
					def.has_capability(StringName(cap_name)),
					"Reloaded PropDef %s should NOT have capability %s" % [def.id, cap_name]
				)
	)

	# ---- Capability field assertions: current def ----
	registry.then("the PropDef endurance hp is {int}", func(ctx, hp: int):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null and def.endurance != null:
			ctx.assert_equal(
				def.endurance.hp, hp, "endurance.hp mismatch on %s" % def.id
			)
		else:
			ctx.fail("endurance cap missing on %s" % (def.id if def != null else "<null>"))
	)

	registry.then("the PropDef endurance is null", func(ctx):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null:
			ctx.assert_null(def.endurance, "endurance should be null on %s" % def.id)
	)

	registry.then("the PropDef movement is null", func(ctx):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null:
			ctx.assert_null(def.movement, "movement should be null on %s" % def.id)
	)

	registry.then("the PropDef combat is null", func(ctx):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null:
			ctx.assert_null(def.combat, "combat should be null on %s" % def.id)
	)

	registry.then("the PropDef behavior is null", func(ctx):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def != null:
			ctx.assert_null(def.behavior, "behavior should be null on %s" % def.id)
	)

	registry.then(
		"the PropDef movement mode {int} has normal speed {float}",
		func(ctx, mode: int, expected: float):
			var def: Resource = ctx.get_value("prop_def", null)
			ctx.assert_not_null(def, "prop_def must exist")
			if def == null or def.movement == null:
				ctx.fail("movement cap missing on %s" % (def.id if def != null else "<null>"))
				return
			var pair = def.movement.modes.get(mode, null)
			ctx.assert_not_null(pair, "movement.modes[%d] missing" % mode)
			if pair != null:
				ctx.assert_equal(float(pair[0]), expected,
					"movement.modes[%d] normal speed mismatch" % mode)
	)

	registry.then("the PropDef behavior diet contains {string}", func(ctx, tag: String):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def == null or def.behavior == null:
			ctx.fail("behavior cap missing on %s" % (def.id if def != null else "<null>"))
			return
		ctx.assert_true(
			def.behavior.diet.has(StringName(tag)),
			"behavior.diet should contain %s (got %s)" % [tag, def.behavior.diet]
		)
	)

	registry.then("the PropDef spawnable first_spawn_day is {int}", func(ctx, day: int):
		var def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(def, "prop_def must exist")
		if def == null or def.spawnable == null:
			ctx.fail("spawnable cap missing on %s" % (def.id if def != null else "<null>"))
			return
		ctx.assert_equal(def.spawnable.first_spawn_day, day,
			"spawnable.first_spawn_day mismatch")
	)

	# ---- Capability field assertions: reloaded def ----
	registry.then(
		"the reloaded PropDef container capacity_size is {float}",
		func(ctx, cap_size: float):
			var def: Resource = ctx.get_value("reloaded_prop_def", null)
			ctx.assert_not_null(def, "reloaded_prop_def must exist")
			if def == null or def.container == null:
				ctx.fail("reloaded container cap missing")
				return
			ctx.assert_equal(def.container.capacity_size, cap_size,
				"reloaded container.capacity_size mismatch")
	)

	registry.then(
		"the reloaded PropDef portable size is {float}",
		func(ctx, size: float):
			var def: Resource = ctx.get_value("reloaded_prop_def", null)
			ctx.assert_not_null(def, "reloaded_prop_def must exist")
			if def == null or def.portable == null:
				ctx.fail("reloaded portable cap missing")
				return
			ctx.assert_equal(def.portable.size, size,
				"reloaded portable.size mismatch")
	)
