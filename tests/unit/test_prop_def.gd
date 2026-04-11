class_name TestPropDef
extends GdUnitTestSuite

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _PortableCap = preload("res://scripts/data/capabilities/portable_cap.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")
const _ContainerCap = preload("res://scripts/data/capabilities/container_cap.gd")
const _LightCap = preload("res://scripts/data/capabilities/light_cap.gd")
const _MovableCap = preload("res://scripts/data/capabilities/movable_cap.gd")
const _StationCap = preload("res://scripts/data/capabilities/station_cap.gd")
const _CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")
const _EnduranceCap = preload("res://scripts/data/capabilities/endurance_cap.gd")
const _MovementCap = preload("res://scripts/data/capabilities/movement_cap.gd")
const _CombatCap = preload("res://scripts/data/capabilities/combat_cap.gd")
const _BehaviorCap = preload("res://scripts/data/capabilities/behavior_cap.gd")
const _SpawnableCap = preload("res://scripts/data/capabilities/spawnable_cap.gd")


func test_has_capability_portable_true_when_set() -> void:
	var def := _PropDef.new()
	def.portable = _PortableCap.new()
	assert_bool(def.has_capability(&"portable")).is_true()

func test_has_capability_portable_false_when_null() -> void:
	var def := _PropDef.new()
	assert_bool(def.has_capability(&"portable")).is_false()

func test_has_capability_all_types() -> void:
	var def := _PropDef.new()
	def.placeable = _PlaceableCap.new()
	def.container = _ContainerCap.new()
	def.light = _LightCap.new()
	def.movable = _MovableCap.new()
	def.station = _StationCap.new()
	def.catalogable = _CatalogableCap.new()
	assert_bool(def.has_capability(&"placeable")).is_true()
	assert_bool(def.has_capability(&"container")).is_true()
	assert_bool(def.has_capability(&"light")).is_true()
	assert_bool(def.has_capability(&"movable")).is_true()
	assert_bool(def.has_capability(&"station")).is_true()
	assert_bool(def.has_capability(&"catalogable")).is_true()

func test_has_capability_unknown_returns_false() -> void:
	var def := _PropDef.new()
	assert_bool(def.has_capability(&"nonexistent")).is_false()

# --- Wave 1 fauna-refactor caps: endurance, movement, combat, behavior, spawnable ---

func test_has_capability_fauna_caps_false_when_null() -> void:
	var def := _PropDef.new()
	assert_bool(def.has_capability(&"endurance")).is_false()
	assert_bool(def.has_capability(&"movement")).is_false()
	assert_bool(def.has_capability(&"combat")).is_false()
	assert_bool(def.has_capability(&"behavior")).is_false()
	assert_bool(def.has_capability(&"spawnable")).is_false()

func test_has_capability_all_fauna_caps_true_when_set() -> void:
	var def := _PropDef.new()
	def.endurance = _EnduranceCap.new()
	def.movement = _MovementCap.new()
	def.combat = _CombatCap.new()
	def.behavior = _BehaviorCap.new()
	def.spawnable = _SpawnableCap.new()
	assert_bool(def.has_capability(&"endurance")).is_true()
	assert_bool(def.has_capability(&"movement")).is_true()
	assert_bool(def.has_capability(&"combat")).is_true()
	assert_bool(def.has_capability(&"behavior")).is_true()
	assert_bool(def.has_capability(&"spawnable")).is_true()

