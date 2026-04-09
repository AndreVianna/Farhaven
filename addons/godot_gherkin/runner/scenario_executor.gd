extends RefCounted
## Executes a single scenario with proper step handling.
##
## Self-reference for headless mode compatibility
const ScenarioExecutorScript = preload("res://addons/godot_gherkin/runner/scenario_executor.gd")
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
const TestResultScript = preload("res://addons/godot_gherkin/runner/test_result.gd")
const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")
##
## Manages step execution order, And/But keyword resolution,
## async step support, and result collection.

signal step_started(step: GherkinASTScript.Step)
signal step_completed(step: GherkinASTScript.Step, result: TestResultScript.StepResult)

var _registry: StepRegistryScript
var _context: TestContextScript
var _previous_keyword: String = "Given"
var _current_scenario_tags: Array[String] = []
var _feature_tags: Array[String] = []


func _init(registry: StepRegistryScript, context: TestContextScript = null) -> void:
	_registry = registry
	_context = context if context else TestContextScript.new()


## Set feature tags for tag inheritance.
## Scenarios will inherit these tags for step scoping with for_tags().
func set_feature_tags(tags: Array[String]) -> void:
	_feature_tags = tags


## Set the test context.
func set_context(context: TestContextScript) -> void:
	_context = context


## Get the current test context.
func get_context() -> TestContextScript:
	return _context


## Execute a scenario with optional background steps.
func execute_scenario(
	scenario: GherkinASTScript.Scenario, background: GherkinASTScript.Background = null
) -> TestResultScript.ScenarioResult:
	var result := TestResultScript.ScenarioResult.new()
	result.scenario_name = scenario.name
	result.tags = scenario.get_tag_names()
	result.line = scenario.location.line if scenario.location else 0
	result.status = TestResultScript.Status.PASSED

	var start_time := Time.get_ticks_msec()

	# Reset context for new scenario
	_context.reset()
	_previous_keyword = "Given"
	# Combine feature tags with scenario tags for tag inheritance
	_current_scenario_tags = scenario.get_tag_names()
	for tag in _feature_tags:
		if tag not in _current_scenario_tags:
			_current_scenario_tags.append(tag)

	# Execute background steps first
	if background:
		for step in background.steps:
			var step_result := await _execute_step(step)
			step_result.is_background = true
			result.step_results.append(step_result)

			if step_result.status != TestResultScript.Status.PASSED:
				result.status = step_result.status
				result.error_message = step_result.error_message
				result.background_failed = true
				# Skip remaining steps on failure
				_skip_remaining_steps(scenario.steps, result, false)
				break

	# Execute scenario steps (only if background passed)
	if result.status == TestResultScript.Status.PASSED:
		for step in scenario.steps:
			var step_result := await _execute_step(step)
			result.step_results.append(step_result)

			if step_result.status != TestResultScript.Status.PASSED:
				result.status = step_result.status
				result.error_message = step_result.error_message
				# Skip remaining steps
				var remaining := scenario.steps.slice(scenario.steps.find(step) + 1)
				_skip_remaining_steps(remaining, result)
				break

	result.duration_ms = Time.get_ticks_msec() - start_time
	return result


## Execute a single step.
func _execute_step(step: GherkinASTScript.Step) -> TestResultScript.StepResult:
	var result := TestResultScript.StepResult.new()
	result.step_text = step.text
	result.keyword = step.keyword
	result.line = step.location.line if step.location else 0

	step_started.emit(step)
	var start_time := Time.get_ticks_msec()

	# Resolve And/But to actual keyword for step lookup
	var effective_keyword := _resolve_keyword(step.keyword)

	# Find matching step definition (pass scenario tags for scoped step matching)
	var step_def := _registry.find_step(effective_keyword, step.text, _current_scenario_tags)

	if not step_def:
		result.status = TestResultScript.Status.UNDEFINED
		result.error_message = "No step definition found for: %s %s" % [step.keyword, step.text]
		result.duration_ms = Time.get_ticks_msec() - start_time
		step_completed.emit(step, result)
		return result

	# Track step definition source for error reporting
	result.step_source = step_def.source_location

	# Execute the step (pass DataTable/DocString argument if present)
	var exec_result = step_def.execute(step.text, _context, step.argument)

	# Handle async execution
	# In GDScript 4, async step functions can return a Signal to await
	if exec_result is Signal:
		exec_result = await exec_result

	# Check for execution errors
	if exec_result is Dictionary and exec_result.get("error", false):
		result.status = TestResultScript.Status.FAILED
		result.error_message = exec_result.get("message", "Step execution failed")
	elif _context.has_failures():
		result.status = TestResultScript.Status.FAILED
		result.error_message = _context.get_last_error()
	else:
		result.status = TestResultScript.Status.PASSED

	result.duration_ms = Time.get_ticks_msec() - start_time
	step_completed.emit(step, result)
	return result


## Resolve And/But/Asterisk to the previous effective keyword.
func _resolve_keyword(keyword: String) -> String:
	if keyword in ["And", "But", "*"]:
		return _previous_keyword

	_previous_keyword = keyword
	return keyword


## Mark remaining steps as skipped.
func _skip_remaining_steps(
	steps: Array, result: TestResultScript.ScenarioResult, is_background: bool = false
) -> void:
	for step: GherkinASTScript.Step in steps:
		var step_result := TestResultScript.StepResult.new()
		step_result.step_text = step.text
		step_result.keyword = step.keyword
		step_result.line = step.location.line if step.location else 0
		step_result.status = TestResultScript.Status.SKIPPED
		step_result.is_background = is_background
		if result.background_failed:
			step_result.error_message = "Skipped due to Background failure"
		else:
			step_result.error_message = "Skipped due to previous failure"
		result.step_results.append(step_result)
