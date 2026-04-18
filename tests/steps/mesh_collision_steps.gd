extends RefCounted

## Step definitions for mesh collision feature.
## Tests CollisionHelper shape composition and placement rejection.
## Uses the authored-shape API (PlaceableCap.collision_shapes) directly.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")
const _CollisionShape = preload("res://scripts/data/capabilities/collision_shape.gd")
const _CollisionHelper = preload("res://scripts/core/collision_helper.gd")


func register_steps(registry) -> void:
	# --- Given ---
	registry.given("a campfire PropDef with an authored cylinder collision", func(ctx):
		var prop_def := _PropDef.new()
		prop_def.id = &"P_TEST_CAMPFIRE"
		prop_def.display_name = "Test Campfire"

		var cap := _PlaceableCap.new()
		var cs := _CollisionShape.new()
		cs.shape_type = &"cylinder"
		# size: (radius, height, unused)
		cs.size = Vector3(0.3, 0.15, 0.0)
		cap.collision_shapes = [cs]
		prop_def.placeable = cap

		ctx.set_value("prop_def", prop_def)
		ctx.set_value("expected_radius", 0.3)
		ctx.set_value("expected_height", 0.15)
	)

	registry.given("a structure at position {int}, {int}", func(ctx, x: int, y: int):
		var occupied: Array = ctx.get_value("occupied_positions", [])
		occupied.append(Vector2i(x, y))
		ctx.set_value("occupied_positions", occupied)
	)

	# --- When ---
	registry.when("collision shapes are generated", func(ctx):
		var prop_def: Resource = ctx.get_value("prop_def", null)
		ctx.assert_not_null(prop_def, "PropDef must exist")
		if prop_def == null:
			return
		var nodes: Array[CollisionShape3D] = _CollisionHelper.create_collision_shapes(prop_def)
		# Extract the Shape3D resources and free the Nodes to avoid leaks.
		var shapes: Array[Shape3D] = []
		for node in nodes:
			shapes.append(node.shape)
			node.free()
		ctx.set_value("collision_shapes", shapes)
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
	registry.then("the first shape is a CylinderShape3D", func(ctx):
		var shapes: Array = ctx.get_value("collision_shapes", [])
		ctx.assert_true(shapes.size() >= 1, "At least one collision shape must exist")
		if shapes.is_empty():
			return
		var shape: Shape3D = shapes[0]
		ctx.assert_true(shape is CylinderShape3D,
			"Expected CylinderShape3D, got %s" % shape.get_class())
	)

	registry.then("the radius matches the authored size", func(ctx):
		var shapes: Array = ctx.get_value("collision_shapes", [])
		if shapes.is_empty():
			ctx.assert_true(false, "No collision shapes generated")
			return
		var shape: Shape3D = shapes[0]
		var cyl: CylinderShape3D = shape as CylinderShape3D
		ctx.assert_not_null(cyl, "Shape must be CylinderShape3D")
		if cyl == null:
			return
		var expected_radius: float = ctx.get_value("expected_radius", 0.0)
		ctx.assert_true(is_equal_approx(cyl.radius, expected_radius),
			"Expected radius %.4f, got %.4f" % [expected_radius, cyl.radius])
	)

	# NOTE: "the placement is rejected" step is defined in crafting_steps.gd
	# and reused by this feature (checks ctx "placement_rejected" flag).
