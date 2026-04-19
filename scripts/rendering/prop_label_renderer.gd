extends Node3D

## PropLabelRenderer — colored marker icons above props.
## Shows colored ❓ for UNKNOWN (color by category), ⚠️ for ENCOUNTERED (fauna only),
## and NO marker for CATALOGED (the prop speaks for itself).
## Subscribes to ScannerSystem signals for 3-state marker management.
## On entry_cataloged: bulk remove — all visible markers of that type disappear.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _HexGrid = preload("res://scripts/hex/hex_grid.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

# --- Constants ---

## Y offset above prop for marker
const LABEL_Y_OFFSET: float = 2.0

## HEX_SIZE for multi-prop offset calculation
const HEX_SIZE: float = 3.0

## Bucket colors for UNKNOWN ❓ markers. Keys are Prop.Category int values
## plus Catalog.ANOMALY_BUCKET for show_as_anomaly overrides.
const CATEGORY_COLORS: Dictionary = {
	_Prop.Category.PLANT:   Color(0.3, 0.8, 0.3),   # Green
	_Prop.Category.MINERAL: Color(0.3, 0.5, 1.0),   # Blue
	_Prop.Category.ANIMAL:  Color(1.0, 0.3, 0.3),   # Red
	_Prop.Category.FUNGI:   Color(0.7, 0.5, 0.85),  # Lavender
	_Prop.Category.LIQUID:  Color(0.3, 0.7, 1.0),   # Cyan
	_Prop.Category.OOZE:    Color(0.5, 0.6, 0.3),   # Olive
	_Catalog.ANOMALY_BUCKET: Color(0.7, 0.3, 0.9),  # Purple — anomaly override
}

## Color for ENCOUNTERED ⚠️ markers
const ENCOUNTERED_COLOR: Color = Color(1.0, 0.6, 0.1)  # Orange/amber

## Display names by bucket. Keys match CATEGORY_COLORS.
const CATEGORY_NAMES: Dictionary = {
	_Prop.Category.PLANT:   "Vegetation",
	_Prop.Category.MINERAL: "Mineral",
	_Prop.Category.ANIMAL:  "Creature",
	_Prop.Category.FUNGI:   "Fungi",
	_Prop.Category.LIQUID:  "Liquid",
	_Prop.Category.OOZE:    "Ooze",
	_Catalog.ANOMALY_BUCKET: "Anomaly",
}

# --- State ---

## Tile coords -> Array of {entry_id: StringName, label_node: Label3D, state: int, category: int}
var _tile_labels: Dictionary = {}

## Reference to ScannerSystem
var _scanner: Node = null

## Reference to HexGrid
var _grid: Node = null

## Player node — source of player_moved. Late-bound (see _find_player).
var _player: Node = null

## Mirror of PropRenderer.STREAM_RADIUS. Keeping the labels on the same
## window as the meshes avoids orphan "?" markers hovering over tiles
## whose 3D props have been unloaded.
const STREAM_RADIUS: int = 20

## Tiles we currently show labels for.
var _streamed_tiles: Dictionary = {}


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_connect_signals()


func _connect_signals() -> void:
	_connect_scanner_signals.call_deferred()
	_connect_player_signals.call_deferred()


func _connect_player_signals() -> void:
	if _player == null:
		_player = _find_player()
	if _player == null:
		return
	if _player.has_signal("player_moved"):
		if not _player.player_moved.is_connected(_on_player_moved):
			_player.player_moved.connect(_on_player_moved)


func _find_player() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("Player")


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
	if not _is_streamed(coords):
		return
	var color: Color = CATEGORY_COLORS.get(category, Color.WHITE)
	_add_marker(coords, entry_id, "❓", color, _Catalog.KnowledgeState.UNKNOWN, category)


func _on_element_encountered(coords: Vector2i, entry_id: StringName, _label: String) -> void:
	if not _is_streamed(coords):
		return
	_add_marker(coords, entry_id, "⚠️", ENCOUNTERED_COLOR, _Catalog.KnowledgeState.ENCOUNTERED, _Prop.Category.ANIMAL)


