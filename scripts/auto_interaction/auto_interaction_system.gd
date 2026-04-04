extends Node
class_name AutoInteractionSystem

## Auto-interaction system — child of Player.
## Resource config, tool tables, weapon tables, can_gather utility,
## auto-gather flow (continuous world-space proximity, tween timer, chaining),
## respawn queue, auto-defend stub, and auto-pickup stub.

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

# --- Signals ---

signal auto_gather_started(coords: Vector2i, resource_type: StringName)
signal auto_gather_completed(coords: Vector2i, resource_type: StringName, amount: int)
signal auto_gather_failed(coords: Vector2i, reason: StringName)
signal auto_defend_triggered(fauna_id: int, damage: int)
signal ground_item_picked_up(item_name: StringName, amount: int)

# --- Tool Priority ---
# Higher = gathered first when multiple candidates exist

const TOOL_PRIORITY: Dictionary = {
	&"stone_pickaxe": 2,
	&"stone_axe": 1,
	&"": 0,
}

# --- Weapon Damage ---

const WEAPON_DAMAGE: Dictionary = {
	&"survival_knife": 10,
	&"": 5,
}

# --- Proximity Gather Config ---

## World-space gather radius in Godot units (0.75u = 1.5m real = arm's reach)
const GATHER_RADIUS: float = 0.75

## Throttle interval for proximity checks (seconds)
const PROXIMITY_CHECK_INTERVAL: float = 0.1

# --- Auto-Defend Config ---

const AUTO_DEFEND_CONFIG: Dictionary = {
	"attack_cooldown": 1.0,
	"attack_range": 1,
}

# --- Properties ---

var _is_gathering: bool = false
var _gather_target_coords: Vector2i = Vector2i.ZERO
var _gather_target_index: int = -1
var _gather_tween: Tween = null
var _defend_cooldown: float = 0.0
var _respawn_queue: Array = []
var _proximity_timer: float = 0.0

# --- External references (set via _ready or injection for tests) ---

var _grid: Node = null       # HexGrid autoload
var _player: Node = null     # Parent Player node
var _catalog: RefCounted = null  # Catalog (from sibling ScannerSystem)
var _inventory: RefCounted = null  # Inventory (from Player)


# --- Lifecycle ---

func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_player = get_parent()
	_connect_signals()
	# Defer fetching catalog + inventory to let siblings initialize
	call_deferred("_resolve_dependencies")


func _resolve_dependencies() -> void:
	if _player == null:
		return
	# Get inventory from Player
	if _inventory == null and _player.has_method("get_inventory"):
		_inventory = _player.get_inventory()
	# Get catalog from sibling ScannerSystem
	if _catalog == null:
		var scanner: Node = _player.get_node_or_null("ScannerSystem")
		if scanner != null and "catalog" in scanner:
			_catalog = scanner.catalog
		elif scanner != null and "_catalog" in scanner:
			_catalog = scanner._catalog


func _process(delta: float) -> void:
	_tick_respawn_queue(delta)
	if _defend_cooldown > 0.0:
		_defend_cooldown -= delta
	# Continuous proximity gather check (throttled)
	_proximity_timer += delta
	if _proximity_timer >= PROXIMITY_CHECK_INTERVAL:
		_proximity_timer = 0.0
		_check_gather_proximity()


func _connect_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("tile_entered"):
		_grid.tile_entered.connect(_on_tile_entered)
	# Auto-defend: connect to FaunaManager.fauna_moved if available
	_connect_fauna_manager()


# --- Continuous Proximity Gather ---

## Check for gatherable resources within GATHER_RADIUS of the player's world position.
func _check_gather_proximity() -> void:
	if _is_gathering:
		return  # Already gathering — chain will re-check after completion
	if _player == null or not "current_tile" in _player:
		return
	_try_gather_nearby(_player.current_tile)


# --- Utility: can_gather ---

## Returns true if the player can gather the given resource prop.
## Bare-hands resources (tool_required == "") always pass.
## Tool-gated resources require an exact match in the corresponding inventory slot.
func can_gather(node: Resource, inventory: RefCounted) -> bool:
	if node.tool_required == &"":
		return true
	var cfg: Dictionary = _Inventory.ITEM_CONFIG.get(node.tool_required, {})
	var slot: StringName = cfg.get("tool_slot", &"")
	if slot == &"":
		return false
	return inventory.get_tool(slot) == node.tool_required


# --- Auto-Gather Flow ---

## Called when player enters a new tile. Triggers auto-pickup only.
func _on_tile_entered(coords: Vector2i) -> void:
	_try_auto_pickup(coords)


