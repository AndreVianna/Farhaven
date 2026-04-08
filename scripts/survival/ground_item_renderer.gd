extends Node3D

## GroundItemRenderer — per-item-type colored markers at sub-hex positions.
## Signal-driven: subscribes to SurvivalSystem ground_item_dropped/picked_up.
## Fog-aware: hidden if tile is HIDDEN, visible if VISIBLE.
## Uses per-instance custom_data for color. One MultiMesh, multiple colors.

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

## Max instances for the MultiMesh pool.
const MAX_INSTANCES: int = 10

## Y offset above tile surface for loot markers.
const MARKER_Y_OFFSET: float = 0.15

## Marker mesh radius.
const MARKER_RADIUS: float = 0.4

## Marker mesh height (thin disc).
const MARKER_HEIGHT: float = 0.05

## Default color for items with no PropDef.
const DEFAULT_COLOR: Color = Color(1.0, 0.85, 0.0)

# --- State ---

## The MultiMeshInstance3D child for loot markers.
var _mmi: MultiMeshInstance3D = null

## Per-item tracking: marker_key (String) → instance_idx.
## Key format: "tile_x,tile_y,sub_q,sub_r,item_type"
var _marker_instances: Dictionary = {}

## Reference to HexGrid (allows override in tests).
var _grid: Node = null

## Reference to SurvivalSystem (allows override in tests).
var _survival: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = get_node_or_null("/root/HexGrid")
	_create_pool()
	_connect_signals()


