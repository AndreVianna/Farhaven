extends Node3D

## ScanProgressRenderer — diegetic scan feedback.
## Replaces the older billboard progress bar with a discreet OmniLight3D
## hovering above the prop being scanned. Light energy flickers gently
## while the scan is active and goes dark on complete/interrupt.
## No HUD chrome; no progress bar; no marker icons.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _HexGrid = preload("res://scripts/hex/hex_grid.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")

# --- Constants ---

## Y offset above tile surface for the light.
const LIGHT_Y_OFFSET: float = 1.5

## Light radius — large enough to read from a few tiles away while still
## not flooding the surrounding terrain.
const LIGHT_RANGE: float = 4.0

## Energy bounds for flicker. Tuned bright enough to be obviously the
## scanner glow even in daylight; still walks within a band so it never
## pegs to a single value.
const FLICKER_ENERGY_MIN: float = 2.5
const FLICKER_ENERGY_MAX: float = 4.5

## How long one flicker cycle takes (seconds). A small random jitter is
## added per cycle so it doesn't feel mechanical.
const FLICKER_PERIOD: float = 0.18

## Cool blue — reads as an active scanner beam.
const LIGHT_COLOR: Color = Color(0.35, 0.65, 1.0)

# --- State ---

var _light: OmniLight3D = null
var _target_coords: Vector2i = Vector2i.ZERO
var _target_entry: StringName = &""
var _active: bool = false
var _flicker_t: float = 0.0
var _flicker_period_jittered: float = FLICKER_PERIOD
var _scanner: Node = null
var _grid: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_create_light()
	_hide_light()
	_connect_signals.call_deferred()
	set_process(false)


func _create_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "ScanGlow"
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.5
	_light.shadow_enabled = false
	_light.light_energy = FLICKER_ENERGY_MIN
	_light.visible = false
	add_child(_light)


func _connect_signals() -> void:
	if _scanner == null:
		_scanner = _find_scanner()
	if _scanner == null:
		return
	if _scanner.has_signal("scan_started"):
		if not _scanner.scan_started.is_connected(_on_scan_started):
			_scanner.scan_started.connect(_on_scan_started)
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


# --- Process (flicker animation) ---

func _process(delta: float) -> void:
	if not _active or _light == null:
		return
	_flicker_t += delta
	if _flicker_t >= _flicker_period_jittered:
		_flicker_t = 0.0
		_flicker_period_jittered = FLICKER_PERIOD * randf_range(0.7, 1.4)
		# Random energy step inside the band — feels organic, never goes
		# fully dark mid-scan.
		_light.light_energy = randf_range(FLICKER_ENERGY_MIN, FLICKER_ENERGY_MAX)


# --- Signal handlers ---

func _on_scan_started(entry_id: StringName, coords: Vector2i) -> void:
	_target_coords = coords
	_target_entry = entry_id
	_active = true
	_flicker_t = 0.0
	_position_at(coords)
	_show_light()
	set_process(true)


func _on_scan_completed(_entry_id: StringName) -> void:
	_active = false
	_hide_light()
	set_process(false)


func _on_scan_interrupted() -> void:
	_active = false
	_hide_light()
	set_process(false)


# --- Internal ---

func _position_at(coords: Vector2i) -> void:
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile = _grid.get_tile(coords) if _grid != null else null
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(world_2d.x, world_2d.y)
	elif tile != null:
		elevation_y = float(tile.elevation) * _HexGrid.ELEVATION_STEP
	# Scale the offset by the target prop's visual scale so a tall tree
	# gets the glow above its canopy and a small pebble doesn't get one
	# floating awkwardly high.
	var visual_scale: float = _PropUtils.get_visual_scale(_target_entry)
	global_position = Vector3(world_2d.x, elevation_y + LIGHT_Y_OFFSET * visual_scale, world_2d.y)


func _show_light() -> void:
	if _light != null:
		_light.visible = true


func _hide_light() -> void:
	if _light != null:
		_light.visible = false


# --- Public API (for testing) ---

func is_active() -> bool:
	return _active


func get_target_coords() -> Vector2i:
	return _target_coords
