class_name TestStructureRenderer
extends GdUnitTestSuite

## Unit tests for StructureRenderer.
## Tests signal-driven rendering of player-placed structures using the
## authored-mesh + composable-collision API (2026-04 refactor). Tests no
## longer assert on specific primitive mesh types or placeholder colors,
## since rendering now pulls meshes from authored PackedScenes (or the
## legacy def.mesh fallback) and materials are neutral until an icon
## system lands.

const _StructureRenderer = preload("res://scripts/building/structure_renderer.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")
const _CollisionShape = preload("res://scripts/data/capabilities/collision_shape.gd")


# ---------------------------------------------------------------------------
# Minimal fakes
# ---------------------------------------------------------------------------


class MockGrid extends Node:
	signal structure_placed(coords: Vector2i, structure_type: StringName)
	signal structure_destroyed(coords: Vector2i, structure_type: StringName)

	var _tiles: Dictionary = {}
	var _terrain_y: float = 0.0

	func set_tile(coords: Vector2i, tile: Resource) -> void:
		_tiles[coords] = tile

	func get_tile(coords: Vector2i) -> Resource:
		return _tiles.get(coords, null)

	func get_all_tiles() -> Dictionary:
		return _tiles

	func has_tile(coords: Vector2i) -> bool:
		return _tiles.has(coords)

	func get_terrain_y(_wx: float, _wz: float) -> float:
		return _terrain_y


# ---------------------------------------------------------------------------
# Prop IDs (matching data/props/*.tres)
# ---------------------------------------------------------------------------

const ID_CAMPFIRE: StringName = &"P00101"
const ID_SHELTER: StringName = &"P00102"
const ID_TORCH: StringName = &"P00103"
const ID_STORAGE_CHEST: StringName = &"P00104"
const ID_WORKBENCH: StringName = &"P00105"
const ID_WALL: StringName = &"P00106"


# ---------------------------------------------------------------------------
# Test state
# ---------------------------------------------------------------------------

var _renderer: Node3D
var _grid: MockGrid
var _registered_defs: Array[StringName] = []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_collision_shape(shape_type: StringName, size: Vector3) -> _CollisionShape:
	var s := _CollisionShape.new()
	s.shape_type = shape_type
	s.size = size
	return s


## Registers a structure PropDef with the given collision shapes. The legacy
## def.mesh = BoxMesh(size.ONE) fallback is always set so the renderer has a
## mesh to render (PackedScene authoring is infeasible in unit tests).
func _ensure_structure_def(id: StringName, collision_shapes: Array[Resource] = []) -> void:
	if PropRegistry.get_def(id) != null:
		return
	var def := _PropDef.new()
	def.id = id
	def.display_name = String(id)
	def.tags = [&"STRUCTURE"]
	def.max_stack = 1
	def.origin = 1  # CRAFTED
	# Authored mesh via legacy fallback (tests can't practically author
	# PackedScenes). The renderer prefers placeable.meshes but falls back
	# to def.mesh when scene-based authoring is absent.
	def.mesh = BoxMesh.new()
	# PlaceableCap with authored collision shapes.
	var pcap := _PlaceableCap.new()
	pcap.collision_shapes = collision_shapes
	def.placeable = pcap
	PropRegistry._defs[id] = def
	_registered_defs.append(id)


func _make_tile(coords: Vector2i = Vector2i.ZERO, elevation: int = 0) -> Resource:
	var tile := _HexTile.new()
	tile.coords = coords
	tile.biome = _HexTile.Biome.GRASSLAND
	tile.elevation = elevation
	return tile


func _add_structure_prop(tile: Resource, type: StringName,
		sub_hex: Vector2i = Vector2i.ZERO) -> void:
	var prop := _Prop.create_structure(type, sub_hex)
	prop.origin = _Prop.Origin.CRAFTED
	tile.props.append(prop)


# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------


