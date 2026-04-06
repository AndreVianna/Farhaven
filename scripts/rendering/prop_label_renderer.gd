extends Node3D

## PropLabelRenderer — colored marker icons above props.
## Shows colored ❓ for UNKNOWN (color by category), ⚠️ for ENCOUNTERED (fauna only),
## and NO marker for CATALOGED (the prop speaks for itself).
## Subscribes to ScannerSystem signals for 3-state marker management.
## On entry_cataloged: bulk remove — all visible markers of that type disappear.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")

# --- Constants ---

## Y offset above prop for marker
const LABEL_Y_OFFSET: float = 2.0

## HEX_SIZE for multi-prop offset calculation
const HEX_SIZE: float = 3.0

## Category colors for UNKNOWN ❓ markers
const CATEGORY_COLORS: Dictionary = {
	_Catalog.CatalogCategory.MINERAL: Color(0.3, 0.5, 1.0),   # Blue
	_Catalog.CatalogCategory.FLORA:   Color(0.3, 0.8, 0.3),   # Green
	_Catalog.CatalogCategory.FAUNA:   Color(1.0, 0.3, 0.3),   # Red
	_Catalog.CatalogCategory.ANOMALY: Color(0.7, 0.3, 0.9),   # Purple
}

## Color for ENCOUNTERED ⚠️ markers
const ENCOUNTERED_COLOR: Color = Color(1.0, 0.6, 0.1)  # Orange/amber

## Category display names (kept for compatibility with test assertions)
const CATEGORY_NAMES: Dictionary = {
	_Catalog.CatalogCategory.FLORA:   "Vegetation",
	_Catalog.CatalogCategory.FAUNA:   "Creature",
	_Catalog.CatalogCategory.MINERAL: "Mineral",
	_Catalog.CatalogCategory.ANOMALY: "Anomaly",
}

# --- State ---

## Tile coords -> Array of {entry_id: StringName, label_node: Label3D, state: int, category: int}
var _tile_labels: Dictionary = {}

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

func _on_element_identified(_coords: Vector2i, _entry_id: StringName) -> void:
	# CATALOGED = no marker at all. The prop speaks for itself.
	pass


func _on_element_unknown(coords: Vector2i, entry_id: StringName, category: int) -> void:
	var color: Color = CATEGORY_COLORS.get(category, Color.WHITE)
	_add_marker(coords, entry_id, "❓", color, _Catalog.KnowledgeState.UNKNOWN, category)


func _on_element_encountered(coords: Vector2i, entry_id: StringName, _label: String) -> void:
	_add_marker(coords, entry_id, "⚠️", ENCOUNTERED_COLOR, _Catalog.KnowledgeState.ENCOUNTERED, _Catalog.CatalogCategory.FAUNA)


func _on_entry_cataloged(entry_id: StringName, _category: int) -> void:
	# CATALOGED = no marker. Remove and free all matching Label3D nodes.
	for coords in _tile_labels.keys():
		var labels: Array = _tile_labels[coords]
		var i: int = labels.size() - 1
		while i >= 0:
			var info: Dictionary = labels[i]
			if info.entry_id == entry_id:
				if info.label_node != null and is_instance_valid(info.label_node):
					info.label_node.queue_free()
				labels.remove_at(i)
			i -= 1
		if labels.is_empty():
			_tile_labels.erase(coords)


func _on_entry_encountered(entry_id: StringName, _label: String) -> void:
	# Update matching UNKNOWN markers to ENCOUNTERED ⚠️
	for coords in _tile_labels:
		var labels: Array = _tile_labels[coords]
		for info in labels:
			if info.entry_id == entry_id and info.state == _Catalog.KnowledgeState.UNKNOWN:
				info.state = _Catalog.KnowledgeState.ENCOUNTERED
				if info.label_node != null:
					info.label_node.text = "⚠️"
					info.label_node.modulate = ENCOUNTERED_COLOR


func _on_tile_visibility_changed(coords: Vector2i, state: int) -> void:
	if state == _HexTile.FogState.HIDDEN:
		_remove_all_labels_at(coords)


# --- Marker management ---

func _add_marker(coords: Vector2i, entry_id: StringName, text: String, color: Color, state: int, category: int) -> void:
	# Prevent duplicate markers for same entry on same tile
	if _tile_labels.has(coords):
		for info in _tile_labels[coords]:
			if info.entry_id == entry_id:
				return  # Already has a marker

	# Position
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile = _grid.get_tile(coords) if _grid != null else null
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.5

	# Look up sub-hex world offset from tile data (anomalies stay at center)
	var placement: Array = _PropUtils.get_prop_placement(tile, entry_id)
	var world_offset: Vector2 = placement[0]  # Already world-space from sub_axial_to_world
	var pos := Vector3(world_2d.x + world_offset.x, elevation_y + LABEL_Y_OFFSET, world_2d.y + world_offset.y)

	var label_3d := Label3D.new()
	label_3d.text = text
	label_3d.font_size = 64
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.pixel_size = 0.008
	label_3d.modulate = color
	label_3d.outline_size = 0
	label_3d.position = pos
	add_child(label_3d)

	if not _tile_labels.has(coords):
		_tile_labels[coords] = []
	_tile_labels[coords].append({
		"entry_id": entry_id,
		"label_node": label_3d,
		"state": state,
		"category": category,
	})


func _remove_all_labels_at(coords: Vector2i) -> void:
	if not _tile_labels.has(coords):
		return
	var labels: Array = _tile_labels[coords]
	for info in labels:
		if info.label_node != null and is_instance_valid(info.label_node):
			info.label_node.queue_free()
	_tile_labels.erase(coords)


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
