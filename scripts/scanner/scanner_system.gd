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


# --- Process (proximity auto-scan) ---

func _process(delta: float) -> void:
	if _player == null or _grid == null:
		return
	var player_tile: Vector2i = _player.current_tile
	if _is_scanning:
		if _update_active_scan(player_tile, delta):
			return  # Still scanning or just completed
	_start_nearest_scan(player_tile)


func _update_active_scan(player_tile: Vector2i, delta: float) -> bool:
	var dist: int = _grid.distance(player_tile, _scan_target_coords)
	if dist > SCAN_RANGE:
		_is_scanning = false
		_scan_progress = 0.0
		# Stop scanning drain on interrupt
		var survival_int: Node = _get_survival_system()
		if survival_int and survival_int.has_method("stop_activity_drain"):
			survival_int.stop_activity_drain(&"scanning")
		scan_interrupted.emit()
		return false  # Interrupted, check for new target
	_scan_progress += delta / _scan_duration
	if _scan_progress >= 1.0:
		_scan_progress = 1.0
		_complete_scan()
		return true  # Completed, check next frame
	scan_progress_updated.emit(_scan_progress)
	return true  # Still in progress


func _start_nearest_scan(player_tile: Vector2i) -> void:
	var nearby_tiles: Array[Vector2i] = [player_tile]
	if _grid.has_method("get_neighbors"):
		var neighbors: Array[Vector2i] = _grid.get_neighbors(player_tile)
		for n in neighbors:
			nearby_tiles.append(n)
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
		_is_scanning = true
		_scan_target_coords = best_coords
		_scan_target_entry_id = best_entry_id
		_scan_progress = 0.0
		var entry = _catalog.get_entry(best_entry_id)
		var category: int = entry.category if entry != null else _Catalog.CatalogCategory.FLORA
		_scan_duration = SCAN_DURATIONS.get(category, 2.0)
		# Apply scanning survival cost + start drain
		var survival: Node = _get_survival_system()
		if survival:
			if survival.has_method("apply_activity_cost"):
				survival.apply_activity_cost(&"scanning")
			if survival.has_method("start_activity_drain"):
				survival.start_activity_drain(&"scanning")
		scan_started.emit(best_entry_id, best_coords)


# --- Scan lifecycle ---

func _complete_scan() -> void:
	var entry_id: StringName = _scan_target_entry_id
	_is_scanning = false
	_scan_progress = 0.0

	# Stop scanning drain on completion
	var survival: Node = _get_survival_system()
	if survival and survival.has_method("stop_activity_drain"):
		survival.stop_activity_drain(&"scanning")

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
	if not _catalog.has_entry(species_type):
		return
	_catalog.encounter_entry(species_type, "Hostile")
	entry_encountered.emit(species_type, "Hostile")
	knowledge_state_changed.emit(species_type, _Catalog.KnowledgeState.UNKNOWN, _Catalog.KnowledgeState.ENCOUNTERED)
	surprise_cataloged.emit(species_type)


# --- Passive fauna flee (feature-010, deferred post-MVP) ---

func on_fauna_fled(_fauna_id, species_type: StringName) -> void:
	if _catalog.is_known(species_type):
		return
	if not _catalog.has_entry(species_type):
		return
	_catalog.encounter_entry(species_type, "Shy")
	entry_encountered.emit(species_type, "Shy")
	knowledge_state_changed.emit(species_type, _Catalog.KnowledgeState.UNKNOWN, _Catalog.KnowledgeState.ENCOUNTERED)


# --- Passive identification ---

func _check_passive_identification(coords: Vector2i) -> void:
	if _grid == null:
		return
	var tile = _grid.get_tile(coords)
	if tile == null:
		return

	for prop in tile.get_props():
		if not PropRegistry.has_def(prop.type):
			continue
		var def = PropRegistry.get_def(prop.type)
		if def.catalogable == null or String(def.catalogable.display_name) == "":
			continue
		var entry_id: StringName = def.id
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
	for prop in tile.get_anomalies():
		var anomaly_id: StringName = prop.type
		var state: int = _catalog.get_knowledge_state(anomaly_id)
		match state:
			_Catalog.KnowledgeState.CATALOGED:
				element_identified.emit(coords, anomaly_id)
			_:
				element_unknown.emit(coords, anomaly_id, _Catalog.CatalogCategory.ANOMALY)


# --- Survival System Helper ---


func _get_survival_system() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child != self and child.has_method("apply_activity_cost"):
			return child
	return null


# --- Public accessors ---

func get_catalog() -> RefCounted:
	return _catalog


func is_scanning() -> bool:
	return _is_scanning


func get_scan_progress() -> float:
	return _scan_progress


## Bootstrap: check passive identification for all currently visible tiles.
## Called by Main after map load to populate initial tile props/labels.
func bootstrap_visible() -> void:
	if _grid == null:
		return
	var all_tiles: Dictionary = _grid.get_all_tiles() if _grid.has_method("get_all_tiles") else {}
	for coords in all_tiles:
		var tile = all_tiles[coords]
		if tile != null:
			_check_passive_identification(coords)


# --- Serialization (delegates to Catalog) ---

func get_save_data() -> Dictionary:
	if _catalog != null:
		return {"catalog": _catalog.get_save_data()}
	return {}


func load_save_data(data: Dictionary) -> void:
	if _catalog != null and data.has("catalog"):
		_catalog.load_save_data(data["catalog"])