func test_prop_def_round_trips_fauna_caps() -> void:
	var def := _PropDef.new()

	var endurance := _EnduranceCap.new()
	endurance.hp = 12
	endurance.vulnerabilities = [&"FIRE"]
	endurance.resistances = [&"BLUNT"]
	endurance.immunities = [&"POISON"]
	def.endurance = endurance

	var movement := _MovementCap.new()
	# FLY mode with normal speed 2.0 (cooldown = 1/2.0 = 0.5s) and max speed 3.0,
	# plus JUMP mode with normal value 3 (treated as max elevation diff).
	movement.modes = {
		int(_MovementCap.Mode.FLY): [2.0, 3.0],
		int(_MovementCap.Mode.JUMP): [3.0, 3.0],
	}
	def.movement = movement

	var combat := _CombatCap.new()
	combat.attacks = [Resource.new()]
	combat.defenses = [Resource.new(), Resource.new()]
	def.combat = combat

	var behavior := _BehaviorCap.new()
	behavior.detection_range = 4
	behavior.activity_cycle = _BehaviorCap.ActivityCycle.NOCTURNAL
	behavior.group_behavior = _BehaviorCap.GroupBehavior.PACK
	behavior.diet = [&"FAUNA"]
	behavior.reactions = [Resource.new()]
	def.behavior = behavior

	var spawnable := _SpawnableCap.new()
	spawnable.spawn_min = 2
	spawnable.spawn_max = 4
	spawnable.first_spawn_day = 5
	spawnable.spawn_min_distance = 6
	spawnable.allowed_biomes = [&"FOREST", &"GRASSLAND"]
	def.spawnable = spawnable

	# Read back and verify
	assert_int(def.endurance.hp).is_equal(12)
	assert_bool(def.endurance.vulnerabilities.has(&"FIRE")).is_true()
	assert_bool(def.endurance.resistances.has(&"BLUNT")).is_true()
	assert_bool(def.endurance.immunities.has(&"POISON")).is_true()

	assert_bool(def.movement.modes.has(int(_MovementCap.Mode.FLY))).is_true()
	var fly_speeds: Array = def.movement.modes[int(_MovementCap.Mode.FLY)]
	assert_float(fly_speeds[0]).is_equal_approx(2.0, 0.001)
	assert_float(fly_speeds[1]).is_equal_approx(3.0, 0.001)
	assert_bool(def.movement.modes.has(int(_MovementCap.Mode.JUMP))).is_true()
	var jump_speeds: Array = def.movement.modes[int(_MovementCap.Mode.JUMP)]
	assert_float(jump_speeds[0]).is_equal_approx(3.0, 0.001)

	assert_int(def.combat.attacks.size()).is_equal(1)
	assert_int(def.combat.defenses.size()).is_equal(2)

	assert_int(def.behavior.detection_range).is_equal(4)
	assert_int(def.behavior.activity_cycle).is_equal(_BehaviorCap.ActivityCycle.NOCTURNAL)
	assert_int(def.behavior.group_behavior).is_equal(_BehaviorCap.GroupBehavior.PACK)
	assert_bool(def.behavior.diet.has(&"FAUNA")).is_true()
	assert_int(def.behavior.reactions.size()).is_equal(1)

	assert_int(def.spawnable.spawn_min).is_equal(2)
	assert_int(def.spawnable.spawn_max).is_equal(4)
	assert_int(def.spawnable.first_spawn_day).is_equal(5)
	assert_int(def.spawnable.spawn_min_distance).is_equal(6)
	assert_bool(def.spawnable.allowed_biomes.has(&"FOREST")).is_true()
	assert_bool(def.spawnable.allowed_biomes.has(&"GRASSLAND")).is_true()

func test_has_tag_true_when_present() -> void:
	var def := _PropDef.new()
	def.tags = [&"SOURCE", &"WOOD"]
	assert_bool(def.has_tag(&"SOURCE")).is_true()
	assert_bool(def.has_tag(&"WOOD")).is_true()

func test_has_tag_false_when_absent() -> void:
	var def := _PropDef.new()
	def.tags = [&"SOURCE", &"WOOD"]
	assert_bool(def.has_tag(&"METAL")).is_false()

func test_has_tag_false_when_empty() -> void:
	var def := _PropDef.new()
	assert_bool(def.has_tag(&"SOURCE")).is_false()

func test_portable_size() -> void:
	var cap := _PortableCap.new()
	cap.size = 2.5
	assert_float(cap.size).is_equal_approx(2.5, 0.0001)

func test_placeable_is_marker() -> void:
	# PlaceableCap is a pure marker — no fields.
	var cap := _PlaceableCap.new()
	assert_bool(cap is Resource).is_true()
	assert_bool("rotation_snap" in cap).is_false()

func test_station_tags() -> void:
	var cap := _StationCap.new()
	cap.station_tags = [&"fire", &"cook"]
	assert_int(cap.station_tags.size()).is_equal(2)

