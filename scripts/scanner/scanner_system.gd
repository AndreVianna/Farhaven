extends Node
class_name ScannerSystem

## Scanner system — child of Player. Manages proximity auto-scan lifecycle,
## passive identification, and surprise encounter. Owns a Catalog instance.
##
## Proximity auto-scan: _process checks nearby tiles (player tile + 6 neighbors
## within SCAN_RANGE) for uncataloged props. Starts scan on nearest match.
## Progress advances while player stays in range. Interrupts immediately
## when player leaves range (no grace period). One scan at a time, nearest first.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")

# --- Scan duration per category (seconds) ---

const SCAN_DURATIONS: Dictionary = {
	_Catalog.CatalogCategory.FLORA:   2.0,
	_Catalog.CatalogCategory.MINERAL: 2.0,
	_Catalog.CatalogCategory.FAUNA:   3.0,
	_Catalog.CatalogCategory.ANOMALY: 3.0,
}

# --- Proximity scan constants ---

const SCAN_RANGE: int = 1  # hexes — adjacent only. Tunable.

# --- Signals ---

signal scan_started(entry_id: StringName, coords: Vector2i)
signal scan_progress_updated(progress: float)
signal scan_completed(entry_id: StringName)
signal scan_interrupted()

signal entry_cataloged(entry_id: StringName, category: int)
signal entry_encountered(entry_id: StringName, label: String)
signal knowledge_state_changed(entry_id: StringName, old_state: int, new_state: int)
signal surprise_cataloged(entry_id: StringName)

signal element_identified(coords: Vector2i, entry_id: StringName)
signal element_unknown(coords: Vector2i, entry_id: StringName, category: int)
signal element_encountered(coords: Vector2i, entry_id: StringName, label: String)

# --- Properties ---

var _catalog: RefCounted  # Catalog instance
var _is_scanning: bool = false
var _scan_target_coords: Vector2i = Vector2i.ZERO
var _scan_target_entry_id: StringName = &""
var _scan_progress: float = 0.0
var _scan_duration: float = 2.0

var _grid: Node  # HexGrid autoload
var _player: Node3D  # Parent Player node


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_player = get_parent()
	_catalog = _Catalog.new()
	_catalog.initialize(_grid, null)
	_connect_grid_signals()


func _connect_grid_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("tile_revealed"):
		_grid.tile_revealed.connect(_on_tile_revealed)
	if _grid.has_signal("tile_visibility_changed"):
		_grid.tile_visibility_changed.connect(_on_tile_visibility_changed)


# --- Process (proximity auto-scan) ---

func _process(delta: float) -> void:
	if _player == null or _grid == null:
		return

	var player_tile: Vector2i = _player.current_tile if "current_tile" in _player else Vector2i.ZERO

	if _is_scanning:
		# Check if player is still in range of current target
		var dist: int = _grid.distance(player_tile, _scan_target_coords)
		if dist > SCAN_RANGE:
			# Player left range — interrupt immediately, reset progress
			_is_scanning = false
			_scan_progress = 0.0
			scan_interrupted.emit()
			# Fall through to check for new nearby targets
		else:
			# Still in range — advance progress
			_scan_progress += delta / _scan_duration
			if _scan_progress >= 1.0:
				_scan_progress = 1.0
				_complete_scan()
				return  # Completed, will check for new targets next frame
			else:
				scan_progress_updated.emit(_scan_progress)
				return  # Don't start a new scan while one is active

	# Not scanning — check nearby tiles for scannable props
	var nearby_tiles: Array[Vector2i] = [player_tile]
	if _grid.has_method("get_neighbors"):
		var neighbors: Array[Vector2i] = _grid.get_neighbors(player_tile)
		for n in neighbors:
			nearby_tiles.append(n)

	# Filter to tiles within SCAN_RANGE and find nearest scannable prop
	var best_entry_id: StringName = &""
	var best_coords: Vector2i = Vector2i.ZERO
	var best_distance: int = 999

	for coords in nearby_tiles:
		var dist: int = _grid.distance(player_tile, coords)
		if dist > SCAN_RANGE:
			continue
		var entry_id: StringName = _catalog.get_scannable_at(coords)
		if entry_id != &"":
			if dist < best_distance:
				best_distance = dist
				best_entry_id = entry_id
				best_coords = coords

	if best_entry_id != &"":
		# Start proximity scan on nearest target
		_is_scanning = true
		_scan_target_coords = best_coords
		_scan_target_entry_id = best_entry_id
		_scan_progress = 0.0
		var entry = _catalog.get_entry(best_entry_id)
		var category: int = entry.category if entry != null else _Catalog.CatalogCategory.FLORA
		_scan_duration = SCAN_DURATIONS.get(category, 2.0)
		scan_started.emit(best_entry_id, best_coords)


