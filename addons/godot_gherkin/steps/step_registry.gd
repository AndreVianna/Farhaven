extends RefCounted
## Central registration and lookup for step definitions.
##
## Self-reference for headless mode compatibility
const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const StepDefinitionScript = preload("res://addons/godot_gherkin/steps/step_definition.gd")
##
## Provides the user-facing API for registering Given/When/Then steps
## and finding matching step definitions for execution.

var _given_steps: Array[StepDefinitionScript] = []
var _when_steps: Array[StepDefinitionScript] = []
var _then_steps: Array[StepDefinitionScript] = []
var _any_steps: Array[StepDefinitionScript] = []  # Steps that match any keyword
var _current_source_file: String = ""  # Tracks source during registration

## Global singleton instance.
static var _instance: StepRegistryScript = null


## Get the global singleton instance.
static func get_instance() -> StepRegistryScript:
	if not _instance:
		_instance = StepRegistryScript.new()
	return _instance


## Reset the global singleton (useful for testing).
static func reset_instance() -> void:
	_instance = null


## Set the current source file for step registration tracking.
func set_source_file(path: String) -> void:
	_current_source_file = path


# === Registration API ===


## Register a Given step definition.
func given(pattern: String, callback: Callable) -> StepDefinitionScript:
	var step := StepDefinitionScript.new(pattern, callback, "Given", _current_source_file)
	_given_steps.append(step)
	return step


## Register a When step definition.
func when(pattern: String, callback: Callable) -> StepDefinitionScript:
	var step := StepDefinitionScript.new(pattern, callback, "When", _current_source_file)
	_when_steps.append(step)
	return step


## Register a Then step definition.
func then(pattern: String, callback: Callable) -> StepDefinitionScript:
	var step := StepDefinitionScript.new(pattern, callback, "Then", _current_source_file)
	_then_steps.append(step)
	return step


## Register a step that matches any keyword (Given/When/Then/And/But).
func step(pattern: String, callback: Callable) -> StepDefinitionScript:
	var step_def := StepDefinitionScript.new(pattern, callback, "", _current_source_file)
	_any_steps.append(step_def)
	return step_def


# === Lookup API ===


## Find a matching step definition for the given keyword and text.
## Optionally filter by scenario tags to support scoped steps.
## Returns null if no match is found.
func find_step(
	keyword: String, text: String, scenario_tags: Array[String] = []
) -> StepDefinitionScript:
	var steps_to_search: Array[StepDefinitionScript] = []

	# Determine which step lists to search based on keyword
	match keyword:
		"Given":
			steps_to_search.append_array(_given_steps)
			steps_to_search.append_array(_any_steps)
		"When":
			steps_to_search.append_array(_when_steps)
			steps_to_search.append_array(_any_steps)
		"Then":
			steps_to_search.append_array(_then_steps)
			steps_to_search.append_array(_any_steps)
		_:  # And, But, * - search all
			steps_to_search.append_array(_given_steps)
			steps_to_search.append_array(_when_steps)
			steps_to_search.append_array(_then_steps)
			steps_to_search.append_array(_any_steps)

	# Find first matching step (prioritize scoped steps over unscoped)
	var unscoped_match: StepDefinitionScript = null

	for step_def in steps_to_search:
		if step_def.matches(text):
			if step_def.matches_tags(scenario_tags):
				# Scoped steps take priority - return immediately if tags match
				if not step_def.scoped_tags.is_empty():
					return step_def
				# Save unscoped match as fallback
				if unscoped_match == null:
					unscoped_match = step_def

	return unscoped_match


