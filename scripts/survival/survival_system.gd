extends Node

## SurvivalSystem — stat tick, consume, take_damage, death, respawn, ground items.
## Child of Player. Reads DayNightCycle.is_daytime for HP regen condition.
## task-029 adds death, respawn, ground items, and scene wiring.

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

signal stat_changed(stat_name: StringName, current: float, max_val: float)
signal player_died()
signal player_respawned()
signal ground_item_dropped(tile: Vector2i, item_type: StringName, count: int, sub_hex: Vector2i)
signal ground_item_picked_up(tile: Vector2i, item_type: StringName, count: int)

const STAT_CONFIG: Dictionary = {
	"hunger_rate": 0.4,
	"thirst_rate": 0.8,
	"hp_drain_no_hunger": 0.1,
	"hp_drain_no_thirst": 0.2,
	"hp_regen_day": 0.5,
}

const CONSUMABLE_CONFIG: Dictionary = {
	&"berries":       {"hunger": 5.0, "thirst": 10.0,  "toxic": 0.0},
	&"toxic_berries": {"hunger": 10.0, "thirst": 0.0,  "toxic": 25.0},
	&"meat":          {"hunger": 25.0, "thirst": 0.0,  "toxic": 0.0},
}

const ACTIVITY_CONFIG: Dictionary = {
	&"gathering": {
		"cost": {"health": 0.0, "thirst": 0.2, "hunger": 0.1},
		"drain": {"health": 0.0, "thirst": 0.0, "hunger": 0.0},
	},
	&"crafting": {
		"cost": {"health": 0.0, "thirst": 0.5, "hunger": 0.2},
		"drain": {"health": 0.0, "thirst": 0.0, "hunger": 0.0},
	},
	&"scanning": {
		"cost": {"health": 0.0, "thirst": 0.1, "hunger": 0.05},
		"drain": {"health": 0.0, "thirst": 0.05, "hunger": 0.02},
	},
	&"building": {
		"cost": {"health": 0.0, "thirst": 1.0, "hunger": 0.5},
		"drain": {"health": 0.0, "thirst": 0.1, "hunger": 0.05},
	},
	&"attacking": {
		"cost": {"health": 0.0, "thirst": 0.3, "hunger": 0.2},
		"drain": {"health": 0.0, "thirst": 0.0, "hunger": 0.0},
	},
	&"moving": {
		"cost": {"health": 0.0, "thirst": 0.0, "hunger": 0.0},
		"drain": {"health": 0.0, "thirst": 0.05, "hunger": 0.02},
	},
}

## Tools are never dropped on death.
const TOOL_TYPES: Array[StringName] = [
	&"stone_axe", &"stone_pickaxe", &"survival_knife", &"scanner",
]

var hp: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var hp_max: float = 100.0
var hunger_max: float = 100.0
var thirst_max: float = 100.0
var is_dead: bool = false

var _inventory: _Inventory
var _day_night_cycle: Node  # DayNightCycle autoload or test substitute
var _hex_grid: Node  # HexGrid autoload or test substitute
var _screen_fade: Node  # ScreenFade CanvasLayer or null
var _respawn_tile: Vector2i = Vector2i.ZERO
var _ground_items: Array[Dictionary] = []
var _waiting_for_dawn: bool = false
var _active_drains: Dictionary = {}  # StringName → drain dict


func _ready() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method(&"get_inventory"):
		_inventory = parent.get_inventory()
	if _day_night_cycle == null:
		_day_night_cycle = get_node_or_null("/root/DayNightCycle")
	if _hex_grid == null:
		_hex_grid = get_node_or_null("/root/HexGrid")
	if _inventory:
		_inventory.item_used.connect(_on_item_used)
	# Connect shelter signals for respawn tile updates
	if _hex_grid:
		if _hex_grid.has_signal("structure_placed"):
			_hex_grid.structure_placed.connect(_on_structure_placed)
		if _hex_grid.has_signal("structure_destroyed"):
			_hex_grid.structure_destroyed.connect(_on_structure_destroyed)
	# Connect dawn signal for deferred night-death respawn
	if _day_night_cycle:
		if _day_night_cycle.has_signal("dawn"):
			_day_night_cycle.dawn.connect(_on_dawn)
	# Look for ScreenFade in tree
	if _screen_fade == null:
		_screen_fade = get_node_or_null("/root/Main/ScreenFade")


func _process(delta: float) -> void:
	if is_dead:
		return
	_tick(delta)


