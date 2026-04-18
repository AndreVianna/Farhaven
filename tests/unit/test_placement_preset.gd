class_name TestPlacementPreset
extends GdUnitTestSuite

## Unit tests for PlacementPreset static helpers.

const _PP = preload("res://scripts/data/capabilities/placement_preset.gd")


# ---------------------------------------------------------------------------
# get_count covers every preset and returns the documented value
# ---------------------------------------------------------------------------


func test_count_single() -> void:
	assert_int(_PP.get_count(_PP.Preset.SINGLE)).is_equal(1)


func test_count_normal() -> void:
	assert_int(_PP.get_count(_PP.Preset.NORMAL)).is_equal(7)


func test_count_dense() -> void:
	assert_int(_PP.get_count(_PP.Preset.DENSE)).is_equal(13)


func test_count_sprouting() -> void:
	assert_int(_PP.get_count(_PP.Preset.SPROUTING)).is_equal(7)


func test_count_spread() -> void:
	assert_int(_PP.get_count(_PP.Preset.SPREAD)).is_equal(13)


func test_count_unknown_falls_back_to_single() -> void:
	# Any value outside the enum should default to 1 so a corrupted .tres
	# renders something rather than crashing or producing 0 instances.
	assert_int(_PP.get_count(999)).is_equal(1)


# ---------------------------------------------------------------------------
# get_sibling_scale matches the spec's sibling visual weight
# ---------------------------------------------------------------------------


func test_sibling_scale_single_is_unused() -> void:
	# SINGLE has no siblings; value is a placeholder.
	assert_float(_PP.get_sibling_scale(_PP.Preset.SINGLE)).is_equal(0.0)


func test_sibling_scale_normal() -> void:
	assert_float(_PP.get_sibling_scale(_PP.Preset.NORMAL)).is_equal(0.5)


func test_sibling_scale_dense() -> void:
	assert_float(_PP.get_sibling_scale(_PP.Preset.DENSE)).is_equal(0.5)


func test_sibling_scale_sprouting_is_small() -> void:
	# Sprouting satellites should be noticeably smaller than the parent.
	assert_float(_PP.get_sibling_scale(_PP.Preset.SPROUTING)).is_equal(0.3)


func test_sibling_scale_spread_is_full() -> void:
	# Spread copies look like peers of the center — same size.
	assert_float(_PP.get_sibling_scale(_PP.Preset.SPREAD)).is_equal(1.0)


# ---------------------------------------------------------------------------
# Labels exist for every enum value (required for editor UI)
# ---------------------------------------------------------------------------


func test_labels_present_for_all_presets() -> void:
	var values := [
		_PP.Preset.SINGLE, _PP.Preset.NORMAL, _PP.Preset.DENSE,
		_PP.Preset.SPROUTING, _PP.Preset.SPREAD,
	]
	for v in values:
		var label: String = _PP.get_label(v)
		assert_str(label).is_not_empty()
		assert_bool(label.length() > 0).is_true()


# ---------------------------------------------------------------------------
# supports_instance_overrides: only SINGLE allows overrides
# ---------------------------------------------------------------------------


func test_overrides_supported_for_single() -> void:
	assert_bool(_PP.supports_instance_overrides(_PP.Preset.SINGLE)).is_true()


func test_overrides_not_supported_for_scatter_presets() -> void:
	var scatters := [
		_PP.Preset.NORMAL, _PP.Preset.DENSE,
		_PP.Preset.SPROUTING, _PP.Preset.SPREAD,
	]
	for preset in scatters:
		assert_bool(_PP.supports_instance_overrides(preset)).is_false()
