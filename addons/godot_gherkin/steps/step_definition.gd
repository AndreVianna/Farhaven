extends RefCounted
## Represents a single step definition with its pattern and callback.
##
## Self-reference for headless mode compatibility
const StepDefinitionScript = preload("res://addons/godot_gherkin/steps/step_definition.gd")
const StepMatcherScript = preload("res://addons/godot_gherkin/steps/step_matcher.gd")
const ParameterTypesScript = preload("res://addons/godot_gherkin/steps/parameter_types.gd")
##
## Step definitions map Gherkin step text to executable GDScript functions.

## The original Cucumber Expression pattern.
var pattern: String = ""

## Compiled regex and parameter types.
var _compiled: StepMatcherScript.CompileResult = null

## The callback function to execute.
var callback: Callable

## The step type constraint ("Given", "When", "Then", or "" for any).
var step_type: String = ""

## Source location for debugging (optional).
var source_location: String = ""

## Tags this step is scoped to (empty means matches all scenarios).
var scoped_tags: Array[String] = []


func _init(
	p_pattern: String, p_callback: Callable, p_step_type: String = "", p_source: String = ""
) -> void:
	pattern = p_pattern
	callback = p_callback
	step_type = p_step_type
	source_location = p_source
	_compile()


## Compile the pattern to regex.
func _compile() -> void:
	_compiled = StepMatcherScript.compile_pattern(pattern)
	if not _compiled.success:
		push_error("Failed to compile step pattern '%s': %s" % [pattern, _compiled.error])


## Check if this step definition matches the given step text.
func matches(step_text: String) -> bool:
	if not _compiled or not _compiled.success:
		return false
	var match_result := StepMatcherScript.match_step(step_text, _compiled)
	return match_result.matched


## Check if this step matches the given scenario tags.
## Returns true if no scoped_tags are set, or if any scoped tag matches.
func matches_tags(scenario_tags: Array[String]) -> bool:
	if scoped_tags.is_empty():
		return true
	for tag in scoped_tags:
		if tag in scenario_tags:
			return true
	return false


## Scope this step to specific tags (fluent API).
## When scoped, this step will only match scenarios with at least one of these tags.
func for_tags(tags: Array[String]) -> StepDefinitionScript:
	scoped_tags = tags
	return self


## Get match result with extracted arguments.
func get_match(step_text: String) -> StepMatcherScript.MatchResult:
	if not _compiled or not _compiled.success:
		return StepMatcherScript.MatchResult.failure()
	return StepMatcherScript.match_step(step_text, _compiled)


## Execute the step with the given context and step text.
## Returns the result of the callback, or an error if execution fails.
## step_argument can be a DataTable or DocString from the step.
func execute(step_text: String, context: Variant, step_argument: Variant = null) -> Variant:
	var match_result := get_match(step_text)
	if not match_result.matched:
		return _create_error("Step does not match pattern: %s" % pattern)

	# Build arguments: context first, then extracted parameters
	var args: Array = [context]
	args.append_array(match_result.arguments)

	# Append step argument (DataTable or DocString) if present
	if step_argument != null:
		args.append(_convert_step_argument(step_argument))

	# Execute callback
	if not callback.is_valid():
		return _create_error("Step callback is not valid")

	return callback.callv(args)


## Execute the step asynchronously (returns result that may be a coroutine).
func execute_async(step_text: String, context: Variant, step_argument: Variant = null) -> Variant:
	return execute(step_text, context, step_argument)


## Convert a step argument (DataTable/DocString) to a user-friendly format.
func _convert_step_argument(arg: Variant) -> Variant:
	const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")

	if arg is GherkinASTScript.DataTable:
		# Convert DataTable to Array of Arrays for easy iteration
		var result: Array = []
		for row in arg.rows:
			result.append(row.get_values())
		return result

	if arg is GherkinASTScript.DocString:
		# Return the content string directly
		return arg.content

	return arg


## Get the compiled regex pattern (for debugging).
func get_regex_pattern() -> String:
	if _compiled and _compiled.regex:
		return _compiled.regex.get_pattern()
	return ""


## Get the parameter types (for introspection).
func get_parameter_types() -> Array[ParameterTypesScript.ParameterType]:
	if _compiled:
		return _compiled.param_types
	return []


## Check if compilation was successful.
func is_valid() -> bool:
	return _compiled != null and _compiled.success


## Create an error result.
func _create_error(message: String) -> Dictionary:
	return {"error": true, "message": message}


func _to_string() -> String:
	var type_str := step_type if step_type else "*"
	return "StepDefinition(%s '%s')" % [type_str, pattern]
