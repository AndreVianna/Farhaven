class_name TestStructureRenderer
extends GdUnitTestSuite

## Unit tests for StructureRenderer (task-034).
## Tests signal-driven rendering of player-placed structures.

const _StructureRenderer = preload("res://scripts/building/structure_renderer.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")


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


func _ensure_structure_def(id: StringName, mesh_type: StringName = &"box",
		params: Dictionary = {}, color: Color = Color.WHITE,
		blocks_movement: bool = false,
		footprint: Array[Vector2i] = [Vector2i(0, 0)]) -> void:
	if PropRegistry.get_def(id) != null:
		return
	var def := _PropDef.new()
	def.id = id
	def.display_name = String(id)
	def.tags = [&"STRUCTURE"]
	def.placeholder_mesh_type = mesh_type
	def.placeholder_params = params
	def.placeholder_color = color
	var pcap := _PlaceableCap.new()
	pcap.footprint = footprint
	pcap.blocks_movement = blocks_movement
	def.placeable = pcap
	def.max_stack = 1
	def.origin = 1  # CRAFTED
	PropRegistry._defs[id] = def
	_registered_defs.append(id)


func _make_tile(coords: Vector2i = Vector2i.ZERO, elevation: int = 0) -> Resource:
	var tile := _HexTile.new()
	tile.coords = coords
	tile.biome = _HexTile.Biome.GRASSLAND
	tile.elevation = elevation
	return tile


func _add_structure_prop(tile: Resource, type: StringName,
		sub_hex: Vector2i = Vector2i.ZERO,
		footprint: Array[Vector2i] = [Vector2i(0, 0)]) -> void:
	var prop := _Prop.create_structure(type, false, sub_hex, footprint)
	prop.origin = _Prop.Origin.CRAFTED
	tile.props.append(prop)


# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------


func before_test() -> void:
	_registered_defs.clear()

	# Ensure structure defs exist (matching actual .tres files).
	_ensure_structure_def(ID_CAMPFIRE, &"cylinder",
		{"radius": 0.3, "height": 0.15},
		Color(0.9, 0.4, 0.1, 1.0))
	_ensure_structure_def(ID_SHELTER, &"box",
		{"size_x": 1.0, "size_y": 0.6, "size_z": 1.0},
		Color(0.45, 0.35, 0.2, 1.0), false,
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)])
	_ensure_structure_def(ID_TORCH, &"cylinder",
		{"radius": 0.05, "height": 0.5},
		Color(0.8, 0.6, 0.1, 1.0))
	_ensure_structure_def(ID_STORAGE_CHEST, &"box",
		{"size_x": 0.4, "size_y": 0.3, "size_z": 0.3},
		Color(0.5, 0.35, 0.15, 1.0))
	_ensure_structure_def(ID_WORKBENCH, &"box",
		{"size_x": 0.8, "size_y": 0.4, "size_z": 0.5},
		Color(0.6, 0.4, 0.2, 1.0), false,
		[Vector2i(0, 0), Vector2i(1, 0)])
	_ensure_structure_def(ID_WALL, &"box",
		{"size_x": 0.8, "size_y": 0.6, "size_z": 0.2},
		Color(0.5, 0.4, 0.3, 1.0), true)

	# Create mock grid.
	_grid = MockGrid.new()
	add_child(_grid)

	# Create renderer with injected grid.
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
	# Clean up registered prop defs.
	for id: StringName in _registered_defs:
		PropRegistry._defs.erase(id)


# ===========================================================================
# Tests: Initial state
# ===========================================================================


func test_initial_instance_count_is_zero() -> void:
	assert_int(_renderer.get_instance_count()).is_equal(0)


# ===========================================================================
# Tests: structure_placed creates Node3D child
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


func test_structure_placed_node_has_mesh_child() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	# Node has MeshInstance3D + StaticBody3D (with CollisionShape3D) children.
	assert_int(node.get_child_count()).is_equal(2)
	assert_bool(node.get_child(0) is MeshInstance3D).is_true()
	assert_bool(node.get_child(1) is StaticBody3D).is_true()


