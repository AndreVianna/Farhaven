class_name TestPlacementCap
extends GdUnitTestSuite

## Unit tests for PlacementCap — the optional scatter-configuration
## capability on PropDef.

const _PlacementCap = preload("res://scripts/data/capabilities/placement_cap.gd")
const _PP = preload("res://scripts/data/capabilities/placement_preset.gd")


func test_cap_is_resource() -> void:
	var cap := _PlacementCap.new()
	assert_bool(cap is Resource).is_true()


func test_default_placement_is_single() -> void:
	# Default = SINGLE (index 0) so a PropDef that adds a PlacementCap
	# without explicitly choosing a preset still behaves as before.
	var cap := _PlacementCap.new()
	assert_int(cap.placement).is_equal(_PP.Preset.SINGLE)


func test_placement_can_be_assigned() -> void:
	var cap := _PlacementCap.new()
	cap.placement = _PP.Preset.DENSE
	assert_int(cap.placement).is_equal(_PP.Preset.DENSE)
