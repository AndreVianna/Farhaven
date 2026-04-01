class_name PlayerPathfinder
extends RefCounted

## AStar2D wrapper for hex-grid pathfinding.
## Builds graph from HexGrid on map_generated, updates on structure changes.
## Uses Dictionary[Vector2i, int] for coord-to-AStar2D-ID mapping.

var _astar := AStar2D.new()
var _coord_to_id: Dictionary = {}  # Vector2i -> int
var _id_to_coord_map: Dictionary = {}  # int -> Vector2i
var _next_id: int = 0
var _grid: Node  # HexGrid reference (autoload or test substitute)


func setup(grid: Node = null) -> void:
	_grid = grid if grid != null else HexGrid
	_grid.map_generated.connect(_on_map_generated)
	_grid.structure_placed.connect(_on_structure_placed)
	_grid.structure_destroyed.connect(_on_structure_destroyed)


func _on_map_generated() -> void:
	_build_graph()


## Build the full AStar2D graph from current grid state.
func _build_graph() -> void:
	_astar.clear()
	_coord_to_id.clear()
	_id_to_coord_map.clear()
	_next_id = 0

	var grid: Node = _grid if _grid != null else HexGrid

	# Add all points first.
	for coords: Vector2i in grid._tiles:
		var id: int = _next_id
		_next_id += 1
		_coord_to_id[coords] = id
		_id_to_coord_map[id] = coords
		var world_2d: Vector2 = grid.axial_to_world(coords)
		_astar.add_point(id, world_2d)

	# Connect passable neighbors.
	for coords: Vector2i in grid._tiles:
		var id: int = _coord_to_id[coords]
		var neighbors: Array[Vector2i] = grid.get_neighbors(coords)
		for neighbor in neighbors:
			if not _coord_to_id.has(neighbor):
				continue
			var neighbor_id: int = _coord_to_id[neighbor]
			if grid.is_passable(coords, neighbor) and grid.is_passable(neighbor, coords):
				if not _astar.are_points_connected(id, neighbor_id):
					_astar.connect_points(id, neighbor_id)


## Find a path from `from` to `to` as an array of axial coords.
## Returns empty array if no path exists or either coord is invalid.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _coord_to_id.has(from) or not _coord_to_id.has(to):
		return []
	var from_id: int = _coord_to_id[from]
	var to_id: int = _coord_to_id[to]
	var id_path: PackedInt64Array = _astar.get_id_path(from_id, to_id)
	if id_path.is_empty():
		return []
	var result: Array[Vector2i] = []
	for id in id_path:
		result.append(_id_to_coord_map.get(id, Vector2i.ZERO))
	return result


func _on_structure_placed(coords: Vector2i, _structure_type: StringName) -> void:
	_update_tile_connections(coords)


func _on_structure_destroyed(coords: Vector2i, _structure_type: StringName) -> void:
	_update_tile_connections(coords)


## Disconnect/reconnect edges for a tile after structure changes.
func _update_tile_connections(coords: Vector2i) -> void:
	if not _coord_to_id.has(coords):
		return

	var grid: Node = _grid if _grid != null else HexGrid
	var id: int = _coord_to_id[coords]
	var neighbors: Array[Vector2i] = grid.get_neighbors(coords)

	# Disconnect all edges for this tile first.
	for neighbor in neighbors:
		if not _coord_to_id.has(neighbor):
			continue
		var neighbor_id: int = _coord_to_id[neighbor]
		if _astar.are_points_connected(id, neighbor_id):
			_astar.disconnect_points(id, neighbor_id)

	# Reconnect passable edges.
	for neighbor in neighbors:
		if not _coord_to_id.has(neighbor):
			continue
		var neighbor_id: int = _coord_to_id[neighbor]
		if grid.is_passable(coords, neighbor) and grid.is_passable(neighbor, coords):
			_astar.connect_points(id, neighbor_id)
