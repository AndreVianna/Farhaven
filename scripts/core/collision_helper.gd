class_name CollisionHelper extends RefCounted

## Generates a CollisionShape3D for a PropDef using its real mesh AABB.
## Used by BuildingSystem and StructureRenderer to create physics bodies for placed props.
## Props without authored meshes fall back to a unit cube so a collision body still exists.

const _PropDef = preload("res://scripts/data/prop_def.gd")


static func create_collision_shape(prop_def: _PropDef) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var aabb: AABB = _get_prop_aabb(prop_def)
	if aabb.size == Vector3.ZERO:
		# Fallback: generic 1×1×1 cube centered on origin.
		var box := BoxShape3D.new()
		box.size = Vector3.ONE
		shape.shape = box
		return shape

	var box_shape := BoxShape3D.new()
	box_shape.size = aabb.size
	shape.shape = box_shape
	# Offset the collision to match the mesh AABB center (not origin).
	shape.position = aabb.position + aabb.size * 0.5
	return shape


## Derive AABB from the first authored mesh (PlaceableCap.meshes[0] or def.mesh).
## Returns Vector3.ZERO-sized AABB if no mesh is authored.
static func _get_prop_aabb(prop_def: _PropDef) -> AABB:
	if prop_def == null:
		return AABB()
	if prop_def.placeable != null and prop_def.placeable.meshes != null:
		for mv in prop_def.placeable.meshes:
			if mv == null or mv.scene == null:
				continue
			var mesh: Mesh = _extract_mesh(mv.scene)
			if mesh != null:
				return mesh.get_aabb()
	if prop_def.mesh != null:
		return prop_def.mesh.get_aabb()
	return AABB()


static func _extract_mesh(scene: PackedScene) -> Mesh:
	var root: Node = scene.instantiate()
	if root == null:
		return null
	var mesh: Mesh = null
	for node in _iter_tree(root):
		if node is MeshInstance3D and node.mesh != null:
			mesh = node.mesh
			break
	root.queue_free()
	return mesh


static func _iter_tree(root: Node) -> Array:
	var result: Array = [root]
	for child in root.get_children():
		result.append_array(_iter_tree(child))
	return result
