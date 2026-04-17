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


static func _build_one(cs: Resource) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape: Shape3D = null
	var shape_type: StringName = cs.shape_type
	var size: Vector3 = cs.size
	match shape_type:
		&"box":
			var box := BoxShape3D.new()
			box.size = size
			shape = box
		&"cylinder":
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(size.x, 0.01)
			cyl.height = maxf(size.y, 0.01)
			shape = cyl
		&"sphere":
			var sph := SphereShape3D.new()
			sph.radius = maxf(size.x, 0.01)
			shape = sph
		_:
			push_warning("CollisionHelper: unknown shape_type %s — skipping" % shape_type)
			return null
	node.shape = shape
	node.position = cs.offset
	return node
