class_name TestPlayerCamera
extends GdUnitTestSuite

## Tests for PlayerCamera serialization and public API.
## Note: PlayerCamera extends Camera3D and needs a scene tree,
## but serialization can be tested on a detached instance via direct field access.


# --- Save/load round-trip ---

func test_save_data_has_required_keys() -> void:
	var cam := Camera3D.new()
	# PlayerCamera extends Camera3D — we test the script directly.
	var script = load("res://scripts/player/player_camera.gd")
	cam.set_script(script)
	# Set internal state via the script properties
	cam._yaw = 1.5
	cam._pitch_deg_current = 45.0
	cam.distance = 8.0
	var data: Dictionary = cam.get_save_data()
	assert_bool(data.has("yaw")).is_true()
	assert_bool(data.has("pitch")).is_true()
	assert_bool(data.has("distance")).is_true()
	cam.free()


func test_save_load_round_trip() -> void:
	var cam := Camera3D.new()
	var script = load("res://scripts/player/player_camera.gd")
	cam.set_script(script)
	cam._yaw = 2.0
	cam._pitch_deg_current = 50.0
	cam.distance = 9.0
	var data: Dictionary = cam.get_save_data()
	# Create a second camera and load
	var cam2 := Camera3D.new()
	cam2.set_script(script)
	cam2.load_save_data(data)
	assert_float(cam2._yaw).is_equal_approx(2.0, 0.001)
	assert_float(cam2._pitch_deg_current).is_equal_approx(50.0, 0.001)
	assert_float(cam2.distance).is_equal_approx(9.0, 0.001)
	cam.free()
	cam2.free()


func test_load_clamps_distance_to_range() -> void:
	var cam := Camera3D.new()
	var script = load("res://scripts/player/player_camera.gd")
	cam.set_script(script)
	# distance_min = 5.0, distance_max = 12.0 by default
	cam.load_save_data({"yaw": 0, "pitch": 40, "distance": 999.0})
	assert_float(cam.distance).is_less_equal(cam.distance_max)
	cam.load_save_data({"yaw": 0, "pitch": 40, "distance": 0.1})
	assert_float(cam.distance).is_greater_equal(cam.distance_min)
	cam.free()


func test_load_uses_defaults_for_missing_keys() -> void:
	var cam := Camera3D.new()
	var script = load("res://scripts/player/player_camera.gd")
	cam.set_script(script)
	cam.load_save_data({})
	assert_float(cam._yaw).is_equal_approx(0.0, 0.001)
	assert_float(cam.distance).is_greater_equal(cam.distance_min)
	cam.free()


# --- Public API ---

func test_get_yaw_returns_current_yaw() -> void:
	var cam := Camera3D.new()
	var script = load("res://scripts/player/player_camera.gd")
	cam.set_script(script)
	cam._yaw = 3.14
	assert_float(cam.get_yaw()).is_equal_approx(3.14, 0.001)
	cam.free()


func test_get_pitch_returns_current_pitch() -> void:
	var cam := Camera3D.new()
	var script = load("res://scripts/player/player_camera.gd")
	cam.set_script(script)
	cam._pitch_deg_current = 55.0
	assert_float(cam.get_pitch()).is_equal_approx(55.0, 0.001)
	cam.free()