func _create_pool() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = MARKER_RADIUS
	mesh.bottom_radius = MARKER_RADIUS
	mesh.height = MARKER_HEIGHT
	mesh.radial_segments = 12
	mesh.rings = 0

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = mesh

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	_mmi.name = "GroundItemPool"

	# Shader material that reads per-instance custom data as color
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
void vertex() {
	COLOR = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_mmi.material_override = mat

	add_child(_mmi)


func _connect_signals() -> void:
	if _survival != null:
		_connect_survival_signals()
	if _grid != null:
		_connect_grid_signals()


func _connect_survival_signals() -> void:
	if _survival == null:
		return
	if _survival.has_signal("ground_item_dropped"):
		if not _survival.ground_item_dropped.is_connected(_on_ground_item_dropped):
			_survival.ground_item_dropped.connect(_on_ground_item_dropped)
	if _survival.has_signal("ground_item_picked_up"):
		if not _survival.ground_item_picked_up.is_connected(_on_ground_item_picked_up):
			_survival.ground_item_picked_up.connect(_on_ground_item_picked_up)


func _connect_grid_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("tile_visibility_changed"):
		if not _grid.tile_visibility_changed.is_connected(_on_tile_visibility_changed):
			_grid.tile_visibility_changed.connect(_on_tile_visibility_changed)


# --- Key helpers ---

static func _make_key(tile: Vector2i, sub_hex: Vector2i, item_type: StringName) -> String:
	return "%d,%d,%d,%d,%s" % [tile.x, tile.y, sub_hex.x, sub_hex.y, String(item_type)]


static func _key_starts_with_tile(key: String, tile: Vector2i) -> bool:
	return key.begins_with("%d,%d," % [tile.x, tile.y])


# --- Signal handlers ---

func _on_ground_item_dropped(tile: Vector2i, item_type: StringName, _count: int, sub_hex: Vector2i) -> void:
	var key: String = _make_key(tile, sub_hex, item_type)
	if _marker_instances.has(key):
		return  # Marker already present
	_try_add_marker(tile, sub_hex, item_type)


func _on_ground_item_picked_up(tile: Vector2i, _item_type: StringName, _count: int) -> void:
	# Check if any items remain on this tile and rebuild markers
	if _survival == null:
		return
	var remaining: Array = _survival.get_ground_items_at(tile)
	# Build set of keys that should exist
	var expected_keys: Dictionary = {}
	for entry: Dictionary in remaining:
		var sub_hex: Vector2i = entry.get("sub_hex", Vector2i.ZERO)
		var itype: StringName = entry.get("item_type", &"")
		if itype != &"":
			expected_keys[_make_key(tile, sub_hex, itype)] = true

	# Remove markers that no longer have items
	var keys_to_remove: Array = []
	for key: String in _marker_instances:
		if _key_starts_with_tile(key, tile) and not expected_keys.has(key):
			keys_to_remove.append(key)
	for key: String in keys_to_remove:
		_remove_marker_by_key(key)


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	match state:
		_HexTile.FogState.HIDDEN:
			_remove_markers_for_tile(coords)
		_HexTile.FogState.VISIBLE:
			# Re-add markers if ground items exist on this tile
			if _survival != null:
				var items: Array = _survival.get_ground_items_at(coords)
				for entry: Dictionary in items:
					var sub_hex: Vector2i = entry.get("sub_hex", Vector2i.ZERO)
					var itype: StringName = entry.get("item_type", &"")
					if itype != &"":
						var key: String = _make_key(coords, sub_hex, itype)
						if not _marker_instances.has(key):
							_add_instance(coords, sub_hex, itype)


# --- Instance management ---

func _try_add_marker(tile: Vector2i, sub_hex: Vector2i, item_type: StringName) -> void:
	# Check fog state — don't add if HIDDEN
	if _grid != null:
		var hex_tile: Resource = _grid.get_tile(tile)
		if hex_tile != null and hex_tile.fog_state == _HexTile.FogState.HIDDEN:
			return
	_add_instance(tile, sub_hex, item_type)


func _add_instance(tile: Vector2i, sub_hex: Vector2i, item_type: StringName) -> void:
	var key: String = _make_key(tile, sub_hex, item_type)
	if _marker_instances.has(key):
		return
	var mm: MultiMesh = _mmi.multimesh
	var idx: int = mm.visible_instance_count
	if idx >= MAX_INSTANCES:
		return

	# World position at sub-hex within the tile
	var world_2d: Vector2 = _HexMath.prop_world_position(tile, sub_hex)
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(world_2d.x, world_2d.y)
	var pos := Vector3(world_2d.x, elevation_y + MARKER_Y_OFFSET, world_2d.y)

	var xform := Transform3D.IDENTITY
	xform.origin = pos

	mm.visible_instance_count = idx + 1
	mm.set_instance_transform(idx, xform)

	# Set per-instance color via custom data
	var def: PropDef = PropRegistry.get_def(item_type)
	var color: Color = def.placeholder_color if def != null else DEFAULT_COLOR
	color.a = 0.8
	mm.set_instance_custom_data(idx, color)

	_marker_instances[key] = idx


func _remove_marker_by_key(key: String) -> void:
	if not _marker_instances.has(key):
		return
	var idx: int = _marker_instances[key]
	_hide_instance(idx)
	_marker_instances.erase(key)


func _remove_markers_for_tile(tile: Vector2i) -> void:
	var keys_to_remove: Array = []
	for key: String in _marker_instances:
		if _key_starts_with_tile(key, tile):
			keys_to_remove.append(key)
	for key: String in keys_to_remove:
		_remove_marker_by_key(key)


func _hide_instance(instance_idx: int) -> void:
	var mm: MultiMesh = _mmi.multimesh
	if instance_idx >= mm.visible_instance_count:
		return
	var last_idx: int = mm.visible_instance_count - 1
	if instance_idx != last_idx:
		var last_xform: Transform3D = mm.get_instance_transform(last_idx)
		var last_custom: Color = mm.get_instance_custom_data(last_idx)
		mm.set_instance_transform(instance_idx, last_xform)
		mm.set_instance_custom_data(instance_idx, last_custom)
		# Update the key that pointed to last_idx
		_update_swapped_index(last_idx, instance_idx)
	mm.visible_instance_count = last_idx


func _update_swapped_index(old_idx: int, new_idx: int) -> void:
	for key: String in _marker_instances:
		if _marker_instances[key] == old_idx:
			_marker_instances[key] = new_idx
			return


# --- Public API ---

func connect_survival(survival_system: Node) -> void:
	_survival = survival_system
	_connect_survival_signals()


func get_visible_count() -> int:
	return _mmi.multimesh.visible_instance_count


func get_tile_instances() -> Dictionary:
	return _marker_instances
