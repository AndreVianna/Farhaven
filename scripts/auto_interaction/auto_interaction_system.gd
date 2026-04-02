extends Node
class_name AutoInteractionSystem

## Auto-interaction system — child of Player.
## Resource config, tool tables, weapon tables, can_gather utility,
## and auto-gather flow (proximity check, tween timer, chaining).

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")
const _Catalog = preload("res://scripts/scanner/catalog.gd")

# --- Signals ---

signal auto_gather_started(coords: Vector2i, resource_type: StringName)
signal auto_gather_completed(coords: Vector2i, resource_type: StringName, amount: int)
signal auto_gather_failed(coords: Vector2i, reason: StringName)
signal auto_defend_triggered(fauna_id: int, damage: int)
signal ground_item_picked_up(item_name: StringName, amount: int)

# --- Resource Config Table ---
# gather_time (seconds) + gather_amount per resource type

const RESOURCE_CONFIG: Dictionary = {
	&"wood":             { "gather_time": 1.0, "gather_amount": 1 },
	&"stone":            { "gather_time": 1.5, "gather_amount": 1 },
	&"berries":          { "gather_time": 0.5, "gather_amount": 2 },
	&"fiber":            { "gather_time": 0.5, "gather_amount": 1 },
	&"ore":              { "gather_time": 2.0, "gather_amount": 1 },
	&"crystal":          { "gather_time": 2.5, "gather_amount": 1 },
	&"toxic_berries":    { "gather_time": 0.5, "gather_amount": 2 },
	&"anomaly_fragment": { "gather_time": 3.0, "gather_amount": 1 },
}

# --- Tool Speed Multipliers ---
# Multiplies gather_time for specific resource types when tool is equipped

const TOOL_SPEED: Dictionary = {
	&"stone_axe":     { &"wood": 0.5 },
	&"stone_pickaxe": { &"stone": 0.5, &"ore": 0.5, &"crystal": 0.5 },
}

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


func _connect_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("tile_entered"):
		_grid.tile_entered.connect(_on_tile_entered)


# --- Utility: can_gather ---

## Returns true if the player can gather the given resource node.
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

## Called when player enters a new tile. Triggers proximity scan for gatherable resources.
func _on_tile_entered(coords: Vector2i) -> void:
	if _is_gathering:
		return  # Already gathering — chain will re-check after completion
	_try_gather_nearby(coords)


## Find the best gatherable resource in the 7-tile area around the given coords.
## Returns true if a gather was started.
func _try_gather_nearby(center: Vector2i) -> bool:
	if _grid == null or _catalog == null or _inventory == null:
		return false

	var candidates: Array = _find_gather_candidates(center)
	if candidates.is_empty():
		return false

	# Sort: TOOL_PRIORITY desc, then distance asc
	candidates.sort_custom(_compare_candidates)

	var best: Dictionary = candidates[0]
	_begin_gather(best["coords"], best["resource_index"], best["node"])
	return true


## Scan current tile + 6 neighbors for gatherable resources.
## Returns array of candidate dictionaries.
func _find_gather_candidates(center: Vector2i) -> Array:
	var candidates: Array = []
	var tiles_to_check: Array[Vector2i] = [center]
	tiles_to_check.append_array(_grid.get_neighbors(center))

	for tile_coords in tiles_to_check:
		var tile = _grid.get_tile(tile_coords)
		if tile == null:
			continue

		for i in tile.resource_nodes.size():
			var node: Resource = tile.resource_nodes[i]
			if node.remaining <= 0:
				continue  # Depleted

			# Catalog gate: must be CATALOGED
			var entry_id: StringName = _Catalog.RESOURCE_TO_ENTRY.get(node.type, &"")
			if entry_id == &"":
				continue
			if not _catalog.is_cataloged(entry_id):
				# Emit tool_gated if cataloged-but-wrong-tool would apply,
				# but for uncataloged, silently skip
				continue

			# Tool gate
			if not can_gather(node, _inventory):
				auto_gather_failed.emit(tile_coords, &"tool_gated")
				continue

			var dist: int = _grid.distance(center, tile_coords)
			var priority: int = TOOL_PRIORITY.get(node.tool_required, 0)
			candidates.append({
				"coords": tile_coords,
				"resource_index": i,
				"node": node,
				"priority": priority,
				"distance": dist,
			})

	return candidates


## Comparison function for sorting candidates: higher priority first, then nearer first.
func _compare_candidates(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] != b["priority"]:
		return a["priority"] > b["priority"]
	return a["distance"] < b["distance"]


## Begin gathering a specific resource node. Creates the tween timer.
func _begin_gather(coords: Vector2i, resource_index: int, node: Resource) -> void:
	_is_gathering = true
	_gather_target_coords = coords
	_gather_target_index = resource_index

	# Compute effective gather time
	var base_time: float = RESOURCE_CONFIG.get(node.type, {}).get("gather_time", 1.0)
	var tool_slot: StringName = _Inventory.ITEM_CONFIG.get(node.tool_required, {}).get("tool_slot", &"")
	var equipped: StringName = _inventory.get_tool(tool_slot) if tool_slot != &"" else &""
	var multiplier: float = TOOL_SPEED.get(equipped, {}).get(node.type, 1.0)
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

	# Get the resource node
	var tile = _grid.get_tile(coords)
	if tile == null or index < 0 or index >= tile.resource_nodes.size():
		_is_gathering = false
		return

	var node: Resource = tile.resource_nodes[index]
	var amount: int = RESOURCE_CONFIG.get(node.type, {}).get("gather_amount", 1)

	# Try to add to inventory
	var added: int = _inventory.add_item(node.type, amount)

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
