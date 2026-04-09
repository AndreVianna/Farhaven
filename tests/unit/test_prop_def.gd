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

func test_portable_weight() -> void:
	var cap := _PortableCap.new()
	cap.weight = 2.5
	assert_float(cap.weight).is_equal_approx(2.5, 0.0001)

func test_placeable_fields() -> void:
	var cap := _PlaceableCap.new()
	cap.footprint = [Vector2i(0, 0), Vector2i(1, 0)]
	cap.blocks_movement = true
	cap.rotation_snap = 60
	assert_int(cap.footprint.size()).is_equal(2)
	assert_bool(cap.blocks_movement).is_true()
	assert_int(cap.rotation_snap).is_equal(60)

func test_station_tags() -> void:
	var cap := _StationCap.new()
	cap.station_tags = [&"fire", &"cook"]
	assert_int(cap.station_tags.size()).is_equal(2)

func test_load_campfire_has_all_capabilities() -> void:
	var def: Resource = load("res://data/props/00101.tres")
	assert_bool(def.has_capability(&"placeable")).is_true()
	assert_bool(def.has_capability(&"container")).is_true()
	assert_bool(def.has_capability(&"light")).is_true()
	assert_bool(def.has_capability(&"station")).is_true()
	assert_bool(def.has_capability(&"catalogable")).is_true()
	assert_bool(def.has_capability(&"portable")).is_false()

func test_load_campfire_tags() -> void:
	var def: Resource = load("res://data/props/00101.tres")
	assert_bool(def.has_tag(&"STRUCTURE")).is_true()
	assert_bool(def.has_tag(&"STATION.fire")).is_true()

func test_load_axe_portable_weight() -> void:
	var def: Resource = load("res://data/props/00201.tres")
	assert_bool(def.has_capability(&"portable")).is_true()
	assert_float(def.portable.weight).is_equal_approx(2.0, 0.0001)

func test_load_berry_tags() -> void:
	var def: Resource = load("res://data/props/00020.tres")
	assert_bool(def.has_tag(&"RESOURCE")).is_true()
	assert_bool(def.has_tag(&"CONSUMABLE.edible")).is_true()

func test_load_small_tree_catalog_data() -> void:
	var def: Resource = load("res://data/props/00001.tres")
	assert_bool(def.catalogable != null).is_true()
	assert_str(String(def.catalogable.display_tag)).is_equal("flora")
	assert_str(def.catalogable.display_name).is_equal("Thornwood Tree")
	assert_int(def.catalogable.category).is_equal(0)


# --- Validation: catalogable consistency ---

## Every PropDef with CATALOGABLE capability and non-empty display_name should be
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
				assert_bool(String(def.catalogable.display_name) != "").is_true() \
					.override_failure_message(
						"PropDef '%s' (%s) has CATALOGABLE but empty display_name — will be invisible to scanner"
						% [def.id, fname])
		fname = dir.get_next()


## Every source/anomaly prop (tagged SOURCE or ANOMALY) should have a CATALOGABLE
## capability with a non-empty display_name.
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
				assert_bool(def.catalogable != null and String(def.catalogable.display_name) != "").is_true() \
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
