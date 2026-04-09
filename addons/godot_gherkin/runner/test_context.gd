extends RefCounted
## Shared state and assertions for step execution.
##
## Self-reference for headless mode compatibility
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")
##
## Each scenario gets a fresh TestContext that persists across steps
## within that scenario. Provides state storage and assertion helpers.

## Scenario-scoped state storage.
var _state: Dictionary = {}

## Optional SceneTree reference for async operations.
var _scene_tree: SceneTree = null

## Current scene for scene-based testing.
var _current_scene: Node = null

## Assertion tracking.
var assertions_passed: int = 0
var assertions_failed: int = 0
var _last_error: String = ""


func _init(scene_tree: SceneTree = null) -> void:
	_scene_tree = scene_tree


# === State Management ===


## Set a value in the context state.
func set_value(key: String, value: Variant) -> void:
	_state[key] = value


## Get a value from the context state.
func get_value(key: String, default: Variant = null) -> Variant:
	return _state.get(key, default)


## Check if a key exists in the state.
func has_value(key: String) -> bool:
	return _state.has(key)


## Remove a value from the state.
func remove_value(key: String) -> void:
	_state.erase(key)


## Clear all state.
func clear_state() -> void:
	_state.clear()


## Clear all state and reset counters.
func reset() -> void:
	_state.clear()
	assertions_passed = 0
	assertions_failed = 0
	_last_error = ""
	free_scene()


# === SceneTree Access ===


## Get the SceneTree (may be null in headless mode).
func get_tree() -> SceneTree:
	return _scene_tree


## Set the SceneTree reference.
func set_tree(tree: SceneTree) -> void:
	_scene_tree = tree


## Check if SceneTree is available.
func has_tree() -> bool:
	return _scene_tree != null


# === Async Helpers ===


## Wait for N process frames (default: 1).
## Returns a Signal that completes after the frames.
## Usage: return await ctx.await_frames()
func await_frames(count: int = 1) -> Signal:
	if not _scene_tree:
		push_warning("await_frames: No SceneTree available")
		return Signal()
	for i in range(count):
		await _scene_tree.process_frame
	return Signal()


## Wait for the next idle frame.
## Returns a Signal that completes on the next idle frame.
## Usage: return await ctx.await_idle()
func await_idle() -> Signal:
	if not _scene_tree:
		push_warning("await_idle: No SceneTree available")
		return Signal()
	await _scene_tree.process_frame
	return Signal()


## Wait for a signal with optional timeout.
## Returns the signal's emitted arguments, or an empty array on timeout.
## Usage: var args = await ctx.await_signal_with_timeout(node.some_signal, 5.0)
func await_signal_with_timeout(sig: Signal, timeout_sec: float = 5.0) -> Array:
	if not _scene_tree:
		push_warning("await_signal_with_timeout: No SceneTree available")
		return []

	var result: Array = []
	var timed_out := false

	# Create timer for timeout
	var timer := _scene_tree.create_timer(timeout_sec)
	timer.timeout.connect(func(): timed_out = true, CONNECT_ONE_SHOT)

	# Connect to signal to capture result
	var captured := false
	sig.connect(
		func(args = []):
			if not timed_out:
				result = [args] if args != null else []
				captured = true,
		CONNECT_ONE_SHOT
	)

	# Wait until either signal fires or timeout
	while not captured and not timed_out:
		await _scene_tree.process_frame

	return result


# === Scene Management ===


## Load and instantiate a scene.
func load_scene(path: String) -> Node:
	free_scene()

	var packed := load(path) as PackedScene
	if not packed:
		_record_error("Failed to load scene: %s" % path)
		return null

	_current_scene = packed.instantiate()

	if _scene_tree:
		_scene_tree.root.add_child(_current_scene)

	return _current_scene


## Get the current scene.
func get_scene() -> Node:
	return _current_scene


## Get a node from the current scene by path.
func get_node(path: String) -> Node:
	if _current_scene:
		return _current_scene.get_node_or_null(path)
	return null


## Free the current scene.
func free_scene() -> void:
	if _current_scene and is_instance_valid(_current_scene):
		_current_scene.queue_free()
		_current_scene = null


