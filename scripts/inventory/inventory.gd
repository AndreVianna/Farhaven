class_name Inventory
extends RefCounted

## Grid-based Tetris inventory (delivery-006f, tasks 090+091).
##
## The player's backpack is a 2D grid of cells. Each item occupies a set of
## cells defined by its PortableCap.slot_shape (an Array[Vector2i] of offsets
## relative to the item origin). Items can be rotated in 90-degree increments
## (4 orientations). No stacking: 1 prop instance = 1 shape on the grid.
##
## Scanner remains body-integrated (not a grid item). All other tools live in
## the grid and are located via find_best_tool_for_action (task-096).

const _PropDef = preload("res://scripts/data/prop_def.gd")

signal inventory_changed()
signal item_added(type: StringName, amount: int)
signal item_removed(type: StringName, amount: int)
signal inventory_full(type: StringName, rejected: int)
signal item_used(type: StringName)
signal tool_changed(slot: StringName, new_tool: StringName, old_tool: StringName)

# --- Grid data ---

## Grid dimensions (cells). Player backpack default: 30 wide × 40 tall.
var grid_width: int = 30
var grid_height: int = 40

## Flat 1D array of size grid_width × grid_height.
## Each cell stores an item_id (0 = empty, >0 = occupied by that item).
var _grid: PackedInt32Array

## Item instances: item_id → { type: StringName, origin: Vector2i,
##   rotation: int (0-3, number of 90° CW rotations), shape: Array[Vector2i] }
var _items: Dictionary = {}

## Next available item id. Monotonically increasing.
var _next_id: int = 1

## Tool slots: slot_name → PropDef id (or &"" if empty).
## Kept for backward compat (crafting_system, auto_interaction_system).
## Scanner is body-integrated; other slots transition to grid in task-096.
var _tool_slots: Dictionary = {
	&"axe":      &"",
	&"pickaxe":  &"",
	&"weapon":   &"",
	&"scanner":  &"",
}


func _init(p_grid_width: int = 30, p_grid_height: int = 40) -> void:
	grid_width = p_grid_width
	grid_height = p_grid_height
	_init_grid()


func _init_grid() -> void:
	_grid = PackedInt32Array()
	_grid.resize(grid_width * grid_height)
	_grid.fill(0)


# ---------------------------------------------------------------------------
# Shape rotation utilities
# ---------------------------------------------------------------------------

## Rotate a shape 90° clockwise once: (x, y) → (-y, x), then normalize so
## all offsets are in the positive quadrant (min x/y = 0).
static func rotate_shape_once(shape: Array[Vector2i]) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = []
	rotated.resize(shape.size())
	var min_x: int = 0
	var min_y: int = 0
	for i in shape.size():
		var cell: Vector2i = shape[i]
		var rx: int = -cell.y
		var ry: int = cell.x
		rotated[i] = Vector2i(rx, ry)
		if rx < min_x:
			min_x = rx
		if ry < min_y:
			min_y = ry
	if min_x != 0 or min_y != 0:
		for i in rotated.size():
			rotated[i] = Vector2i(rotated[i].x - min_x, rotated[i].y - min_y)
	return rotated


## Get a shape rotated by `times` × 90° clockwise.
static func get_rotated_shape(base_shape: Array[Vector2i], times: int) -> Array[Vector2i]:
	var n: int = times % 4
	if n < 0:
		n += 4
	if n == 0:
		return base_shape.duplicate()
	var result: Array[Vector2i] = base_shape
	for _i in n:
		result = rotate_shape_once(result)
	return result


## Compute the bounding-box size of a shape (max_x + 1, max_y + 1).
static func get_shape_bounds(shape: Array[Vector2i]) -> Vector2i:
	var mx: int = 0
	var my: int = 0
	for cell in shape:
		if cell.x > mx:
			mx = cell.x
		if cell.y > my:
			my = cell.y
	return Vector2i(mx + 1, my + 1)


# ---------------------------------------------------------------------------
# Grid helpers
# ---------------------------------------------------------------------------

