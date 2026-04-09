extends RefCounted
## Generates step definition snippets for undefined steps.
##
## Self-reference for headless mode compatibility
const SnippetGeneratorScript = preload("res://addons/godot_gherkin/util/snippet_generator.gd")
##
## Analyzes step text to infer parameter types and generates
## copy-pasteable step definition code.


## Generate a step definition snippet for an undefined step.
## step_signature should be in format "Given some step text" or "When the user does {something}"
static func generate_snippet(step_signature: String) -> String:
	# Parse keyword and step text
	var parts := step_signature.split(" ", false, 1)
	if parts.size() < 2:
		return ""

	var keyword := parts[0].to_lower()
	var step_text := parts[1]

	# Infer parameter types and build pattern
	var pattern_result := _infer_pattern(step_text)
	var pattern := pattern_result.pattern
	var param_types := pattern_result.param_types

	# Generate function name
	var func_name := _generate_function_name(step_text)

	# Build parameter list for function signature
	var params := "ctx"
	for i in range(param_types.size()):
		var type_hint := param_types[i]
		params += ", arg%d: %s" % [i + 1, type_hint]

	# Generate the snippet
	var snippet := '    registry.%s("%s", %s)\n\n' % [keyword, pattern, func_name]
	snippet += "    func %s(%s) -> void:\n" % [func_name, params]
	snippet += "        # TODO: implement step\n"
	snippet += "        pass"

	return snippet


## Result of pattern inference.
class PatternResult:
	var pattern: String = ""
	var param_types: Array[String] = []


## Infer a Cucumber Expression pattern from step text.
static func _infer_pattern(step_text: String) -> PatternResult:
	var result := PatternResult.new()
	var pattern := step_text
	var param_types: Array[String] = []

	# Regex patterns for common parameter types
	var int_regex := RegEx.new()
	int_regex.compile("\\b\\d+\\b")

	var float_regex := RegEx.new()
	float_regex.compile("\\b\\d+\\.\\d+\\b")

	var string_regex := RegEx.new()
	string_regex.compile('"[^"]*"')

	# Replace floats first (more specific than ints)
	var float_matches := float_regex.search_all(pattern)
	for i in range(float_matches.size() - 1, -1, -1):  # Reverse order to preserve positions
		var m := float_matches[i]
		pattern = pattern.substr(0, m.get_start()) + "{float}" + pattern.substr(m.get_end())
		param_types.insert(0, "float")

	# Replace integers (but not those already replaced as floats)
	var int_matches := int_regex.search_all(pattern)
	for i in range(int_matches.size() - 1, -1, -1):
		var m := int_matches[i]
		# Skip if this is part of {float}
		if pattern.substr(m.get_start(), 7) == "{float}":
			continue
		pattern = pattern.substr(0, m.get_start()) + "{int}" + pattern.substr(m.get_end())
		param_types.insert(0, "int")

	# Replace quoted strings
	var string_matches := string_regex.search_all(pattern)
	for i in range(string_matches.size() - 1, -1, -1):
		var m := string_matches[i]
		pattern = pattern.substr(0, m.get_start()) + "{string}" + pattern.substr(m.get_end())
		param_types.insert(0, "String")

	result.pattern = pattern
	result.param_types = param_types
	return result


## Generate a valid GDScript function name from step text.
static func _generate_function_name(step_text: String) -> String:
	var name := step_text.to_lower()

	# Remove quotes and their contents
	var quote_regex := RegEx.new()
	quote_regex.compile('"[^"]*"')
	name = quote_regex.sub(name, "", true)

	# Replace numbers with placeholders
	var num_regex := RegEx.new()
	num_regex.compile("\\d+\\.?\\d*")
	name = num_regex.sub(name, "n", true)

	# Replace non-alphanumeric with underscores
	var clean_regex := RegEx.new()
	clean_regex.compile("[^a-z0-9]+")
	name = clean_regex.sub(name, "_", true)

	# Remove leading/trailing underscores
	name = name.strip_edges().trim_prefix("_").trim_suffix("_")

	# Collapse multiple underscores
	var multi_underscore := RegEx.new()
	multi_underscore.compile("_+")
	name = multi_underscore.sub(name, "_", true)

	# Prefix with underscore for private function
	if not name.is_empty():
		name = "_" + name

	# Fallback if empty
	if name == "_" or name.is_empty():
		name = "_undefined_step"

	return name
