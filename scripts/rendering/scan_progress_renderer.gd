extends Node3D

## ScanProgressRenderer — single billboard progress bar above scan target.
## Shows/hides on scan lifecycle signals from ScannerSystem.
## Only one scan at a time, so a single progress bar instance suffices.

const _HexMath = preload("res://scripts/hex/hex_math.gd")

# --- Constants ---

## Y offset above tile surface (slightly higher than icons)
const PROGRESS_Y_OFFSET: float = 3.5

## Bar dimensions
const BAR_WIDTH: float = 1.5
const BAR_HEIGHT: float = 0.2
const BAR_BG_COLOR: Color = Color(0.2, 0.2, 0.2, 0.8)
const BAR_FILL_COLOR: Color = Color(0.2, 0.9, 0.4, 1.0)

# --- State ---

var _bg_mesh_instance: MeshInstance3D = null
var _fill_mesh_instance: MeshInstance3D = null
var _progress: float = 0.0
var _target_coords: Vector2i = Vector2i.ZERO
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
	# Background bar (full width, dark)
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = BAR_BG_COLOR
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true

	_bg_mesh_instance = MeshInstance3D.new()
	_bg_mesh_instance.mesh = bg_mesh
	_bg_mesh_instance.material_override = bg_mat
	_bg_mesh_instance.name = "ProgressBG"
	add_child(_bg_mesh_instance)

	# Fill bar (scales with progress)
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = BAR_FILL_COLOR
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.no_depth_test = true

	_fill_mesh_instance = MeshInstance3D.new()
	_fill_mesh_instance.mesh = fill_mesh
	_fill_mesh_instance.material_override = fill_mat
	_fill_mesh_instance.name = "ProgressFill"
	add_child(_fill_mesh_instance)


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

func _on_scan_started(_entry_id: StringName, coords: Vector2i) -> void:
	_target_coords = coords
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
	if tile != null:
		elevation_y = float(tile.elevation) * 0.5
	global_position = Vector3(world_2d.x, elevation_y + PROGRESS_Y_OFFSET, world_2d.y)


func _update_fill(progress: float) -> void:
	if _fill_mesh_instance == null:
		return
	# Scale the fill bar width based on progress (0.0 to 1.0)
	# Offset so it grows from left to right
	var fill_width: float = BAR_WIDTH * clampf(progress, 0.0, 1.0)
	var offset_x: float = (fill_width - BAR_WIDTH) * 0.5
	_fill_mesh_instance.scale = Vector3(clampf(progress, 0.001, 1.0), 1.0, 1.0)
	_fill_mesh_instance.position = Vector3(offset_x, 0.0, 0.0)


func _show_bar() -> void:
	if _bg_mesh_instance != null:
		_bg_mesh_instance.visible = true
	if _fill_mesh_instance != null:
		_fill_mesh_instance.visible = true


func _hide_bar() -> void:
	if _bg_mesh_instance != null:
		_bg_mesh_instance.visible = false
	if _fill_mesh_instance != null:
		_fill_mesh_instance.visible = false


# --- Public API (for testing) ---

func is_bar_visible() -> bool:
	return _active and _bg_mesh_instance != null and _bg_mesh_instance.visible


func get_progress() -> float:
	return _progress
