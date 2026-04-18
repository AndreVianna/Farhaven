class_name TestCollisionHelper
extends GdUnitTestSuite

## Unit tests for CollisionHelper.create_collision_shapes.
## Exercises the authored-shape composition API (PlaceableCap.collision_shapes).

const _CollisionHelper = preload("res://scripts/core/collision_helper.gd")
const _CollisionShape = preload("res://scripts/data/capabilities/collision_shape.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")


# ---------------------------------------------------------------------------
# Helpers to build minimal props with authored collision shapes
# ---------------------------------------------------------------------------


func _make_shape(shape_type: StringName, size: Vector3, offset: Vector3 = Vector3.ZERO) -> _CollisionShape:
	var s := _CollisionShape.new()
	s.shape_type = shape_type
	s.size = size
	s.offset = offset
	return s


func _make_prop_with_shapes(shapes: Array[Resource]) -> _PropDef:
	var def := _PropDef.new()
	var cap := _PlaceableCap.new()
	cap.collision_shapes = shapes
	def.placeable = cap
	return def


# ---------------------------------------------------------------------------
# Walkthrough props — empty / missing collision_shapes → empty array
# ---------------------------------------------------------------------------


func test_walkthrough_empty_array_returns_no_shapes() -> void:
	var def := _make_prop_with_shapes([])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(0)


func test_null_prop_def_returns_empty() -> void:
	var out := _CollisionHelper.create_collision_shapes(null)
	assert_int(out.size()).is_equal(0)


func test_prop_without_placeable_cap_returns_empty() -> void:
	var def := _PropDef.new()
	# def.placeable left null
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(0)


# ---------------------------------------------------------------------------
# box → BoxShape3D with full extents
# ---------------------------------------------------------------------------


func test_single_box_returns_one_box_shape() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"box", Vector3(1.0, 0.5, 0.8))])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(1)
	assert_object(out[0].shape).is_instanceof(BoxShape3D)


func test_box_size_matches_authored_size() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"box", Vector3(1.0, 0.5, 0.8))])
	var out := _CollisionHelper.create_collision_shapes(def)
	var box: BoxShape3D = out[0].shape as BoxShape3D
	assert_float(box.size.x).is_equal_approx(1.0, 0.001)
	assert_float(box.size.y).is_equal_approx(0.5, 0.001)
	assert_float(box.size.z).is_equal_approx(0.8, 0.001)


# ---------------------------------------------------------------------------
# cylinder → CylinderShape3D (radius from size.x, height from size.y)
# ---------------------------------------------------------------------------


func test_single_cylinder_returns_cylinder_shape() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"cylinder", Vector3(0.3, 1.0, 0.0))])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(1)
	assert_object(out[0].shape).is_instanceof(CylinderShape3D)


func test_cylinder_radius_and_height_match_size() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"cylinder", Vector3(0.3, 1.0, 0.0))])
	var out := _CollisionHelper.create_collision_shapes(def)
	var cyl: CylinderShape3D = out[0].shape as CylinderShape3D
	assert_float(cyl.radius).is_equal_approx(0.3, 0.001)
	assert_float(cyl.height).is_equal_approx(1.0, 0.001)


# ---------------------------------------------------------------------------
# sphere → SphereShape3D (radius from size.x)
# ---------------------------------------------------------------------------


func test_single_sphere_returns_sphere_shape() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"sphere", Vector3(0.4, 0.0, 0.0))])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(1)
	assert_object(out[0].shape).is_instanceof(SphereShape3D)


func test_sphere_radius_matches_size_x() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"sphere", Vector3(0.4, 0.0, 0.0))])
	var out := _CollisionHelper.create_collision_shapes(def)
	var sph: SphereShape3D = out[0].shape as SphereShape3D
	assert_float(sph.radius).is_equal_approx(0.4, 0.001)


# ---------------------------------------------------------------------------
# Composition — multiple shapes in one prop
# ---------------------------------------------------------------------------


