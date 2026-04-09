extends RefCounted
## Orchestrates test execution across features and scenarios.
##
## Self-reference for headless mode compatibility
const GherkinTestRunnerScript = preload("res://addons/godot_gherkin/runner/test_runner.gd")
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
const GherkinParserScript = preload("res://addons/godot_gherkin/core/gherkin_parser.gd")
const TestResultScript = preload("res://addons/godot_gherkin/runner/test_result.gd")
const TestContextScript = preload("res://addons/godot_gherkin/runner/test_context.gd")
const StepRegistryScript = preload("res://addons/godot_gherkin/steps/step_registry.gd")
const ScenarioExecutorScript = preload("res://addons/godot_gherkin/runner/scenario_executor.gd")
const FileScannerScript = preload("res://addons/godot_gherkin/util/file_scanner.gd")
##
## Discovers feature files, loads step definitions, parses features,
## and executes scenarios with result aggregation.

signal run_started(feature_count: int)
signal run_completed(result: TestResultScript.SuiteResult)
signal feature_started(feature: GherkinASTScript.Feature)
signal feature_completed(result: TestResultScript.FeatureResult)
signal scenario_started(scenario: GherkinASTScript.Scenario)
signal scenario_completed(result: TestResultScript.ScenarioResult)

var _registry: StepRegistryScript
var _parser: GherkinParserScript
var _file_scanner: FileScannerScript
var _scene_tree: SceneTree = null
var _step_instances: Array = []  # Keep step definition instances alive
var _load_errors: Array[Dictionary] = []  # Track step file load errors

## Configuration
var features_path: String = "res://tests/features"
var steps_path: String = "res://tests/steps"
var tag_filter: Array[String] = []
var fail_fast: bool = false


func _init(scene_tree: SceneTree = null) -> void:
	_registry = StepRegistryScript.new()
	_parser = GherkinParserScript.new()
	_file_scanner = FileScannerScript.new()
	_scene_tree = scene_tree


## Set the SceneTree for async step support.
func set_scene_tree(tree: SceneTree) -> void:
	_scene_tree = tree


## Get the step registry for manual step registration.
func get_registry() -> StepRegistryScript:
	return _registry


## Load step definitions from the configured steps path.
## Call this before run_feature_file() when running specific features.
func load_steps() -> void:
	_load_steps(steps_path)
	_print_load_errors()
	_print_duplicate_warnings()


## Run all tests in the configured paths.
func run_all() -> TestResultScript.SuiteResult:
	var suite_result := TestResultScript.SuiteResult.new()
	suite_result.start_time = Time.get_ticks_msec()

	# Load step definitions
	_load_steps(steps_path)

	# Print any load errors or duplicate warnings (silent if no issues)
	_print_load_errors()
	_print_duplicate_warnings()

	# Find and parse all feature files
	var feature_files := _file_scanner.find_feature_files(features_path)
	run_started.emit(feature_files.size())

	for file_path in feature_files:
		var feature_result := await run_feature_file(file_path)
		suite_result.feature_results.append(feature_result)

		# Collect undefined steps
		for scenario in feature_result.scenario_results:
			if scenario.status == TestResultScript.Status.UNDEFINED:
				for step in scenario.step_results:
					if step.status == TestResultScript.Status.UNDEFINED:
						var step_sig := "%s %s" % [step.keyword, step.step_text]
						if not suite_result.undefined_steps.has(step_sig):
							suite_result.undefined_steps.append(step_sig)

		if fail_fast and not feature_result.is_passed():
			break

	suite_result.end_time = Time.get_ticks_msec()
	suite_result.total_duration_ms = suite_result.end_time - suite_result.start_time

	run_completed.emit(suite_result)
	return suite_result


## Run a specific feature file.
func run_feature_file(file_path: String) -> TestResultScript.FeatureResult:
	var content := FileScannerScript.read_file(file_path)
	if content.is_empty():
		var empty_result := TestResultScript.FeatureResult.new()
		empty_result.file_path = file_path
		empty_result.feature_name = "Error: Could not read file"
		return empty_result

	var feature := _parser.parse(content, file_path)
	return await run_feature(feature)


## Run a parsed feature.
func run_feature(feature: GherkinASTScript.Feature) -> TestResultScript.FeatureResult:
	var result := TestResultScript.FeatureResult.new()
	result.feature_name = feature.name
	result.file_path = feature.source_path
	result.tags = feature.get_tag_names()

	feature_started.emit(feature)
	var start_time := Time.get_ticks_msec()

	var executor := ScenarioExecutorScript.new(_registry)
	executor.set_context(TestContextScript.new(_scene_tree))
	var feature_tag_names := feature.get_tag_names()
	executor.set_feature_tags(feature_tag_names)

	# Run scenarios at feature level
	for scenario_item in feature.scenarios:
		# Check tag filter (scenarios inherit feature tags)
		if not _matches_tag_filter(scenario_item, feature_tag_names):
			continue

		var scenario_result: TestResultScript.ScenarioResult

		if scenario_item is GherkinASTScript.ScenarioOutline:
			# Expand scenario outline into multiple scenarios
			var expanded := _expand_scenario_outline(scenario_item)
			for expanded_scenario in expanded:
				scenario_started.emit(expanded_scenario)
				scenario_result = await executor.execute_scenario(
					expanded_scenario, feature.background
				)
				scenario_result.feature_name = feature.name
				result.scenario_results.append(scenario_result)
				scenario_completed.emit(scenario_result)

				if fail_fast and not scenario_result.is_passed():
					break
		else:
			scenario_started.emit(scenario_item)
			scenario_result = await executor.execute_scenario(scenario_item, feature.background)
			scenario_result.feature_name = feature.name
			result.scenario_results.append(scenario_result)
			scenario_completed.emit(scenario_result)

		if fail_fast and result.scenario_results.size() > 0:
			if not result.scenario_results[-1].is_passed():
				break

	# Run scenarios within rules
	for rule in feature.rules:
		var rule_background := rule.background if rule.background else feature.background

		for scenario_item in rule.scenarios:
			if not _matches_tag_filter(scenario_item, feature_tag_names):
				continue

			var scenario_result: TestResultScript.ScenarioResult

			if scenario_item is GherkinASTScript.ScenarioOutline:
				var expanded := _expand_scenario_outline(scenario_item)
				for expanded_scenario in expanded:
					scenario_started.emit(expanded_scenario)
					scenario_result = await executor.execute_scenario(
						expanded_scenario, rule_background
					)
					scenario_result.feature_name = feature.name
					result.scenario_results.append(scenario_result)
					scenario_completed.emit(scenario_result)

					if fail_fast and not scenario_result.is_passed():
						break
			else:
				scenario_started.emit(scenario_item)
				scenario_result = await executor.execute_scenario(scenario_item, rule_background)
				scenario_result.feature_name = feature.name
				result.scenario_results.append(scenario_result)
				scenario_completed.emit(scenario_result)

			if fail_fast and result.scenario_results.size() > 0:
				if not result.scenario_results[-1].is_passed():
					break

		if fail_fast and not result.is_passed():
			break

	result.duration_ms = Time.get_ticks_msec() - start_time
	feature_completed.emit(result)
	return result


