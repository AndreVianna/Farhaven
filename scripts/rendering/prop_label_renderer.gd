extends Node3D

## PropLabelRenderer — floating pill-shaped labels above props.
## Shows "❓ Unknown [category]" for UNKNOWN, "⚠️ Unidentified Fauna (label)"
## for ENCOUNTERED, real name for CATALOGED.
## Subscribes to ScannerSystem signals for 3-state label management.
## On entry_cataloged: bulk label update — all visible props of that type flip.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

# --- Constants ---

## Y offset above prop for label
const LABEL_Y_OFFSET: float = 2.0

## HEX_SIZE for multi-prop offset calculation
const HEX_SIZE: float = 3.0

## Radial offset factor (must match PropRenderer)
const MULTI_PROP_RADIUS_FACTOR: float = 0.3

## Category display names for UNKNOWN labels
const CATEGORY_NAMES: Dictionary = {
	_Catalog.CatalogCategory.FLORA:   "Vegetation",
	_Catalog.CatalogCategory.FAUNA:   "Creature",
	_Catalog.CatalogCategory.MINERAL: "Mineral",
	_Catalog.CatalogCategory.ANOMALY: "Anomaly",
}

# --- State ---

## Tile coords -> Array of {entry_id: StringName, label_node: Label3D, state: int}
var _tile_labels: Dictionary = {}

## Tile coords -> int (label count for offset calculation)
var _tile_label_count: Dictionary = {}

## Reference to ScannerSystem
var _scanner: Node = null

## Reference to HexGrid
var _grid: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_connect_signals()


func _connect_signals() -> void:
	_connect_scanner_signals.call_deferred()
	_connect_grid_signals()


func _connect_grid_signals() -> void:
	if _grid != null and _grid.has_signal("tile_visibility_changed"):
		if not _grid.tile_visibility_changed.is_connected(_on_tile_visibility_changed):
			_grid.tile_visibility_changed.connect(_on_tile_visibility_changed)


func _connect_scanner_signals() -> void:
	if _scanner == null:
		_scanner = _find_scanner()
	if _scanner == null:
		return
	if _scanner.has_signal("element_identified"):
		if not _scanner.element_identified.is_connected(_on_element_identified):
			_scanner.element_identified.connect(_on_element_identified)
	if _scanner.has_signal("element_unknown"):
		if not _scanner.element_unknown.is_connected(_on_element_unknown):
			_scanner.element_unknown.connect(_on_element_unknown)
	if _scanner.has_signal("element_encountered"):
		if not _scanner.element_encountered.is_connected(_on_element_encountered):
			_scanner.element_encountered.connect(_on_element_encountered)
	if _scanner.has_signal("entry_cataloged"):
		if not _scanner.entry_cataloged.is_connected(_on_entry_cataloged):
			_scanner.entry_cataloged.connect(_on_entry_cataloged)
	if _scanner.has_signal("entry_encountered"):
		if not _scanner.entry_encountered.is_connected(_on_entry_encountered):
			_scanner.entry_encountered.connect(_on_entry_encountered)


func _find_scanner() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var player: Node = world.get_node_or_null("Player")
	if player == null:
		return null
	return player.get_node_or_null("ScannerSystem")


# --- Signal handlers ---

func _on_element_identified(coords: Vector2i, entry_id: StringName) -> void:
	var catalog: RefCounted = _get_catalog()
	var display_name: String = entry_id
	if catalog != null:
		var entry = catalog.get_entry(entry_id)
		if entry != null:
			display_name = entry.display_name
	_add_label(coords, entry_id, display_name, _Catalog.KnowledgeState.CATALOGED)


func _on_element_unknown(coords: Vector2i, entry_id: StringName, category: int) -> void:
	var cat_name: String = CATEGORY_NAMES.get(category, "Unknown")
	var text: String = "❓ Unknown %s" % cat_name
	_add_label(coords, entry_id, text, _Catalog.KnowledgeState.UNKNOWN)


func _on_element_encountered(coords: Vector2i, entry_id: StringName, label: String) -> void:
	var text: String = "⚠️ Unidentified Fauna (%s)" % label
	_add_label(coords, entry_id, text, _Catalog.KnowledgeState.ENCOUNTERED)