func before_test() -> void:
	_registered_defs.clear()

	# Campfire, torch — walkthrough (no collision).
	_ensure_structure_def(ID_CAMPFIRE)
	_ensure_structure_def(ID_TORCH)
	# Wall, workbench, chest, shelter — box collision so StaticBody3D is added.
	var box_shape: Array[Resource] = [_make_collision_shape(&"box", Vector3.ONE)]
	_ensure_structure_def(ID_WALL, box_shape)
	_ensure_structure_def(ID_WORKBENCH, box_shape)
	_ensure_structure_def(ID_STORAGE_CHEST, box_shape)
	_ensure_structure_def(ID_SHELTER, box_shape)

	_grid = MockGrid.new()
	add_child(_grid)

	_renderer = _StructureRenderer.new()
	_renderer.name = "StructureRenderer"
	_renderer._grid = _grid
	add_child(_renderer)


func after_test() -> void:
	if is_instance_valid(_renderer):
		remove_child(_renderer)
		_renderer.queue_free()
	if is_instance_valid(_grid):
		remove_child(_grid)
		_grid.queue_free()
	_renderer = null
	_grid = null
	for id: StringName in _registered_defs:
		PropRegistry._defs.erase(id)


# ===========================================================================
# Initial state
# ===========================================================================


func test_initial_instance_count_is_zero() -> void:
	assert_int(_renderer.get_instance_count()).is_equal(0)


# ===========================================================================
# structure_placed creates instance
# ===========================================================================


func test_structure_placed_creates_instance() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	assert_int(_renderer.get_instance_count()).is_equal(1)
	assert_bool(_renderer.has_instance(Vector2i.ZERO, ID_CAMPFIRE)).is_true()


func test_structure_placed_creates_node3d_child() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	assert_bool(node != null).is_true()
	assert_bool(node is Node3D).is_true()


func test_placed_node_has_mesh_child_when_collision_authored() -> void:
	# ID_WALL has a box collision_shape authored → MeshInstance3D + StaticBody3D.
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	assert_int(node.get_child_count()).is_equal(2)
	assert_bool(node.get_child(0) is MeshInstance3D).is_true()
	assert_bool(node.get_child(1) is StaticBody3D).is_true()


func test_walkthrough_prop_has_no_static_body() -> void:
	# ID_CAMPFIRE has no collision_shapes authored → walkthrough, only MeshInstance3D.
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_CAMPFIRE)
	assert_int(node.get_child_count()).is_equal(1)
	assert_bool(node.get_child(0) is MeshInstance3D).is_true()


# ===========================================================================
# structure_destroyed removes instance
# ===========================================================================


func test_structure_destroyed_removes_instance() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)
	assert_int(_renderer.get_instance_count()).is_equal(1)

	_grid.structure_destroyed.emit(Vector2i.ZERO, ID_CAMPFIRE)
	assert_int(_renderer.get_instance_count()).is_equal(0)
	assert_bool(_renderer.has_instance(Vector2i.ZERO, ID_CAMPFIRE)).is_false()


func test_structure_destroyed_for_nonexistent_is_safe() -> void:
	_grid.structure_destroyed.emit(Vector2i(5, 5), ID_WALL)
	assert_int(_renderer.get_instance_count()).is_equal(0)


# ===========================================================================
# Multiple structures
# ===========================================================================


func test_multiple_structures_at_different_tiles() -> void:
	var tile1 := _make_tile(Vector2i(0, 0))
	_add_structure_prop(tile1, ID_CAMPFIRE)
	_grid.set_tile(Vector2i(0, 0), tile1)

	var tile2 := _make_tile(Vector2i(1, 0))
	_add_structure_prop(tile2, ID_WALL)
	_grid.set_tile(Vector2i(1, 0), tile2)

	_grid.structure_placed.emit(Vector2i(0, 0), ID_CAMPFIRE)
	_grid.structure_placed.emit(Vector2i(1, 0), ID_WALL)

	assert_int(_renderer.get_instance_count()).is_equal(2)
	assert_bool(_renderer.has_instance(Vector2i(0, 0), ID_CAMPFIRE)).is_true()
	assert_bool(_renderer.has_instance(Vector2i(1, 0), ID_WALL)).is_true()


func test_multiple_structures_same_tile_different_types() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE, Vector2i(0, 0))
	_add_structure_prop(tile, ID_TORCH, Vector2i(1, 0))
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)
	_grid.structure_placed.emit(Vector2i.ZERO, ID_TORCH)

	assert_int(_renderer.get_instance_count()).is_equal(2)
	assert_bool(_renderer.has_instance(Vector2i.ZERO, ID_CAMPFIRE)).is_true()
	assert_bool(_renderer.has_instance(Vector2i.ZERO, ID_TORCH)).is_true()


