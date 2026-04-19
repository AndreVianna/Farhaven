class_name CollisionHelper extends RefCounted

## Generates CollisionShape3D nodes for a PropDef based on the composed
## shapes authored in its PlaceableCap.collision_shapes array. A prop
## with an empty (or missing) collision_shapes array has no collision
## (walkthrough). Props with shapes get one CollisionShape3D per entry,
## all parented to the caller's StaticBody3D.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _CollisionShape = preload("res://scripts/data/capabilities/collision_shape.gd")

## Minimum effective shape dimension (after scaling) below which a
## scattered natural prop is treated as walkthrough. 0.15 m ≈ 15 cm —
## player physics body is ~1-2 m tall, anything smaller than this is
## debris (loose pebbles, grass blades) that the player would walk over
## without tripping. Tune per Andre's calibration on 2026-04-19.
const MIN_COLLISION_DIM: float = 0.15


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


## Returns CollisionShape3D nodes pre-scaled for a scattered natural prop
## instance (MultiMesh path — no parent Node3D with a scale to inherit).
## Dimensions and offsets are baked so callers can parent each node to
## a StaticBody3D placed at the instance's world position without any
## further scaling.
##
## Filters out shapes whose smallest effective dimension falls below
## MIN_COLLISION_DIM: tiny grass-blade hitboxes would just tax the
## PhysicsServer without the player ever interacting with them.
## Returns empty array if all shapes fall below threshold (prop is
## effectively walkthrough at this scale).
static func create_scaled_collision_shapes(
		prop_def: _PropDef, effective_scale: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	if prop_def == null or prop_def.placeable == null:
		return out
	if is_nan(effective_scale) or effective_scale <= 0.0:
		return out
	var shapes: Array = prop_def.placeable.collision_shapes
	if shapes == null or shapes.is_empty():
		return out
	for cs_resource in shapes:
		var cs: _CollisionShape = cs_resource as _CollisionShape
		if cs == null:
			continue
		if not _passes_size_threshold(cs, effective_scale):
			continue
		var node: CollisionShape3D = _build_one_scaled(cs, effective_scale)
		if node != null:
			out.append(node)
	return out


## True if the shape's smallest effective (scaled) dimension is at or
## above MIN_COLLISION_DIM. Shape-specific minimum:
##   box      → min(x, y, z)
##   cylinder → min(radius×2, height)  (compare diameters, not radii)
##   sphere   → radius × 2              (diameter)
static func _passes_size_threshold(cs: _CollisionShape, effective_scale: float) -> bool:
	var size: Vector3 = cs.size
	var min_dim: float
	match cs.shape_type:
		&"box":
			min_dim = minf(minf(size.x, size.y), size.z)
		&"cylinder":
			min_dim = minf(size.x * 2.0, size.y)
		&"sphere":
			min_dim = size.x * 2.0
		_:
			return false
	return (min_dim * effective_scale) >= MIN_COLLISION_DIM


static func _build_one_scaled(cs: _CollisionShape, effective_scale: float) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape: Shape3D = null
	var size: Vector3 = cs.size
	match cs.shape_type:
		&"box":
			var box := BoxShape3D.new()
			box.size = Vector3(
				maxf(size.x * effective_scale, 0.01),
				maxf(size.y * effective_scale, 0.01),
				maxf(size.z * effective_scale, 0.01),
			)
			shape = box
		&"cylinder":
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(size.x * effective_scale, 0.01)
			cyl.height = maxf(size.y * effective_scale, 0.01)
			shape = cyl
		&"sphere":
			var sph := SphereShape3D.new()
			sph.radius = maxf(size.x * effective_scale, 0.01)
			shape = sph
		_:
			return null
	node.shape = shape
	node.position = cs.offset * effective_scale
	return node
