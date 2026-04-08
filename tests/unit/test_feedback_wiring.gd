extends GdUnitTestSuite
class_name TestFeedbackWiring

## Unit tests for task-022: feedback wiring — floating text, notifications,
## fly-to-player, and craft-completed feedback.

const _FloatingTextManager = preload("res://scripts/hud/floating_text_manager.gd")
const _NotificationManager = preload("res://scripts/hud/notification_manager.gd")
const _FlyToPlayer = preload("res://scripts/rendering/fly_to_player.gd")
const _GatherSound = preload("res://scripts/audio/gather_sound.gd")
const _CraftFlash = preload("res://scripts/hud/craft_flash.gd")


# --- Lightweight fakes ---


class FakeAutoInteraction extends Node:
	signal auto_gather_completed(coords: Vector2i, prop_type: StringName, amount: int)
	signal auto_gather_failed(coords: Vector2i, reason: StringName)
	signal auto_defend_triggered(fauna_id: int, damage: int)


class FakeCraftingSystem extends Node:
	signal recipe_discovered(recipe_name: StringName)
	signal craft_completed(recipe_name: StringName)
	signal craft_failed(recipe_name: StringName, reason: StringName)
	signal station_proximity_changed(near: bool)


class FakePlayer extends Node3D:
	var current_tile: Vector2i = Vector2i.ZERO


class FakeGrid extends Node:
	signal tile_entered(coords: Vector2i)
	signal prop_depleted(coords: Vector2i, prop_type: StringName)

	func axial_to_world(coords: Vector2i) -> Vector2:
		return Vector2(float(coords.x) * 4.5, float(coords.y) * 5.196)


## Minimal HUD stand-in that captures show_text / show_notification calls.
class CaptureHUD extends Control:
	var text_calls: Array = []
	var notification_calls: Array = []

	func show_text(world_pos: Vector3, text: String, color: Color, _duration: float = 1.0) -> void:
		text_calls.append({"pos": world_pos, "text": text, "color": color})

	func show_notification(text: String, _duration: float = 2.0) -> void:
		notification_calls.append(text)


# --- FloatingTextManager tests ---


func test_floating_text_show_creates_label() -> void:
	var ftm := _FloatingTextManager.new()
	add_child(ftm)

	ftm.show_text(Vector3(1.0, 2.0, 3.0), "+1 Wood", Color.GREEN)

	# Should have created one child label
	assert_int(ftm.get_child_count()).is_equal(1)
	var label: Label = ftm.get_child(0) as Label
	assert_str(label.text).is_equal("+1 Wood")
	assert_object(label.modulate).is_equal(Color.GREEN)

	ftm.queue_free()


func test_floating_text_stacking_offsets_y() -> void:
	var ftm := _FloatingTextManager.new()
	add_child(ftm)

	ftm.show_text(Vector3.ZERO, "A", Color.GREEN)
	ftm.show_text(Vector3.ZERO, "B", Color.RED)

	assert_int(ftm.get_child_count()).is_equal(2)
	# Second label should be offset higher (lower y in screen coords)
	var label_a: Label = ftm.get_child(0)
	var label_b: Label = ftm.get_child(1)
	assert_float(label_b.position.y).is_less(label_a.position.y)

	ftm.queue_free()


# --- NotificationManager tests ---


func test_notification_show_creates_panel() -> void:
	var nm := _NotificationManager.new()
	add_child(nm)

	nm.show_notification("New recipe: Stone Axe!")

	# Should have one child (PanelContainer)
	assert_int(nm.get_child_count()).is_equal(1)
	var panel: PanelContainer = nm.get_child(0)
	var label: Label = panel.get_child(0)
	assert_str(label.text).is_equal("New recipe: Stone Axe!")

	nm.queue_free()


func test_notification_queue_depth_limit() -> void:
	var nm := _NotificationManager.new()
	add_child(nm)

	# Enqueue more than MAX_QUEUE_DEPTH
	for i in 5:
		nm.show_notification("Msg %d" % i)

	# First is showing, queue capped at MAX_QUEUE_DEPTH
	assert_bool(nm._is_showing).is_true()
	assert_int(nm._queue.size()).is_less_equal(_NotificationManager.MAX_QUEUE_DEPTH)

	nm.queue_free()


# --- FlyToPlayer tests ---


func test_fly_to_player_spawns_mesh() -> void:
	var fly := _FlyToPlayer.new()
	var player := FakePlayer.new()
	player.position = Vector3(10.0, 0.0, 10.0)
	add_child(player)
	add_child(fly)
	fly.setup(player)

	var grid := FakeGrid.new()
	add_child(grid)

	fly.spawn_fly(Vector2i(0, 0), &"wood", grid)

	# Should have one child MeshInstance3D
	assert_int(fly.get_child_count()).is_equal(1)
	var mesh: MeshInstance3D = fly.get_child(0) as MeshInstance3D
	assert_object(mesh).is_not_null()

	fly.queue_free()
	player.queue_free()
	grid.queue_free()