## Player crossed a hex boundary. Diff the label set: drop labels
## on tiles that are now too far away (frees the Label3D nodes and
## the "?" swarm with them), and repopulate labels for tiles that
## just came into range using the catalog's cached knowledge state.
func _on_player_moved(from: Vector2i, to: Vector2i) -> void:
	if from == to and _streamed_tiles.size() > 0:
		return
	_stream_around(to)


func _stream_around(center: Vector2i) -> void:
	if _grid == null:
		return
	var desired: Dictionary = {}
	# Test doubles typically lack get_tiles_in_range — fall back to
	# get_all_tiles so the unit suite still covers the full label set.
	if _grid.has_method("get_tiles_in_range"):
		for coords in _grid.get_tiles_in_range(center, STREAM_RADIUS):
			desired[coords] = true
	elif _grid.has_method("get_all_tiles"):
		for coords in _grid.get_all_tiles():
			desired[coords] = true

	for coords in _streamed_tiles.keys():
		if not desired.has(coords):
			_remove_all_labels_at(coords)
			_streamed_tiles.erase(coords)

	for coords in desired.keys():
		if _streamed_tiles.has(coords):
			continue
		_streamed_tiles[coords] = true
		_rehydrate_labels_for_tile(coords)


## Restore labels for every prop on the tile using the scanner's
## knowledge state. Called when a tile enters the streaming window
## so the user sees the right marker even if they never saw the
## original element_unknown / element_encountered signal for this
## instance (e.g. spawned by Populate outside the streaming window).
func _rehydrate_labels_for_tile(coords: Vector2i) -> void:
	if _grid == null:
		return
	var tile: Resource = _grid.get_tile(coords) if _grid.has_method("get_tile") else null
	if tile == null:
		return
	var catalog: RefCounted = _get_catalog()
	var props: Array = tile.get_props() if tile.has_method("get_props") else []
	for prop in props:
		var entry_id: StringName = prop.type
		var state: int = _Catalog.KnowledgeState.UNKNOWN
		if catalog != null and catalog.has_method("get_knowledge_state"):
			state = catalog.get_knowledge_state(entry_id)
		if state == _Catalog.KnowledgeState.CATALOGED:
			continue  # already identified — no marker
		var category: int = prop.category if "category" in prop else _Prop.Category.PLANT
		if state == _Catalog.KnowledgeState.ENCOUNTERED:
			_add_marker(coords, entry_id, "⚠️", ENCOUNTERED_COLOR, state, _Prop.Category.ANIMAL)
		else:
			var color: Color = CATEGORY_COLORS.get(category, Color.WHITE)
			_add_marker(coords, entry_id, "❓", color, state, category)


func _is_streamed(coords: Vector2i) -> bool:
	# First signal after _ready can fire before the player has emitted
	# player_moved; accept everything until the first stream happens so
	# we don't drop labels in the warm-up window.
	if _streamed_tiles.is_empty():
		return true
	return _streamed_tiles.has(coords)


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
	# Look up sub-hex world offset from tile data (anomalies stay at center)
	var placement: Array = _PropUtils.get_prop_placement(tile, entry_id)
	var world_offset: Vector2 = placement[0]  # Already world-space from sub_axial_to_world
	var wx: float = world_2d.x + world_offset.x
	var wz: float = world_2d.y + world_offset.y
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(wx, wz)
	elif tile != null:
		elevation_y = float(tile.elevation) * _HexGrid.ELEVATION_STEP
	# Scale the label offset by the prop's visual scale so small props
	# (scale 0.3) don't get their markers floating in empty air and large
	# props (scale 1.2) don't hide their marker inside the mesh.
	var visual_scale: float = _PropUtils.get_visual_scale(entry_id)
	var pos := Vector3(wx, elevation_y + LABEL_Y_OFFSET * visual_scale, wz)

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
