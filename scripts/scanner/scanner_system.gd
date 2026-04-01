extends Node
class_name ScannerSystem

## Scanner system — child of Player. Manages scan lifecycle, passive
## identification, and surprise catalog. Owns a Catalog instance.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")

# --- Enums ---

enum ScanState { IDLE, SCANNING, COMPLETE, REJECTED }

# --- Scan duration per category (seconds) ---

const SCAN_DURATIONS: Dictionary = {
	_Catalog.CatalogCategory.FLORA:   2.0,
	_Catalog.CatalogCategory.MINERAL: 2.0,
	_Catalog.CatalogCategory.FAUNA:   3.0,
	_Catalog.CatalogCategory.ANOMALY: 3.0,
}

# --- Signals ---

signal scan_started(entry_id: StringName, coords: Vector2i)
signal scan_progress_updated(progress: float)
signal scan_completed(entry_id: StringName)
signal scan_cancelled()
signal scan_rejected(coords: Vector2i)

signal entry_cataloged(entry_id: StringName, category: int)
signal surprise_cataloged(entry_id: StringName)

signal element_identified(coords: Vector2i, entry_id: StringName)
signal element_unknown(coords: Vector2i)

# --- Properties ---

var _catalog: RefCounted  # Catalog instance
var _scan_state: int = ScanState.IDLE
var _scan_target_coords: Vector2i = Vector2i.ZERO
var _scan_target_entry_id: StringName = &""
var _scan_progress: float = 0.0
var _scan_duration: float = 2.0
var _scan_range: int = 2  # max hex distance

var _grid: Node  # HexGrid autoload
var _player: Node3D  # Parent Player node
var _player_input: Node  # PlayerInput sibling
var _camera: Camera3D  # Camera3D for screen→world projection (drift check)


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_player = get_parent()
	_catalog = _Catalog.new()
	_catalog.initialize(_grid, null)
	_connect_player_input()
	_connect_grid_signals()
	# Camera is a sibling of Player in World
	var world: Node = _player.get_parent() if _player != null else null
	if world != null:
		_camera = world.get_node_or_null("Camera3D") as Camera3D


func _connect_player_input() -> void:
	if _player == null:
		return
	_player_input = _player.get_node_or_null("PlayerInput")
	if _player_input == null:
		return
	if _player_input.has_signal("scan_hold_started"):
		_player_input.scan_hold_started.connect(_on_scan_hold_started)
	if _player_input.has_signal("scan_hold_ended"):
		_player_input.scan_hold_ended.connect(_on_scan_hold_ended)
	if _player_input.has_signal("scan_hold_update"):
		_player_input.scan_hold_update.connect(_on_scan_hold_update)


func _connect_grid_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("tile_revealed"):
		_grid.tile_revealed.connect(_on_tile_revealed)
	if _grid.has_signal("tile_visibility_changed"):
		_grid.tile_visibility_changed.connect(_on_tile_visibility_changed)


# --- Process (scan progress tick) ---

func _process(delta: float) -> void:
	if _scan_state != ScanState.SCANNING:
		return

	# Range check: cancel if player moved too far from target
	if _player != null and _grid != null:
		var player_tile: Vector2i = _player.current_tile if "current_tile" in _player else Vector2i.ZERO
		var dist: int = _grid.distance(player_tile, _scan_target_coords)
		if dist > _scan_range:
			_cancel_scan()
			return

	# Progress tick
	_scan_progress += delta / _scan_duration
	if _scan_progress >= 1.0:
		_scan_progress = 1.0
		_complete_scan()
	else:
		scan_progress_updated.emit(_scan_progress)


# --- Scan hold handlers (from PlayerInput) ---

func _on_scan_hold_started(coords: Vector2i) -> void:
	if _scan_state == ScanState.SCANNING:
		# Never emit scan_rejected while scanning
		return

	var entry_id: StringName = _catalog.get_scannable_at(coords)
	if entry_id == &"":
		_scan_state = ScanState.REJECTED
		scan_rejected.emit(coords)
		_scan_state = ScanState.IDLE
		return

	# Look up entry to determine duration
	var entry = _catalog.get_entry(entry_id)
	var category: int = entry.category if entry != null else _Catalog.CatalogCategory.FLORA
	_scan_duration = SCAN_DURATIONS.get(category, 2.0)

	_scan_target_coords = coords
	_scan_target_entry_id = entry_id
	_scan_progress = 0.0
	_scan_state = ScanState.SCANNING
	scan_started.emit(entry_id, coords)


func _on_scan_hold_ended() -> void:
	if _scan_state == ScanState.SCANNING and _scan_progress < 1.0:
		_cancel_scan()


func _on_scan_hold_update(screen_pos: Vector2) -> void:
	if _scan_state != ScanState.SCANNING:
		return
	if _camera == null or _grid == null:
		return
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if abs(ray_dir.y) < 0.0001:
		return
	var t: float = -ray_origin.y / ray_dir.y
	var world_3d: Vector3 = ray_origin + ray_dir * t
	var coords: Vector2i = _grid.world_to_axial(Vector2(world_3d.x, world_3d.z))
	if coords != _scan_target_coords:
		_cancel_scan()


# --- Scan lifecycle ---

func _complete_scan() -> void:
	_scan_state = ScanState.COMPLETE
	_catalog.catalog_entry(_scan_target_entry_id)

	var entry = _catalog.get_entry(_scan_target_entry_id)
	var category: int = entry.category if entry != null else _Catalog.CatalogCategory.FLORA

	scan_completed.emit(_scan_target_entry_id)
	entry_cataloged.emit(_scan_target_entry_id, category)

	_scan_state = ScanState.IDLE
	_scan_progress = 0.0


func _cancel_scan() -> void:
	_scan_state = ScanState.IDLE
	_scan_progress = 0.0
	scan_cancelled.emit()


# --- Surprise catalog (fauna first-hit, feature-010) ---

func on_fauna_attacked_player(_fauna_id, _damage, species_type: StringName) -> void:
	if _catalog.is_cataloged(species_type):
		return
	if not _catalog._all_entries.has(species_type):
		return
	_catalog.catalog_entry(species_type)
	surprise_cataloged.emit(species_type)
	entry_cataloged.emit(species_type, _Catalog.CatalogCategory.FAUNA)


# --- Passive identification (on tile reveal/visibility change) ---

func _on_tile_revealed(coords: Vector2i) -> void:
	_check_passive_identification(coords)


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	if state == _HexTile.FogState.VISIBLE:
		_check_passive_identification(coords)


func _check_passive_identification(coords: Vector2i) -> void:
	if _grid == null:
		return
	var tile = _grid.get_tile(coords)
	if tile == null:
		return

	# Check resource nodes (flora + mineral)
	for node in tile.resource_nodes:
		var entry_id: StringName = _Catalog.RESOURCE_TO_ENTRY.get(node.type, &"")
		if entry_id == &"":
			continue
		if _catalog.is_cataloged(entry_id):
			element_identified.emit(coords, entry_id)
		else:
			element_unknown.emit(coords)

	# Check anomaly
	if tile.anomaly != &"":
		if _catalog.is_cataloged(tile.anomaly):
			element_identified.emit(coords, tile.anomaly)
		else:
			element_unknown.emit(coords)


# --- Public accessors ---

func get_catalog() -> RefCounted:
	return _catalog


func get_scan_state() -> int:
	return _scan_state


func get_scan_progress() -> float:
	return _scan_progress
