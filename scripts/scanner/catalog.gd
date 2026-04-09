class_name Catalog
extends RefCounted

const CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")
# TODO: remove CatalogEntry import when fauna PropDefs exist
const CatalogEntry = preload("res://scripts/scanner/catalog_entry.gd")

enum CatalogCategory { FLORA, FAUNA, MINERAL, ANOMALY }
enum KnowledgeState { UNKNOWN, ENCOUNTERED, CATALOGED }

signal entry_cataloged(entry_id: StringName, category: int)
signal entry_encountered(entry_id: StringName, label: String)
signal knowledge_state_changed(entry_id: StringName, old_state: int, new_state: int)

var _knowledge: Dictionary = {}           # StringName → KnowledgeState
var _encounter_labels: Dictionary = {}    # StringName → String ("Hostile" or "Shy")
var _all_entries: Dictionary = {}         # StringName → CatalogableCap (or CatalogEntry for fauna fallback)
var _total_count: int = 0
var _hex_grid = null
var _fauna_manager = null


func initialize(hex_grid = null, fauna_manager = null) -> void:
	_hex_grid = hex_grid
	_fauna_manager = fauna_manager
	_load_all_entries()


func _load_all_entries() -> void:
	# Load from PropRegistry — all PropDefs with CATALOGABLE capability and non-empty display_name
	for def in PropRegistry.get_all():
		if def.catalogable != null and String(def.catalogable.display_name) != "":
			var entry_id: StringName = def.id  # Use PropDef id directly
			_all_entries[entry_id] = def.catalogable  # Store CatalogableCap directly

	# TODO: remove when fauna PropDefs exist — fauna fallback from .tres file
	var fauna_data = load("res://data/catalog/fauna.tres")
	if fauna_data != null:
		for entry in fauna_data.entries:
			_all_entries[entry.entry_id] = entry

	_total_count = _all_entries.size()


# --- Query API ---

func get_knowledge_state(entry_id: StringName) -> int:
	return _knowledge.get(entry_id, KnowledgeState.UNKNOWN)


func is_cataloged(entry_id: StringName) -> bool:
	return get_knowledge_state(entry_id) == KnowledgeState.CATALOGED


func is_encountered(entry_id: StringName) -> bool:
	return get_knowledge_state(entry_id) == KnowledgeState.ENCOUNTERED


func is_known(entry_id: StringName) -> bool:
	return get_knowledge_state(entry_id) >= KnowledgeState.ENCOUNTERED


func get_entry(entry_id: StringName):
	return _all_entries.get(entry_id, null)


## Returns true if an entry with the given id exists in the catalog data.
func has_entry(entry_id: StringName) -> bool:
	return _all_entries.has(entry_id)


func get_discovered_entries() -> Array:
	var result: Array = []
	for id in _knowledge:
		if _knowledge[id] >= KnowledgeState.ENCOUNTERED and _all_entries.has(id):
			result.append({entry_id = id, entry = _all_entries[id]})
	return result


func get_discovered_by_category(category: int) -> Array:
	var result: Array = []
	for id in _knowledge:
		if _knowledge[id] < KnowledgeState.ENCOUNTERED:
			continue
		var entry = _all_entries.get(id, null)
		if entry != null and entry.category == category:
			result.append({entry_id = id, entry = entry})
	return result


func get_discovery_count() -> int:
	var count: int = 0
	for id in _knowledge:
		if _knowledge[id] >= KnowledgeState.ENCOUNTERED:
			count += 1
	return count


func get_total_count() -> int:
	return _total_count


func get_discovery_text() -> String:
	var count: int = get_discovery_count()
	if count == 1:
		return "1 entry"
	return "%d entries" % count


func get_encounter_label(entry_id: StringName) -> String:
	return _encounter_labels.get(entry_id, "")


# --- Mutation ---