func test_destroy_one_keeps_others() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE, Vector2i(0, 0))
	_add_structure_prop(tile, ID_TORCH, Vector2i(1, 0))
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)
	_grid.structure_placed.emit(Vector2i.ZERO, ID_TORCH)

	_grid.structure_destroyed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	assert_int(_renderer.get_instance_count()).is_equal(1)
	assert_bool(_renderer.has_instance(Vector2i.ZERO, ID_CAMPFIRE)).is_false()
	assert_bool(_renderer.has_instance(Vector2i.ZERO, ID_TORCH)).is_true()


# ===========================================================================
# Collision shape composition — StaticBody3D has one child per authored shape
# ===========================================================================


func test_single_collision_shape_produces_one_static_body_child() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	var static_body: StaticBody3D = node.get_child(1) as StaticBody3D
	assert_int(static_body.get_child_count()).is_equal(1)
	assert_bool(static_body.get_child(0) is CollisionShape3D).is_true()


func test_composite_collision_produces_multiple_static_body_children() -> void:
	# Register a prop with two collision shapes.
	var composite_id: StringName = &"P99901"
	var shapes: Array[Resource] = [
		_make_collision_shape(&"box", Vector3.ONE),
		_make_collision_shape(&"sphere", Vector3(0.3, 0.0, 0.0)),
	]
	_ensure_structure_def(composite_id, shapes)

	var tile := _make_tile()
	_add_structure_prop(tile, composite_id)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, composite_id)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, composite_id)
	var static_body: StaticBody3D = node.get_child(1) as StaticBody3D
	assert_int(static_body.get_child_count()).is_equal(2)


# ===========================================================================
# Positioning — sub-hex offset
# ===========================================================================


func test_structure_at_sub_hex_has_ssh_snapped_position() -> void:
	var tile := _make_tile()
	var sub_hex := Vector2i(1, -1)
	_add_structure_prop(tile, ID_TORCH, sub_hex)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_TORCH)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_TORCH)
	var tile_center: Vector2 = _HexMath.axial_to_world(Vector2i.ZERO)
	var sub_offset: Vector2 = _HexMath.sub_axial_to_world(sub_hex)
	var raw_pos: Vector2 = tile_center + sub_offset
	var ssh_result: Dictionary = _HexMath.snap_to_ssh(raw_pos, Vector2i.ZERO)
	var snapped: Vector2 = ssh_result["snapped_world"]
	assert_float(node.position.x).is_equal_approx(snapped.x, 0.01)
	assert_float(node.position.z).is_equal_approx(snapped.y, 0.01)


func test_structure_at_tile_center_uses_ssh_snapped_pos() -> void:
	var coords := Vector2i(2, 3)
	var tile := _make_tile(coords)
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(coords, tile)

	_grid.structure_placed.emit(coords, ID_CAMPFIRE)

	var node: Node3D = _renderer.get_instance(coords, ID_CAMPFIRE)
	var expected_2d: Vector2 = _HexMath.axial_to_world(coords)
	var ssh_result: Dictionary = _HexMath.snap_to_ssh(expected_2d, coords)
	var snapped: Vector2 = ssh_result["snapped_world"]
	assert_float(node.position.x).is_equal_approx(snapped.x, 0.01)
	assert_float(node.position.z).is_equal_approx(snapped.y, 0.01)


# ===========================================================================
# Positioning — elevation
# ===========================================================================


func test_structure_at_elevated_tile_has_y_offset() -> void:
	# Default BoxMesh has size (1,1,1) → AABB.position.y = -0.5 → y_offset = 0.5.
	_grid._terrain_y = 2.5
	var tile := _make_tile(Vector2i.ZERO, 5)
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	assert_float(node.position.y).is_equal_approx(2.5 + 0.5, 0.01)


func test_structure_at_zero_elevation() -> void:
	_grid._terrain_y = 0.0
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_CAMPFIRE)
	# BoxMesh default size(1,1,1) → y_offset = 0.5.
	assert_float(node.position.y).is_equal_approx(0.5, 0.01)