# ===========================================================================
# Tests: structure_destroyed removes instance
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
	# Should not crash when removing something that doesn't exist.
	_grid.structure_destroyed.emit(Vector2i(5, 5), ID_WALL)
	assert_int(_renderer.get_instance_count()).is_equal(0)


# ===========================================================================
# Tests: Multiple structures
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
# Tests: Correct mesh types per structure (visual distinction)
# ===========================================================================


func test_campfire_uses_cylinder_mesh() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_CAMPFIRE)
	var mesh_inst: MeshInstance3D = node.get_child(0) as MeshInstance3D
	assert_bool(mesh_inst.mesh is CylinderMesh).is_true()


func test_wall_uses_box_mesh() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	var mesh_inst: MeshInstance3D = node.get_child(0) as MeshInstance3D
	assert_bool(mesh_inst.mesh is BoxMesh).is_true()


func test_torch_uses_cylinder_mesh() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_TORCH)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_TORCH)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_TORCH)
	var mesh_inst: MeshInstance3D = node.get_child(0) as MeshInstance3D
	assert_bool(mesh_inst.mesh is CylinderMesh).is_true()


func test_workbench_uses_box_mesh() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WORKBENCH, Vector2i.ZERO,
		[Vector2i(0, 0), Vector2i(1, 0)])
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WORKBENCH)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WORKBENCH)
	var mesh_inst: MeshInstance3D = node.get_child(0) as MeshInstance3D
	assert_bool(mesh_inst.mesh is BoxMesh).is_true()


# ===========================================================================
# Tests: Material color matches PropDef
# ===========================================================================


func test_campfire_has_correct_color() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_CAMPFIRE)
	var mesh_inst: MeshInstance3D = node.get_child(0) as MeshInstance3D
	var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
	assert_bool(mat != null).is_true()
	# Campfire color: Color(0.9, 0.4, 0.1, 1.0)
	assert_float(mat.albedo_color.r).is_equal_approx(0.9, 0.01)
	assert_float(mat.albedo_color.g).is_equal_approx(0.4, 0.01)
	assert_float(mat.albedo_color.b).is_equal_approx(0.1, 0.01)


func test_wall_has_correct_color() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	var mesh_inst: MeshInstance3D = node.get_child(0) as MeshInstance3D
	var mat: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
	assert_bool(mat != null).is_true()
	# Wall color: Color(0.5, 0.4, 0.3, 1.0)
	assert_float(mat.albedo_color.r).is_equal_approx(0.5, 0.01)
	assert_float(mat.albedo_color.g).is_equal_approx(0.4, 0.01)
	assert_float(mat.albedo_color.b).is_equal_approx(0.3, 0.01)


# ===========================================================================
# Tests: Positioning — sub-hex offset
# ===========================================================================


func test_structure_at_sub_hex_has_offset_position() -> void:
	var tile := _make_tile()
	var sub_hex := Vector2i(1, -1)
	_add_structure_prop(tile, ID_TORCH, sub_hex)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_TORCH)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_TORCH)
	# Position should include sub-hex offset, not just tile center.
	var tile_center: Vector2 = _HexMath.axial_to_world(Vector2i.ZERO)
	var sub_offset: Vector2 = _HexMath.sub_axial_to_world(sub_hex)
	var expected_x: float = tile_center.x + sub_offset.x
	var expected_z: float = tile_center.y + sub_offset.y
	assert_float(node.position.x).is_equal_approx(expected_x, 0.01)
	assert_float(node.position.z).is_equal_approx(expected_z, 0.01)


func test_structure_at_tile_center_uses_tile_world_pos() -> void:
	var coords := Vector2i(2, 3)
	var tile := _make_tile(coords)
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(coords, tile)

	_grid.structure_placed.emit(coords, ID_CAMPFIRE)

	var node: Node3D = _renderer.get_instance(coords, ID_CAMPFIRE)
	var expected_2d: Vector2 = _HexMath.axial_to_world(coords)
	assert_float(node.position.x).is_equal_approx(expected_2d.x, 0.01)
	assert_float(node.position.z).is_equal_approx(expected_2d.y, 0.01)


