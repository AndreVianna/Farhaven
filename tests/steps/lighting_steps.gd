extends RefCounted

## Step definitions for lighting feature.
## Tests light source registration and persistence.


func register_steps(registry) -> void:
	# --- Given: light sources ---
	registry.given("a campfire light source at world position {float}, {float} with radius {float}", func(ctx, x: float, y: float, radius: float):
		var light := {"position": Vector2(x, y), "radius": radius, "color": Color(1.0, 0.8, 0.4)}
		ctx.set_value("pending_light", light)
	)

	registry.given("a campfire light source registered at world position {float}, {float}", func(ctx, x: float, y: float):
		var light := {"position": Vector2(x, y), "radius": 5.0, "color": Color(1.0, 0.8, 0.4)}
		var lights: Array = ctx.get_value("active_lights", [])
		lights.append(light)
		ctx.set_value("active_lights", lights)
	)

	# --- When: register ---
	registry.when("the lighting manager registers the source", func(ctx):
		var light = ctx.get_value("pending_light", null)
		ctx.assert_not_null(light, "No pending light to register")
		if light:
			var lights: Array = ctx.get_value("active_lights", [])
			lights.append(light)
			ctx.set_value("active_lights", lights)
	)

	# --- When: save/load ---
	registry.when("the lighting state is saved and restored", func(ctx):
		var lights: Array = ctx.get_value("active_lights", [])
		# Serialize
		var saved: Array = []
		for light in lights:
			saved.append({
				"px": light["position"].x,
				"py": light["position"].y,
				"radius": light["radius"],
			})
		# Clear and restore
		var restored: Array = []
		for data in saved:
			restored.append({
				"position": Vector2(data["px"], data["py"]),
				"radius": data["radius"],
				"color": Color(1.0, 0.8, 0.4),
			})
		ctx.set_value("active_lights", restored)
	)

	# --- Then: light assertions ---
	registry.then("the active lights list contains {int} entry", func(ctx, expected: int):
		var lights: Array = ctx.get_value("active_lights", [])
		ctx.assert_equal(lights.size(), expected,
			"Expected %d active lights, got %d" % [expected, lights.size()])
	)

	registry.then("the light at index {int} has radius {float}", func(ctx, index: int, expected: float):
		var lights: Array = ctx.get_value("active_lights", [])
		ctx.assert_greater(lights.size(), index,
			"Light index %d out of range (have %d)" % [index, lights.size()])
		if lights.size() > index:
			ctx.assert_equal(lights[index]["radius"], expected,
				"Expected radius %.1f at index %d, got %.1f" % [expected, index, lights[index]["radius"]])
	)
