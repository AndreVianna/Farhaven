class_name TestCollisionHelper
extends GdUnitTestSuite

## Unit tests for CollisionHelper.create_collision_shape (task-061).

const _CollisionHelper = preload("res://scripts/core/collision_helper.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")


# ---------------------------------------------------------------------------
# Helper to build a minimal PropDef with placeholder params
# ---------------------------------------------------------------------------


func _make_prop_def(_mesh_type: StringName, _params: Dictionary = {}) -> Resource:
	# TODO: rewrite these tests to author a real MeshInstance3D and assert
	# AABB-derived collision dimensions. The old placeholder-type API is
	# gone; collision now defaults to a unit cube for meshless props.
	return _PropDef.new()


# ---------------------------------------------------------------------------
# cube → BoxShape3D with correct size
# ---------------------------------------------------------------------------


func test_cube_returns_box_shape() -> void:
	var def := _make_prop_def(&"cube", {"half_size": 0.35})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	assert_object(cs).is_not_null()
	assert_object(cs.shape).is_instanceof(BoxShape3D)


func test_cube_size_matches_half_size() -> void:
	var def := _make_prop_def(&"cube", {"half_size": 0.35})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var box: BoxShape3D = cs.shape as BoxShape3D
	assert_float(box.size.x).is_equal_approx(0.7, 0.001)
	assert_float(box.size.y).is_equal_approx(0.7, 0.001)
	assert_float(box.size.z).is_equal_approx(0.7, 0.001)


func test_cube_default_half_size() -> void:
	var def := _make_prop_def(&"cube", {})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var box: BoxShape3D = cs.shape as BoxShape3D
	assert_float(box.size.x).is_equal_approx(0.5, 0.001)


# ---------------------------------------------------------------------------
# box → BoxShape3D with x/y/z
# ---------------------------------------------------------------------------


func test_box_returns_box_shape() -> void:
	var def := _make_prop_def(&"box", {"size_x": 1.0, "size_y": 0.5, "size_z": 0.8})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	assert_object(cs.shape).is_instanceof(BoxShape3D)


func test_box_size_matches_params() -> void:
	var def := _make_prop_def(&"box", {"size_x": 1.0, "size_y": 0.5, "size_z": 0.8})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var box: BoxShape3D = cs.shape as BoxShape3D
	assert_float(box.size.x).is_equal_approx(1.0, 0.001)
	assert_float(box.size.y).is_equal_approx(0.5, 0.001)
	assert_float(box.size.z).is_equal_approx(0.8, 0.001)


func test_box_default_sizes() -> void:
	var def := _make_prop_def(&"box", {})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var box: BoxShape3D = cs.shape as BoxShape3D
	assert_float(box.size.x).is_equal_approx(0.5, 0.001)
	assert_float(box.size.y).is_equal_approx(0.5, 0.001)
	assert_float(box.size.z).is_equal_approx(0.5, 0.001)


# ---------------------------------------------------------------------------
# cylinder → CylinderShape3D with radius/height
# ---------------------------------------------------------------------------


func test_cylinder_returns_cylinder_shape() -> void:
	var def := _make_prop_def(&"cylinder", {"radius": 0.3, "height": 1.0})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	assert_object(cs.shape).is_instanceof(CylinderShape3D)


func test_cylinder_params_match() -> void:
	var def := _make_prop_def(&"cylinder", {"radius": 0.3, "height": 1.0})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var cyl: CylinderShape3D = cs.shape as CylinderShape3D
	assert_float(cyl.radius).is_equal_approx(0.3, 0.001)
	assert_float(cyl.height).is_equal_approx(1.0, 0.001)


func test_cylinder_default_params() -> void:
	var def := _make_prop_def(&"cylinder", {})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var cyl: CylinderShape3D = cs.shape as CylinderShape3D
	assert_float(cyl.radius).is_equal_approx(0.25, 0.001)
	assert_float(cyl.height).is_equal_approx(0.5, 0.001)


# ---------------------------------------------------------------------------
# sphere → SphereShape3D with radius
# ---------------------------------------------------------------------------


func test_sphere_returns_sphere_shape() -> void:
	var def := _make_prop_def(&"sphere", {"radius": 0.4})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	assert_object(cs.shape).is_instanceof(SphereShape3D)