# --- Scan lifecycle ---

func _complete_scan() -> void:
	var entry_id: StringName = _scan_target_entry_id
	_is_scanning = false
	_scan_progress = 0.0

	var old_state: int = _catalog.get_knowledge_state(entry_id)
	_catalog.catalog_entry(entry_id)

	var entry = _catalog.get_entry(entry_id)
	var category: int = entry.category if entry != null else _Catalog.CatalogCategory.FLORA

	scan_completed.emit(entry_id)
	entry_cataloged.emit(entry_id, category)
	knowledge_state_changed.emit(entry_id, old_state, _Catalog.KnowledgeState.CATALOGED)


# --- Surprise encounter (fauna first-hit, feature-010) ---

func on_fauna_attacked_player(_fauna_id, _damage, species_type: StringName) -> void:
	if _catalog.is_known(species_type):
		return
	if not _catalog._all_entries.has(species_type):
		return
	_catalog.encounter_entry(species_type, "Hostile")
	entry_encountered.emit(species_type, "Hostile")
	knowledge_state_changed.emit(species_type, _Catalog.KnowledgeState.UNKNOWN, _Catalog.KnowledgeState.ENCOUNTERED)
	surprise_cataloged.emit(species_type)


# --- Passive fauna flee (feature-010, deferred post-MVP) ---

func on_fauna_fled(_fauna_id, species_type: StringName) -> void:
	if _catalog.is_known(species_type):
		return
	if not _catalog._all_entries.has(species_type):
		return
	_catalog.encounter_entry(species_type, "Shy")
	entry_encountered.emit(species_type, "Shy")
	knowledge_state_changed.emit(species_type, _Catalog.KnowledgeState.UNKNOWN, _Catalog.KnowledgeState.ENCOUNTERED)


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
		var state: int = _catalog.get_knowledge_state(entry_id)
		match state:
			_Catalog.KnowledgeState.CATALOGED:
				element_identified.emit(coords, entry_id)
			_Catalog.KnowledgeState.ENCOUNTERED:
				var label: String = _catalog.get_encounter_label(entry_id)
				element_encountered.emit(coords, entry_id, label)
			_Catalog.KnowledgeState.UNKNOWN:
				var entry = _catalog.get_entry(entry_id)
				var cat: int = entry.category if entry != null else _Catalog.CatalogCategory.FLORA
				element_unknown.emit(coords, entry_id, cat)

	# Check anomaly
	if tile.anomaly != &"":
		var anomaly_id: StringName = tile.anomaly
		var state: int = _catalog.get_knowledge_state(anomaly_id)
		match state:
			_Catalog.KnowledgeState.CATALOGED:
				element_identified.emit(coords, anomaly_id)
			_:
				element_unknown.emit(coords, anomaly_id, _Catalog.CatalogCategory.ANOMALY)


# --- Public accessors ---

func get_catalog() -> RefCounted:
	return _catalog


func is_scanning() -> bool:
	return _is_scanning


func get_scan_progress() -> float:
	return _scan_progress
