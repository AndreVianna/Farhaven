extends GdUnitTestSuite
class_name TestAutoInteractionSystem

const _AutoInteraction = preload("res://scripts/auto_interaction/auto_interaction_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _ResourceNode = preload("res://scripts/hex/resource_node.gd")

var _sys: Node
var _inv: RefCounted


func before_test() -> void:
	_sys = _AutoInteraction.new()
	add_child(_sys)
	_inv = _Inventory.new()


func after_test() -> void:
	_sys.queue_free()
	_inv = null


# --- Helper ---

func _make_resource(type: StringName, tool_req: StringName = &"") -> Resource:
	var rn: Resource = _ResourceNode.new()
	rn.type = type
	rn.remaining = 3
	rn.max_amount = 3
	rn.tool_required = tool_req
	return rn


# --- can_gather: bare hands gathers wood ---

func test_can_gather_bare_hands_wood() -> void:
	var rn := _make_resource(&"wood", &"")
	assert_bool(_sys.can_gather(rn, _inv)).is_true()


# --- can_gather: stone_pickaxe gathers ore ---

func test_can_gather_pickaxe_gathers_ore() -> void:
	_inv.set_tool(&"pickaxe", &"stone_pickaxe")
	var rn := _make_resource(&"ore", &"stone_pickaxe")
	assert_bool(_sys.can_gather(rn, _inv)).is_true()


# --- can_gather: stone_axe does NOT mine ore ---

func test_can_gather_axe_cannot_mine_ore() -> void:
	_inv.set_tool(&"axe", &"stone_axe")
	var rn := _make_resource(&"ore", &"stone_pickaxe")
	assert_bool(_sys.can_gather(rn, _inv)).is_false()


# --- can_gather: empty slot rejects gated resource ---

func test_can_gather_empty_slot_rejects_gated() -> void:
	# pickaxe slot is empty by default
	var rn := _make_resource(&"ore", &"stone_pickaxe")
	assert_bool(_sys.can_gather(rn, _inv)).is_false()


# --- Resource config: all 8 types present with correct values ---

func test_resource_config_wood() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"wood"]
	assert_float(cfg["gather_time"]).is_equal(1.0)
	assert_int(cfg["gather_amount"]).is_equal(1)


func test_resource_config_stone() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"stone"]
	assert_float(cfg["gather_time"]).is_equal(1.5)
	assert_int(cfg["gather_amount"]).is_equal(1)


func test_resource_config_berries() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"berries"]
	assert_float(cfg["gather_time"]).is_equal(0.5)
	assert_int(cfg["gather_amount"]).is_equal(2)


func test_resource_config_fiber() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"fiber"]
	assert_float(cfg["gather_time"]).is_equal(0.5)
	assert_int(cfg["gather_amount"]).is_equal(1)


func test_resource_config_ore() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"ore"]
	assert_float(cfg["gather_time"]).is_equal(2.0)
	assert_int(cfg["gather_amount"]).is_equal(1)


func test_resource_config_crystal() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"crystal"]
	assert_float(cfg["gather_time"]).is_equal(2.5)
	assert_int(cfg["gather_amount"]).is_equal(1)


func test_resource_config_toxic_berries() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"toxic_berries"]
	assert_float(cfg["gather_time"]).is_equal(0.5)
	assert_int(cfg["gather_amount"]).is_equal(2)


func test_resource_config_anomaly_fragment() -> void:
	var cfg: Dictionary = _AutoInteraction.RESOURCE_CONFIG[&"anomaly_fragment"]
	assert_float(cfg["gather_time"]).is_equal(3.0)
	assert_int(cfg["gather_amount"]).is_equal(1)


func test_resource_config_has_exactly_8_types() -> void:
	assert_int(_AutoInteraction.RESOURCE_CONFIG.size()).is_equal(8)


# --- Tool speed: stone_axe halves wood gather time ---

