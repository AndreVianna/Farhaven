extends Node3D

## ScanProgressRenderer — single billboard progress bar above scan target.
## Uses a shader-based approach: one QuadMesh with a spatial shader that
## handles both billboard orientation and progress fill via UV coordinates.
## Only one scan at a time, so a single progress bar instance suffices.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _HexGrid = preload("res://scripts/hex/hex_grid.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")

# --- Constants ---

## Y offset above tile surface (slightly higher than icons)
const PROGRESS_Y_OFFSET: float = 3.5

## Bar dimensions
const BAR_WIDTH: float = 1.5
const BAR_HEIGHT: float = 0.2

# --- State ---

var _mesh_instance: MeshInstance3D = null
var _shader_material: ShaderMaterial = null
var _progress: float = 0.0
var _target_coords: Vector2i = Vector2i.ZERO
var _target_entry: StringName = &""
var _active: bool = false
var _scanner: Node = null
var _grid: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_create_bar()
	_hide_bar()
	_connect_signals.call_deferred()


func _create_bar() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	var shader := load("res://shaders/scan_progress.gdshader")
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("progress", 0.0)
	_shader_material.set_shader_parameter("fill_color", Color(0.2, 0.9, 0.4, 1.0))
	_shader_material.set_shader_parameter("bg_color", Color(0.2, 0.2, 0.2, 0.8))

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = quad
	_mesh_instance.material_override = _shader_material
	_mesh_instance.name = "ProgressBar"
	_mesh_instance.visible = false
	add_child(_mesh_instance)


func _connect_signals() -> void:
	if _scanner == null:
		_scanner = _find_scanner()
	if _scanner == null:
		return
	if _scanner.has_signal("scan_started"):
		if not _scanner.scan_started.is_connected(_on_scan_started):
			_scanner.scan_started.connect(_on_scan_started)
	if _scanner.has_signal("scan_progress_updated"):
		if not _scanner.scan_progress_updated.is_connected(_on_scan_progress_updated):
			_scanner.scan_progress_updated.connect(_on_scan_progress_updated)
	if _scanner.has_signal("scan_completed"):
		if not _scanner.scan_completed.is_connected(_on_scan_completed):
			_scanner.scan_completed.connect(_on_scan_completed)
	if _scanner.has_signal("scan_interrupted"):
		if not _scanner.scan_interrupted.is_connected(_on_scan_interrupted):
			_scanner.scan_interrupted.connect(_on_scan_interrupted)


func _find_scanner() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var player: Node = world.get_node_or_null("Player")
	if player == null:
		return null
	return player.get_node_or_null("ScannerSystem")


# --- Signal handlers ---

func _on_scan_started(entry_id: StringName, coords: Vector2i) -> void:
	_target_coords = coords
	_target_entry = entry_id
	_progress = 0.0
	_active = true
	_position_at(coords)
	_update_fill(0.0)
	_show_bar()


func _on_scan_progress_updated(progress: float) -> void:
	if not _active:
		return
	_progress = progress
	_update_fill(progress)


func _on_scan_completed(_entry_id: StringName) -> void:
	_hide_bar()
	_active = false
	_progress = 0.0


func _on_scan_interrupted() -> void:
	_hide_bar()
	_active = false
	_progress = 0.0


# --- Internal ---

func _position_at(coords: Vector2i) -> void:
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile = _grid.get_tile(coords) if _grid != null else null
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(world_2d.x, world_2d.y)
	elif tile != null:
		elevation_y = float(tile.elevation) * _HexGrid.ELEVATION_STEP
	# Scale the progress bar offset by the target prop's visual scale so
	# the bar tracks the scanned prop's size rather than floating at a
	# fixed world height regardless of what's being scanned.
	var visual_scale: float = _PropUtils.get_visual_scale(_target_entry)
	global_position = Vector3(world_2d.x, elevation_y + PROGRESS_Y_OFFSET * visual_scale, world_2d.y)


func _update_fill(progress_val: float) -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("progress", clampf(progress_val, 0.0, 1.0))


func _show_bar() -> void:
	if _mesh_instance != null:
		_mesh_instance.visible = true


func _hide_bar() -> void:
	if _mesh_instance != null:
		_mesh_instance.visible = false


# --- Public API (for testing) ---

func is_bar_visible() -> bool:
	return _active and _mesh_instance != null and _mesh_instance.visible


func get_progress() -> float:
	return _progress
