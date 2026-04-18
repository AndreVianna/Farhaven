class_name CollisionHelper extends RefCounted

## Generates CollisionShape3D nodes for a PropDef based on the composed
## shapes authored in its PlaceableCap.collision_shapes array. A prop
## with an empty (or missing) collision_shapes array has no collision
## (walkthrough). Props with shapes get one CollisionShape3D per entry,
## all parented to the caller's StaticBody3D.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _CollisionShape = preload("res://scripts/data/capabilities/collision_shape.gd")


## Returns an array of CollisionShape3D nodes ready to be parented to a
## StaticBody3D. Empty array = walkthrough prop. Caller is responsible
## for adding each node to the physics body.
static func create_collision_shapes(prop_def: _PropDef) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	if prop_def == null or prop_def.placeable == null:
		return out
	var shapes: Array = prop_def.placeable.collision_shapes
	if shapes == null or shapes.is_empty():
		return out
	for cs in shapes:
		if cs == null:
			continue
		var node: CollisionShape3D = _build_one(cs)
		if node != null:
			out.append(node)
	return out


static func _build_one(cs_resource: Resource) -> CollisionShape3D:
	# Defensive cast — a non-CollisionShape resource in the array would
	# throw when accessing .shape_type/.size/.offset below. Skip silently
	# and let the outer "no meshes" warning surface the broader issue.
	var cs: _CollisionShape = cs_resource as _CollisionShape
	if cs == null:
		push_warning("CollisionHelper: skipping non-CollisionShape entry in collision_shapes array")
		return null
	var node := CollisionShape3D.new()
	var shape: Shape3D = null
	var shape_type: StringName = cs.shape_type
	var size: Vector3 = cs.size
	match shape_type:
		&"box":
			if is_nan(size.x) or size.x <= 0.0:
				push_warning("CollisionHelper: box size.x %s clamped to 0.01 — likely an authoring error" % size.x)
			if is_nan(size.y) or size.y <= 0.0:
				push_warning("CollisionHelper: box size.y %s clamped to 0.01 — likely an authoring error" % size.y)
			if is_nan(size.z) or size.z <= 0.0:
				push_warning("CollisionHelper: box size.z %s clamped to 0.01 — likely an authoring error" % size.z)
			var box := BoxShape3D.new()
			box.size = Vector3(
				0.01 if is_nan(size.x) else maxf(size.x, 0.01),
				0.01 if is_nan(size.y) else maxf(size.y, 0.01),
				0.01 if is_nan(size.z) else maxf(size.z, 0.01),
			)
			shape = box
		&"cylinder":
			if is_nan(size.x) or size.x <= 0.0:
				push_warning("CollisionHelper: cylinder radius %s clamped to 0.01 — likely an authoring error" % size.x)
			if is_nan(size.y) or size.y <= 0.0:
				push_warning("CollisionHelper: cylinder height %s clamped to 0.01 — likely an authoring error" % size.y)
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.01 if is_nan(size.x) else maxf(size.x, 0.01)
			cyl.height = 0.01 if is_nan(size.y) else maxf(size.y, 0.01)
			shape = cyl
		&"sphere":
			if is_nan(size.x) or size.x <= 0.0:
				push_warning("CollisionHelper: sphere radius %s clamped to 0.01 — likely an authoring error" % size.x)
			var sph := SphereShape3D.new()
			sph.radius = 0.01 if is_nan(size.x) else maxf(size.x, 0.01)
			shape = sph
		_:
			push_warning("CollisionHelper: unknown shape_type %s — skipping" % shape_type)
			return null
	node.shape = shape
	node.position = cs.offset
	return node