func _on_entry_cataloged(entry_id: StringName, _category: int) -> void:
	# Bulk label update: iterate all visible labels, update matching entry_id
	var catalog: RefCounted = _get_catalog()
	var display_name: String = String(entry_id)
	if catalog != null:
		var entry = catalog.get_entry(entry_id)
		if entry != null:
			display_name = entry.display_name

	for coords in _tile_labels:
		var labels: Array = _tile_labels[coords]
		for info in labels:
			if info.entry_id == entry_id and info.state != _Catalog.KnowledgeState.CATALOGED:
				info.state = _Catalog.KnowledgeState.CATALOGED
				if info.label_node != null:
					info.label_node.text = display_name


func _on_entry_encountered(entry_id: StringName, label: String) -> void:
	# Update matching UNKNOWN labels to ENCOUNTERED
	var text: String = "⚠️ Unidentified Fauna (%s)" % label

	for coords in _tile_labels:
		var labels: Array = _tile_labels[coords]
		for info in labels:
			if info.entry_id == entry_id and info.state == _Catalog.KnowledgeState.UNKNOWN:
				info.state = _Catalog.KnowledgeState.ENCOUNTERED
				if info.label_node != null:
					info.label_node.text = text


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	if state == _HexTile.FogState.REVEALED or state == _HexTile.FogState.HIDDEN:
		_remove_all_labels_at(coords)


# --- Label management ---

func _add_label(coords: Vector2i, entry_id: StringName, text: String, state: int) -> void:
	var label_index: int = _tile_label_count.get(coords, 0)
	_tile_label_count[coords] = label_index + 1

	# Position
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile = _grid.get_tile(coords) if _grid != null else null
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.5

	var offset: Vector2 = _calc_label_offset(coords, label_index)
	var pos := Vector3(world_2d.x + offset.x, elevation_y + LABEL_Y_OFFSET, world_2d.y + offset.y)

	var label_3d := Label3D.new()
	label_3d.text = text
	label_3d.font_size = 48
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.pixel_size = 0.01
	label_3d.position = pos
	add_child(label_3d)

	if not _tile_labels.has(coords):
		_tile_labels[coords] = []
	_tile_labels[coords].append({
		"entry_id": entry_id,
		"label_node": label_3d,
		"state": state,
	})


func _calc_label_offset(coords: Vector2i, label_index: int) -> Vector2:
	var total: int = _tile_label_count.get(coords, 1)
	if total <= 1:
		return Vector2.ZERO
	var angle: float = (2.0 * PI / float(total)) * float(label_index)
	var radius: float = MULTI_PROP_RADIUS_FACTOR * HEX_SIZE
	return Vector2(cos(angle) * radius, sin(angle) * radius)


func _remove_all_labels_at(coords: Vector2i) -> void:
	if not _tile_labels.has(coords):
		return
	var labels: Array = _tile_labels[coords]
	for info in labels:
		if info.label_node != null and is_instance_valid(info.label_node):
			info.label_node.queue_free()
	_tile_labels.erase(coords)
	_tile_label_count.erase(coords)


# --- Helpers ---

func _get_catalog() -> RefCounted:
	if _scanner != null and _scanner.has_method("get_catalog"):
		return _scanner.get_catalog()
	return null


# --- Public API (for testing) ---

func get_tile_labels() -> Dictionary:
	return _tile_labels


func get_label_count() -> int:
	var count: int = 0
	for coords in _tile_labels:
		count += _tile_labels[coords].size()
	return count


func get_label_text_at(coords: Vector2i, index: int = 0) -> String:
	if not _tile_labels.has(coords):
		return ""
	var labels: Array = _tile_labels[coords]
	if index >= labels.size():
		return ""
	return labels[index].label_node.text if labels[index].label_node != null else ""


func get_label_state_at(coords: Vector2i, index: int = 0) -> int:
	if not _tile_labels.has(coords):
		return -1
	var labels: Array = _tile_labels[coords]
	if index >= labels.size():
		return -1
	return labels[index].state
