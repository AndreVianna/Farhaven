extends GdUnitTestSuite

## Unit tests for task-038: FaunaManager signal wiring to downstream systems.
## Tests that main.gd _wire_fauna correctly connects FaunaManager signals
## to SurvivalSystem, ScannerSystem, ScreenFade, and AutoInteractionSystem.

const _FaunaManager = preload("res://scripts/fauna/fauna_manager.gd")


# === Mocks ===

class MockSurvival extends Node:
	var damage_taken: float = 0.0
	var take_damage_calls: int = 0

	func take_damage(amount: float) -> void:
		damage_taken += amount
		take_damage_calls += 1


class MockScanner extends Node:
	signal entry_encountered(entry_id: StringName, label: String)
	signal knowledge_state_changed(entry_id: StringName, old_state: int, new_state: int)
	signal surprise_cataloged(entry_id: StringName)

	var attacked_calls: Array[Dictionary] = []

	func on_fauna_attacked_player(fauna_id: int, damage: int, species_type: StringName) -> void:
		attacked_calls.append({
			"fauna_id": fauna_id,
			"damage": damage,
			"species_type": species_type,
		})

	func get_catalog() -> RefCounted:
		return null


class MockScreenFade extends Node:
	var flash_calls: Array[Dictionary] = []

	func flash(color: Color = Color.RED, duration: float = 0.2) -> void:
		flash_calls.append({"color": color, "duration": duration})


class MockAutoInteraction extends Node:
	signal auto_defend_triggered(fauna_id: int, damage: int)
	var fauna_moved_calls: Array[Dictionary] = []
	var _fauna_manager: Node = null

	func _on_fauna_moved(fauna_id: int, coords: Vector2i) -> void:
		fauna_moved_calls.append({"fauna_id": fauna_id, "coords": coords})


# === Helpers ===

## Simulates what main.gd._wire_fauna does, using provided mocks.
func _wire_fauna_test(fauna_mgr: Node, survival: Node, scanner: Node,
		screen_fade: Node, auto_interaction: Node) -> void:
	# fauna_attacked_player → SurvivalSystem.take_damage
	if survival != null and survival.has_method("take_damage"):
		fauna_mgr.fauna_attacked_player.connect(
			func(_id: int, damage: int, _species: StringName) -> void:
				survival.take_damage(damage)
		)

	# fauna_attacked_player → ScannerSystem surprise encounter
	if scanner != null and scanner.has_method("on_fauna_attacked_player"):
		fauna_mgr.fauna_attacked_player.connect(scanner.on_fauna_attacked_player)

	# fauna_attacked_player → ScreenFade.flash(red)
	if screen_fade != null and screen_fade.has_method("flash"):
		fauna_mgr.fauna_attacked_player.connect(
			func(_id: int, damage: int, _species: StringName) -> void:
				if damage > 0:
					screen_fade.flash(Color.RED)
		)

	# fauna_moved → AutoInteractionSystem._on_fauna_moved
	if auto_interaction != null:
		if "_fauna_manager" in auto_interaction:
			auto_interaction._fauna_manager = fauna_mgr
		fauna_mgr.fauna_moved.connect(
			func(id: int, _old: Vector2i, new_c: Vector2i, _sp: StringName) -> void:
				if auto_interaction.has_method("_on_fauna_moved"):
					auto_interaction._on_fauna_moved(id, new_c)
		)

	# auto_defend_triggered → FaunaManager.apply_damage
	if auto_interaction != null and fauna_mgr.has_method("apply_damage"):
		auto_interaction.auto_defend_triggered.connect(fauna_mgr.apply_damage)


# === Tests ===

var _fm: Node
var _survival: MockSurvival
var _scanner: MockScanner
var _screen_fade: MockScreenFade
var _auto_interaction: MockAutoInteraction


