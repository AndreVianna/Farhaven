class_name TestGatherSound
extends GdUnitTestSuite

const _GatherSound = preload("res://scripts/audio/gather_sound.gd")


func test_gather_ding_emits_signal_without_stream() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var fired: Array = []
	gs.gather_ding_played.connect(func() -> void: fired.append(true))
	gs.play_gather_ding()
	assert_int(fired.size()).is_equal(1)


func test_craft_success_emits_signal_without_stream() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var fired: Array = []
	gs.craft_success_played.connect(func() -> void: fired.append(true))
	gs.play_craft_success()
	assert_int(fired.size()).is_equal(1)


func test_ready_creates_gather_player_child() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var gather_player: Node = gs.get_node_or_null("GatherPlayer")
	assert_object(gather_player).is_not_null()


func test_ready_creates_craft_player_child() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var craft_player: Node = gs.get_node_or_null("CraftPlayer")
	assert_object(craft_player).is_not_null()


func test_set_gather_stream_assigns_stream() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var stream := AudioStreamWAV.new()
	gs.set_gather_stream(stream)
	var gather_player: AudioStreamPlayer = gs.get_node_or_null("GatherPlayer")
	assert_object(gather_player.stream).is_same(stream)


func test_set_craft_stream_assigns_stream() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var stream := AudioStreamWAV.new()
	gs.set_craft_stream(stream)
	var craft_player: AudioStreamPlayer = gs.get_node_or_null("CraftPlayer")
	assert_object(craft_player.stream).is_same(stream)


func test_gather_player_volume_is_minus_six() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var gather_player: AudioStreamPlayer = gs.get_node_or_null("GatherPlayer")
	assert_float(gather_player.volume_db).is_equal_approx(-6.0, 0.1)


func test_craft_player_volume_is_minus_three() -> void:
	var gs: Node = auto_free(_GatherSound.new())
	add_child(gs)
	var craft_player: AudioStreamPlayer = gs.get_node_or_null("CraftPlayer")
	assert_float(craft_player.volume_db).is_equal_approx(-3.0, 0.1)
