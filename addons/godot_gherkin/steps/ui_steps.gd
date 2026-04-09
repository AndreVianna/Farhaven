extends RefCounted
## Built-in UI testing step definitions for GodotGherkin.
##
## These steps provide common UI testing patterns. To use them, either:
## 1. Copy this file to your tests/steps directory
## 2. Or load it manually in your test setup
##
## Supports query syntax for node selection:
##   "Button:text=Continue" - Button with text "Continue"
##   "Label:first" - First Label node
##   "Control:visible" - First visible Control
##   "Button:focused" - Focused button
##
## Available steps:
##   Given I load scene {string}
##   When I click button {string}
##   When I click {string}
##   When I press key {string}
##   When I type {string} into field {string}
##   When I hover over {string}
##   Then button {string} should be visible/hidden/enabled/disabled
##   Then {string} should be visible/hidden/focused
##   Then {string} should have text {string}
##   Then {string} should be below/above/right of/left of {string}
##   Then {string} should have color {string}
##   Then {string} should fit within viewport
##   Then no UI elements should overlap

const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")


func register_steps(registry: StepRegistryScript) -> void:
	# Scene loading
	registry.given("I load scene {string}", _load_scene)

	# Interactions
	registry.when("I click button {string}", _click_button)
	registry.when("I click {string}", _click_node)
	registry.when("I press key {string}", _press_key)
	registry.when("I type {string}", _type_text)
	registry.when("I type {string} into field {string}", _type_into_field)
	registry.when("I hover over {string}", _hover_over)
	registry.when("I focus {string}", _focus_node)

	# Button visibility assertions
	registry.then("button {string} should be visible", _button_visible)
	registry.then("button {string} should be hidden", _button_hidden)
	registry.then("button {string} should not be visible", _button_hidden)
	registry.then("button {string} should be enabled", _button_enabled)
	registry.then("button {string} should be disabled", _button_disabled)

	# Generic node assertions
	registry.then("{string} should be visible", _node_visible)
	registry.then("{string} should be hidden", _node_hidden)
	registry.then("{string} should have text {string}", _node_has_text)
	registry.then("{string} should be focused", _node_focused)
	registry.then("{string} should exist", _node_exists)
	registry.then("{string} should not exist", _node_not_exists)

	# Layout assertions
	registry.then("{string} should be below {string}", _node_below)
	registry.then("{string} should be above {string}", _node_above)
	registry.then("{string} should be right of {string}", _node_right_of)
	registry.then("{string} should be left of {string}", _node_left_of)
	registry.then("{string} should fit within viewport", _node_within_viewport)
	registry.then("{string} should have color {string}", _node_has_color)
	registry.then("no UI elements should overlap", _no_overlap)


# === Scene Loading ===


func _load_scene(ctx: TestContextScript, path: String) -> void:
	var scene := ctx.load_scene(path)
	ctx.assert_not_null(scene, "Failed to load scene: %s" % path)


# === Interactions ===


func _click_button(ctx: TestContextScript, button_text: String) -> void:
	var button := ctx.find_button(button_text)
	ctx.assert_not_null(button, "Button not found: %s" % button_text)
	if button:
		ctx.simulate_click(button)


func _press_key(ctx: TestContextScript, key_name: String) -> void:
	ctx.simulate_key_press(key_name)


func _type_text(ctx: TestContextScript, text: String) -> void:
	ctx.simulate_text_input(text)


func _type_into_field(ctx: TestContextScript, text: String, field_name: String) -> void:
	var field := _find_node(ctx, field_name)
	ctx.assert_not_null(field, "Field not found: %s" % field_name)
	if field and field is Control:
		field.grab_focus()
		ctx.simulate_text_input(text)


