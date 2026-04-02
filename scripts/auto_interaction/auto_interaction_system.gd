extends Node
class_name AutoInteractionSystem

## Auto-interaction data layer — child of Player.
## Resource config, tool tables, weapon tables, and can_gather utility.
## Flow logic (proximity checks, tween timers, chaining) added in later tasks.

const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")

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
