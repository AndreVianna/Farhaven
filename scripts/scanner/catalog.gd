class_name Catalog
extends RefCounted

const CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")

enum CatalogCategory { FLORA, FAUNA, MINERAL, ANOMALY }

signal entry_cataloged(entry_id: StringName, category: int)

const RESOURCE_TO_ENTRY: Dictionary = {
	&"wood":          &"wood_tree",
	&"berries":       &"berry_bush",
	&"toxic_berries": &"toxic_berry_bush",
	&"fiber":         &"fiber_grass",
	&"stone":         &"stone_deposit",
	&"ore":           &"iron_deposit",
	&"crystal":       &"crystal_cluster",
}

var _discovered: Dictionary = {}      # StringName → bool
var _all_entries: Dictionary = {}     # StringName → CatalogEntry
var _total_count: int = 0
var _hex_grid = null
var _fauna_manager = null


func initialize(hex_grid = null, fauna_manager = null) -> void:
	_hex_grid = hex_grid
	_fauna_manager = fauna_manager
	_load_all_entries()


func _load_all_entries() -> void:
	var paths: Array = [
		"res://data/catalog/flora.tres",
		"res://data/catalog/fauna.tres",
		"res://data/catalog/minerals.tres",
		"res://data/catalog/anomalies.tres",
	]
	for path in paths:
		var data = load(path)
		if data == null:
			continue
		for entry in data.entries:
			_all_entries[entry.entry_id] = entry
	_total_count = _all_entries.size()


# --- Query API ---

func is_cataloged(entry_id: StringName) -> bool:
	return _discovered.get(entry_id, false)


func get_entry(entry_id: StringName) -> CatalogEntry:
	return _all_entries.get(entry_id, null)


func get_discovered_entries() -> Array:
	var result: Array = []
	for id in _discovered:
		if _all_entries.has(id):
			result.append(_all_entries[id])
	return result


func get_discovered_by_category(category: int) -> Array:
	var result: Array = []
	for id in _discovered:
		var entry: CatalogEntry = _all_entries.get(id, null)
		if entry != null and entry.category == category:
			result.append(entry)
	return result


func get_discovery_count() -> int:
	return _discovered.size()


func get_total_count() -> int:
	return _total_count


func get_discovery_text() -> String:
	var count: int = get_discovery_count()
	if count == 1:
		return "1 entry"
	return "%d entries" % count


# --- Mutation ---

func catalog_entry(entry_id: StringName) -> void:
	if _discovered.get(entry_id, false):
		return
	_discovered[entry_id] = true
	var entry: CatalogEntry = _all_entries.get(entry_id, null)
	var category: int = entry.category if entry != null else CatalogCategory.FLORA
	entry_cataloged.emit(entry_id, category)


# --- Eligibility ---

func get_scannable_at(coords: Vector2i) -> StringName:
	if _hex_grid == null:
		return &""
	var tile = _hex_grid.get_tile(coords)
	if tile == null:
		return &""

	# Check resource nodes (flora + mineral)
	for node in tile.resource_nodes:
		var entry_id: StringName = RESOURCE_TO_ENTRY.get(node.type, &"")
		if entry_id == &"":
			continue
		if not is_cataloged(entry_id) and _all_entries.has(entry_id):
			return entry_id

	# Check anomaly
	if tile.anomaly != &"":
		var anomaly_id: StringName = tile.anomaly
		if not is_cataloged(anomaly_id) and _all_entries.has(anomaly_id):
			return anomaly_id

	# Fauna handled by ScannerSystem via FaunaManager; not queried here at data layer

	return &""


# --- Save / Load ---

func get_save_data() -> Dictionary:
	return {"discovered": _discovered.keys()}


func load_save_data(data: Dictionary) -> void:
	_discovered.clear()
	for id in data.get("discovered", []):
		_discovered[StringName(id)] = true