func _hover_over(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node and node is Control:
		ctx.simulate_hover(node)


func _focus_node(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node and node is Control:
		node.grab_focus()


# === Button Assertions ===


func _button_visible(ctx: TestContextScript, button_text: String) -> void:
	var button := ctx.find_button(button_text)
	ctx.assert_not_null(button, "Button not found: %s" % button_text)
	if button:
		ctx.assert_true(button.visible, "Button should be visible: %s" % button_text)


func _button_hidden(ctx: TestContextScript, button_text: String) -> void:
	var button := ctx.find_button(button_text)
	# Button being null OR not visible both count as "hidden"
	if button:
		ctx.assert_false(button.visible, "Button should be hidden: %s" % button_text)


func _button_enabled(ctx: TestContextScript, button_text: String) -> void:
	var button := ctx.find_button(button_text)
	ctx.assert_not_null(button, "Button not found: %s" % button_text)
	if button:
		ctx.assert_false(button.disabled, "Button should be enabled: %s" % button_text)


func _button_disabled(ctx: TestContextScript, button_text: String) -> void:
	var button := ctx.find_button(button_text)
	ctx.assert_not_null(button, "Button not found: %s" % button_text)
	if button:
		ctx.assert_true(button.disabled, "Button should be disabled: %s" % button_text)


# === Generic Node Assertions ===


func _node_visible(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node and node is CanvasItem:
		ctx.assert_true(node.visible, "Node should be visible: %s" % node_query)


func _node_hidden(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	if node and node is CanvasItem:
		ctx.assert_false(node.visible, "Node should be hidden: %s" % node_query)


func _node_has_text(ctx: TestContextScript, node_query: String, expected_text: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node:
		var actual_text = node.get("text")
		ctx.assert_equal(actual_text, expected_text, "Node text mismatch")


func _node_focused(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node and node is Control:
		ctx.assert_true(node.has_focus(), "Node should be focused: %s" % node_query)


func _node_exists(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node should exist: %s" % node_query)


func _node_not_exists(ctx: TestContextScript, node_path: String) -> void:
	var node := _find_node(ctx, node_path)
	ctx.assert_null(node, "Node should not exist: %s" % node_path)


# === Layout Assertions ===


func _node_below(ctx: TestContextScript, node_a_query: String, node_b_query: String) -> void:
	var node_a := _find_node(ctx, node_a_query)
	var node_b := _find_node(ctx, node_b_query)

	ctx.assert_not_null(node_a, "Node not found: %s" % node_a_query)
	ctx.assert_not_null(node_b, "Node not found: %s" % node_b_query)

	if node_a and node_b and node_a is Control and node_b is Control:
		ctx.assert_below(node_a, node_b)


func _node_above(ctx: TestContextScript, node_a_query: String, node_b_query: String) -> void:
	var node_a := _find_node(ctx, node_a_query)
	var node_b := _find_node(ctx, node_b_query)

	ctx.assert_not_null(node_a, "Node not found: %s" % node_a_query)
	ctx.assert_not_null(node_b, "Node not found: %s" % node_b_query)

	if node_a and node_b and node_a is Control and node_b is Control:
		ctx.assert_above(node_a, node_b)


func _node_right_of(ctx: TestContextScript, node_a_query: String, node_b_query: String) -> void:
	var node_a := _find_node(ctx, node_a_query)
	var node_b := _find_node(ctx, node_b_query)

	ctx.assert_not_null(node_a, "Node not found: %s" % node_a_query)
	ctx.assert_not_null(node_b, "Node not found: %s" % node_b_query)

	if node_a and node_b and node_a is Control and node_b is Control:
		ctx.assert_right_of(node_a, node_b)


func _node_left_of(ctx: TestContextScript, node_a_query: String, node_b_query: String) -> void:
	var node_a := _find_node(ctx, node_a_query)
	var node_b := _find_node(ctx, node_b_query)

	ctx.assert_not_null(node_a, "Node not found: %s" % node_a_query)
	ctx.assert_not_null(node_b, "Node not found: %s" % node_b_query)

	if node_a and node_b and node_a is Control and node_b is Control:
		ctx.assert_left_of(node_a, node_b)


func _node_within_viewport(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node and node is Control:
		ctx.assert_within_viewport(node)


func _node_has_color(ctx: TestContextScript, node_query: String, color: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node and node is CanvasItem:
		ctx.assert_color(node, color)


func _no_overlap(ctx: TestContextScript) -> void:
	var controls := ctx.find_nodes_by_type("Control")
	# Filter to only visible controls
	var visible_controls: Array = []
	for ctrl in controls:
		if ctrl is Control and ctrl.visible:
			visible_controls.append(ctrl)
	ctx.assert_no_overlap(visible_controls)


# === Helpers ===


## Find a node using query syntax, node path, or text search.
## Query syntax: "Type:property=value" or "Type:special"
func _find_node(ctx: TestContextScript, identifier: String) -> Node:
	# Check if it's a query (contains colon with type prefix)
	if ":" in identifier and _looks_like_query(identifier):
		return ctx.query_node(identifier)

	# Try node path first (for paths like "VBoxContainer/Button")
	var node := ctx.get_node(identifier)
	if node:
		return node

	# Try recursive name search (for names like "TitleLabel")
	node = ctx.find_node_by_name(identifier)
	if node:
		return node

	# Try text search as fallback
	return ctx.find_node_by_text(identifier)


## Check if the identifier looks like a query (Type:rest format).
func _looks_like_query(identifier: String) -> bool:
	var colon_idx := identifier.find(":")
	if colon_idx <= 0:
		return false

	# Check if the part before colon is a valid class name (starts with uppercase)
	var type_part := identifier.substr(0, colon_idx)
	return type_part.length() > 0 and type_part[0] == type_part[0].to_upper()


## Click a node found by query, path, or text.
func _click_node(ctx: TestContextScript, node_query: String) -> void:
	var node := _find_node(ctx, node_query)
	ctx.assert_not_null(node, "Node not found: %s" % node_query)
	if node and node is Control:
		ctx.simulate_click(node)
