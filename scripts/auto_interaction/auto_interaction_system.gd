extends Node
class_name AutoInteractionSystem

## Auto-interaction system — child of Player.
## Queries RecipeRegistry for gather recipes matching nearby props,
## filters by DiscoveryWatcher (known recipes) and PredicateEvaluator (conditions),
## runs tween-based gather timers using recipe time, resolves yields from recipe outputs.
## Also: respawn queue, auto-defend stub, and auto-pickup stub.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PredicateEvaluator = preload("res://scripts/recipes/predicate_evaluator.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")

# --- Signals (UNCHANGED — consumed by HUD, FlyToPlayer, GatherSound, etc.) ---

signal auto_gather_started(coords: Vector2i, prop_type: StringName)
signal auto_gather_completed(coords: Vector2i, prop_type: StringName, amount: int)
signal auto_gather_failed(coords: Vector2i, reason: StringName)
signal auto_defend_triggered(fauna_id: int, damage: int)
signal ground_item_picked_up(item_name: StringName, amount: int)

# --- Weapon Damage ---
# Keyed by the equipped weapon's PropDef id.

const WEAPON_DAMAGE: Dictionary = {
	&"P00204": 10,  # survival_knife
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

# --- Legacy constants kept for existing tests ---
# TOOL_SLOT_PRIORITY is no longer used for gather candidate sorting;
# recipe conditions (has_tool) replace the tool gate. Kept for test compat.
const TOOL_SLOT_PRIORITY: Dictionary = {
	&"pickaxe": 2,
	&"axe": 1,
	&"": 0,
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
var _registry: Node = null   # RecipeRegistry autoload
var _discovery: Node = null  # DiscoveryWatcher autoload


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
	# Get RecipeRegistry autoload
	if _registry == null:
		_registry = _get_autoload(&"RecipeRegistry")
	# Get DiscoveryWatcher autoload
	if _discovery == null:
		_discovery = _get_autoload(&"DiscoveryWatcher")
	# Wire catalog to DiscoveryWatcher if both are available
	if _catalog != null and _discovery != null:
		if "_catalog" in _discovery and _discovery._catalog == null:
			_discovery._catalog = _catalog
			# Re-connect the catalog signal now that we have a reference
			if _discovery.has_method("_connect_catalog_signal"):
				_discovery._connect_catalog_signal()


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


func _exit_tree() -> void:
	if _gather_tween != null and _gather_tween.is_valid():
		if _gather_tween.finished.is_connected(_on_gather_tween_complete):
			_gather_tween.finished.disconnect(_on_gather_tween_complete)
		_gather_tween.kill()
		_gather_tween = null
	if _grid != null:
		if _grid.has_signal("tile_entered") and _grid.tile_entered.is_connected(_on_tile_entered):
			_grid.tile_entered.disconnect(_on_tile_entered)
	# Note: fauna_moved connection uses a lambda, disconnected automatically on free.
	# No manual disconnect needed.


func _connect_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("tile_entered"):
		_grid.tile_entered.connect(_on_tile_entered)
	# Auto-defend: connect to FaunaManager.fauna_moved if available
	_connect_fauna_manager()


# --- Utility: can_gather (kept for backward compat with tests) ---

## Returns true if the player can gather the given prop.
## Bare-hands props (tool_required == "") always pass.
## Tool-gated props store a slot name (e.g. "pickaxe") in tool_required —
## the player passes if ANY tool is equipped in that slot.
func can_gather(node: Resource, inventory: RefCounted) -> bool:
	var slot: StringName = node.tool_required
	if slot == &"":
		return true
	return inventory.get_tool(slot) != &""


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


# --- Auto-Gather Flow ---

## Called when player enters a new tile. Reserved for future use.
func _on_tile_entered(_coords: Vector2i) -> void:
	pass


## Find the best gatherable prop within GATHER_RADIUS around the given coords.
## Returns true if a gather was started.
func _try_gather_nearby(center: Vector2i) -> bool:
	if _grid == null or _inventory == null:
		return false
	# Require either old catalog or new recipe system
	if _catalog == null and _registry == null:
		return false

	var scan: Dictionary = _find_gather_candidates(center)
	var candidates: Array = scan["candidates"]
	if candidates.is_empty():
		# If there are tool-gated props in range, emit auto_gather_failed hint.
		var tool_gated: Array = scan["tool_gated"]
		if not tool_gated.is_empty():
			var first: Dictionary = tool_gated[0]
			auto_gather_failed.emit(first["coords"], &"tool_required")
		return false

	# Sort: priority desc (tool-gated recipes first), then world distance asc
	candidates.sort_custom(_compare_candidates)

	var best: Dictionary = candidates[0]
	_begin_gather(best["coords"], best["prop_index"], best["node"], best.get("recipe"))
	return true


## Scan current tile + 6 neighbors for gatherable props within GATHER_RADIUS.
## Uses world-space distance (XZ plane) instead of hex distance.
## Now queries RecipeRegistry for matching gather recipes and uses
## DiscoveryWatcher + PredicateEvaluator for filtering.
func _find_gather_candidates(center: Vector2i) -> Dictionary:
	var candidates: Array = []
	var tool_gated: Array = []
	var player_pos_xz: Vector2 = _get_player_world_pos_xz()
	var tiles_to_check: Array[Vector2i] = [center]
	tiles_to_check.append_array(_grid.get_neighbors(center))

	for tile_coords in tiles_to_check:
		var tile = _grid.get_tile(tile_coords)
		if tile == null:
			continue
		_scan_tile_for_candidates(tile, tile_coords, player_pos_xz, candidates, tool_gated)

	return {"candidates": candidates, "tool_gated": tool_gated}


## Returns the player's world-space position on the XZ plane.
func _get_player_world_pos_xz() -> Vector2:
	if _player != null and "global_position" in _player:
		return Vector2(_player.global_position.x, _player.global_position.z)
	elif _player != null and "position" in _player:
		return Vector2(_player.position.x, _player.position.z)
	return Vector2.ZERO


## Scan a single tile's props for gather candidates within GATHER_RADIUS.
func _scan_tile_for_candidates(tile: Resource, tile_coords: Vector2i,
		player_pos_xz: Vector2, candidates: Array, tool_gated: Array) -> void:
	var tile_center_2d: Vector2 = _grid.axial_to_world(tile_coords)

	for i in tile.props.size():
		var prop: Resource = tile.props[i]
		if prop.origin != Prop.Origin.NATURAL:
			continue
		if prop.remaining <= 0:
			continue

		var sub_hex_offset: Vector2 = _HexMath.sub_axial_to_world(prop.sub_hex)
		var prop_pos_xz: Vector2 = Vector2(
			tile_center_2d.x + sub_hex_offset.x,
			tile_center_2d.y + sub_hex_offset.y
		)
		var world_dist: float = player_pos_xz.distance_to(prop_pos_xz)
		if world_dist > GATHER_RADIUS:
			continue

		_evaluate_prop_candidate(prop, tile, tile_coords, i, world_dist, candidates, tool_gated)


## Evaluate a single prop against recipe system or legacy catalog gate.
func _evaluate_prop_candidate(prop: Resource, tile: Resource, tile_coords: Vector2i,
		prop_index: int, world_dist: float, candidates: Array, tool_gated: Array) -> void:
	var matched_recipe: Resource = _find_gather_recipe(prop, tile, tile_coords)
	if matched_recipe == null:
		_try_legacy_catalog_gate(prop, candidates, tool_gated, tile_coords, prop_index, world_dist)
		return

	var ctx: _WorldContext = _build_context(tile, tile_coords)
	var conditions_pass := true
	var tool_blocked := false
	for cond in matched_recipe.conditions:
		if cond.predicate != null:
			if not _PredicateEvaluator.evaluate(cond.predicate, ctx):
				conditions_pass = false
				if cond.predicate.kind == &"has_tool":
					tool_blocked = true
				break

	if not conditions_pass:
		if tool_blocked:
			tool_gated.append({
				"coords": tile_coords,
				"prop_index": prop_index,
				"node": prop,
				"distance": world_dist,
			})
		return

	var priority: int = _get_recipe_priority(matched_recipe)
	candidates.append({
		"coords": tile_coords,
		"prop_index": prop_index,
		"node": prop,
		"priority": priority,
		"distance": world_dist,
		"recipe": matched_recipe,
	})


## Find a matching gather recipe for the given prop.
## Returns the first eligible recipe or null.
func _find_gather_recipe(prop: Resource, _tile: Resource, _tile_coords: Vector2i) -> Resource:
	if _registry == null:
		return null
	var recipes: Array = _registry.find_recipes_for_input(prop.type)
	for recipe in recipes:
		# Only consider recipes with "gather" action
		if not recipe.actions.has(&"gather"):
			continue
		# Must be known (DiscoveryWatcher filter)
		if _discovery != null and not _discovery.is_known(recipe.id):
			continue
		return recipe
	return null


## Legacy catalog gate fallback — used when RecipeRegistry is not available.
func _try_legacy_catalog_gate(prop: Resource, candidates: Array, tool_gated: Array,
		tile_coords: Vector2i, prop_index: int, world_dist: float) -> bool:
	if _catalog == null:
		return false
	if not PropRegistry.has_def(prop.type):
		return false
	var def = PropRegistry.get_def(prop.type)
	if def.catalogable == null or String(def.display_name) == "":
		return false
	var entry_id: StringName = def.id
	if not _catalog.is_cataloged(entry_id):
		return false
	# Tool gate
	if not can_gather(prop, _inventory):
		tool_gated.append({
			"coords": tile_coords,
			"prop_index": prop_index,
			"node": prop,
			"distance": world_dist,
		})
		return false

	var priority: int = TOOL_SLOT_PRIORITY.get(prop.tool_required, 0)
	candidates.append({
		"coords": tile_coords,
		"prop_index": prop_index,
		"node": prop,
		"priority": priority,
		"distance": world_dist,
	})
	return true


## Get priority for a recipe-based candidate. Tool-gated recipes get higher priority.
func _get_recipe_priority(recipe: Resource) -> int:
	var max_priority: int = 0
	for cond in recipe.conditions:
		if cond.predicate != null and cond.predicate.kind == &"has_tool":
			var tool_name: StringName = StringName(cond.predicate.params.get("tool", ""))
			var p: int = TOOL_SLOT_PRIORITY.get(tool_name, 1)
			if p > max_priority:
				max_priority = p
	return max_priority


## Comparison function for sorting candidates: higher priority first, then nearer first.
func _compare_candidates(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] != b["priority"]:
		return a["priority"] > b["priority"]
	return a["distance"] < b["distance"]


## Begin gathering a specific prop. Creates the tween timer.
## If a recipe is provided, uses its time field; otherwise falls back to PropDef.
func _begin_gather(coords: Vector2i, prop_index: int, node: Resource, recipe: Resource = null) -> void:
	_is_gathering = true
	_gather_target_coords = coords
	_gather_target_index = prop_index

	# Compute effective gather time
	var effective_time: float = 1.0
	if recipe != null:
		effective_time = recipe.duration
	else:
		# Legacy fallback: use PropDef gather_time + tool speed
		if PropRegistry.has_def(node.type):
			var def = PropRegistry.get_def(node.type)
			var base_time: float = def.gather_time
			var tool_slot: StringName = node.tool_required
			var equipped: StringName = _inventory.get_tool(tool_slot) if tool_slot != &"" else &""
			var multiplier: float = PropRegistry.get_tool_speed(node.type, equipped)
			effective_time = base_time * multiplier

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


# --- Build WorldContext for predicate evaluation ---

func _build_context(tile: Resource, _tile_coords: Vector2i) -> _WorldContext:
	var ctx := _WorldContext.new()
	ctx.player = _player
	ctx.tile = tile
	ctx.grid = _grid
	if _catalog != null:
		ctx.catalog = _catalog
	# Auto-fill day_night from autoload
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		ctx.day_night = tree.root.get_node_or_null("DayNightCycle")
	return ctx


# --- Auto-Defend Stub ---

var _fauna_manager: Node = null


## Attempt to connect to FaunaManager.fauna_moved signal.
## FaunaManager is a sibling node (child of Player).
## If not available at _ready time, main.gd wires the connection instead.
func _connect_fauna_manager() -> void:
	if _player == null:
		return
	var fm: Node = _player.get_node_or_null("FaunaManager")
	if fm == null:
		return
	if not fm.has_signal("fauna_moved"):
		return
	_fauna_manager = fm
	# fauna_moved signal has 4 args: (id, old_coords, new_coords, species_type)
	# Wrap to match our 2-arg handler.
	fm.fauna_moved.connect(
		func(id: int, _old: Vector2i, new_c: Vector2i, _sp: StringName) -> void:
			_on_fauna_moved(id, new_c)
	)


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


# --- Autoload helpers ---


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