# === Assertions ===


## Assert that two values are equal.
func assert_equal(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s but got %s" % [expected, actual]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that two values are not equal.
func assert_not_equal(actual: Variant, not_expected: Variant, message: String = "") -> bool:
	if actual != not_expected:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected value to not equal %s" % [not_expected]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a condition is true.
func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected condition to be true"
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a condition is false.
func assert_false(condition: bool, message: String = "") -> bool:
	if not condition:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected condition to be false"
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is not null.
func assert_not_null(value: Variant, message: String = "") -> bool:
	if value != null:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected non-null value"
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is null.
func assert_null(value: Variant, message: String = "") -> bool:
	if value == null:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected null but got %s" % [value]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a container contains an item.
func assert_contains(container: Variant, item: Variant, message: String = "") -> bool:
	var contains := false

	if container is String:
		contains = container.contains(str(item))
	elif container is Array:
		contains = container.has(item)
	elif container is Dictionary:
		contains = container.has(item)
	else:
		_record_error("assert_contains: Unsupported container type")
		assertions_failed += 1
		return false

	if contains:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to contain %s" % [container, item]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a container does not contain an item.
func assert_not_contains(container: Variant, item: Variant, message: String = "") -> bool:
	var contains := false

	if container is String:
		contains = container.contains(str(item))
	elif container is Array:
		contains = container.has(item)
	elif container is Dictionary:
		contains = container.has(item)
	else:
		_record_error("assert_not_contains: Unsupported container type")
		assertions_failed += 1
		return false

	if not contains:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to not contain %s" % [container, item]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is greater than another.
## Alias: assert_greater_than
func assert_greater(actual: Variant, threshold: Variant, message: String = "") -> bool:
	if actual > threshold:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to be greater than %s" % [actual, threshold]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is less than another.
## Alias: assert_less_than
func assert_less(actual: Variant, threshold: Variant, message: String = "") -> bool:
	if actual < threshold:
		assertions_passed += 1
		return true

	var msg := message if message else "Expected %s to be less than %s" % [actual, threshold]
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is greater than or equal to another.
func assert_greater_or_equal(actual: Variant, threshold: Variant, message: String = "") -> bool:
	if actual >= threshold:
		assertions_passed += 1
		return true

	var msg := (
		message
		if message
		else "Expected %s to be greater than or equal to %s" % [actual, threshold]
	)
	_record_error(msg)
	assertions_failed += 1
	return false


## Assert that a value is less than or equal to another.
func assert_less_or_equal(actual: Variant, threshold: Variant, message: String = "") -> bool:
	if actual <= threshold:
		assertions_passed += 1
		return true

	var msg := (
		message if message else "Expected %s to be less than or equal to %s" % [actual, threshold]
	)
	_record_error(msg)
	assertions_failed += 1
	return false


## Alias for assert_greater for naming consistency.
func assert_greater_than(actual: Variant, threshold: Variant, message: String = "") -> bool:
	return assert_greater(actual, threshold, message)


## Alias for assert_less for naming consistency.
func assert_less_than(actual: Variant, threshold: Variant, message: String = "") -> bool:
	return assert_less(actual, threshold, message)


## Fail with a message.
func fail(message: String = "Test failed") -> bool:
	_record_error(message)
	assertions_failed += 1
	return false


# === Error Tracking ===


## Record an error message.
func _record_error(message: String) -> void:
	_last_error = message
	push_error("ASSERTION FAILED: " + message)


## Get the last error message.
func get_last_error() -> String:
	return _last_error


## Check if any assertions failed.
func has_failures() -> bool:
	return assertions_failed > 0


## Get total assertion count.
func total_assertions() -> int:
	return assertions_passed + assertions_failed


# === Input Simulation ===


## Simulate clicking a Control node (button, etc).
## Emits pressed signal for BaseButton, or gui_input for other Controls.
func simulate_click(node: Control) -> void:
	if not is_instance_valid(node):
		_record_error("simulate_click: Node is not valid")
		return

	# For buttons, emit pressed signal directly
	if node is BaseButton:
		node.emit_signal("pressed")
		return

	# For other controls, simulate mouse click via gui_input
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = node.size / 2
	node._gui_input(click)

	# Release
	click.pressed = false
	node._gui_input(click)


## Simulate pressing a key.
## key_code can be a KEY_* constant or a string like "Enter", "Escape", "Space".
func simulate_key_press(key_code: Variant) -> void:
	var keycode: int
	if key_code is String:
		keycode = _string_to_keycode(key_code)
	else:
		keycode = key_code

	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)

	event.pressed = false
	Input.parse_input_event(event)