func test_composite_returns_one_node_per_shape() -> void:
	var def := _make_prop_with_shapes([
		_make_shape(&"box", Vector3.ONE),
		_make_shape(&"cylinder", Vector3(0.5, 1.0, 0.0)),
		_make_shape(&"sphere", Vector3(0.3, 0.0, 0.0)),
	])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(3)
	assert_object(out[0].shape).is_instanceof(BoxShape3D)
	assert_object(out[1].shape).is_instanceof(CylinderShape3D)
	assert_object(out[2].shape).is_instanceof(SphereShape3D)


func test_composite_preserves_order() -> void:
	var def := _make_prop_with_shapes([
		_make_shape(&"sphere", Vector3(0.2, 0.0, 0.0)),
		_make_shape(&"box", Vector3(2.0, 0.5, 0.5)),
	])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_object(out[0].shape).is_instanceof(SphereShape3D)
	assert_object(out[1].shape).is_instanceof(BoxShape3D)


# ---------------------------------------------------------------------------
# Offset applied to CollisionShape3D.position
# ---------------------------------------------------------------------------


func test_offset_applied_to_node_position() -> void:
	var def := _make_prop_with_shapes([
		_make_shape(&"box", Vector3.ONE, Vector3(0.5, 0.0, -0.3)),
	])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_float(out[0].position.x).is_equal_approx(0.5, 0.001)
	assert_float(out[0].position.y).is_equal_approx(0.0, 0.001)
	assert_float(out[0].position.z).is_equal_approx(-0.3, 0.001)


# ---------------------------------------------------------------------------
# Zero / negative dimensions are clamped to 0.01 (cylinder/sphere)
# ---------------------------------------------------------------------------


func test_cylinder_zero_radius_clamped() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"cylinder", Vector3(0.0, 1.0, 0.0))])
	var out := _CollisionHelper.create_collision_shapes(def)
	var cyl: CylinderShape3D = out[0].shape as CylinderShape3D
	assert_float(cyl.radius).is_equal_approx(0.01, 0.001)


func test_sphere_negative_radius_clamped() -> void:
	var def := _make_prop_with_shapes([_make_shape(&"sphere", Vector3(-0.5, 0.0, 0.0))])
	var out := _CollisionHelper.create_collision_shapes(def)
	var sph: SphereShape3D = out[0].shape as SphereShape3D
	assert_float(sph.radius).is_equal_approx(0.01, 0.001)


# ---------------------------------------------------------------------------
# Defensive — unknown shape_type skipped, null entries skipped
# ---------------------------------------------------------------------------


func test_unknown_shape_type_is_skipped() -> void:
	var def := _make_prop_with_shapes([
		_make_shape(&"box", Vector3.ONE),
		_make_shape(&"hexagonal_dodecahedron", Vector3.ONE),
		_make_shape(&"sphere", Vector3(0.3, 0.0, 0.0)),
	])
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(2)
	assert_object(out[0].shape).is_instanceof(BoxShape3D)
	assert_object(out[1].shape).is_instanceof(SphereShape3D)


func test_null_entry_is_skipped() -> void:
	var shapes: Array[Resource] = [
		_make_shape(&"box", Vector3.ONE),
		null,
		_make_shape(&"sphere", Vector3(0.3, 0.0, 0.0)),
	]
	var def := _make_prop_with_shapes(shapes)
	var out := _CollisionHelper.create_collision_shapes(def)
	assert_int(out.size()).is_equal(2)


# ---------------------------------------------------------------------------
# Type contract — always returns Array[CollisionShape3D] with valid shapes
# ---------------------------------------------------------------------------


func test_all_valid_types_produce_nonnull_shapes() -> void:
	var types: Array[StringName] = [&"box", &"cylinder", &"sphere"]
	for st in types:
		var def := _make_prop_with_shapes([_make_shape(st, Vector3.ONE)])
		var out := _CollisionHelper.create_collision_shapes(def)
		assert_int(out.size()).is_equal(1)
		assert_object(out[0]).is_not_null()
		assert_object(out[0].shape).is_not_null()
