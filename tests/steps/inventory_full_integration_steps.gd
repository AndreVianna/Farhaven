extends RefCounted

## Step definitions for the inventory_full_integration BDD feature.
##
## Exercises the REAL Inventory class (scripts/inventory/inventory.gd)
## against the REAL PropRegistry autoload so PortableCap sizes and
## tool_slot constraints are honoured. No shallow mocks:
## - `Inventory` is a pure RefCounted we `new()` directly — no node.
## - PropRegistry is the autoload bootstrapped by the engine (see
##   scanner_integration_steps.gd for an explanation of the frame-advance
##   trick needed to force autoload bootstrap under `--script` mode).
## - Real PropDefs are fetched by id from PropRegistry — `P00010` for
##   size-1 wood with max_stack=99, `P00204` for the survival knife with
##   tool_slot=&"weapon" and max_stack=1.
##
## Signal capture is synchronous — we connect spy Callables to
## `inventory_full` and `tool_changed` and write observations into the
## TestContext's key-value store. Because we create a fresh Inventory for
## every scenario (via the Background step), there is no cross-scenario
## state leakage and no need for the set_meta trick used elsewhere.

## We lazy-load Inventory for the same reason scanner_integration_steps
## avoids preloading scanner_system.gd — `inventory.gd` references the
## bare `PropRegistry` autoload identifier, and that identifier is not
## registered at step-file-load time. Loading it at runtime inside the
## Background step (after the frame-advance step has yielded) lets the
## parser see the autoload and compile cleanly.
static var _Inventory = null


static func _lazy_load() -> void:
	if _Inventory != null:
		return
	_Inventory = load("res://scripts/inventory/inventory.gd")


# --------------------------------------------------------------------------
# World setup
# --------------------------------------------------------------------------


## Build (or rebuild) a fresh real Inventory and wire signal spies.
## Called from the Background step AFTER the one-frame advance so autoloads
## (in particular PropRegistry) are up and `inventory.gd` compiles cleanly.
static func build_world(ctx) -> void:
	_lazy_load()

	var tree: SceneTree = ctx.get_tree()
	if tree == null:
		ctx.fail("SceneTree must be available")
		return

	var prop_registry: Node = tree.root.get_node_or_null(NodePath("PropRegistry"))
	if prop_registry == null:
		ctx.fail("PropRegistry autoload must be present on tree.root — " +
			"make sure the Background step 'advanced one engine frame' ran first")
		return

	var inv = _Inventory.new()

	# Signal spies — write observations into ctx so Then steps can read.
	var full_log: Array = []
	var tool_log: Array = []
	var added_log: Array = []
	inv.inventory_full.connect(func(type: StringName, rejected: int):
		full_log.append({"type": type, "rejected": rejected})
	)
	inv.tool_changed.connect(func(slot: StringName, new_tool: StringName, old_tool: StringName):
		tool_log.append({"slot": slot, "new_tool": new_tool, "old_tool": old_tool})
	)
	inv.item_added.connect(func(type: StringName, amount: int):
		added_log.append({"type": type, "amount": amount})
	)

	ctx.set_value("real_inventory", inv)
	ctx.set_value("inventory_full_log", full_log)
	ctx.set_value("inventory_tool_log", tool_log)
	ctx.set_value("inventory_added_log", added_log)
	ctx.set_value("last_add_return", -1)
	ctx.set_value("prop_registry", prop_registry)


# --------------------------------------------------------------------------
# Step registration
# --------------------------------------------------------------------------