func catalog_entry(entry_id: StringName) -> void:
	var old_state: int = get_knowledge_state(entry_id)
	if old_state == KnowledgeState.CATALOGED:
		return
	_knowledge[entry_id] = KnowledgeState.CATALOGED
	# Remove encounter label if upgrading from ENCOUNTERED
	_encounter_labels.erase(entry_id)
	var entry = _all_entries.get(entry_id, null)
	var category: int = entry.category if entry != null else CatalogCategory.FLORA
	entry_cataloged.emit(entry_id, category)
	knowledge_state_changed.emit(entry_id, old_state, KnowledgeState.CATALOGED)


func encounter_entry(entry_id: StringName, label: String) -> void:
	var entry = get_entry(entry_id)
	if entry == null:
		push_warning("encounter_entry called for unknown entry: %s" % entry_id)
		return
	# Guard: only fauna can enter ENCOUNTERED state (flora/mineral are static)
	if entry.category != CatalogCategory.FAUNA:
		push_warning("encounter_entry called for non-fauna entry: %s" % entry_id)
		return
	var old_state: int = get_knowledge_state(entry_id)
	if old_state >= KnowledgeState.ENCOUNTERED:
		return
	_knowledge[entry_id] = KnowledgeState.ENCOUNTERED
	_encounter_labels[entry_id] = label
	entry_encountered.emit(entry_id, label)
	knowledge_state_changed.emit(entry_id, old_state, KnowledgeState.ENCOUNTERED)


# --- Eligibility ---

func get_scannable_at(coords: Vector2i) -> StringName:
	if _hex_grid == null:
		return &""
	var tile = _hex_grid.get_tile(coords)
	if tile == null:
		return &""

	for prop in tile.get_props():
		if not PropRegistry.has_def(prop.type):
			continue
		var def = PropRegistry.get_def(prop.type)
		if def.catalogable == null:
			continue
		var entry_id: StringName = def.id
		if entry_id == &"" or String(def.catalogable.display_name) == "":
			continue
		if not is_cataloged(entry_id) and _all_entries.has(entry_id):
			# Skip ENCOUNTERED fauna (needs Trap/Sneak, not proximity scan)
			var entry = _all_entries[entry_id]
			if entry.category == CatalogCategory.FAUNA and is_encountered(entry_id):
				continue
			return entry_id
	for prop in tile.get_anomalies():
		var anomaly_id: StringName = prop.type
		if not is_cataloged(anomaly_id) and _all_entries.has(anomaly_id):
			return anomaly_id

	# Fauna handled by ScannerSystem via FaunaManager; not queried here at data layer

	return &""


# --- Save / Load ---

func get_save_data() -> Dictionary:
	var knowledge_save: Dictionary = {}
	for id in _knowledge:
		match _knowledge[id]:
			KnowledgeState.ENCOUNTERED:
				knowledge_save[String(id)] = "ENCOUNTERED"
			KnowledgeState.CATALOGED:
				knowledge_save[String(id)] = "CATALOGED"
	var labels_save: Dictionary = {}
	for id in _encounter_labels:
		labels_save[String(id)] = _encounter_labels[id]
	return {
		"knowledge": knowledge_save,
		"encounter_labels": labels_save,
	}


func load_save_data(data: Dictionary) -> void:
	_knowledge.clear()
	_encounter_labels.clear()
	var knowledge_data: Dictionary = data.get("knowledge", {})
	for id_str in knowledge_data:
		var id: StringName = StringName(id_str)
		match knowledge_data[id_str]:
			"ENCOUNTERED":
				_knowledge[id] = KnowledgeState.ENCOUNTERED
			"CATALOGED":
				_knowledge[id] = KnowledgeState.CATALOGED
	var labels_data: Dictionary = data.get("encounter_labels", {})
	for id_str in labels_data:
		_encounter_labels[StringName(id_str)] = labels_data[id_str]
	# Backwards compatibility: support old "discovered" format
	var discovered: Array = data.get("discovered", [])
	for id in discovered:
		var sn: StringName = StringName(id)
		if not _knowledge.has(sn):
			_knowledge[sn] = KnowledgeState.CATALOGED
