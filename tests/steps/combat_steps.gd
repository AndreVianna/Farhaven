extends RefCounted

## Step definitions for the combat BDD feature.
##
## Task-115: BDD scenarios for the combat runtime introduced in
## delivery-006e (tasks 102-116). These scenarios drive the damage
## pipeline directly:
##   DamageEvent -> DamageResolver.resolve(event, endurance) -> int
## ...so they run with no scene tree, no physics, no autoloads. The
## auto-defend gating scenarios simulate the ENCOUNTERED/UNKNOWN gate
## at the dictionary level rather than spinning up AutoInteractionSystem,
## FaunaManager, and Catalog — the real gate logic is covered in the
## unit tests; the BDD layer asserts the policy.

const _DamageResolver = preload("res://scripts/combat/damage_resolver.gd")
const _DamageEvent = preload("res://scripts/combat/damage_event.gd")
const _DamageType = preload("res://scripts/combat/damage_type.gd")
const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")


## Map a damage-type name string to the DamageType.Type enum. Mirrors
## CombatRuntime._name_to_type so the BDD step accepts the same vocab
## the production system accepts.
static func _name_to_type(name: String) -> _DamageType.Type:
	match name.to_upper():
		"PHYSICAL": return _DamageType.Type.PHYSICAL
		"FIRE":     return _DamageType.Type.FIRE
		"COLD":     return _DamageType.Type.COLD
		"POISON":   return _DamageType.Type.POISON
		"ELECTRIC": return _DamageType.Type.ELECTRIC
		"MAGIC":    return _DamageType.Type.MAGIC
	return _DamageType.Type.PHYSICAL


static func _get_target(ctx) -> _EnduranceCap:
	return ctx.get_value("combat_target", null) as _EnduranceCap


func register_steps(registry) -> void:
	# ------------------------------------------------------------------
	# Given: target setup
	# ------------------------------------------------------------------
	registry.given("a target with hp {int} and no multipliers", func(ctx, hp: int):
		var endurance := _EnduranceCap.new()
		endurance.hp = hp
		ctx.set_value("combat_target", endurance)
	)

	registry.given("a target with hp {int} and vulnerability to {string}",
		func(ctx, hp: int, dmg_type: String):
			var endurance := _EnduranceCap.new()
			endurance.hp = hp
			var vulns: Array[StringName] = [StringName(dmg_type.to_upper())]
			endurance.vulnerabilities = vulns
			ctx.set_value("combat_target", endurance)
	)

	registry.given("a target with hp {int} and resistance to {string}",
		func(ctx, hp: int, dmg_type: String):
			var endurance := _EnduranceCap.new()
			endurance.hp = hp
			var res: Array[StringName] = [StringName(dmg_type.to_upper())]
			endurance.resistances = res
			ctx.set_value("combat_target", endurance)
	)

	registry.given("a target with hp {int} and immunity to {string}",
		func(ctx, hp: int, dmg_type: String):
			var endurance := _EnduranceCap.new()
			endurance.hp = hp
			var imm: Array[StringName] = [StringName(dmg_type.to_upper())]
			endurance.immunities = imm
			ctx.set_value("combat_target", endurance)
	)

	registry.given("the target is also immune to {string}", func(ctx, dmg_type: String):
		var endurance := _get_target(ctx)
		if endurance == null:
			ctx.fail("combat_target must be set by an earlier Given step")
			return
		var imm: Array[StringName] = endurance.immunities.duplicate()
		imm.append(StringName(dmg_type.to_upper()))
		endurance.immunities = imm
	)

	# --- Auto-defend gating: knowledge state simulation ---
	registry.given("a fauna with knowledge state {string}", func(ctx, state: String):
		# UNKNOWN (0), ENCOUNTERED (1), CATALOGED (2) — mirrors Catalog.
		# Auto-defend requires state >= ENCOUNTERED.
		var upper := state.to_upper()
		var state_value: int = 0
		match upper:
			"UNKNOWN":     state_value = 0
			"ENCOUNTERED": state_value = 1
			"CATALOGED":   state_value = 2
			_:             state_value = 0
		ctx.set_value("knowledge_state", state_value)
		ctx.set_value("auto_defend_fired", false)
	)

	# ------------------------------------------------------------------
	# When: damage resolution
	# ------------------------------------------------------------------
	registry.when("a {string} damage event of {int} is resolved",
		func(ctx, dmg_type: String, amount: int):
			var endurance := _get_target(ctx)
			if endurance == null:
				ctx.fail("combat_target must exist before resolving damage")
				return
			var event := _DamageEvent.create(_name_to_type(dmg_type), amount)
			var dealt: int = _DamageResolver.resolve(event, endurance)
			ctx.set_value("last_damage_dealt", dealt)
	)

	registry.when("the auto-defend check runs", func(ctx):
		# Replicates the AutoInteractionSystem gate: fire only when the
		# target is at least ENCOUNTERED (state >= 1). The full method
		# also enforces cooldown, hostility, range, and weapon lookup —
		# those are covered by the unit tests; here we pin the policy
		# for the knowledge gate specifically.
		var state: int = ctx.get_value("knowledge_state", 0)
		var ENCOUNTERED := 1
		ctx.set_value("auto_defend_fired", state >= ENCOUNTERED)
	)

	# ------------------------------------------------------------------
	# Then: assertions
	# ------------------------------------------------------------------
	registry.then("the damage dealt was {int}", func(ctx, expected: int):
		var actual: int = ctx.get_value("last_damage_dealt", -999)
		ctx.assert_equal(actual, expected,
			"expected %d damage dealt, got %d" % [expected, actual])
	)

	registry.then("the target hp is {int}", func(ctx, expected: int):
		var endurance := _get_target(ctx)
		ctx.assert_not_null(endurance, "combat_target must exist")
		if endurance == null:
			return
		ctx.assert_equal(endurance.hp, expected,
			"expected hp=%d, got hp=%d" % [expected, endurance.hp])
	)

	registry.then("the target is dead", func(ctx):
		var endurance := _get_target(ctx)
		ctx.assert_not_null(endurance, "combat_target must exist")
		if endurance == null:
			return
		ctx.assert_less_or_equal(endurance.hp, 0,
			"expected hp<=0 for a dead target, got %d" % endurance.hp)
	)

	registry.then("the target is alive", func(ctx):
		var endurance := _get_target(ctx)
		ctx.assert_not_null(endurance, "combat_target must exist")
		if endurance == null:
			return
		ctx.assert_greater(endurance.hp, 0,
			"expected hp>0 for a live target, got %d" % endurance.hp)
	)

	registry.then("the auto-defend fired", func(ctx):
		var fired: bool = ctx.get_value("auto_defend_fired", false)
		ctx.assert_true(fired, "expected auto-defend to fire")
	)

	registry.then("the auto-defend did not fire", func(ctx):
		var fired: bool = ctx.get_value("auto_defend_fired", true)
		ctx.assert_false(fired, "expected auto-defend to be skipped")
	)
