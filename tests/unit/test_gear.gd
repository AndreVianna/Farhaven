class_name TestGear
extends GdUnitTestSuite

## Unit tests for Gear base class (task-055).

const _Gear = preload("res://scripts/core/gear.gd")


# --- Default values ---

func test_gear_id_defaults_to_empty() -> void:
	var gear := _Gear.new()
	assert_str(String(gear.id)).is_equal("")

func test_gear_display_name_defaults_to_empty() -> void:
	var gear := _Gear.new()
	assert_str(gear.display_name).is_equal("")

func test_gear_short_description_defaults_to_empty() -> void:
	var gear := _Gear.new()
	assert_str(gear.short_description).is_equal("")

func test_gear_long_description_defaults_to_empty() -> void:
	var gear := _Gear.new()
	assert_str(gear.long_description).is_equal("")


# --- Field set and read ---

func test_gear_id_set_and_read() -> void:
	var gear := _Gear.new()
	gear.id = &"R00001"
	assert_str(String(gear.id)).is_equal("R00001")

func test_gear_display_name_set_and_read() -> void:
	var gear := _Gear.new()
	gear.display_name = "Eat Berry"
	assert_str(gear.display_name).is_equal("Eat Berry")

func test_gear_short_description_set_and_read() -> void:
	var gear := _Gear.new()
	gear.short_description = "A short summary."
	assert_str(gear.short_description).is_equal("A short summary.")

func test_gear_long_description_set_and_read() -> void:
	var gear := _Gear.new()
	gear.long_description = "A much longer description with details."
	assert_str(gear.long_description).is_equal("A much longer description with details.")


# --- Type hierarchy ---

func test_gear_extends_resource() -> void:
	var gear := _Gear.new()
	assert_bool(gear is Resource).is_true()