func _tick(delta: float) -> void:
	hunger -= STAT_CONFIG["hunger_rate"] * delta
	thirst -= STAT_CONFIG["thirst_rate"] * delta

	# Activity drains (on top of passive drain)
	for drain: Dictionary in _active_drains.values():
		hunger -= drain["hunger"] * delta
		thirst -= drain["thirst"] * delta
		hp -= drain["health"] * delta

	var hp_drain: float = 0.0
	if hunger <= 0.0:
		hp_drain += STAT_CONFIG["hp_drain_no_hunger"]
	if thirst <= 0.0:
		hp_drain += STAT_CONFIG["hp_drain_no_thirst"]
	if hp_drain > 0.0:
		hp -= hp_drain * delta

	var is_daytime: bool = true
	if _day_night_cycle != null:
		is_daytime = _day_night_cycle.is_daytime
	if is_daytime and hunger > 0.0 and thirst > 0.0:
		hp += STAT_CONFIG["hp_regen_day"] * delta

	hp = clampf(hp, 0.0, hp_max)
	hunger = clampf(hunger, 0.0, hunger_max)
	thirst = clampf(thirst, 0.0, thirst_max)

	stat_changed.emit(&"hp", hp, hp_max)
	stat_changed.emit(&"hunger", hunger, hunger_max)
	stat_changed.emit(&"thirst", thirst, thirst_max)

	_check_death()


func consume(item_type: StringName) -> void:
	if not CONSUMABLE_CONFIG.has(item_type):
		return
	var cfg: Dictionary = CONSUMABLE_CONFIG[item_type]
	hunger = minf(hunger + cfg["hunger"], hunger_max)
	thirst = minf(thirst + cfg["thirst"], thirst_max)
	var toxic: float = cfg["toxic"]
	if toxic > 0.0:
		take_damage(toxic)