## Find the best gatherable resource within GATHER_RADIUS around the given coords.
## Returns true if a gather was started.
func _try_gather_nearby(center: Vector2i) -> bool:
	if _grid == null or _catalog == null or _inventory == null:
		return false

	var candidates: Array = _find_gather_candidates(center)
	if candidates.is_empty():
		return false

	# Sort: TOOL_PRIORITY desc, then world distance asc
	candidates.sort_custom(_compare_candidates)

	var best: Dictionary = candidates[0]
	_begin_gather(best["coords"], best["resource_index"], best["node"])
	return true


## Scan current tile + 6 neighbors for gatherable resources within GATHER_RADIUS.
## Uses world-space distance (XZ plane) instead of hex distance.
## Returns array of candidate dictionaries.
func _find_gather_candidates(center: Vector2i) -> Array:
	var candidates: Array = []
	var tiles_to_check: Array[Vector2i] = [center]
	tiles_to_check.append_array(_grid.get_neighbors(center))

	# Player world position on XZ plane
	var player_pos_xz: Vector2 = Vector2.ZERO
	if _player != null and "global_position" in _player:
		player_pos_xz = Vector2(_player.global_position.x, _player.global_position.z)
	elif _player != null and "position" in _player:
		player_pos_xz = Vector2(_player.position.x, _player.position.z)

	for tile_coords in tiles_to_check:
		var tile = _grid.get_tile(tile_coords)
		if tile == null:
			continue

		# Tile center in world space
		var tile_center_2d: Vector2 = _grid.axial_to_world(tile_coords)

		for i in tile.props.size():
			var prop: Resource = tile.props[i]
			if prop.category != _Prop.Category.RESOURCE:
				continue
			if prop.remaining <= 0:
				continue  # Depleted

			# Catalog gate: must be CATALOGED
			var entry_id: StringName = ResourceRegistry.get_def(prop.type).catalog_entry if ResourceRegistry.has_def(prop.type) else &""
			if entry_id == &"":
				continue
			if not _catalog.is_cataloged(entry_id):
				continue

			# Tool gate (silent skip — no signal for tool_gated)
			if not can_gather(prop, _inventory):
				continue

			# Compute world-space position of this resource prop
			var sub_hex_offset: Vector2 = _HexMath.sub_axial_to_world(prop.sub_hex)
			var resource_pos_xz: Vector2 = Vector2(
				tile_center_2d.x + sub_hex_offset.x,
				tile_center_2d.y + sub_hex_offset.y
			)

			# World-space distance on XZ plane
			var world_dist: float = player_pos_xz.distance_to(resource_pos_xz)
			if world_dist > GATHER_RADIUS:
				continue  # Out of arm's reach

			var priority: int = TOOL_PRIORITY.get(prop.tool_required, 0)
			candidates.append({
				"coords": tile_coords,
				"resource_index": i,
				"node": prop,
				"priority": priority,
				"distance": world_dist,
			})

	return candidates


## Comparison function for sorting candidates: higher priority first, then nearer first (world distance).
func _compare_candidates(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] != b["priority"]:
		return a["priority"] > b["priority"]
	return a["distance"] < b["distance"]


## Begin gathering a specific resource prop. Creates the tween timer.
func _begin_gather(coords: Vector2i, resource_index: int, node: Resource) -> void:
	_is_gathering = true
	_gather_target_coords = coords
	_gather_target_index = resource_index

	# Compute effective gather time
	var base_time: float = ResourceRegistry.get_def(node.type).gather_time if ResourceRegistry.has_def(node.type) else 1.0
	var tool_slot: StringName = _Inventory.ITEM_CONFIG.get(node.tool_required, {}).get("tool_slot", &"")
	var equipped: StringName = _inventory.get_tool(tool_slot) if tool_slot != &"" else &""
	var multiplier: float = ResourceRegistry.get_tool_speed(node.type, equipped)
	var effective_time: float = base_time * multiplier

	auto_gather_started.emit(coords, node.type)

	# Create tween — gather ALWAYS completes, no cancel
	if _gather_tween != null and _gather_tween.is_valid():
		_gather_tween.kill()

	_gather_tween = create_tween()
	_gather_tween.tween_interval(effective_time)
	_gather_tween.finished.connect(_on_gather_tween_complete)


