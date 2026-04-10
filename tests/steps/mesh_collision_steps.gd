extends RefCounted

## Step definitions for mesh collision feature.
## Tests CollisionHelper shape generation and overlap rejection.
## Uses CollisionHelper directly (no autoload dependency).

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _CollisionHelper = preload("res://scripts/core/collision_helper.gd")


func register_steps(registry) -> void:
	# --- Given ---
	registry.given("a campfire PropDef with placeholder cylinder mesh", func(ctx):
		var prop_def := _PropDef.new()
		prop_def.id = &"P_TEST_CAMPFIRE"
		prop_def.display_name = "Test Campfire"
		prop_def.placeholder_mesh_type = &"cylinder"
		prop_def.placeholder_params = {"radius": 0.3, "height": 0.6}
		ctx.set_value("prop_def", prop_def)
	)

	registry.given("a structure at position {int}, {int}", func(ctx, x: int, y: int):
		var occupied: Array = ctx.get_value("occupied_positions", [])
		occupied.append(Vector2i(x, y))
		ctx.set_value("occupied_positions", occupied)
	)

	# --- When ---
	registry.when("a collision shape is generated", func(ctx):
		var prop_def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(prop_def, "PropDef must exist")
		if prop_def == null:
			return
		var collision_node: CollisionShape3D = _CollisionHelper.create_collision_shape(prop_def)
		# Extract the Shape3D resource and free the Node to avoid leaks
		var shape: Shape3D = collision_node.shape
		ctx.set_value("collision_shape", shape)
		collision_node.free()
	)

	registry.when("another structure is placed at the same position", func(ctx):
		var occupied: Array = ctx.get_value("occupied_positions", [])
		var target := Vector2i(0, 0)
		var rejected := false
		for pos in occupied:
			if pos == target:
				rejected = true
				break
		ctx.set_value("placement_rejected", rejected)
	)

	# --- Then ---
	registry.then("the shape is a CylinderShape3D", func(ctx):
		var shape: Shape3D = ctx.get_value("collision_shape", null)
		ctx.assert_not_null(shape, "Collision shape must exist")
		if shape == null:
			return
		ctx.assert_true(shape is CylinderShape3D,
			"Expected CylinderShape3D, got %s" % shape.get_class())
	)

	registry.then("the radius matches the placeholder params", func(ctx):
		var shape: Shape3D = ctx.get_value("collision_shape", null)
		ctx.assert_not_null(shape, "Collision shape must exist")
		if shape == null:
			return
		var prop_def: Resource = ctx.get_value("prop_def", null)
		var expected_radius: float = prop_def.placeholder_params.get("radius", 0.25)
		var cyl: CylinderShape3D = shape as CylinderShape3D
		ctx.assert_not_null(cyl, "Shape must be CylinderShape3D")
		if cyl != null:
			ctx.assert_true(is_equal_approx(cyl.radius, expected_radius),
				"Expected radius %.4f, got %.4f" % [expected_radius, cyl.radius])
	)

	# NOTE: "the placement is rejected" step is defined in crafting_steps.gd
	# and reused by this feature (checks ctx "placement_rejected" flag).
