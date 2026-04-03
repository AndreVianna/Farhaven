extends Node

## SurvivalSystem — stat tick, consume, take_damage.
## Child of Player. Reads DayNightCycle.is_daytime for HP regen condition.
## task-029 adds death, respawn, ground items, and scene wiring.

const _Inventory = preload("res://scripts/inventory/inventory.gd")

signal stat_changed(stat_name: StringName, current: float, max_val: float)

const STAT_CONFIG: Dictionary = {
	"hunger_rate": 1.0,
	"thirst_rate": 1.5,
	"hp_drain_no_hunger": 2.0,
	"hp_drain_no_thirst": 3.0,
	"hp_regen_day": 0.5,
}

const CONSUMABLE_CONFIG: Dictionary = {
	&"berries":       {"hunger": 15.0, "thirst": 5.0,  "toxic": 0.0},
	&"toxic_berries": {"hunger": 10.0, "thirst": 0.0,  "toxic": 25.0},
	&"meat":          {"hunger": 25.0, "thirst": 0.0,  "toxic": 0.0},
}

var hp: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var hp_max: float = 100.0
var hunger_max: float = 100.0
var thirst_max: float = 100.0
var is_dead: bool = false

var _inventory: _Inventory
var _day_night_cycle: Node  # DayNightCycle autoload or test substitute


func _ready() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method(&"get_inventory"):
		_inventory = parent.get_inventory()
	if _day_night_cycle == null:
		_day_night_cycle = get_node_or_null(&"/root/DayNightCycle")
	if _inventory:
		_inventory.item_used.connect(_on_item_used)


func _process(delta: float) -> void:
	if is_dead:
		return
	_tick(delta)


func _tick(delta: float) -> void:
	hunger -= STAT_CONFIG["hunger_rate"] * delta
	thirst -= STAT_CONFIG["thirst_rate"] * delta

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


func _on_item_used(item_type: StringName) -> void:
	consume(item_type)