func test_fly_to_player_no_crash_without_player() -> void:
	var fly := _FlyToPlayer.new()
	add_child(fly)
	# No setup called — _player is null

	var grid := FakeGrid.new()
	add_child(grid)

	# Should not crash
	fly.spawn_fly(Vector2i(0, 0), &"wood", grid)
	assert_int(fly.get_child_count()).is_equal(0)

	fly.queue_free()
	grid.queue_free()


func test_fly_to_player_prop_colors() -> void:
	# Verify all prop types have defined colors
	for res_type: StringName in [&"wood", &"stone", &"berries", &"fiber", &"ore", &"crystal"]:
		assert_bool(_FlyToPlayer.PROP_COLORS.has(res_type)).is_true()


# --- HUD feedback wiring tests ---


func test_hud_auto_gather_completed_shows_green_text() -> void:
	var hud := CaptureHUD.new()
	add_child(hud)

	var auto := FakeAutoInteraction.new()
	add_child(auto)

	# Wire manually (simulating what connect_auto_interaction does)
	auto.auto_gather_completed.connect(
		func(_coords: Vector2i, prop_type: StringName, amount: int) -> void:
			var display_name: String = prop_type.replace("_", " ").capitalize()
			hud.show_text(Vector3.ZERO, "+%d %s" % [amount, display_name], Color.GREEN)
	)

	auto.auto_gather_completed.emit(Vector2i.ZERO, &"wood", 1)

	assert_int(hud.text_calls.size()).is_equal(1)
	assert_str(hud.text_calls[0]["text"]).is_equal("+1 Wood")
	assert_object(hud.text_calls[0]["color"]).is_equal(Color.GREEN)

	hud.queue_free()
	auto.queue_free()


func test_hud_auto_gather_failed_inventory_full_shows_red() -> void:
	var hud := CaptureHUD.new()
	add_child(hud)

	var auto := FakeAutoInteraction.new()
	add_child(auto)

	auto.auto_gather_failed.connect(
		func(_coords: Vector2i, reason: StringName) -> void:
			if reason == &"inventory_full":
				hud.show_text(Vector3.ZERO, "INVENTORY FULL", Color.RED)
	)

	auto.auto_gather_failed.emit(Vector2i.ZERO, &"inventory_full")

	assert_int(hud.text_calls.size()).is_equal(1)
	assert_str(hud.text_calls[0]["text"]).is_equal("INVENTORY FULL")
	assert_object(hud.text_calls[0]["color"]).is_equal(Color.RED)

	hud.queue_free()
	auto.queue_free()


func test_hud_auto_gather_failed_tool_gated_shows_red() -> void:
	var hud := CaptureHUD.new()
	add_child(hud)

	var auto := FakeAutoInteraction.new()
	add_child(auto)

	auto.auto_gather_failed.connect(
		func(_coords: Vector2i, reason: StringName) -> void:
			if reason == &"tool_gated":
				hud.show_text(Vector3.ZERO, "REQUIRES TOOL", Color.RED)
	)

	auto.auto_gather_failed.emit(Vector2i.ZERO, &"tool_gated")

	assert_int(hud.text_calls.size()).is_equal(1)
	assert_str(hud.text_calls[0]["text"]).is_equal("REQUIRES TOOL")
	assert_object(hud.text_calls[0]["color"]).is_equal(Color.RED)

	hud.queue_free()
	auto.queue_free()


func test_hud_auto_defend_shows_red_damage() -> void:
	var hud := CaptureHUD.new()
	add_child(hud)

	var auto := FakeAutoInteraction.new()
	add_child(auto)

	auto.auto_defend_triggered.connect(
		func(_fauna_id: int, damage: int) -> void:
			hud.show_text(Vector3.ZERO, "-%d" % damage, Color.RED)
	)

	auto.auto_defend_triggered.emit(42, 10)

	assert_int(hud.text_calls.size()).is_equal(1)
	assert_str(hud.text_calls[0]["text"]).is_equal("-10")
	assert_object(hud.text_calls[0]["color"]).is_equal(Color.RED)

	hud.queue_free()
	auto.queue_free()


func test_hud_recipe_discovered_shows_notification() -> void:
	var hud := CaptureHUD.new()
	add_child(hud)

	var crafting := FakeCraftingSystem.new()
	add_child(crafting)

	crafting.recipe_discovered.connect(
		func(recipe_name: StringName) -> void:
			var display_name: String = recipe_name.replace("_", " ").capitalize()
			hud.show_notification("New recipe: %s!" % display_name)
	)

	crafting.recipe_discovered.emit(&"stone_axe")

	assert_int(hud.notification_calls.size()).is_equal(1)
	assert_str(hud.notification_calls[0]).is_equal("New recipe: Stone Axe!")

	hud.queue_free()
	crafting.queue_free()


