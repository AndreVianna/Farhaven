class_name CollisionHelper extends RefCounted

## Generates a CollisionShape3D from PropDef placeholder parameters.
## Used by BuildingSystem and StructureRenderer to create physics bodies for placed props.

const _PropDef = preload("res://scripts/data/prop_def.gd")


static func create_collision_shape(prop_def: Resource) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var mesh_type: String = String(prop_def.placeholder_mesh_type)
	var params: Dictionary = prop_def.placeholder_params

	match mesh_type:
		"cube":
			var box := BoxShape3D.new()
			var half_size: float = params.get("half_size", 0.25)
			box.size = Vector3(half_size * 2, half_size * 2, half_size * 2)
			shape.shape = box
		"box":
			var box := BoxShape3D.new()
			box.size = Vector3(
				params.get("size_x", 0.5),
				params.get("size_y", 0.5),
				params.get("size_z", 0.5)
			)
			shape.shape = box
		"cylinder":
			var cyl := CylinderShape3D.new()
			cyl.radius = params.get("radius", 0.25)
			cyl.height = params.get("height", 0.5)
			shape.shape = cyl
		"sphere":
			var sphere := SphereShape3D.new()
			sphere.radius = params.get("radius", 0.25)
			shape.shape = sphere
		"octahedron", "prism":
			# Approximate with a cylinder
			var cyl := CylinderShape3D.new()
			cyl.radius = params.get("radius", 0.25)
			cyl.height = params.get("height", 0.5)
			shape.shape = cyl
		_:
			# Fallback: small box
			var box := BoxShape3D.new()
			box.size = Vector3(0.5, 0.5, 0.5)
			shape.shape = box

	return shape