# ===========================================================================
# Tests: Positioning — elevation
# ===========================================================================


func test_structure_at_elevated_tile_has_y_offset() -> void:
	_grid._terrain_y = 2.5
	var tile := _make_tile(Vector2i.ZERO, 5)
	_add_structure_prop(tile, ID_WALL)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WALL)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WALL)
	# Y should be terrain_y (2.5) + y_offset (size_y/2 = 0.3).
	assert_float(node.position.y).is_equal_approx(2.5 + 0.3, 0.01)


func test_structure_at_zero_elevation() -> void:
	_grid._terrain_y = 0.0
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_CAMPFIRE)
	# Campfire: cylinder height 0.15, y_offset = 0.075.
	assert_float(node.position.y).is_equal_approx(0.075, 0.01)


# ===========================================================================
# Tests: Multi-hex structures render at anchor position
# ===========================================================================


func test_workbench_renders_at_anchor_not_footprint_center() -> void:
	# Workbench has 2-hex footprint [(0,0), (1,0)] anchored at sub_hex (0,0).
	var tile := _make_tile()
	_add_structure_prop(tile, ID_WORKBENCH, Vector2i.ZERO,
		[Vector2i(0, 0), Vector2i(1, 0)])
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_WORKBENCH)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_WORKBENCH)
	# Anchor is at sub_hex (0,0), so position should be tile center.
	var tile_center: Vector2 = _HexMath.axial_to_world(Vector2i.ZERO)
	assert_float(node.position.x).is_equal_approx(tile_center.x, 0.01)
	assert_float(node.position.z).is_equal_approx(tile_center.y, 0.01)


func test_shelter_renders_at_anchor_position() -> void:
	# Shelter has 3-hex footprint [(0,0), (1,0), (0,1)].
	var tile := _make_tile()
	var anchor := Vector2i(1, 1)
	_add_structure_prop(tile, ID_SHELTER, anchor,
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)])
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_SHELTER)

	var node: Node3D = _renderer.get_instance(Vector2i.ZERO, ID_SHELTER)
	# Position at anchor sub_hex (1,1) offset.
	var tile_center: Vector2 = _HexMath.axial_to_world(Vector2i.ZERO)
	var sub_offset: Vector2 = _HexMath.sub_axial_to_world(anchor)
	assert_float(node.position.x).is_equal_approx(tile_center.x + sub_offset.x, 0.01)
	assert_float(node.position.z).is_equal_approx(tile_center.y + sub_offset.y, 0.01)


# ===========================================================================
# Tests: Signal-driven only (no per-frame queries)
# ===========================================================================


func test_no_instances_without_signals() -> void:
	# Even with tiles in the grid, no instances until signals are emitted.
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	# No signal emitted — should have zero instances.
	assert_int(_renderer.get_instance_count()).is_equal(0)


# ===========================================================================
# Tests: Idempotent placement
# ===========================================================================


func test_duplicate_placed_signal_replaces_instance() -> void:
	var tile := _make_tile()
	_add_structure_prop(tile, ID_CAMPFIRE)
	_grid.set_tile(Vector2i.ZERO, tile)

	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)
	_grid.structure_placed.emit(Vector2i.ZERO, ID_CAMPFIRE)

	# Should still have exactly 1 instance (replaced, not duplicated).
	assert_int(_renderer.get_instance_count()).is_equal(1)


# ===========================================================================
# Tests: Key format
# ===========================================================================


func test_key_format_includes_coords_and_type() -> void:
	var tile := _make_tile(Vector2i(3, -2))
	_add_structure_prop(tile, ID_TORCH)
	_grid.set_tile(Vector2i(3, -2), tile)

	_grid.structure_placed.emit(Vector2i(3, -2), ID_TORCH)

	var keys: Array = _renderer.get_all_keys()
	assert_int(keys.size()).is_equal(1)
	assert_str(keys[0]).is_equal("3,-2:P00103")


# ===========================================================================
# Tests: All 6 structure types render
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