func test_sphere_radius_matches() -> void:
	var def := _make_prop_def(&"sphere", {"radius": 0.4})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var sphere: SphereShape3D = cs.shape as SphereShape3D
	assert_float(sphere.radius).is_equal_approx(0.4, 0.001)


func test_sphere_default_radius() -> void:
	var def := _make_prop_def(&"sphere", {})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var sphere: SphereShape3D = cs.shape as SphereShape3D
	assert_float(sphere.radius).is_equal_approx(0.25, 0.001)


# ---------------------------------------------------------------------------
# octahedron → CylinderShape3D (approximate)
# ---------------------------------------------------------------------------


func test_octahedron_returns_cylinder_shape() -> void:
	var def := _make_prop_def(&"octahedron", {"radius": 0.35, "height": 0.7})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	assert_object(cs.shape).is_instanceof(CylinderShape3D)


func test_octahedron_params_match() -> void:
	var def := _make_prop_def(&"octahedron", {"radius": 0.35, "height": 0.7})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var cyl: CylinderShape3D = cs.shape as CylinderShape3D
	assert_float(cyl.radius).is_equal_approx(0.35, 0.001)
	assert_float(cyl.height).is_equal_approx(0.7, 0.001)


# ---------------------------------------------------------------------------
# prism → CylinderShape3D (approximate)
# ---------------------------------------------------------------------------


func test_prism_returns_cylinder_shape() -> void:
	var def := _make_prop_def(&"prism", {"radius": 0.2, "height": 0.9})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	assert_object(cs.shape).is_instanceof(CylinderShape3D)


func test_prism_params_match() -> void:
	var def := _make_prop_def(&"prism", {"radius": 0.2, "height": 0.9})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var cyl: CylinderShape3D = cs.shape as CylinderShape3D
	assert_float(cyl.radius).is_equal_approx(0.2, 0.001)
	assert_float(cyl.height).is_equal_approx(0.9, 0.001)


# ---------------------------------------------------------------------------
# unknown type → fallback BoxShape3D
# ---------------------------------------------------------------------------


func test_unknown_type_returns_box_shape() -> void:
	var def := _make_prop_def(&"hexagonal_dodecahedron", {})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	assert_object(cs.shape).is_instanceof(BoxShape3D)


func test_unknown_type_fallback_size() -> void:
	var def := _make_prop_def(&"hexagonal_dodecahedron", {})
	var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
	var box: BoxShape3D = cs.shape as BoxShape3D
	assert_float(box.size.x).is_equal_approx(0.5, 0.001)
	assert_float(box.size.y).is_equal_approx(0.5, 0.001)
	assert_float(box.size.z).is_equal_approx(0.5, 0.001)


# ---------------------------------------------------------------------------
# All shapes have non-zero dimensions
# ---------------------------------------------------------------------------


func test_all_shapes_have_nonzero_dimensions() -> void:
	var types: Array[StringName] = [&"cube", &"box", &"cylinder", &"sphere", &"octahedron", &"prism"]
	for mesh_type: StringName in types:
		var def := _make_prop_def(mesh_type, {})
		var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
		assert_object(cs.shape).is_not_null()
		# Verify shapes have positive volume by checking type-specific dimensions
		if cs.shape is BoxShape3D:
			var box: BoxShape3D = cs.shape as BoxShape3D
			assert_bool(box.size.x > 0.0).is_true()
			assert_bool(box.size.y > 0.0).is_true()
			assert_bool(box.size.z > 0.0).is_true()
		elif cs.shape is CylinderShape3D:
			var cyl: CylinderShape3D = cs.shape as CylinderShape3D
			assert_bool(cyl.radius > 0.0).is_true()
			assert_bool(cyl.height > 0.0).is_true()
		elif cs.shape is SphereShape3D:
			var sphere: SphereShape3D = cs.shape as SphereShape3D
			assert_bool(sphere.radius > 0.0).is_true()


# ---------------------------------------------------------------------------
# CollisionShape3D node is always returned (never null)
# ---------------------------------------------------------------------------


func test_always_returns_collision_shape_node() -> void:
	var types: Array[StringName] = [&"cube", &"box", &"cylinder", &"sphere", &"octahedron", &"prism", &"unknown"]
	for mesh_type: StringName in types:
		var def := _make_prop_def(mesh_type, {})
		var cs: CollisionShape3D = _CollisionHelper.create_collision_shape(def)
		assert_object(cs).is_not_null()
		assert_object(cs.shape).is_not_null()