func register_steps(registry) -> void:
	# ---- Background: frame-advance helper (same pattern as scanner) ----
	# See scanner_integration_steps.gd for the full rationale. In short:
	# returning `tree.process_frame` from the step callback makes the
	# scenario executor await a Signal, which yields control to the engine
	# and lets autoloads (PropRegistry in particular) bootstrap before any
	# step loads scripts that reference their bare identifiers.
	registry.given("the test runner has advanced one engine frame for inventory",
		func(ctx):
			var tree: SceneTree = ctx.get_tree()
			if tree == null:
				ctx.fail("SceneTree must be available to advance a frame")
				return null
			return tree.process_frame
	)

	# ---- Background: real Inventory build ----
	registry.given("a clean inventory world with a real Inventory backed by PropRegistry",
		func(ctx):
			build_world(ctx)
	)

	# ---- Inventory capacity tweaks ----
	registry.given("the real inventory is a {int}x{int} grid",
		func(ctx, w: int, h: int):
			# Replace the default 30x40 inventory with a tight grid so small
			# capacities (like 3 cells) can be exercised. Grid-model capacity
			# cannot shrink via the capacity_size setter, so we rebuild.
			var fresh = _Inventory.new(w, h)
			# Re-wire signal spies on the fresh inventory so Then steps see events.
			var full_log: Array = ctx.get_value("inventory_full_log", [] as Array)
			var tool_log: Array = ctx.get_value("inventory_tool_log", [] as Array)
			var added_log: Array = ctx.get_value("inventory_added_log", [] as Array)
			fresh.inventory_full.connect(func(type: StringName, rejected: int):
				full_log.append({"type": type, "rejected": rejected})
			)
			fresh.tool_changed.connect(func(slot: StringName, new_tool: StringName, old_tool: StringName):
				tool_log.append({"slot": slot, "new_tool": new_tool, "old_tool": old_tool})
			)
			fresh.item_added.connect(func(type: StringName, amount: int):
				added_log.append({"type": type, "amount": amount})
			)
			ctx.set_value("real_inventory", fresh)
	)

	registry.given("the real inventory has {int} {string} in regular slots",
		func(ctx, count: int, prop_id: String):
			var inv = ctx.get_value("real_inventory", null)
			if inv == null:
				return
			var added: int = inv.add_item(StringName(prop_id), count)
			ctx.assert_equal(added, count,
				"seed add_item should succeed — got %d, expected %d" % [added, count])
			# Clear signal logs so the scenario's actual action does not
			# race the seed. Preserve the added log for non-signal steps
			# that might still want to inspect it.
			# Clear IN PLACE so the signal spy lambdas (which captured the
			# array by reference at connect time) keep writing into the same
			# array the Then steps read. Replacing ctx values with new empty
			# arrays would orphan the spy closures.
			var full_log: Array = ctx.get_value("inventory_full_log", [] as Array)
			full_log.clear()
	)

	registry.given("the real inventory has tool {string} set to {string}",
		func(ctx, slot: String, tool_id: String):
			var inv = ctx.get_value("real_inventory", null)
			if inv != null:
				inv.set_tool(StringName(slot), StringName(tool_id))
			# Clear in place (see note above for inventory_full_log).
			var tool_log: Array = ctx.get_value("inventory_tool_log", [] as Array)
			tool_log.clear()
	)

	registry.given("the real inventory has {int} base slots",
		func(ctx, count: int):
			# Informational — historical 12-slot invariant. Grid model default
			# is grid_width * grid_height cells instead (1200 for 30x40). The
			# assertion now uses the actual grid size.
			var inv = ctx.get_value("real_inventory", null)
			ctx.assert_equal(inv.get_max_slots(), count,
				"expected %d base slots, got %d" % [count, inv.get_max_slots()])
	)

	# ---- When: inventory mutation ----
	registry.when("the player attempts to add {int} {string} to the real inventory",
		func(ctx, count: int, prop_id: String):
			var inv = ctx.get_value("real_inventory", null)
			if inv == null:
				return
			var added: int = inv.add_item(StringName(prop_id), count)
			ctx.set_value("last_add_return", added)
	)

	registry.when("the player sets tool slot {string} to {string} on the real inventory",
		func(ctx, slot: String, tool_id: String):
			var inv = ctx.get_value("real_inventory", null)
			if inv != null:
				inv.set_tool(StringName(slot), StringName(tool_id))
	)

	registry.when("the real inventory is saved, cleared, and loaded back",
		func(ctx):
			var inv = ctx.get_value("real_inventory", null)
			if inv == null:
				return
			var snapshot: Dictionary = inv.get_save_data()
			# Replace with a fresh instance to prove round-trip is honest —
			# clearing in-place would leave stale cached fields.
			var fresh = _Inventory.new()
			fresh.load_save_data(snapshot)
			ctx.set_value("real_inventory", fresh)
	)

	registry.when("the real inventory is expanded by {int} slots",
		func(ctx, count: int):
			var inv = ctx.get_value("real_inventory", null)
			if inv != null:
				# Remember the pre-expansion size for the "has N more total
				# slots" assertion.
				ctx.set_value("pre_expand_slots", inv.get_max_slots())
				# expand(n) adds n rows of grid_width cells.
				inv.expand(count)
	)

	# ---- Then: inventory state ----
	registry.then("the real inventory has {int} {string}",
		func(ctx, count: int, prop_id: String):
			var inv = ctx.get_value("real_inventory", null)
			ctx.assert_not_null(inv, "real inventory must exist")
			if inv == null:
				return
			ctx.assert_equal(inv.get_count(StringName(prop_id)), count,
				"expected %d of %s, got %d" %
				[count, prop_id, inv.get_count(StringName(prop_id))])
	)

	registry.then("the last add returned {int}", func(ctx, expected: int):
		var actual: int = ctx.get_value("last_add_return", -999)
		ctx.assert_equal(actual, expected,
			"expected last add to return %d, got %d" % [expected, actual])
	)

	registry.then("the inventory_full signal fired for {string} with rejected count {int}",
		func(ctx, prop_id: String, rejected: int):
			var log: Array = ctx.get_value("inventory_full_log", [])
			var found := false
			for e in log:
				if String(e.get("type", &"")) == prop_id and int(e.get("rejected", 0)) == rejected:
					found = true
					break
			ctx.assert_true(found,
				"expected inventory_full(%s, %d), got log=%s" %
				[prop_id, rejected, log])
	)

	registry.then("the tool slot {string} is empty", func(ctx, slot: String):
		var inv = ctx.get_value("real_inventory", null)
		ctx.assert_not_null(inv)
		if inv == null:
			return
		ctx.assert_equal(String(inv.get_tool(StringName(slot))), "",
			"expected tool slot %s empty, got %s" %
			[slot, inv.get_tool(StringName(slot))])
	)

	registry.then("the tool slot {string} holds {string}",
		func(ctx, slot: String, tool_id: String):
			var inv = ctx.get_value("real_inventory", null)
			ctx.assert_not_null(inv)
			if inv == null:
				return
			ctx.assert_equal(String(inv.get_tool(StringName(slot))), tool_id,
				"expected tool slot %s to hold %s, got %s" %
				[slot, tool_id, inv.get_tool(StringName(slot))])
	)

	registry.then("the tool_changed signal fired for slot {string} with new {string}",
		func(ctx, slot: String, tool_id: String):
			var log: Array = ctx.get_value("inventory_tool_log", [])
			var found := false
			for e in log:
				if String(e.get("slot", &"")) == slot and String(e.get("new_tool", &"")) == tool_id:
					found = true
					break
			ctx.assert_true(found,
				"expected tool_changed(%s -> %s), got log=%s" %
				[slot, tool_id, log])
	)

	registry.then("the real inventory has {int} total slots", func(ctx, count: int):
		var inv = ctx.get_value("real_inventory", null)
		ctx.assert_not_null(inv)
		if inv == null:
			return
		ctx.assert_equal(inv.get_max_slots(), count,
			"expected %d total slots, got %d" % [count, inv.get_max_slots()])
	)

	registry.then("the real inventory has {int} more total slots", func(ctx, delta: int):
		var inv = ctx.get_value("real_inventory", null)
		ctx.assert_not_null(inv)
		if inv == null:
			return
		var pre: int = ctx.get_value("pre_expand_slots", 0)
		var diff: int = inv.get_max_slots() - pre
		ctx.assert_equal(diff, delta,
			"expected %d more total slots, got %d (pre=%d now=%d)" %
			[delta, diff, pre, inv.get_max_slots()])
	)

	registry.then("the real inventory used slot count is {int}", func(ctx, count: int):
		var inv = ctx.get_value("real_inventory", null)
		ctx.assert_not_null(inv)
		if inv == null:
			return
		ctx.assert_equal(inv.get_used_slot_count(), count,
			"expected %d used slots, got %d" % [count, inv.get_used_slot_count()])
	)