func _cell_index(x: int, y: int) -> int:
	return y * grid_width + x


func _is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height


## Write an item_id into all cells occupied by the rotated shape at origin.
func _write_cells(item_id: int, shape: Array[Vector2i], origin: Vector2i, rotation: int) -> void:
	var rotated: Array[Vector2i] = get_rotated_shape(shape, rotation)
	for cell in rotated:
		_grid[_cell_index(origin.x + cell.x, origin.y + cell.y)] = item_id


## Clear all cells belonging to an item_id.
func _clear_cells(item_id: int) -> void:
	for i in _grid.size():
		if _grid[i] == item_id:
			_grid[i] = 0


## Resolve the base shape for a prop type from PropRegistry.
## Empty shapes are normalized to a single cell so placement always works.
func _get_shape_for_type(type: StringName) -> Array[Vector2i]:
	var def: _PropDef = PropRegistry.get_def(type)
	if def != null and def.portable != null and def.portable.slot_shape.size() > 0:
		return def.portable.slot_shape
	return [Vector2i(0, 0)]


# ---------------------------------------------------------------------------
# Placement queries
# ---------------------------------------------------------------------------

## Check whether a shape fits at origin with rotation, ignoring cells occupied
## by `exclude_id` (0 = ignore nothing).
func can_fit(shape: Array[Vector2i], origin: Vector2i, rotation: int = 0, exclude_id: int = 0) -> bool:
	var rotated: Array[Vector2i] = get_rotated_shape(shape, rotation)
	for cell in rotated:
		var x: int = origin.x + cell.x
		var y: int = origin.y + cell.y
		if not _is_in_bounds(x, y):
			return false
		var occupant: int = _grid[_cell_index(x, y)]
		if occupant != 0 and occupant != exclude_id:
			return false
	return true


## First-fit search for a shape across the entire grid.
## Tries rotations 0–3, scanning left-to-right, top-to-bottom.
## Returns { "origin": Vector2i, "rotation": int } or empty Dictionary.
func find_placement(shape: Array[Vector2i]) -> Dictionary:
	for rot in 4:
		var rotated: Array[Vector2i] = get_rotated_shape(shape, rot)
		var bounds: Vector2i = get_shape_bounds(rotated)
		var max_ox: int = grid_width - bounds.x
		var max_oy: int = grid_height - bounds.y
		for oy in range(max_oy + 1):
			for ox in range(max_ox + 1):
				var fits: bool = true
				for cell in rotated:
					if _grid[_cell_index(ox + cell.x, oy + cell.y)] != 0:
						fits = false
						break
				if fits:
					return {"origin": Vector2i(ox, oy), "rotation": rot}
	return {}


# ---------------------------------------------------------------------------
# Grid item operations (new API)
# ---------------------------------------------------------------------------

## Auto-place a single item into the grid. Returns item_id (>0) or 0 on failure.
func place_item(type: StringName) -> int:
	var shape: Array[Vector2i] = _get_shape_for_type(type)
	var placement: Dictionary = find_placement(shape)
	if placement.is_empty():
		return 0
	return _place_internal(type, shape, placement["origin"], placement["rotation"])


## Place an item at an explicit position. Returns item_id (>0) or 0 on failure.
func place_item_at(type: StringName, origin: Vector2i, rotation: int = 0) -> int:
	var shape: Array[Vector2i] = _get_shape_for_type(type)
	if not can_fit(shape, origin, rotation):
		return 0
	return _place_internal(type, shape, origin, rotation)


## Internal: allocate id, record item, write cells. No signals.
func _place_internal(type: StringName, shape: Array[Vector2i], origin: Vector2i, rotation: int) -> int:
	var item_id: int = _next_id
	_next_id += 1
	_items[item_id] = {
		"type": type,
		"origin": origin,
		"rotation": rotation,
		"shape": shape,
	}
	_write_cells(item_id, shape, origin, rotation)
	return item_id