## Expand a scenario outline into concrete scenarios.
func _expand_scenario_outline(
	outline: GherkinASTScript.ScenarioOutline
) -> Array[GherkinASTScript.Scenario]:
	var scenarios: Array[GherkinASTScript.Scenario] = []

	for examples in outline.examples:
		if not examples.table or examples.table.rows.size() < 2:
			continue  # Need header + at least one data row

		var headers := examples.table.get_headers()
		var data_rows := examples.table.get_data_rows()

		for row_idx in range(data_rows.size()):
			var row := data_rows[row_idx]
			var scenario := GherkinASTScript.Scenario.new()
			scenario.name = "%s (Example %d)" % [outline.name, row_idx + 1]
			scenario.tags = outline.tags.duplicate()
			scenario.location = outline.location

			# Replace placeholders in steps
			for step in outline.steps:
				var new_step := GherkinASTScript.Step.new()
				new_step.keyword = step.keyword
				new_step.location = step.location
				new_step.text = step.text

				# Replace <placeholder> with values
				var row_values := row.get_values()
				for col_idx in range(headers.size()):
					if col_idx < row_values.size():
						var placeholder := "<%s>" % headers[col_idx]
						new_step.text = new_step.text.replace(placeholder, row_values[col_idx])

				scenario.steps.append(new_step)

			scenarios.append(scenario)

	return scenarios


## Check if a scenario matches the tag filter.
## Scenarios inherit feature tags for filtering purposes.
func _matches_tag_filter(scenario: Variant, feature_tags: Array[String] = []) -> bool:
	if tag_filter.is_empty():
		return true

	var scenario_tags: Array[String] = []
	if scenario is GherkinASTScript.Scenario:
		scenario_tags = scenario.get_tag_names()
	elif scenario is GherkinASTScript.ScenarioOutline:
		scenario_tags = scenario.get_tag_names()

	# Inherit feature tags (scenarios should match feature-level tags)
	for tag in feature_tags:
		if tag not in scenario_tags:
			scenario_tags.append(tag)

	for filter_tag in tag_filter:
		# Exclusion filter (starts with ~)
		if filter_tag.begins_with("~"):
			var excluded_tag := filter_tag.substr(1)
			if excluded_tag in scenario_tags:
				return false
		else:
			# Inclusion filter
			if filter_tag in scenario_tags:
				return true

	# If only exclusion filters, include by default
	var has_inclusion := false
	for filter_tag in tag_filter:
		if not filter_tag.begins_with("~"):
			has_inclusion = true
			break

	return not has_inclusion


## Load step definition files from the steps path.
func _load_steps(path: String) -> void:
	_registry.clear()
	_load_errors.clear()

	if not FileScannerScript.dir_exists(path):
		push_warning("GherkinTestRunner: Steps directory not found: %s" % path)
		return

	var step_files := _file_scanner.find_step_files(path)

	for file_path in step_files:
		_load_step_file(file_path)


## Load a single step definition file.
func _load_step_file(file_path: String) -> void:
	var script := load(file_path) as GDScript
	if not script or not script.can_instantiate():
		_load_errors.append({"file": file_path, "error": "Could not load script (parse error?)"})
		return

	# Create instance and look for register_steps method
	var instance = script.new()
	if not instance.has_method("register_steps"):
		_load_errors.append({"file": file_path, "error": "Missing register_steps() method"})
		return

	# Set source file for tracking, then register steps
	_registry.set_source_file(file_path)
	instance.register_steps(_registry)
	_registry.set_source_file("")

	# Keep the instance alive so callbacks remain valid
	_step_instances.append(instance)


## Print step file load errors (silent if none).
func _print_load_errors() -> void:
	if _load_errors.is_empty():
		return

	print("")
	print("=== Step File Load Errors ===")
	for err in _load_errors:
		print("  ✗ %s" % err.file)
		print("    %s" % err.error)
	print("")


## Print duplicate step definition warnings (silent if none).
func _print_duplicate_warnings() -> void:
	var analysis := _registry.analyze()
	if not analysis.has_issues():
		return

	print("")
	print("=== Duplicate Step Definitions ===")
	for dup in analysis.duplicates:
		print("  %s '%s'" % [dup.keyword, dup.pattern])
		for source in dup.sources:
			print("    - %s" % source)
	print("")