func test_load_campfire_has_all_capabilities() -> void:
	var def: Resource = load("res://data/props/P00101.tres")
	assert_bool(def.has_capability(&"placeable")).is_true()
	assert_bool(def.has_capability(&"container")).is_true()
	assert_bool(def.has_capability(&"light")).is_true()
	assert_bool(def.has_capability(&"station")).is_true()
	assert_bool(def.has_capability(&"catalogable")).is_true()
	assert_bool(def.has_capability(&"portable")).is_false()

func test_load_campfire_tags() -> void:
	var def: Resource = load("res://data/props/P00101.tres")
	assert_bool(def.has_tag(&"STRUCTURE")).is_true()
	assert_bool(def.has_tag(&"STATION.fire")).is_true()

func test_load_axe_portable_size() -> void:
	var def: Resource = load("res://data/props/P00201.tres")
	assert_bool(def.has_capability(&"portable")).is_true()
	assert_float(def.portable.size).is_equal_approx(2.0, 0.0001)

func test_load_berry_tags() -> void:
	var def: Resource = load("res://data/props/P00020.tres")
	assert_bool(def.has_tag(&"RESOURCE")).is_true()
	assert_bool(def.has_tag(&"CONSUMABLE.edible")).is_true()

func test_load_small_tree_catalog_data() -> void:
	var def: Resource = load("res://data/props/P00001.tres")
	assert_bool(def.catalogable != null).is_true()
	assert_bool(def.catalogable.show_as_anomaly).is_false()
	# display_name now lives on the PropDef (Gear base), not the catalogable cap.
	assert_str(def.display_name).is_equal("Thornwood Tree")
	# prop_category comes from PropDef (Prop.Category.PLANT = 0)
	assert_int(def.prop_category).is_equal(0)


# --- Validation: catalogable consistency ---

## Every PropDef with CATALOGABLE capability and non-empty Gear display_name should be
## registered in the catalog. This catches the bug where 10001 (Anomaly Fragment)
## had no catalog data and was invisible to the scanner.
func test_all_catalogable_props_have_display_name() -> void:
	var dir := DirAccess.open("res://data/props")
	if dir == null:
		fail("Cannot open res://data/props")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var def: Resource = load("res://data/props/" + fname)
			var is_source: bool = def.has_tag(&"SOURCE") or def.has_tag(&"ANOMALY")
			if is_source and def.catalogable != null:
				assert_bool(String(def.display_name) != "").is_true() \
					.override_failure_message(
						"PropDef '%s' (%s) has CATALOGABLE but empty display_name — will be invisible to scanner"
						% [def.id, fname])
		fname = dir.get_next()


## Every source/anomaly prop (tagged SOURCE or ANOMALY) should have a CATALOGABLE
## capability and a non-empty Gear display_name.
## This ensures no world-placed scannable prop is invisible to the scanner.
## Structures (tagged STRUCTURE, origin=CRAFTED) don't need catalog entries.
func test_all_source_props_have_catalogable() -> void:
	var dir := DirAccess.open("res://data/props")
	if dir == null:
		fail("Cannot open res://data/props")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var def: Resource = load("res://data/props/" + fname)
			var is_source: bool = def.has_tag(&"SOURCE") or def.has_tag(&"ANOMALY")
			if is_source:
				assert_bool(def.catalogable != null and String(def.display_name) != "").is_true() \
					.override_failure_message(
						"PropDef '%s' (%s) is tagged SOURCE/ANOMALY but has no CATALOGABLE with display_name — will be invisible to scanner"
						% [def.id, fname])
		fname = dir.get_next()


## Every PropDef type should have a matching pool in PropRenderer. This catches
## the hardcoded "anomaly_fragment" pool bug — each prop type needs its own pool.
func test_all_prop_types_registered_in_registry() -> void:
	var dir := DirAccess.open("res://data/props")
	if dir == null:
		fail("Cannot open res://data/props")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var def: Resource = load("res://data/props/" + fname)
			assert_bool(String(def.id) != "").is_true() \
				.override_failure_message("PropDef in %s has empty id" % fname)
			# Verify PropRegistry has this def
			if PropRegistry != null and PropRegistry.has_method("has_def"):
				assert_bool(PropRegistry.has_def(def.id)).is_true() \
					.override_failure_message(
						"PropDef '%s' (%s) not found in PropRegistry" % [def.id, fname])
		fname = dir.get_next()