## Remove a specific item instance by id. Returns true if removed.
func remove_item_by_id(item_id: int) -> bool:
	if not _items.has(item_id):
		return false
	_clear_cells(item_id)
	_items.erase(item_id)
	return true


## Move an item to a new position/rotation. Atomic: reverts if new pos invalid.
func move_item(item_id: int, new_origin: Vector2i, new_rotation: int) -> bool:
	if not _items.has(item_id):
		return false
	var item: Dictionary = _items[item_id]
	if not can_fit(item["shape"], new_origin, new_rotation, item_id):
		return false
	_clear_cells(item_id)
	_write_cells(item_id, item["shape"], new_origin, new_rotation)
	item["origin"] = new_origin
	item["rotation"] = new_rotation
	return true


## Return a copy of an item's data, or null if not found.
func get_item(item_id: int) -> Variant:
	if _items.has(item_id):
		return _items[item_id].duplicate()
	return null


## Return all item_ids for a given prop type.
func get_items_by_type(type: StringName) -> Array[int]:
	var result: Array[int] = []
	for item_id: int in _items:
		if _items[item_id]["type"] == type:
			result.append(item_id)
	return result


## Read-only copy of all items. Keys are item_ids, values are item dicts.
func get_all_items() -> Dictionary:
	var copy: Dictionary = {}
	for item_id: int in _items:
		copy[item_id] = _items[item_id].duplicate()
	return copy


## Return the item_id occupying grid cell (x, y), or 0 if empty/out-of-bounds.
func get_grid_cell(x: int, y: int) -> int:
	if not _is_in_bounds(x, y):
		return 0
	return _grid[_cell_index(x, y)]


## Count instances of a given prop type in the grid.
func get_count(type: StringName) -> int:
	var count: int = 0
	for item_id: int in _items:
		if _items[item_id]["type"] == type:
			count += 1
	return count


## Find an item in the grid (or tool slots) whose PropDef supports the
## requested action. Returns item_id (>0), -1 if found in a tool slot, or 0.
func find_best_tool_for_action(action: StringName) -> int:
	# Search grid items via PropDef.supports_actions.
	for item_id: int in _items:
		var type: StringName = _items[item_id]["type"]
		var def: _PropDef = PropRegistry.get_def(type)
		if def != null and def.supports_actions.size() > 0 and def.supports_actions.has(action):
			return item_id
	# Fallback: check tool slots (backward compat until task-096 migrates).
	var _slot_map: Dictionary = {
		&"chop": &"axe",
		&"mine": &"pickaxe",
		&"attack_melee": &"weapon",
		&"scan": &"scanner",
	}
	var slot: StringName = _slot_map.get(action, &"")
	if slot != &"" and _tool_slots.get(slot, &"") != &"":
		return -1
	return 0


# ---------------------------------------------------------------------------
# Backward-compatible item API
# ---------------------------------------------------------------------------

## Add items to the grid by auto-placing each instance.
## Returns the number of instances successfully placed.
## Tools with a dedicated slot go through set_tool, not the grid.
func add_item(type: StringName, amount: int = 1) -> int:
	var def: _PropDef = PropRegistry.get_def(type)
	if def == null:
		return 0
	if def.tool_slot != &"":
		return 0

	var shape: Array[Vector2i] = _get_shape_for_type(type)
	var added: int = 0
	for _i in amount:
		var placement: Dictionary = find_placement(shape)
		if placement.is_empty():
			break
		_place_internal(type, shape, placement["origin"], placement["rotation"])
		added += 1

	if added > 0:
		item_added.emit(type, added)
		inventory_changed.emit()
	var rejected: int = amount - added
	if rejected > 0:
		inventory_full.emit(type, rejected)
	return added


## Remove `amount` instances of `type` from the grid.
## Returns the number actually removed.
func remove_item(type: StringName, amount: int = 1) -> int:
	var ids: Array[int] = get_items_by_type(type)
	var to_remove: int = mini(amount, ids.size())
	for i in to_remove:
		remove_item_by_id(ids[i])

	if to_remove > 0:
		item_removed.emit(type, to_remove)
		inventory_changed.emit()
	return to_remove


