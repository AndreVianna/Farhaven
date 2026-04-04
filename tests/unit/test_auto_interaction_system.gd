extends GdUnitTestSuite
class_name TestAutoInteractionSystem

const _AutoInteraction = preload("res://scripts/auto_interaction/auto_interaction_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

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
	var prop: Resource = _Prop.new()
	prop.type = type
	prop.category = Prop.Category.RESOURCE
	prop.remaining = 3
	prop.max_amount = 3
	prop.tool_required = tool_req
	prop.sub_hex = Vector2i.ZERO
	return prop


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


# --- Resource config: values match ResourceRegistry ---

func test_resource_config_wood() -> void:
	var def = ResourceRegistry.get_def(&"wood")
	assert_float(def.gather_time).is_equal(1.0)
	assert_int(def.gather_amount).is_equal(1)


func test_resource_config_stone() -> void:
	var def = ResourceRegistry.get_def(&"stone")
	assert_float(def.gather_time).is_equal(1.5)
	assert_int(def.gather_amount).is_equal(1)


func test_resource_config_berries() -> void:
	var def = ResourceRegistry.get_def(&"berries")
	assert_float(def.gather_time).is_equal(0.5)
	assert_int(def.gather_amount).is_equal(2)


func test_resource_config_fiber() -> void:
	var def = ResourceRegistry.get_def(&"fiber")
	assert_float(def.gather_time).is_equal(0.5)
	assert_int(def.gather_amount).is_equal(1)


func test_resource_config_ore() -> void:
	var def = ResourceRegistry.get_def(&"ore")
	assert_float(def.gather_time).is_equal(2.0)
	assert_int(def.gather_amount).is_equal(1)


func test_resource_config_crystal() -> void:
	var def = ResourceRegistry.get_def(&"crystal")
	assert_float(def.gather_time).is_equal(2.5)
	assert_int(def.gather_amount).is_equal(1)


func test_resource_config_toxic_berries() -> void:
	var def = ResourceRegistry.get_def(&"toxic_berries")
	assert_float(def.gather_time).is_equal(0.5)
	assert_int(def.gather_amount).is_equal(2)


func test_resource_config_anomaly_fragment() -> void:
	var def = ResourceRegistry.get_def(&"anomaly_fragment")
	assert_float(def.gather_time).is_equal(3.0)
	assert_int(def.gather_amount).is_equal(1)


func test_resource_registry_has_9_types() -> void:
	assert_int(ResourceRegistry.get_all().size()).is_equal(9)


func test_resource_config_loose_rock() -> void:
	var def = ResourceRegistry.get_def(&"loose_rock")
	assert_float(def.gather_time).is_equal(1.0)
	assert_int(def.gather_amount).is_equal(2)


func test_gather_yield_loose_rock_gives_stone() -> void:
	var yield_type: StringName = ResourceRegistry.get_yield_type(&"loose_rock")
	assert_str(String(yield_type)).is_equal("stone")


# --- Tool speed: stone_axe halves wood gather time ---

func test_tool_speed_stone_axe_halves_wood() -> void:
	var base_time: float = ResourceRegistry.get_def(&"wood").gather_time
	var multiplier: float = ResourceRegistry.get_tool_speed(&"wood", &"stone_axe")
	assert_float(base_time * multiplier).is_equal(0.5)


func test_tool_speed_stone_pickaxe_halves_stone() -> void:
	var base_time: float = ResourceRegistry.get_def(&"stone").gather_time
	var multiplier: float = ResourceRegistry.get_tool_speed(&"stone", &"stone_pickaxe")
	assert_float(base_time * multiplier).is_equal(0.75)


func test_tool_speed_stone_pickaxe_halves_ore() -> void:
	var base_time: float = ResourceRegistry.get_def(&"ore").gather_time
	var multiplier: float = ResourceRegistry.get_tool_speed(&"ore", &"stone_pickaxe")
	assert_float(base_time * multiplier).is_equal(1.0)


func test_tool_speed_stone_pickaxe_halves_crystal() -> void:
	var base_time: float = ResourceRegistry.get_def(&"crystal").gather_time
	var multiplier: float = ResourceRegistry.get_tool_speed(&"crystal", &"stone_pickaxe")
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