## Find all matching step definitions (useful for detecting ambiguous steps).
func find_all_steps(keyword: String, text: String) -> Array[StepDefinitionScript]:
	var matches: Array[StepDefinitionScript] = []
	var steps_to_search: Array[StepDefinitionScript] = []

	match keyword:
		"Given":
			steps_to_search.append_array(_given_steps)
			steps_to_search.append_array(_any_steps)
		"When":
			steps_to_search.append_array(_when_steps)
			steps_to_search.append_array(_any_steps)
		"Then":
			steps_to_search.append_array(_then_steps)
			steps_to_search.append_array(_any_steps)
		_:
			steps_to_search.append_array(_given_steps)
			steps_to_search.append_array(_when_steps)
			steps_to_search.append_array(_then_steps)
			steps_to_search.append_array(_any_steps)

	for step_def in steps_to_search:
		if step_def.matches(text):
			matches.append(step_def)

	return matches


# === Management API ===


## Clear all registered step definitions.
func clear() -> void:
	_given_steps.clear()
	_when_steps.clear()
	_then_steps.clear()
	_any_steps.clear()
	_current_source_file = ""


## Get the total count of registered step definitions.
func count() -> int:
	return _given_steps.size() + _when_steps.size() + _then_steps.size() + _any_steps.size()


## Get all registered Given steps.
func get_given_steps() -> Array[StepDefinitionScript]:
	return _given_steps.duplicate()


## Get all registered When steps.
func get_when_steps() -> Array[StepDefinitionScript]:
	return _when_steps.duplicate()


## Get all registered Then steps.
func get_then_steps() -> Array[StepDefinitionScript]:
	return _then_steps.duplicate()


## Get all registered universal steps.
func get_any_steps() -> Array[StepDefinitionScript]:
	return _any_steps.duplicate()


## Get all registered steps across all categories.
func get_all_steps() -> Array[StepDefinitionScript]:
	var all: Array[StepDefinitionScript] = []
	all.append_array(_given_steps)
	all.append_array(_when_steps)
	all.append_array(_then_steps)
	all.append_array(_any_steps)
	return all


## Check if a step exists for the given pattern (any keyword).
func has_step(pattern: String) -> bool:
	for step_def in get_all_steps():
		if step_def.pattern == pattern:
			return true
	return false


# === Analysis API ===


## Result of analyzing registered steps for duplicates and issues.
class AnalysisResult:
	var duplicates: Array[Dictionary] = []  # [{pattern, keyword, sources: [file1, file2]}]
	var total_steps: int = 0

	func has_issues() -> bool:
		return duplicates.size() > 0


## Analyze registered steps for duplicates and potential issues.
## Returns an AnalysisResult with any problems found.
func analyze() -> AnalysisResult:
	var result := AnalysisResult.new()
	result.total_steps = count()

	# Analyze each keyword category separately
	_analyze_step_list(_given_steps, "Given", result)
	_analyze_step_list(_when_steps, "When", result)
	_analyze_step_list(_then_steps, "Then", result)
	_analyze_step_list(_any_steps, "*", result)

	return result


## Analyze a list of steps for duplicates.
func _analyze_step_list(
	steps: Array[StepDefinitionScript], keyword: String, result: AnalysisResult
) -> void:
	# Group steps by pattern
	var pattern_map: Dictionary = {}  # pattern -> Array[StepDefinition]

	for step_def in steps:
		if not pattern_map.has(step_def.pattern):
			pattern_map[step_def.pattern] = []
		pattern_map[step_def.pattern].append(step_def)

	# Find patterns with multiple definitions that could conflict
	for pattern in pattern_map:
		var step_list: Array = pattern_map[pattern]
		if step_list.size() < 2:
			continue

		# Check for actual conflicts (unscoped duplicates or overlapping scopes)
		var unscoped_steps: Array = []
		var scoped_steps: Array = []

		for step_def in step_list:
			if step_def.scoped_tags.is_empty():
				unscoped_steps.append(step_def)
			else:
				scoped_steps.append(step_def)

		# Multiple unscoped steps with same pattern = definite duplicate
		if unscoped_steps.size() > 1:
			var sources: Array[String] = []
			for step_def in unscoped_steps:
				var source: String = (
					step_def.source_location if step_def.source_location else "unknown"
				)
				if source not in sources:
					sources.append(source)

			if sources.size() > 1:
				result.duplicates.append(
					{"pattern": pattern, "keyword": keyword, "sources": sources}
				)