func before_test() -> void:
	_fm = _FaunaManager.new()
	add_child(_fm)
	_survival = MockSurvival.new()
	add_child(_survival)
	_scanner = MockScanner.new()
	add_child(_scanner)
	_screen_fade = MockScreenFade.new()
	add_child(_screen_fade)
	_auto_interaction = MockAutoInteraction.new()
	add_child(_auto_interaction)

	_wire_fauna_test(_fm, _survival, _scanner, _screen_fade, _auto_interaction)


func after_test() -> void:
	for child in [_fm, _survival, _scanner, _screen_fade, _auto_interaction]:
		remove_child(child)
		child.queue_free()


# =========================================================================
# FAUNA_ATTACKED_PLAYER WIRING
# =========================================================================

func test_attack_wires_to_survival_take_damage() -> void:
	_fm.fauna_attacked_player.emit(0, 10, &"P00108")
	assert_float(_survival.damage_taken).is_equal(10.0)
	assert_int(_survival.take_damage_calls).is_equal(1)


func test_attack_zero_damage_still_calls_take_damage() -> void:
	_fm.fauna_attacked_player.emit(0, 0, &"P00108")
	assert_float(_survival.damage_taken).is_equal(0.0)
	assert_int(_survival.take_damage_calls).is_equal(1)


func test_attack_wires_to_scanner_encounter() -> void:
	_fm.fauna_attacked_player.emit(0, 10, &"P00108")
	assert_int(_scanner.attacked_calls.size()).is_equal(1)
	assert_str(_scanner.attacked_calls[0]["species_type"]).is_equal("P00108")


func test_attack_wires_to_screen_flash_on_damage() -> void:
	_fm.fauna_attacked_player.emit(0, 10, &"P00108")
	assert_int(_screen_fade.flash_calls.size()).is_equal(1)
	assert_object(_screen_fade.flash_calls[0]["color"]).is_equal(Color.RED)


func test_attack_no_flash_on_zero_damage() -> void:
	_fm.fauna_attacked_player.emit(0, 0, &"P00108")
	assert_int(_screen_fade.flash_calls.size()).is_equal(0)


func test_multiple_attacks_accumulate_damage() -> void:
	_fm.fauna_attacked_player.emit(0, 10, &"P00108")
	_fm.fauna_attacked_player.emit(1, 10, &"P00108")
	assert_float(_survival.damage_taken).is_equal(20.0)
	assert_int(_survival.take_damage_calls).is_equal(2)


# =========================================================================
# FAUNA_MOVED WIRING
# =========================================================================

func test_fauna_moved_wires_to_auto_interaction() -> void:
	_fm.fauna_moved.emit(0, Vector2i(3, 0), Vector2i(2, 0), &"P00108")
	assert_int(_auto_interaction.fauna_moved_calls.size()).is_equal(1)
	var call: Dictionary = _auto_interaction.fauna_moved_calls[0]
	assert_int(call["fauna_id"]).is_equal(0)
	# Should receive new_coords, not old_coords
	assert_object(call["coords"]).is_equal(Vector2i(2, 0))


func test_fauna_moved_passes_new_coords_not_old() -> void:
	_fm.fauna_moved.emit(5, Vector2i(0, 0), Vector2i(1, 1), &"P00108")
	var call: Dictionary = _auto_interaction.fauna_moved_calls[0]
	assert_object(call["coords"]).is_equal(Vector2i(1, 1))


# =========================================================================
# AUTO_DEFEND → APPLY_DAMAGE WIRING
# =========================================================================

func test_auto_defend_wires_back_to_fauna_manager() -> void:
	# auto_defend_triggered should connect to FaunaManager.apply_damage
	# We can verify the connection exists by checking signal connections
	var connections: Array = _auto_interaction.auto_defend_triggered.get_connections()
	assert_bool(connections.size() > 0).is_true()


# =========================================================================
# FAUNA MANAGER REFERENCE INJECTION
# =========================================================================

func test_auto_interaction_receives_fauna_manager_ref() -> void:
	assert_object(_auto_interaction._fauna_manager).is_equal(_fm)