func has_item(type: StringName, amount: int = 1) -> bool:
	return get_count(type) >= amount


func use_item(type: StringName) -> bool:
	if not has_item(type):
		return false
	remove_item(type, 1)
	item_used.emit(type)
	return true


func is_full() -> bool:
	for i in _grid.size():
		if _grid[i] == 0:
			return false
	return true


## Backward compat: returns items grouped by type as {type, quantity}.
## Empty types are never included.
func get_slots() -> Array[Dictionary]:
	var type_counts: Dictionary = {}
	for item_id: int in _items:
		var t: StringName = _items[item_id]["type"]
		if type_counts.has(t):
			type_counts[t] += 1
		else:
			type_counts[t] = 1
	var result: Array[Dictionary] = []
	for t: StringName in type_counts:
		result.append({"type": t, "quantity": type_counts[t]})
	return result


## Backward compat: items grouped by type with cell-count size info.
func get_stacks() -> Array[Dictionary]:
	var type_counts: Dictionary = {}
	for item_id: int in _items:
		var t: StringName = _items[item_id]["type"]
		if type_counts.has(t):
			type_counts[t] += 1
		else:
			type_counts[t] = 1
	var result: Array[Dictionary] = []
	for t: StringName in type_counts:
		var shape: Array[Vector2i] = _get_shape_for_type(t)
		var cells_per: float = float(shape.size())
		var count: int = type_counts[t]
		result.append({
			"type": t,
			"count": count,
			"size_per_unit": cells_per,
			"total_size": cells_per * float(count),
		})
	return result


## Expand the grid by adding rows.
func expand(additional_rows: int) -> void:
	grid_height += additional_rows
	_rebuild_grid()
	inventory_changed.emit()


## Rebuild the flat grid array from the items dict (after resize, load, etc.).
## Items that no longer fit after a resize are removed with a warning.
func _rebuild_grid() -> void:
	_grid = PackedInt32Array()
	_grid.resize(grid_width * grid_height)
	_grid.fill(0)
	var to_remove: Array[int] = []
	for item_id: int in _items:
		var item: Dictionary = _items[item_id]
		if can_fit(item["shape"], item["origin"], item["rotation"]):
			_write_cells(item_id, item["shape"], item["origin"], item["rotation"])
		else:
			push_warning("Inventory._rebuild_grid: item %d no longer fits — removed" % item_id)
			to_remove.append(item_id)
	for item_id in to_remove:
		_items.erase(item_id)


# ---------------------------------------------------------------------------
# Size / capacity — backward compat (cell-count based)
# ---------------------------------------------------------------------------

## Total cells occupied by items.
func get_current_size() -> float:
	var occupied: int = 0
	for i in _grid.size():
		if _grid[i] != 0:
			occupied += 1
	return float(occupied)


## Total grid cells.
func get_capacity_size() -> float:
	return float(grid_width * grid_height)


## Writable capacity_size for backward compat (tests, legacy saves).
## Keeps grid_width fixed and only increases grid_height. Refuses shrink.
var capacity_size: float:
	get:
		return float(grid_width * grid_height)
	set(value):
		var target_cells: int = int(max(1.0, value))
		var current_cells: int = grid_width * grid_height
		if target_cells <= current_cells:
			return  # refuse shrink
		grid_height = int(ceil(float(target_cells) / float(grid_width)))
		_rebuild_grid()


func get_remaining_capacity() -> float:
	return get_capacity_size() - get_current_size()


func get_size_display() -> String:
	return "%.0f / %.0f" % [get_current_size(), get_capacity_size()]


## Backward compat: total grid cells.
func get_max_slots() -> int:
	return grid_width * grid_height


## Number of distinct item instances currently in the grid.
func get_used_slot_count() -> int:
	return _items.size()


# ---------------------------------------------------------------------------
# Tool API (scanner only — body-integrated)
# ---------------------------------------------------------------------------

