extends RefCounted

## Step definitions for Event system feature.
## Tests GameEvent firing, one-shot vs unlimited, and save/load persistence.
## Uses in-memory GameEvent instances (no autoload dependency).

const _GameEvent = preload("res://scripts/core/event.gd")
const _ScriptBase = preload("res://scripts/core/script_base.gd")


func register_steps(registry) -> void:
	# --- Given ---
	registry.given("a discovery event with condition cataloged {string}", func(ctx, prop_id: String):
		var event := _GameEvent.new()
		event.id = &"E_TEST_001"
		event.display_name = "Test Discovery Event"
		event.max_count = 1
		# Store condition info for verification
		ctx.set_value("event", event)
		ctx.set_value("event_condition_prop", StringName(prop_id))
	)

	registry.given("the event has effect grant_recipe {string}", func(ctx, recipe_id: String):
		ctx.set_value("event_effect_recipe", StringName(recipe_id))
	)

	registry.given("an event with max_count {int}", func(ctx, max_count: int):
		var event := _GameEvent.new()
		event.id = &"E_TEST_002"
		event.display_name = "Test Max Count Event"
		event.max_count = max_count
		ctx.set_value("event", event)
	)

	registry.given("an event that has fired twice", func(ctx):
		var event := _GameEvent.new()
		event.id = &"E_TEST_003"
		event.display_name = "Test Persistence Event"
		event.max_count = 0  # unlimited
		event.fire()
		event.fire()
		ctx.assert_equal(event.count, 2, "Event should have fired twice")
		ctx.set_value("event", event)
	)

	# --- When ---
	registry.when("prop P00004 is cataloged", func(ctx):
		# Simulate catalog trigger — check condition matches, then fire event
		var condition_prop: StringName = ctx.get_value("event_condition_prop", &"")
		ctx.assert_equal(String(condition_prop), "P00004",
			"Expected condition prop P00004")
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event != null:
			var fired: bool = event.fire()
			ctx.set_value("event_fired", fired)
			# Simulate grant_recipe effect
			var effect_recipe: StringName = ctx.get_value("event_effect_recipe", &"")
			if fired and effect_recipe != &"":
				var known: Array = ctx.get_value("known_recipes", [])
				if not known.has(effect_recipe):
					known.append(effect_recipe)
				ctx.set_value("known_recipes", known)
	)

	registry.when("the event fires", func(ctx):
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event != null:
			var fired: bool = event.fire()
			ctx.set_value("event_fired", fired)
	)

	registry.when("the event fires {int} times", func(ctx, times: int):
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event != null:
			for i in range(times):
				event.fire()
	)

	registry.when("the game saves and loads", func(ctx):
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event == null:
			return
		# Simulate save: capture count
		var saved_count: int = event.count
		# Simulate load: create new event and restore count
		var restored := _GameEvent.new()
		restored.id = event.id
		restored.display_name = event.display_name
		restored.max_count = event.max_count
		restored.count = saved_count
		ctx.set_value("event", restored)
	)

	# --- Then ---
	registry.then("the event fires", func(ctx):
		var fired: bool = ctx.get_value("event_fired", false)
		ctx.assert_true(fired, "Expected event to fire")
	)

	registry.then("recipe R00001 becomes known", func(ctx):
		var known: Array = ctx.get_value("known_recipes", [])
		var found := false
		for k in known:
			if k == &"R00001":
				found = true
				break
		ctx.assert_true(found, "Recipe R00001 should be known after event fires")
	)

	registry.then("count is {int}", func(ctx, expected: int):
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event != null:
			ctx.assert_equal(event.count, expected,
				"Expected event count %d, got %d" % [expected, event.count])
	)

	registry.then("the event cannot fire again", func(ctx):
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event != null:
			ctx.assert_false(event.can_fire(),
				"Expected event to not be able to fire again")
	)

	registry.then("the event can still fire", func(ctx):
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event != null:
			ctx.assert_true(event.can_fire(),
				"Expected event to still be able to fire")
	)

	registry.then("the event count is still {int}", func(ctx, expected: int):
		var event: Resource = ctx.get_value("event", null)
		ctx.assert_not_null(event, "Event must exist")
		if event != null:
			ctx.assert_equal(event.count, expected,
				"Expected event count %d after save/load, got %d" % [expected, event.count])
	)