## Called when the gather tween finishes. Applies results and chains.
func _on_gather_tween_complete() -> void:
	var coords: Vector2i = _gather_target_coords
	var index: int = _gather_target_index
	_gather_tween = null

	# Get the resource prop
	var tile = _grid.get_tile(coords)
	if tile == null or index < 0 or index >= tile.props.size():
		_is_gathering = false
		return

	var node: Resource = tile.props[index]
	var amount: int = ResourceRegistry.get_def(node.type).gather_amount if ResourceRegistry.has_def(node.type) else 1

	# Resolve yield type (e.g. loose_rock yields stone)
	var yield_type: StringName = ResourceRegistry.get_yield_type(node.type)

	# Try to add to inventory
	var added: int = _inventory.add_item(yield_type, amount)

	if added > 0:
		node.remaining -= 1
		auto_gather_completed.emit(coords, node.type, added)

		# Check depletion
		if node.remaining <= 0:
			_grid.resource_depleted.emit(coords, node.type)
			# Add to respawn queue if respawn_time > 0
			if node.respawn_time > 0.0:
				_respawn_queue.append({
					"coords": coords,
					"resource_index": index,
					"time_remaining": node.respawn_time,
				})
	else:
		auto_gather_failed.emit(coords, &"inventory_full")

	_is_gathering = false

	# Chain: re-check from player's CURRENT position
	if _player != null and "current_tile" in _player:
		_try_gather_nearby(_player.current_tile)


# --- Respawn Queue ---

## Tick respawn timers. Always ticks (fog system removed).
## On expire: reset node.remaining = max_amount, emit HexGrid.resource_respawned.
func _tick_respawn_queue(delta: float) -> void:
	var i: int = _respawn_queue.size() - 1
	while i >= 0:
		var entry: Dictionary = _respawn_queue[i]
		var coords: Vector2i = entry["coords"]
		entry["time_remaining"] -= delta
		if entry["time_remaining"] <= 0.0:
			# Respawn the resource
			var tile = _grid.get_tile(coords) if _grid != null else null
			if tile != null:
				var idx: int = entry["resource_index"]
				if idx >= 0 and idx < tile.props.size():
					var node: Resource = tile.props[idx]
					node.remaining = node.max_amount
					_grid.resource_respawned.emit(coords, node.type)
			_respawn_queue.remove_at(i)
		i -= 1


# --- Auto-Defend Stub ---

var _fauna_manager: Node = null


## Attempt to connect to FaunaManager.fauna_moved signal.
## If FaunaManager is not available, this is a no-op.
func _connect_fauna_manager() -> void:
	var fm: Node = get_node_or_null("/root/FaunaManager")
	if fm == null:
		return
	if not fm.has_signal("fauna_moved"):
		return
	_fauna_manager = fm
	fm.fauna_moved.connect(_on_fauna_moved)


## Called when fauna moves. Checks adjacent tiles for cataloged hostile fauna,
## applies cooldown gate, looks up weapon damage, emits auto_defend_triggered.
func _on_fauna_moved(fauna_id: int, coords: Vector2i) -> void:
	if _player == null or _grid == null or _catalog == null:
		return
	if _defend_cooldown > 0.0:
		return
	var player_tile: Vector2i = _player.current_tile if "current_tile" in _player else Vector2i.ZERO
	var dist: int = _grid.distance(player_tile, coords)
	if dist > AUTO_DEFEND_CONFIG["attack_range"]:
		return
	# Check if fauna is cataloged or encountered AND hostile
	if _fauna_manager == null:
		return
	if not _fauna_manager.has_method("get_fauna_entry_id"):
		return
	var entry_id: StringName = _fauna_manager.get_fauna_entry_id(fauna_id)
	if entry_id == &"":
		return
	# Must be ENCOUNTERED or CATALOGED
	var state: int = _catalog.get_knowledge_state(entry_id)
	if state < _Catalog.KnowledgeState.ENCOUNTERED:
		return
	# Must be hostile
	if not _fauna_manager.has_method("is_hostile"):
		return
	if not _fauna_manager.is_hostile(fauna_id):
		return
	# Weapon lookup
	var weapon: StringName = &""
	if _inventory != null:
		var equipped: StringName = _inventory.get_tool(&"weapon") if _inventory.has_method("get_tool") else &""
		if equipped != &"":
			weapon = equipped
	var damage: int = WEAPON_DAMAGE.get(weapon, WEAPON_DAMAGE.get(&"", 5))
	_defend_cooldown = AUTO_DEFEND_CONFIG["attack_cooldown"]
	auto_defend_triggered.emit(fauna_id, damage)


# --- Auto-Pickup Stub ---

## On tile_entered: query SurvivalSystem for ground items and pick them up.
func _try_auto_pickup(coords: Vector2i) -> void:
	var survival: Node = get_node_or_null("/root/SurvivalSystem")
	if survival == null:
		return
	if not survival.has_method("get_ground_items_at"):
		return
	var items: Array = survival.get_ground_items_at(coords)
	if items.is_empty():
		return
	if _inventory == null:
		return
	for item in items:
		var item_name: StringName = item.get("name", &"")
		var amount: int = item.get("amount", 1)
		if item_name == &"":
			continue
		var added: int = _inventory.add_item(item_name, amount)
		if added > 0:
			ground_item_picked_up.emit(item_name, added)