func get_tool(slot: StringName) -> StringName:
	return _tool_slots.get(slot, &"")


func set_tool(slot: StringName, tool: StringName) -> StringName:
	var old: StringName = _tool_slots.get(slot, &"")
	_tool_slots[slot] = tool
	tool_changed.emit(slot, tool, old)
	inventory_changed.emit()
	return old


func has_tool_for(slot: StringName) -> bool:
	return _tool_slots.get(slot, &"") != &""


# ---------------------------------------------------------------------------
# Save / Load (task-091)
# ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var items_data: Array = []
	var sorted_ids: Array = _items.keys()
	sorted_ids.sort()
	for item_id: int in sorted_ids:
		var item: Dictionary = _items[item_id]
		items_data.append({
			"id": item_id,
			"type": str(item["type"]),
			"origin": [item["origin"].x, item["origin"].y],
			"rotation": item["rotation"],
		})
	return {
		"grid_width": grid_width,
		"grid_height": grid_height,
		"items": items_data,
		"scanner": str(_tool_slots.get(&"scanner", &"")),
	}


func load_save_data(data: Dictionary) -> void:
	# Detect save format: new grid-based vs legacy slot-based.
	if data.has("items") and data.has("grid_width"):
		_load_grid_save(data)
	elif data.has("slots"):
		_load_legacy_save(data)

	# Load scanner from new format.
	if data.has("scanner"):
		var scanner_type: StringName = StringName(data["scanner"])
		if scanner_type != &"":
			_tool_slots[&"scanner"] = scanner_type

	# Load tools from old format (backward compat).
	if data.has("tools"):
		var tools_data: Dictionary = data["tools"]
		for key in tools_data:
			var slot: StringName = StringName(key)
			# Only accept scanner in the new model; other tools are grid items.
			if slot == &"scanner":
				_tool_slots[slot] = StringName(tools_data[key])


func _load_grid_save(data: Dictionary) -> void:
	grid_width = int(data.get("grid_width", 30))
	grid_height = int(data.get("grid_height", 40))
	_items.clear()
	_next_id = 1
	_init_grid()

	var items_data: Array = data.get("items", [])
	for entry in items_data:
		var item_id: int = int(entry.get("id", _next_id))
		# Sanitize: item_id must be >= 1 (0 is the empty-cell sentinel).
		if item_id < 1:
			item_id = _next_id
		var type: StringName = StringName(entry.get("type", ""))
		if type == &"":
			continue
		var origin_arr: Array = entry.get("origin", [0, 0])
		var origin: Vector2i = Vector2i(int(origin_arr[0]), int(origin_arr[1]))
		var rotation: int = int(entry.get("rotation", 0))
		var shape: Array[Vector2i] = _get_shape_for_type(type)

		if can_fit(shape, origin, rotation):
			_items[item_id] = {
				"type": type,
				"origin": origin,
				"rotation": rotation,
				"shape": shape,
			}
			_write_cells(item_id, shape, origin, rotation)
		else:
			push_warning(
				"Inventory.load: item %d (%s) no longer fits at %s rot %d — skipped"
				% [item_id, type, origin, rotation]
			)

		if item_id >= _next_id:
			_next_id = item_id + 1


func _load_legacy_save(data: Dictionary) -> void:
	## Load old slot-based save format: replay items into the grid.
	grid_width = 30
	grid_height = 40
	_items.clear()
	_next_id = 1
	_init_grid()

	var slots_data: Array = data.get("slots", [])
	for entry in slots_data:
		var type: StringName = StringName(entry.get("type", ""))
		if type == &"":
			continue
		var quantity: int = int(entry.get("quantity", 0))
		var shape: Array[Vector2i] = _get_shape_for_type(type)
		for _i in quantity:
			var placement: Dictionary = find_placement(shape)
			if placement.is_empty():
				push_warning(
					"Inventory.load_legacy: no room for %s — skipped" % type
				)
				break
			_place_internal(type, shape, placement["origin"], placement["rotation"])
