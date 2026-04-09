class_name TestHexTile
extends GdUnitTestSuite

const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _PropDef = preload("res://scripts/data/prop_def.gd")
const _PlaceableCap = preload("res://scripts/data/capabilities/placeable_cap.gd")
const _StationCap = preload("res://scripts/data/capabilities/station_cap.gd")
const _CatalogableCap = preload("res://scripts/data/capabilities/catalogable_cap.gd")


# --- Defaults ---

func test_default_coords_are_zero() -> void:
	var tile := _HexTile.new()
	assert_bool(tile.coords == Vector2i.ZERO).is_true()


func test_default_biome_is_grassland() -> void:
	var tile := _HexTile.new()
	assert_int(tile.biome).is_equal(_HexTile.Biome.GRASSLAND)


func test_default_elevation_is_zero() -> void:
	var tile := _HexTile.new()
	assert_int(tile.elevation).is_equal(0)


func test_default_props_is_empty() -> void:
	var tile := _HexTile.new()
	assert_int(tile.props.size()).is_equal(0)


# --- Biome enum values ---

func test_biome_crash_site_value() -> void:
	assert_int(_HexTile.Biome.CRASH_SITE).is_equal(0)


func test_biome_grassland_value() -> void:
	assert_int(_HexTile.Biome.GRASSLAND).is_equal(1)


func test_biome_forest_value() -> void:
	assert_int(_HexTile.Biome.FOREST).is_equal(2)


func test_biome_rocky_value() -> void:
	assert_int(_HexTile.Biome.ROCKY).is_equal(3)


func test_biome_water_value() -> void:
	assert_int(_HexTile.Biome.WATER).is_equal(4)


# --- get_props: returns natural-origin props ---

func test_get_props_returns_natural_props() -> void:
	var tile := _HexTile.new()
	var natural_prop := _Prop.new()
	natural_prop.type = &"00001"
	natural_prop.origin = _Prop.Origin.NATURAL
	tile.props.append(natural_prop)
	var result := tile.get_props()
	assert_int(result.size()).is_equal(1)


func test_get_props_excludes_crafted_props() -> void:
	var tile := _HexTile.new()
	var crafted_prop := _Prop.new()
	crafted_prop.type = &"00101"
	crafted_prop.origin = _Prop.Origin.CRAFTED
	tile.props.append(crafted_prop)
	var result := tile.get_props()
	assert_int(result.size()).is_equal(0)


func test_get_props_mixed_origins() -> void:
	var tile := _HexTile.new()
	var natural := _Prop.new()
	natural.origin = _Prop.Origin.NATURAL
	var crafted := _Prop.new()
	crafted.origin = _Prop.Origin.CRAFTED
	var unknown := _Prop.new()
	unknown.origin = _Prop.Origin.UNKNOWN
	tile.props = [natural, crafted, unknown]
	var result := tile.get_props()
	assert_int(result.size()).is_equal(1)  # only natural


# --- get_anomalies ---

func test_get_anomalies_returns_unknown_origin() -> void:
	var tile := _HexTile.new()
	var anomaly := _Prop.new()
	anomaly.origin = _Prop.Origin.UNKNOWN
	tile.props.append(anomaly)
	var result := tile.get_anomalies()
	assert_int(result.size()).is_equal(1)


func test_get_anomalies_excludes_natural() -> void:
	var tile := _HexTile.new()
	var natural := _Prop.new()
	natural.origin = _Prop.Origin.NATURAL
	tile.props.append(natural)
	var result := tile.get_anomalies()
	assert_int(result.size()).is_equal(0)


func test_get_anomalies_includes_native_alien() -> void:
	var tile := _HexTile.new()
	var alien := _Prop.new()
	alien.origin = _Prop.Origin.NATIVE_ALIEN
	tile.props.append(alien)
	var result := tile.get_anomalies()
	assert_int(result.size()).is_equal(1)


# --- get_props_by_category (deprecated but still used) ---

func test_get_props_by_category_filters_correctly() -> void:
	var tile := _HexTile.new()
	var plant := _Prop.new()
	plant.category = _Prop.Category.PLANT
	var mineral := _Prop.new()
	mineral.category = _Prop.Category.MINERAL
	tile.props = [plant, mineral]
	var result := tile.get_props_by_category(_Prop.Category.PLANT)
	assert_int(result.size()).is_equal(1)
	assert_int(result[0].category).is_equal(_Prop.Category.PLANT)


func test_get_props_by_category_returns_empty_for_no_match() -> void:
	var tile := _HexTile.new()
	var plant := _Prop.new()
	plant.category = _Prop.Category.PLANT
	tile.props = [plant]
	var result := tile.get_props_by_category(_Prop.Category.MINERAL)
	assert_int(result.size()).is_equal(0)


# --- Tile config ---

func test_tile_with_elevation() -> void:
	var tile := _HexTile.new()
	tile.elevation = 3
	assert_int(tile.elevation).is_equal(3)


func test_tile_is_resource() -> void:
	var tile := _HexTile.new()
	assert_bool(tile is Resource).is_true()
