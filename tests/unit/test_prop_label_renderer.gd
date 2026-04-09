class_name TestPropLabelRenderer
extends GdUnitTestSuite

## Tests for PropLabelRenderer constants and category color mappings.

const _Catalog = preload("res://scripts/scanner/catalog.gd")


# --- Constants ---

func test_label_y_offset_positive() -> void:
	# PropLabelRenderer.LABEL_Y_OFFSET should be positive to appear above props.
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	assert_float(script.LABEL_Y_OFFSET).is_greater(0.0)


func test_hex_size_matches_design() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	assert_float(script.HEX_SIZE).is_equal_approx(3.0, 0.001)


# --- Category colors ---

func test_category_colors_has_all_four_categories() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	var colors: Dictionary = script.CATEGORY_COLORS
	assert_int(colors.size()).is_equal(4)
	assert_bool(colors.has(_Catalog.CatalogCategory.MINERAL)).is_true()
	assert_bool(colors.has(_Catalog.CatalogCategory.FLORA)).is_true()
	assert_bool(colors.has(_Catalog.CatalogCategory.FAUNA)).is_true()
	assert_bool(colors.has(_Catalog.CatalogCategory.ANOMALY)).is_true()


func test_mineral_color_is_blue() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	var c: Color = script.CATEGORY_COLORS[_Catalog.CatalogCategory.MINERAL]
	assert_float(c.b).is_greater(c.r)


func test_flora_color_is_green() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	var c: Color = script.CATEGORY_COLORS[_Catalog.CatalogCategory.FLORA]
	assert_float(c.g).is_greater(c.r)


func test_fauna_color_is_red() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	var c: Color = script.CATEGORY_COLORS[_Catalog.CatalogCategory.FAUNA]
	assert_float(c.r).is_greater(c.g)


func test_anomaly_color_is_purple() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	var c: Color = script.CATEGORY_COLORS[_Catalog.CatalogCategory.ANOMALY]
	assert_float(c.r).is_greater(c.g)
	assert_float(c.b).is_greater(c.g)


# --- Encountered color ---

func test_encountered_color_is_orange() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	var c: Color = script.ENCOUNTERED_COLOR
	assert_float(c.r).is_equal_approx(1.0, 0.01)
	assert_float(c.g).is_equal_approx(0.6, 0.01)


# --- Category names ---

func test_category_names_has_four_entries() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	assert_int(script.CATEGORY_NAMES.size()).is_equal(4)


func test_flora_name_is_vegetation() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	assert_str(script.CATEGORY_NAMES[_Catalog.CatalogCategory.FLORA]).is_equal("Vegetation")


func test_anomaly_name_is_anomaly() -> void:
	var script = load("res://scripts/rendering/prop_label_renderer.gd")
	assert_str(script.CATEGORY_NAMES[_Catalog.CatalogCategory.ANOMALY]).is_equal("Anomaly")
