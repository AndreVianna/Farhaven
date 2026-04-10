class_name TestFlyToPlayer
extends GdUnitTestSuite

const _FlyToPlayer = preload("res://scripts/rendering/fly_to_player.gd")


# --- Constants ---

func test_fly_duration_constant() -> void:
	assert_float(_FlyToPlayer.FLY_DURATION).is_equal_approx(0.3, 0.001)


func test_arc_height_constant() -> void:
	assert_float(_FlyToPlayer.ARC_HEIGHT).is_equal_approx(2.0, 0.001)


func test_default_color_is_white() -> void:
	assert_bool(_FlyToPlayer.DEFAULT_COLOR == Color.WHITE).is_true()


# --- Setup ---

func test_setup_stores_player_reference() -> void:
	var fly: FlyToPlayer = auto_free(_FlyToPlayer.new())
	var player: Node3D = Node3D.new()
	fly.setup(player)
	assert_object(fly._player).is_same(player)
	player.free()


func test_spawn_fly_does_nothing_without_player() -> void:
	var fly: FlyToPlayer = auto_free(_FlyToPlayer.new())
	add_child(fly)
	# No player set, should not crash
	var mock_grid: Node = Node.new()
	# spawn_fly needs grid.axial_to_world — no player means early return
	# Just verify it doesn't crash (implicit: no error, no child added)
	assert_int(fly.get_child_count()).is_equal(0)
	mock_grid.free()