## Type text into the focused control.
## Simulates key presses for each character.
func simulate_text_input(text: String) -> void:
	for c in text:
		var event := InputEventKey.new()
		event.unicode = c.unicode_at(0)
		event.pressed = true
		Input.parse_input_event(event)
		event.pressed = false
		Input.parse_input_event(event)


## Move the mouse to a position (relative to viewport).
func simulate_mouse_move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


## Simulate mouse hover over a control.
func simulate_hover(node: Control) -> void:
	if not is_instance_valid(node):
		return
	var center := node.global_position + node.size / 2
	simulate_mouse_move(center)


# === Node Finding ===


## Find a node by its text property (for Label, Button, etc).
## Searches within the current scene or optionally a specific root.
func find_node_by_text(text: String, root: Node = null) -> Node:
	var search_root: Node = root if root else _current_scene
	if not search_root:
		return null
	return _find_node_by_property(search_root, "text", text)


## Find a node by its name (recursive search).
func find_node_by_name(node_name: String, root: Node = null) -> Node:
	var search_root: Node = root if root else _current_scene
	if not search_root:
		return null
	return _find_node_by_property(search_root, "name", node_name)


## Find a button by its text.
func find_button(text: String, root: Node = null) -> BaseButton:
	var search_root: Node = root if root else _current_scene
	if not search_root:
		return null

	var result := _find_node_by_property_type(search_root, "text", text, "BaseButton")
	return result as BaseButton


## Find a node by a property value.
func _find_node_by_property(root: Node, property: String, value: Variant) -> Node:
	if root.get(property) == value:
		return root

	for child in root.get_children():
		var found := _find_node_by_property(child, property, value)
		if found:
			return found

	return null


## Find a node by property value and type.
func _find_node_by_property_type(
	root: Node, property: String, value: Variant, type_name: String
) -> Node:
	if root.is_class(type_name) and root.get(property) == value:
		return root

	for child in root.get_children():
		var found := _find_node_by_property_type(child, property, value, type_name)
		if found:
			return found

	return null


## Find all nodes of a specific type.
func find_nodes_by_type(type_name: String, root: Node = null) -> Array[Node]:
	var search_root: Node = root if root else _current_scene
	var results: Array[Node] = []
	if search_root:
		_collect_nodes_by_type(search_root, type_name, results)
	return results


func _collect_nodes_by_type(root: Node, type_name: String, results: Array[Node]) -> void:
	if root.is_class(type_name):
		results.append(root)
	for child in root.get_children():
		_collect_nodes_by_type(child, type_name, results)


## Keycode lookup table for string to KEY_* conversion.
const KEYCODE_MAP := {
	"enter": KEY_ENTER,
	"return": KEY_ENTER,
	"escape": KEY_ESCAPE,
	"esc": KEY_ESCAPE,
	"space": KEY_SPACE,
	"tab": KEY_TAB,
	"backspace": KEY_BACKSPACE,
	"delete": KEY_DELETE,
	"up": KEY_UP,
	"down": KEY_DOWN,
	"left": KEY_LEFT,
	"right": KEY_RIGHT,
	"home": KEY_HOME,
	"end": KEY_END,
	"pageup": KEY_PAGEUP,
	"pagedown": KEY_PAGEDOWN,
	"f1": KEY_F1,
	"f2": KEY_F2,
	"f3": KEY_F3,
	"f4": KEY_F4,
	"f5": KEY_F5,
	"f6": KEY_F6,
	"f7": KEY_F7,
	"f8": KEY_F8,
	"f9": KEY_F9,
	"f10": KEY_F10,
	"f11": KEY_F11,
	"f12": KEY_F12,
}


