extends Node3D

## GroundItemRenderer — single MultiMeshInstance3D for ground item loot markers.
## Signal-driven: subscribes to SurvivalSystem ground_item_dropped/picked_up.
## Fog-aware: hidden if tile is HIDDEN, visible if REVEALED or VISIBLE.
## One draw call via single MultiMesh pool (~10 max instances).

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

# --- State ---

## The MultiMeshInstance3D child for loot markers.
var _mmi: MultiMeshInstance3D = null

## Per-tile tracking: coords → instance_idx.
var _tile_instances: Dictionary = {}

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
	mm.use_custom_data = false
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = mesh

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	_mmi.name = "GroundItemPool"

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.0)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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


# --- Signal handlers ---

func _on_ground_item_dropped(tile: Vector2i, _item_type: StringName, _count: int) -> void:
	# Add a marker if there isn't one already for this tile
	if _tile_instances.has(tile):
		return  # Marker already present
	_try_add_marker(tile)


func _on_ground_item_picked_up(tile: Vector2i, _item_type: StringName, _count: int) -> void:
	# Check if any items remain on this tile
	if _survival == null:
		return
	var remaining: Array = _survival.get_ground_items_at(tile)
	if remaining.is_empty():
		_remove_marker(tile)


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	match state:
		_HexTile.FogState.HIDDEN:
			_remove_marker(coords)
		_HexTile.FogState.REVEALED, _HexTile.FogState.VISIBLE:
			# Re-add marker if ground items exist on this tile
			if _survival != null and not _tile_instances.has(coords):
				var items: Array = _survival.get_ground_items_at(coords)
				if not items.is_empty():
					_add_instance(coords)


# --- Instance management ---

func _try_add_marker(tile: Vector2i) -> void:
	# Check fog state — don't add if HIDDEN
	if _grid != null:
		var hex_tile: Resource = _grid.get_tile(tile)
		if hex_tile != null and hex_tile.fog_state == _HexTile.FogState.HIDDEN:
			return
	_add_instance(tile)


func _add_instance(tile: Vector2i) -> void:
	if _tile_instances.has(tile):
		return
	var mm: MultiMesh = _mmi.multimesh
	var idx: int = mm.visible_instance_count
	if idx >= MAX_INSTANCES:
		return

	var world_2d: Vector2 = _HexMath.axial_to_world(tile)
	var elevation_y: float = 0.0
	if _grid != null:
		var hex_tile: Resource = _grid.get_tile(tile)
		if hex_tile != null:
			elevation_y = float(hex_tile.elevation) * 0.5
	var pos := Vector3(world_2d.x, elevation_y + MARKER_Y_OFFSET, world_2d.y)

	var xform := Transform3D.IDENTITY
	xform.origin = pos

	mm.visible_instance_count = idx + 1
	mm.set_instance_transform(idx, xform)

	_tile_instances[tile] = idx


func _remove_marker(tile: Vector2i) -> void:
	if not _tile_instances.has(tile):
		return
	var idx: int = _tile_instances[tile]
	_hide_instance(idx)
	_tile_instances.erase(tile)


func _hide_instance(instance_idx: int) -> void:
	var mm: MultiMesh = _mmi.multimesh
	if instance_idx >= mm.visible_instance_count:
		return
	var last_idx: int = mm.visible_instance_count - 1
	if instance_idx != last_idx:
		var last_xform: Transform3D = mm.get_instance_transform(last_idx)
		mm.set_instance_transform(instance_idx, last_xform)
		# Update the tile that pointed to last_idx
		_update_swapped_index(last_idx, instance_idx)
	mm.visible_instance_count = last_idx


func _update_swapped_index(old_idx: int, new_idx: int) -> void:
	for tile_key in _tile_instances:
		if _tile_instances[tile_key] == old_idx:
			_tile_instances[tile_key] = new_idx
			return


# --- Public API ---

func connect_survival(survival_system: Node) -> void:
	_survival = survival_system
	_connect_survival_signals()


func get_visible_count() -> int:
	return _mmi.multimesh.visible_instance_count


func get_tile_instances() -> Dictionary:
	return _tile_instances
