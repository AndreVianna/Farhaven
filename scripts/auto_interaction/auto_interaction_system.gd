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

signal auto_gather_started(coords: Vector2i, prop_type: StringName)
signal auto_gather_completed(coords: Vector2i, prop_type: StringName, amount: int)
signal auto_gather_failed(coords: Vector2i, reason: StringName)
signal auto_defend_triggered(fauna_id: int, damage: int)
signal ground_item_picked_up(item_name: StringName, amount: int)

# --- Tool Priority ---
# Higher = gathered first when multiple candidates exist.
# Keyed by the tool slot name on the prop (PropDef.tool_required).
# Pickaxe-gated props are gathered before axe-gated, then bare-handed.

const TOOL_SLOT_PRIORITY: Dictionary = {
	&"pickaxe": 2,
	&"axe": 1,
	&"": 0,
}

# --- Weapon Damage ---
# Keyed by the equipped weapon's PropDef id.

const WEAPON_DAMAGE: Dictionary = {
	&"00204": 10,  # survival_knife
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
	# Continuous proximity gather + pickup check (throttled)
	_proximity_timer += delta
	if _proximity_timer >= PROXIMITY_CHECK_INTERVAL:
		_proximity_timer = 0.0
		_check_gather_proximity()
		_check_pickup_proximity()


func _connect_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("tile_entered"):
		_grid.tile_entered.connect(_on_tile_entered)
	# Auto-defend: connect to FaunaManager.fauna_moved if available
	_connect_fauna_manager()


# --- Continuous Proximity Gather ---

## Check for gatherable props within GATHER_RADIUS of the player's world position.
func _check_gather_proximity() -> void:
	if _is_gathering:
		return  # Already gathering — chain will re-check after completion
	if _player == null or not "current_tile" in _player:
		return
	# Don't gather while dead
	var survival: Node = _get_survival_system()
	if survival != null and "is_dead" in survival and survival.is_dead:
		return
	_try_gather_nearby(_player.current_tile)


# --- Utility: can_gather ---

## Returns true if the player can gather the given prop.
## Bare-hands props (tool_required == "") always pass.
## Tool-gated props store a slot name (e.g. "pickaxe") in tool_required —
## the player passes if ANY tool is equipped in that slot.
func can_gather(node: Resource, inventory: RefCounted) -> bool:
	var slot: StringName = node.tool_required
	if slot == &"":
		return true
	return inventory.get_tool(slot) != &""


# --- Auto-Gather Flow ---

## Called when player enters a new tile. Reserved for future use.
func _on_tile_entered(_coords: Vector2i) -> void:
	pass


## Find the best gatherable prop within GATHER_RADIUS around the given coords.
## Returns true if a gather was started.
func _try_gather_nearby(center: Vector2i) -> bool:
	if _grid == null or _catalog == null or _inventory == null:
		return false

	var scan: Dictionary = _find_gather_candidates(center)
	var candidates: Array = scan["candidates"]
	if candidates.is_empty():
		# If there are cataloged props in range but the player lacks the
		# required tool, emit auto_gather_failed so the HUD can show a hint.
		var tool_gated: Array = scan["tool_gated"]
		if not tool_gated.is_empty():
			var first: Dictionary = tool_gated[0]
			auto_gather_failed.emit(first["coords"], &"tool_required")
		return false

	# Sort: TOOL_PRIORITY desc, then world distance asc
	candidates.sort_custom(_compare_candidates)

	var best: Dictionary = candidates[0]
	_begin_gather(best["coords"], best["prop_index"], best["node"])
	return true


## Scan current tile + 6 neighbors for gatherable props within GATHER_RADIUS.
## Uses world-space distance (XZ plane) instead of hex distance.
## Returns a dictionary with two arrays:
##   "candidates": props the player can gather now (cataloged + tool available)
##   "tool_gated": props the player could gather with the right tool
## The tool_gated list lets callers surface a UI hint when the only reachable
## props are blocked by the tool gate.
func _find_gather_candidates(center: Vector2i) -> Dictionary:
	var candidates: Array = []
	var tool_gated: Array = []
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
			if not prop.is_natural_category():
				continue
			if prop.remaining <= 0:
				continue  # Depleted

			# Catalog gate: must be CATALOGED
			var entry_id: StringName = PropRegistry.get_def(prop.type).catalog_entry if PropRegistry.has_def(prop.type) else &""
			if entry_id == &"":
				continue
			if not _catalog.is_cataloged(entry_id):
				continue

			# Compute world-space position of this prop
			var sub_hex_offset: Vector2 = _HexMath.sub_axial_to_world(prop.sub_hex)
			var prop_pos_xz: Vector2 = Vector2(
				tile_center_2d.x + sub_hex_offset.x,
				tile_center_2d.y + sub_hex_offset.y
			)

			# World-space distance on XZ plane
			var world_dist: float = player_pos_xz.distance_to(prop_pos_xz)
			if world_dist > GATHER_RADIUS:
				continue  # Out of arm's reach

			# Tool gate: props the player cannot gather yet are still in-range
			# and reported separately so the caller can emit tool_required hints.
			if not can_gather(prop, _inventory):
				tool_gated.append({
					"coords": tile_coords,
					"prop_index": i,
					"node": prop,
					"distance": world_dist,
				})
				continue

			var priority: int = TOOL_SLOT_PRIORITY.get(prop.tool_required, 0)
			candidates.append({
				"coords": tile_coords,
				"prop_index": i,
				"node": prop,
				"priority": priority,
				"distance": world_dist,
			})

	return {"candidates": candidates, "tool_gated": tool_gated}


## Comparison function for sorting candidates: higher priority first, then nearer first (world distance).
func _compare_candidates(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] != b["priority"]:
		return a["priority"] > b["priority"]
	return a["distance"] < b["distance"]


## Begin gathering a specific prop. Creates the tween timer.
func _begin_gather(coords: Vector2i, prop_index: int, node: Resource) -> void:
	_is_gathering = true
	_gather_target_coords = coords
	_gather_target_index = prop_index

	# Compute effective gather time
	var base_time: float = PropRegistry.get_def(node.type).gather_time if PropRegistry.has_def(node.type) else 1.0
	# node.tool_required is now a slot name (e.g. "pickaxe"); look up equipped tool in that slot.
	var tool_slot: StringName = node.tool_required
	var equipped: StringName = _inventory.get_tool(tool_slot) if tool_slot != &"" else &""
	var multiplier: float = PropRegistry.get_tool_speed(node.type, equipped)
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

	# Get the prop
	var tile = _grid.get_tile(coords)
	if tile == null or index < 0 or index >= tile.props.size():
		_is_gathering = false
		return

	# Apply gathering survival cost
	var survival: Node = _get_survival_system()
	if survival and survival.has_method("apply_activity_cost"):
		survival.apply_activity_cost(&"gathering")

	var node: Resource = tile.props[index]
	var amount: int = PropRegistry.get_def(node.type).gather_amount if PropRegistry.has_def(node.type) else 1

	# Resolve yield type (e.g. loose_rock yields stone)
	var yield_type: StringName = PropRegistry.get_yield_type(node.type)

	# Try to add to inventory
	var added: int = _inventory.add_item(yield_type, amount)

	if added > 0:
		node.remaining -= 1
		auto_gather_completed.emit(coords, node.type, added)

		# Check depletion
		if node.remaining <= 0:
			_grid.prop_depleted.emit(coords, node.type)
			# Add to respawn queue if respawn_time > 0
			if node.respawn_time > 0.0:
				_respawn_queue.append({
					"coords": coords,
					"prop_index": index,
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
## On expire: reset node.remaining = max_amount, emit HexGrid.prop_respawned.
func _tick_respawn_queue(delta: float) -> void:
	var i: int = _respawn_queue.size() - 1
	while i >= 0:
		var entry: Dictionary = _respawn_queue[i]
		var coords: Vector2i = entry["coords"]
		entry["time_remaining"] -= delta
		if entry["time_remaining"] <= 0.0:
			# Respawn the prop
			var tile = _grid.get_tile(coords) if _grid != null else null
			if tile != null:
				var idx: int = entry["prop_index"]
				if idx >= 0 and idx < tile.props.size():
					var node: Resource = tile.props[idx]
					node.remaining = node.max_amount
					_grid.prop_respawned.emit(coords, node.type)
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
	# Apply attacking survival cost
	var survival_atk: Node = _get_survival_system()
	if survival_atk and survival_atk.has_method("apply_activity_cost"):
		survival_atk.apply_activity_cost(&"attacking")
	auto_defend_triggered.emit(fauna_id, damage)


# --- Survival System Helper ---


func _get_survival_system() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child != self and child.has_method("apply_activity_cost"):
			return child
	return null


# --- Auto-Pickup (Proximity-Based) ---

## Check for ground items within GATHER_RADIUS of the player's world position.
## Picks up all items at a sub-hex when the player is close enough.
func _check_pickup_proximity() -> void:
	if _player == null or not "current_tile" in _player:
		return
	var survival: Node = _get_survival_system()
	if survival == null or not survival.has_method("get_ground_items_at"):
		return
	# Don't pick up items while dead (prevents recollecting dropped items before respawn)
	if "is_dead" in survival and survival.is_dead:
		return
	if _inventory == null:
		return

	# Player world position on XZ plane
	var player_pos_xz: Vector2 = Vector2.ZERO
	if "global_position" in _player:
		player_pos_xz = Vector2(_player.global_position.x, _player.global_position.z)
	elif "position" in _player:
		player_pos_xz = Vector2(_player.position.x, _player.position.z)

	var current_tile: Vector2i = _player.current_tile
	var items: Array = survival.get_ground_items_at(current_tile)
	if items.is_empty():
		return

	# Check each ground item's sub-hex distance to player
	for item in items:
		var item_name: StringName = item.get("item_type", &"")
		var amount: int = item.get("count", 0)
		var sub_hex: Vector2i = item.get("sub_hex", Vector2i.ZERO)
		if item_name == &"" or amount <= 0:
			continue

		# Compute world position of this ground item
		var item_world_pos: Vector2 = _HexMath.prop_world_position(current_tile, sub_hex)
		var dist: float = player_pos_xz.distance_to(item_world_pos)
		if dist > GATHER_RADIUS:
			continue

		# Pick up all items at this sub-hex
		var added: int = _inventory.add_item(item_name, amount)
		if added > 0:
			survival.remove_ground_item(current_tile, item_name, added, sub_hex)
			ground_item_picked_up.emit(item_name, added)