## Convert a string key name to keycode.
func _string_to_keycode(key_name: String) -> int:
	var lower_name := key_name.to_lower()
	if KEYCODE_MAP.has(lower_name):
		return KEYCODE_MAP[lower_name]

	# Try to get single character keycode
	if key_name.length() == 1:
		return key_name.to_upper().unicode_at(0)

	return KEY_NONE


# === Node Query Syntax ===


## Query for a single node using query syntax.
## Format: "Type:property=value" or "Type:special"
## Examples:
##   "Button:text=Continue" - Button with text "Continue"
##   "Label:first" - First Label node
##   "Control:visible" - First visible Control
##   "Button:focused" - Focused button
func query_node(query: String, root: Node = null) -> Node:
	var results := query_nodes(query, root)
	return results[0] if results.size() > 0 else null


## Query for all nodes matching the query syntax.
func query_nodes(query: String, root: Node = null) -> Array[Node]:
	var search_root: Node = root if root else _current_scene
	if not search_root:
		return []

	var parsed := _parse_query(query)
	if parsed.is_empty():
		return []

	var type_name: String = parsed.get("type", "Node")
	var property: String = parsed.get("property", "")
	var value: String = parsed.get("value", "")
	var special: String = parsed.get("special", "")

	# Find all nodes of the type
	var candidates := find_nodes_by_type(type_name, search_root)

	# Apply filters
	var results: Array[Node] = []
	for node in candidates:
		if _node_matches_query(node, property, value, special):
			results.append(node)

	# Handle special selectors that modify results
	if special == "first" and results.size() > 0:
		return [results[0]]
	if special == "last" and results.size() > 0:
		return [results[-1]]

	return results


## Parse a query string into components.
func _parse_query(query: String) -> Dictionary:
	var result := {}

	# Check for Type:rest format
	var colon_idx := query.find(":")
	if colon_idx == -1:
		# Just a type name or node path
		result["type"] = query
		return result

	result["type"] = query.substr(0, colon_idx)
	var rest := query.substr(colon_idx + 1)

	# Check for property=value format
	var eq_idx := rest.find("=")
	if eq_idx != -1:
		result["property"] = rest.substr(0, eq_idx)
		result["value"] = rest.substr(eq_idx + 1)
	else:
		# Special selector (first, last, visible, focused)
		result["special"] = rest

	return result


## Check if a node matches query criteria.
func _node_matches_query(node: Node, property: String, value: String, special: String) -> bool:
	# Property=value matching
	if not property.is_empty():
		var node_value = node.get(property)
		if node_value == null:
			return false
		return str(node_value) == value

	# Special selectors
	match special:
		"visible":
			return node is CanvasItem and node.visible
		"hidden":
			return node is CanvasItem and not node.visible
		"focused":
			return node is Control and node.has_focus()
		"enabled":
			return node is BaseButton and not node.disabled
		"disabled":
			return node is BaseButton and node.disabled
		"first", "last":
			return true  # Handled after collection
		"":
			return true  # No filter

	return true


# === Layout Assertions ===


## Assert that node_a is positioned below node_b (higher Y value).
func assert_below(node_a: Control, node_b: Control, message: String = "") -> bool:
	if not is_instance_valid(node_a) or not is_instance_valid(node_b):
		return fail("assert_below: One or both nodes are invalid")

	var a_top := node_a.global_position.y
	var b_bottom := node_b.global_position.y + node_b.size.y

	if a_top >= b_bottom:
		assertions_passed += 1
		return true

	var msg := message if message else "'%s' should be below '%s'" % [node_a.name, node_b.name]
	return fail(msg)