func take_damage(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	stat_changed.emit(&"hp", hp, hp_max)
	_check_death()


func _check_death() -> void:
	if hp <= 0.0 and not is_dead:
		is_dead = true
		_execute_death()


func _on_item_used(item_type: StringName) -> void:
	consume(item_type)


# --- Activity costs ---


## Apply the one-time cost of an activity. Called when activity starts or completes.
func apply_activity_cost(activity: StringName) -> void:
	if is_dead:
		return
	if not ACTIVITY_CONFIG.has(activity):
		return
	var cost: Dictionary = ACTIVITY_CONFIG[activity]["cost"]
	hp = clampf(hp - cost["health"], 0.0, hp_max)
	hunger = clampf(hunger - cost["hunger"], 0.0, hunger_max)
	thirst = clampf(thirst - cost["thirst"], 0.0, thirst_max)
	stat_changed.emit(&"hp", hp, hp_max)
	stat_changed.emit(&"hunger", hunger, hunger_max)
	stat_changed.emit(&"thirst", thirst, thirst_max)
	_check_death()


## Start continuous drain for a duration-based activity (scanning, building, moving).
func start_activity_drain(activity: StringName) -> void:
	if ACTIVITY_CONFIG.has(activity):
		_active_drains[activity] = ACTIVITY_CONFIG[activity]["drain"]


## Stop continuous drain when the activity ends.
func stop_activity_drain(activity: StringName) -> void:
	_active_drains.erase(activity)


# --- Death sequence ---

func _execute_death() -> void:
	var death_tile: Vector2i = _get_player_tile()
	_drop_items(death_tile)
	player_died.emit()
	_start_death_sequence()


func _get_player_tile() -> Vector2i:
	var parent: Node = get_parent()
	if parent and "current_tile" in parent:
		return parent.current_tile
	return Vector2i.ZERO


func _drop_items(death_tile: Vector2i) -> void:
	if _inventory == null:
		return
	# Get sub-hex position from player world position
	var sub_hex: Vector2i = Vector2i.ZERO
	var parent: Node = get_parent()
	if parent and "global_position" in parent:
		var hex_center: Vector2 = _HexMath.axial_to_world(death_tile)
		var offset: Vector2 = Vector2(parent.global_position.x, parent.global_position.z) - hex_center
		sub_hex = _HexMath.world_to_sub_axial(offset)

	var slots: Array[Dictionary] = _inventory.get_slots()
	for slot: Dictionary in slots:
		var item_type: StringName = slot["type"]
		if item_type == &"":
			continue
		# Skip tools — they are not dropped
		if item_type in TOOL_TYPES:
			continue
		var count: int = slot["quantity"]
		_inventory.remove_item(item_type, count)
		add_ground_item(death_tile, item_type, count, sub_hex)
		ground_item_dropped.emit(death_tile, item_type, count, sub_hex)


func _start_death_sequence() -> void:
	if _screen_fade != null and _screen_fade.has_method("fade_out"):
		_screen_fade.fade_out()
		if _screen_fade.has_signal("fade_out_completed"):
			await _screen_fade.fade_out_completed
		_try_respawn()
	else:
		# No screen fade (test/headless) — skip to dawn if night, then respawn.
		var is_day: bool = true
		if _day_night_cycle != null:
			is_day = _day_night_cycle.is_daytime
		if not is_day and _day_night_cycle != null and _day_night_cycle.has_method("skip_to_dawn"):
			_day_night_cycle.skip_to_dawn()
		respawn()


func _try_respawn() -> void:
	var is_daytime: bool = true
	if _day_night_cycle != null:
		is_daytime = _day_night_cycle.is_daytime
	if not is_daytime and _day_night_cycle != null and _day_night_cycle.has_method("skip_to_dawn"):
		_day_night_cycle.skip_to_dawn()
	respawn()


func _on_dawn() -> void:
	if _waiting_for_dawn:
		_waiting_for_dawn = false
		respawn()


func respawn() -> void:
	hp = hp_max
	hunger = hunger_max * 0.5
	thirst = thirst_max * 0.5
	is_dead = false
	# Teleport player to respawn tile
	var parent: Node = get_parent()
	if parent and parent.has_method("_snap_to_tile"):
		parent.current_tile = _respawn_tile
		parent._snap_to_tile(_respawn_tile)
	player_respawned.emit()
	# Fade in
	if _screen_fade and _screen_fade.has_method("fade_in"):
		_screen_fade.fade_in()


# --- Shelter / Respawn tile ---

func _on_structure_placed(coords: Vector2i, structure_type: StringName) -> void:
	if PropRegistry.has_def(structure_type):
		var def: Resource = PropRegistry.get_def(structure_type)
		if def.is_respawn_point:
			_respawn_tile = coords


func _on_structure_destroyed(coords: Vector2i, structure_type: StringName) -> void:
	if _respawn_tile == coords:
		_respawn_tile = Vector2i.ZERO


# --- Ground items API ---

func get_ground_items_at(tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _ground_items:
		if entry["tile"] == tile:
			result.append(entry)
	return result


func add_ground_item(tile: Vector2i, item_type: StringName, count: int, sub_hex: Vector2i = Vector2i.ZERO) -> void:
	# Try to merge with existing entry on same tile, type, and sub_hex
	for entry: Dictionary in _ground_items:
		if entry["tile"] == tile and entry["item_type"] == item_type and entry["sub_hex"] == sub_hex:
			entry["count"] += count
			return
	_ground_items.append({"tile": tile, "sub_hex": sub_hex, "item_type": item_type, "count": count})


func remove_ground_item(tile: Vector2i, item_type: StringName, count: int, sub_hex: Vector2i = Vector2i.ZERO) -> int:
	for i in range(_ground_items.size() - 1, -1, -1):
		var entry: Dictionary = _ground_items[i]
		if entry["tile"] == tile and entry["item_type"] == item_type and entry["sub_hex"] == sub_hex:
			var removed: int = mini(entry["count"], count)
			entry["count"] -= removed
			if entry["count"] <= 0:
				_ground_items.remove_at(i)
			ground_item_picked_up.emit(tile, item_type, removed)
			return removed
	return 0


func get_all_ground_items() -> Array[Dictionary]:
	return _ground_items.duplicate()


# --- Fauna meat stub (activates with F-010) ---

func _on_fauna_killed(_coords: Vector2i, _fauna_type: StringName) -> void:
	# Stub: will add meat to ground items when fauna system arrives.
	pass


# --- Save / Load ---

func get_save_data() -> Dictionary:
	var ground_data: Array = []
	for entry: Dictionary in _ground_items:
		ground_data.append({
			"tile_col": entry["tile"].x,
			"tile_row": entry["tile"].y,
			"sub_hex_q": entry["sub_hex"].x,
			"sub_hex_r": entry["sub_hex"].y,
			"item_type": String(entry["item_type"]),
			"count": entry["count"],
		})
	return {
		"hp": hp,
		"hunger": hunger,
		"thirst": thirst,
		"respawn_tile_col": _respawn_tile.x,
		"respawn_tile_row": _respawn_tile.y,
		"ground_items": ground_data,
	}


func load_save_data(data: Dictionary) -> void:
	hp = data.get("hp", 100.0)
	hunger = data.get("hunger", 100.0)
	thirst = data.get("thirst", 100.0)
	# is_dead is never saved — always respawn on load
	is_dead = false
	_waiting_for_dawn = false
	_respawn_tile = Vector2i(
		int(data.get("respawn_tile_col", 0)),
		int(data.get("respawn_tile_row", 0)),
	)
	_ground_items.clear()
	var ground_data: Array = data.get("ground_items", [])
	for entry in ground_data:
		_ground_items.append({
			"tile": Vector2i(int(entry["tile_col"]), int(entry["tile_row"])),
			"sub_hex": Vector2i(int(entry.get("sub_hex_q", 0)), int(entry.get("sub_hex_r", 0))),
			"item_type": StringName(entry["item_type"]),
			"count": int(entry["count"]),
		})