# ===========================================================================
# Multi-hex structure anchor position
# ===========================================================================


func test_workbench_renders_at_anchor_ssh_snapped() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WORKBENCH, Vector2i.ZERO)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WORKBENCH)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WORKBENCH)
	var tile_center: Vector2 = _HexMath.axial_to_world(Vector2i.ZERO)
	var ssh_result: Dictionary = _HexMath.snap_to_ssh(tile_center, Vector2i.ZERO)
	var snapped: Vector2 = ssh_result["snapped_world"]
	assert_float(node.position.x).is_equal_approx(snapped.x, 0.01)
	assert_float(node.position.z).is_equal_approx(snapped.y, 0.01)


func test_shelter_renders_at_anchor_ssh_snapped() -> void:
	var tile := _make_tile()
	var anchor := Vector2i(1, 1)
	_add_structure_prop(tile, ID_SHELTER, anchor)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_SHELTER)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_SHELTER)
	var tile_center: Vector2 = _HexMath.axial_to_world(Vector2i.ZERO)
	var sub_offset: Vector2 = _HexMath.sub_axial_to_world(anchor)
	var raw_pos: Vector2 = tile_center + sub_offset
	var ssh_result: Dictionary = _HexMath.snap_to_ssh(raw_pos, Vector2i.ZERO)
	var snapped: Vector2 = ssh_result["snapped_world"]
	assert_float(node.position.x).is_equal_approx(snapped.x, 0.01)
	assert_float(node.position.z).is_equal_approx(snapped.y, 0.01)


# ===========================================================================
# Signal-driven only
# ===========================================================================


func test_no_instances_without_signals() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)
	assert_int(_renderer.get_instance_count()).is_equal(0)


# ===========================================================================
# Idempotent placement
# ===========================================================================


func test_duplicate_placed_signal_replaces_instance() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)
	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	assert_int(_renderer.get_instance_count()).is_equal(1)


# ===========================================================================
# Key format
# ===========================================================================


func test_key_format_includes_coords_and_type() -> void:
	var tile := _make_tile(Vector2i(3, -2))
	_add_structure_prop(tile, ID_TORCH)
	_grid.set_tile(Vector2i(3, -2), tile)

	_grid.structure_placed.emit(Vector2i(3, -2), ID_TORCH)

	var keys: Array = _renderer.get_all_keys()
	assert_int(keys.size()).is_equal(1)
	assert_str(keys[0]).is_equal("3,-2:0,0:P00103")


# ===========================================================================
# All 6 structure types render
# ===========================================================================


func test_all_six_structure_types_render() -> void:
	var types: Array[StringName] = [
		ID_CAMPFIRE, ID_SHELTER, ID_TORCH,
		ID_STORAGE_CHEST, ID_WORKBENCH, ID_WALL,
	]
	for i in range(types.size()):
		var coords := Vector2i(i, 0)
		var tile := _make_tile(coords)
		_add_structure_prop(tile, types[i])
		_grid.set_tile(coords, tile)
		_grid.structure_placed.emit(coords, types[i])

	assert_int(_renderer.get_instance_count()).is_equal(6)
	for i in range(types.size()):
		assert_bool(_renderer.has_instance(Vector2i(i, 0), types[i])).is_true()


# ===========================================================================
# Props without meshes are skipped
# ===========================================================================


func test_prop_without_mesh_is_not_rendered() -> void:
	# Register a def with no mesh and no placeable.meshes — renderer should skip.
	var meshless_id: StringName = &"P99902"
	var def := _PropDef.new()
	def.id = meshless_id
	def.display_name = String(meshless_id)
	def.tags = [&"STRUCTURE"]
	def.max_stack = 1
	def.origin = 1
	def.placeable = _PlaceableCap.new()
	# No def.mesh, no placeable.meshes.
	PropRegistry._defs[meshless_id] = def
	_registered_defs.append(meshless_id)

	var tile := _make_tile()
	_add_structure_prop(tile, meshless_id)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, meshless_id)

	assert_int(_renderer.get_instance_count()).is_equal(0)