## Assert that node_a is positioned above node_b (lower Y value).
func assert_above(node_a: Control, node_b: Control, message: String = "") -> bool:
	if not is_instance_valid(node_a) or not is_instance_valid(node_b):
		return fail("assert_above: One or both nodes are invalid")

	var a_bottom := node_a.global_position.y + node_a.size.y
	var b_top := node_b.global_position.y

	if a_bottom <= b_top:
		assertions_passed += 1
		return true

	var msg := message if message else "'%s' should be above '%s'" % [node_a.name, node_b.name]
	return fail(msg)


## Assert that node_a is positioned to the right of node_b.
func assert_right_of(node_a: Control, node_b: Control, message: String = "") -> bool:
	if not is_instance_valid(node_a) or not is_instance_valid(node_b):
		return fail("assert_right_of: One or both nodes are invalid")

	var a_left := node_a.global_position.x
	var b_right := node_b.global_position.x + node_b.size.x

	if a_left >= b_right:
		assertions_passed += 1
		return true

	var msg := message if message else "'%s' should be right of '%s'" % [node_a.name, node_b.name]
	return fail(msg)


## Assert that node_a is positioned to the left of node_b.
func assert_left_of(node_a: Control, node_b: Control, message: String = "") -> bool:
	if not is_instance_valid(node_a) or not is_instance_valid(node_b):
		return fail("assert_left_of: One or both nodes are invalid")

	var a_right := node_a.global_position.x + node_a.size.x
	var b_left := node_b.global_position.x

	if a_right <= b_left:
		assertions_passed += 1
		return true

	var msg := message if message else "'%s' should be left of '%s'" % [node_a.name, node_b.name]
	return fail(msg)


## Assert that a node fits entirely within the viewport.
func assert_within_viewport(node: Control, message: String = "") -> bool:
	if not is_instance_valid(node):
		return fail("assert_within_viewport: Node is invalid")

	if not _scene_tree:
		return fail("assert_within_viewport: No SceneTree available")

	var viewport_size := _scene_tree.root.get_visible_rect().size
	var node_rect := Rect2(node.global_position, node.size)
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)

	if viewport_rect.encloses(node_rect):
		assertions_passed += 1
		return true

	var msg := message if message else "'%s' should fit within viewport" % node.name
	return fail(msg)


## Assert that no nodes in the array overlap each other.
func assert_no_overlap(nodes: Array, message: String = "") -> bool:
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var node_a: Control = nodes[i]
			var node_b: Control = nodes[j]

			if not is_instance_valid(node_a) or not is_instance_valid(node_b):
				continue

			var rect_a := Rect2(node_a.global_position, node_a.size)
			var rect_b := Rect2(node_b.global_position, node_b.size)

			if rect_a.intersects(rect_b):
				var msg := (
					message if message else "'%s' and '%s' overlap" % [node_a.name, node_b.name]
				)
				return fail(msg)

	assertions_passed += 1
	return true


## Assert that a control has a specific modulate/self_modulate color.
## color can be a Color or a hex string like "#ff0000".
func assert_color(node: CanvasItem, expected_color: Variant, message: String = "") -> bool:
	if not is_instance_valid(node):
		return fail("assert_color: Node is invalid")

	var expected: Color
	if expected_color is String:
		expected = Color.from_string(expected_color, Color.WHITE)
	else:
		expected = expected_color

	# Check self_modulate first (more specific), then modulate
	var actual := node.self_modulate if node.self_modulate != Color.WHITE else node.modulate

	if actual.is_equal_approx(expected):
		assertions_passed += 1
		return true

	var msg := (
		message
		if message
		else "'%s' color mismatch: expected %s, got %s" % [node.name, expected, actual]
	)
	return fail(msg)


## Assert that a node has a specific theme color override.
func assert_theme_color(
	node: Control, color_name: String, expected: Color, msg: String = ""
) -> bool:
	if not is_instance_valid(node):
		return fail("assert_theme_color: Node is invalid")

	if not node.has_theme_color_override(color_name):
		return fail("'%s' has no theme color override '%s'" % [node.name, color_name])

	var actual := node.get_theme_color(color_name)
	if actual.is_equal_approx(expected):
		assertions_passed += 1
		return true

	var message := msg if msg else "'%s' theme color '%s' mismatch" % [node.name, color_name]
	return fail(message)