func test_tool_speed_stone_axe_halves_wood() -> void:
	var base_time: float = _AutoInteraction.RESOURCE_CONFIG[&"wood"]["gather_time"]
	var multiplier: float = _AutoInteraction.TOOL_SPEED[&"stone_axe"][&"wood"]
	assert_float(base_time * multiplier).is_equal(0.5)


func test_tool_speed_stone_pickaxe_halves_stone() -> void:
	var base_time: float = _AutoInteraction.RESOURCE_CONFIG[&"stone"]["gather_time"]
	var multiplier: float = _AutoInteraction.TOOL_SPEED[&"stone_pickaxe"][&"stone"]
	assert_float(base_time * multiplier).is_equal(0.75)


func test_tool_speed_stone_pickaxe_halves_ore() -> void:
	var base_time: float = _AutoInteraction.RESOURCE_CONFIG[&"ore"]["gather_time"]
	var multiplier: float = _AutoInteraction.TOOL_SPEED[&"stone_pickaxe"][&"ore"]
	assert_float(base_time * multiplier).is_equal(1.0)


func test_tool_speed_stone_pickaxe_halves_crystal() -> void:
	var base_time: float = _AutoInteraction.RESOURCE_CONFIG[&"crystal"]["gather_time"]
	var multiplier: float = _AutoInteraction.TOOL_SPEED[&"stone_pickaxe"][&"crystal"]
	assert_float(base_time * multiplier).is_equal(1.25)


# --- Weapon damage ---

func test_weapon_damage_survival_knife() -> void:
	assert_int(_AutoInteraction.WEAPON_DAMAGE[&"survival_knife"]).is_equal(10)


func test_weapon_damage_bare_hands() -> void:
	assert_int(_AutoInteraction.WEAPON_DAMAGE[&""]).is_equal(5)


# --- Auto-defend config ---

func test_auto_defend_attack_cooldown() -> void:
	assert_float(_AutoInteraction.AUTO_DEFEND_CONFIG["attack_cooldown"]).is_equal(1.0)


func test_auto_defend_attack_range() -> void:
	assert_int(_AutoInteraction.AUTO_DEFEND_CONFIG["attack_range"]).is_equal(1)


# --- Tool priority ---

func test_tool_priority_pickaxe_highest() -> void:
	assert_int(_AutoInteraction.TOOL_PRIORITY[&"stone_pickaxe"]).is_equal(2)


func test_tool_priority_axe_middle() -> void:
	assert_int(_AutoInteraction.TOOL_PRIORITY[&"stone_axe"]).is_equal(1)


func test_tool_priority_bare_hands_lowest() -> void:
	assert_int(_AutoInteraction.TOOL_PRIORITY[&""]).is_equal(0)


# --- 5 signals declared ---

func test_signal_auto_gather_started_exists() -> void:
	assert_bool(_sys.has_signal("auto_gather_started")).is_true()


func test_signal_auto_gather_completed_exists() -> void:
	assert_bool(_sys.has_signal("auto_gather_completed")).is_true()


func test_signal_auto_gather_failed_exists() -> void:
	assert_bool(_sys.has_signal("auto_gather_failed")).is_true()


func test_signal_auto_defend_triggered_exists() -> void:
	assert_bool(_sys.has_signal("auto_defend_triggered")).is_true()


func test_signal_ground_item_picked_up_exists() -> void:
	assert_bool(_sys.has_signal("ground_item_picked_up")).is_true()


# --- Properties exist with correct defaults ---

func test_property_is_gathering_default() -> void:
	assert_bool(_sys._is_gathering).is_false()


func test_property_gather_target_coords_default() -> void:
	assert_object(_sys._gather_target_coords).is_equal(Vector2i.ZERO)


func test_property_gather_target_index_default() -> void:
	assert_int(_sys._gather_target_index).is_equal(-1)


func test_property_gather_tween_default_null() -> void:
	assert_object(_sys._gather_tween).is_null()


func test_property_defend_cooldown_default() -> void:
	assert_float(_sys._defend_cooldown).is_equal(0.0)


func test_property_respawn_queue_default_empty() -> void:
	assert_int(_sys._respawn_queue.size()).is_equal(0)