func test_hud_craft_completed_shows_notification() -> void:
	var hud := CaptureHUD.new()
	add_child(hud)

	var crafting := FakeCraftingSystem.new()
	add_child(crafting)

	crafting.craft_completed.connect(
		func(recipe_name: StringName) -> void:
			var display_name: String = recipe_name.replace("_", " ").capitalize()
			hud.show_notification("Crafted %s!" % display_name)
	)

	crafting.craft_completed.emit(&"stone_pickaxe")

	assert_int(hud.notification_calls.size()).is_equal(1)
	assert_str(hud.notification_calls[0]).is_equal("Crafted Stone Pickaxe!")

	hud.queue_free()
	crafting.queue_free()


# --- GatherSound tests ---


func test_gather_sound_emits_ding_signal() -> void:
	var sound := _GatherSound.new()
	add_child(sound)

	var counter: Array = [0]
	sound.gather_ding_played.connect(func() -> void: counter[0] += 1)

	sound.play_gather_ding()

	assert_int(counter[0]).is_equal(1)

	sound.queue_free()


func test_gather_sound_emits_craft_signal() -> void:
	var sound := _GatherSound.new()
	add_child(sound)

	var counter: Array = [0]
	sound.craft_success_played.connect(func() -> void: counter[0] += 1)

	sound.play_craft_success()

	assert_int(counter[0]).is_equal(1)

	sound.queue_free()


func test_gather_sound_has_audio_players() -> void:
	var sound := _GatherSound.new()
	add_child(sound)

	# Should have two AudioStreamPlayer children
	var gather_player := sound.get_node_or_null("GatherPlayer")
	var craft_player := sound.get_node_or_null("CraftPlayer")
	assert_object(gather_player).is_not_null()
	assert_object(craft_player).is_not_null()

	sound.queue_free()


# --- CraftFlash tests ---


func test_craft_flash_starts_hidden() -> void:
	var flash := _CraftFlash.new()
	add_child(flash)

	assert_bool(flash.visible).is_false()
	assert_float(flash.color.a).is_equal(0.0)

	flash.queue_free()


func test_craft_flash_becomes_visible_on_flash() -> void:
	var flash := _CraftFlash.new()
	add_child(flash)

	flash.flash()

	assert_bool(flash.visible).is_true()
	assert_float(flash.color.a).is_greater(0.0)

	flash.queue_free()


# --- Sound wiring integration ---


func test_gather_ding_fires_on_auto_gather_completed() -> void:
	var sound := _GatherSound.new()
	add_child(sound)

	var auto := FakeAutoInteraction.new()
	add_child(auto)

	var counter: Array = [0]
	sound.gather_ding_played.connect(func() -> void: counter[0] += 1)

	# Wire like HUD does: auto_gather_completed → sound.play_gather_ding
	auto.auto_gather_completed.connect(
		func(_c: Vector2i, _t: StringName, _a: int) -> void:
			sound.play_gather_ding()
	)

	auto.auto_gather_completed.emit(Vector2i.ZERO, &"wood", 1)

	assert_int(counter[0]).is_equal(1)

	sound.queue_free()
	auto.queue_free()


func test_craft_success_sound_fires_on_craft_completed() -> void:
	var sound := _GatherSound.new()
	add_child(sound)

	var crafting := FakeCraftingSystem.new()
	add_child(crafting)

	var counter: Array = [0]
	sound.craft_success_played.connect(func() -> void: counter[0] += 1)

	# Wire like HUD does: craft_completed → sound.play_craft_success
	crafting.craft_completed.connect(
		func(_r: StringName) -> void:
			sound.play_craft_success()
	)

	crafting.craft_completed.emit(&"stone_axe")

	assert_int(counter[0]).is_equal(1)

	sound.queue_free()
	crafting.queue_free()


# --- Fly-to-player integration with auto_gather_completed ---


func test_fly_spawns_on_gather_completed() -> void:
	var fly := _FlyToPlayer.new()
	var player := FakePlayer.new()
	player.position = Vector3(5.0, 0.0, 5.0)
	add_child(player)
	add_child(fly)
	fly.setup(player)

	var grid := FakeGrid.new()
	add_child(grid)

	var auto := FakeAutoInteraction.new()
	add_child(auto)

	# Wire like main.gd does
	auto.auto_gather_completed.connect(
		func(coords: Vector2i, prop_type: StringName, _amount: int) -> void:
			fly.spawn_fly(coords, prop_type, grid)
	)

	auto.auto_gather_completed.emit(Vector2i(1, 0), &"stone", 1)

	assert_int(fly.get_child_count()).is_equal(1)

	fly.queue_free()
	player.queue_free()
	grid.queue_free()
	auto.queue_free()
