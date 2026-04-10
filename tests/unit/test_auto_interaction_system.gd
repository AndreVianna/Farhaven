extends GdUnitTestSuite
class_name TestAutoInteractionSystem

const _AutoInteraction = preload("res://scripts/auto_interaction/auto_interaction_system.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

# World prop ids
const ID_TREE: StringName = &"P00001"
const ID_LOOSE_ROCKS: StringName = &"P00002"
const ID_TALL_GRASS: StringName = &"P00003"
const ID_BERRY_BUSH: StringName = &"P00004"
const ID_BOULDER: StringName = &"P00005"
const ID_IRON_DEPOSIT: StringName = &"P00006"
const ID_CRYSTAL_CLUSTER: StringName = &"P00007"
const ID_TOXIC_BUSH: StringName = &"P00008"
# Item ids (yields)
const ID_WOOD: StringName = &"P00010"
const ID_ROCK: StringName = &"P00011"
const ID_STONE: StringName = &"P00013"
# Anomaly id
const ID_ANOMALY_FRAGMENT: StringName = &"P10001"
# Tool ids
const ID_AXE: StringName = &"P00201"
const ID_PICKAXE: StringName = &"P00202"
const ID_KNIFE: StringName = &"P00204"

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

func _make_prop(type: StringName, tool_req: StringName = &"") -> Resource:
	return _Prop.create_prop(type, 3, 3, tool_req)


# --- can_gather: bare hands gathers wood (tree) ---

func test_can_gather_bare_hands_tree() -> void:
	var rn := _make_prop(ID_TREE, &"")
	assert_bool(_sys.can_gather(rn, _inv)).is_true()


# --- can_gather: any pickaxe equipped gathers iron deposit ---

func test_can_gather_pickaxe_gathers_iron_deposit() -> void:
	_inv.set_tool(&"pickaxe", ID_PICKAXE)
	var rn := _make_prop(ID_IRON_DEPOSIT, &"pickaxe")
	assert_bool(_sys.can_gather(rn, _inv)).is_true()


# --- can_gather: equipping axe doesn't satisfy a pickaxe-gated prop ---

func test_can_gather_axe_cannot_mine_iron() -> void:
	_inv.set_tool(&"axe", ID_AXE)
	var rn := _make_prop(ID_IRON_DEPOSIT, &"pickaxe")
	assert_bool(_sys.can_gather(rn, _inv)).is_false()


# --- can_gather: empty slot rejects gated prop ---

func test_can_gather_empty_slot_rejects_gated() -> void:
	# pickaxe slot is empty by default
	var rn := _make_prop(ID_IRON_DEPOSIT, &"pickaxe")
	assert_bool(_sys.can_gather(rn, _inv)).is_false()


# --- PropDef config: values match PropRegistry ---

func test_prop_config_tree() -> void:
	var def = PropRegistry.get_def(ID_TREE)
	assert_float(def.gather_time).is_equal(1.0)
	assert_int(def.gather_amount).is_equal(1)


func test_prop_config_boulder() -> void:
	var def = PropRegistry.get_def(ID_BOULDER)
	assert_float(def.gather_time).is_equal(1.5)
	assert_int(def.gather_amount).is_equal(1)


func test_prop_config_berry_bush() -> void:
	var def = PropRegistry.get_def(ID_BERRY_BUSH)
	assert_float(def.gather_time).is_equal(0.5)
	assert_int(def.gather_amount).is_equal(2)


func test_prop_config_tall_grass() -> void:
	var def = PropRegistry.get_def(ID_TALL_GRASS)
	assert_float(def.gather_time).is_equal(0.5)
	assert_int(def.gather_amount).is_equal(1)


func test_prop_config_iron_deposit() -> void:
	var def = PropRegistry.get_def(ID_IRON_DEPOSIT)
	assert_float(def.gather_time).is_equal(2.0)
	assert_int(def.gather_amount).is_equal(1)


func test_prop_config_crystal_cluster() -> void:
	var def = PropRegistry.get_def(ID_CRYSTAL_CLUSTER)
	assert_float(def.gather_time).is_equal(2.5)
	assert_int(def.gather_amount).is_equal(1)


func test_prop_config_toxic_berry_bush() -> void:
	var def = PropRegistry.get_def(ID_TOXIC_BUSH)
	assert_float(def.gather_time).is_equal(0.5)
	assert_int(def.gather_amount).is_equal(2)


func test_prop_config_anomaly_fragment() -> void:
	var def = PropRegistry.get_def(ID_ANOMALY_FRAGMENT)
	assert_bool(def != null).override_failure_message(
		"PropRegistry must contain anomaly fragment def"
	).is_true()


func test_prop_registry_has_at_least_natural_props() -> void:
	# Total PropDefs include natural props (8), inventory items (~9), structures (5), tools (5),
	# and the anomaly fragment — verify the count grew with the migration.
	assert_int(PropRegistry.get_all().size()).is_greater_equal(20)


func test_prop_config_loose_rocks() -> void:
	var def = PropRegistry.get_def(ID_LOOSE_ROCKS)
	assert_float(def.gather_time).is_equal(1.0)
	assert_int(def.gather_amount).is_equal(2)


func test_gather_yield_loose_rocks_gives_rock() -> void:
	var yield_type: StringName = PropRegistry.get_yield_type(ID_LOOSE_ROCKS)
	assert_str(String(yield_type)).is_equal(String(ID_ROCK))


func test_gather_yield_boulder_gives_stone() -> void:
	var yield_type: StringName = PropRegistry.get_yield_type(ID_BOULDER)
	assert_str(String(yield_type)).is_equal(String(ID_STONE))


# --- Tool speed: axe halves wood-tree gather time ---

func test_tool_speed_axe_halves_tree() -> void:
	var base_time: float = PropRegistry.get_def(ID_TREE).gather_time
	var multiplier: float = PropRegistry.get_tool_speed(ID_TREE, ID_AXE)
	assert_float(base_time * multiplier).is_equal(0.5)


func test_tool_speed_pickaxe_halves_boulder() -> void:
	var base_time: float = PropRegistry.get_def(ID_BOULDER).gather_time
	var multiplier: float = PropRegistry.get_tool_speed(ID_BOULDER, ID_PICKAXE)
	assert_float(base_time * multiplier).is_equal(0.75)


func test_tool_speed_pickaxe_halves_iron_deposit() -> void:
	var base_time: float = PropRegistry.get_def(ID_IRON_DEPOSIT).gather_time
	var multiplier: float = PropRegistry.get_tool_speed(ID_IRON_DEPOSIT, ID_PICKAXE)
	assert_float(base_time * multiplier).is_equal(1.0)


func test_tool_speed_pickaxe_halves_crystal_cluster() -> void:
	var base_time: float = PropRegistry.get_def(ID_CRYSTAL_CLUSTER).gather_time
	var multiplier: float = PropRegistry.get_tool_speed(ID_CRYSTAL_CLUSTER, ID_PICKAXE)
	assert_float(base_time * multiplier).is_equal(1.25)


# --- Weapon damage ---

func test_weapon_damage_survival_knife() -> void:
	assert_int(_AutoInteraction.WEAPON_DAMAGE[ID_KNIFE]).is_equal(10)


func test_weapon_damage_bare_hands() -> void:
	assert_int(_AutoInteraction.WEAPON_DAMAGE[&""]).is_equal(5)


# --- Auto-defend config ---

func test_auto_defend_attack_cooldown() -> void:
	assert_float(_AutoInteraction.AUTO_DEFEND_CONFIG["attack_cooldown"]).is_equal(1.0)


func test_auto_defend_attack_range() -> void:
	assert_int(_AutoInteraction.AUTO_DEFEND_CONFIG["attack_range"]).is_equal(1)


# --- Tool slot priority ---

func test_tool_slot_priority_pickaxe_highest() -> void:
	assert_int(_AutoInteraction.TOOL_SLOT_PRIORITY[&"pickaxe"]).is_equal(2)


func test_tool_slot_priority_axe_middle() -> void:
	assert_int(_AutoInteraction.TOOL_SLOT_PRIORITY[&"axe"]).is_equal(1)


func test_tool_slot_priority_bare_hands_lowest() -> void:
	assert_int(_AutoInteraction.TOOL_SLOT_PRIORITY[&""]).is_equal(0)


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
