extends RefCounted
## Machine-readable JSON output reporter.
##
## Self-reference for headless mode compatibility
const JsonReporterScript = preload("res://addons/godot_gherkin/runner/reporters/json_reporter.gd")
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
const TestResultScript = preload("res://addons/godot_gherkin/runner/test_result.gd")
##
## Produces JSON output suitable for parsing by AI assistants and automation tools.

var _output_path: String = ""
var _result: TestResultScript.SuiteResult = null


func _init(output_path: String = "") -> void:
	_output_path = output_path


## Report start of test run (no output for JSON).
func report_start(_feature_count: int) -> void:
	pass


## Report feature start (no output for JSON).
func report_feature_start(_feature: GherkinASTScript.Feature) -> void:
	pass


## Report feature completion (no output for JSON).
func report_feature_complete(_result: TestResultScript.FeatureResult) -> void:
	pass


## Report scenario start (no output for JSON).
func report_scenario_start(_scenario: GherkinASTScript.Scenario) -> void:
	pass


## Report scenario completion (no output for JSON).
func report_scenario_complete(_result: TestResultScript.ScenarioResult) -> void:
	pass


## Report full suite results as JSON.
func report_results(result: TestResultScript.SuiteResult) -> void:
	_result = result
	var json_output := result.to_json()

	if _output_path:
		_write_to_file(json_output)
	else:
		print(json_output)


## Get the result as a Dictionary (for programmatic access).
func get_result_dict() -> Dictionary:
	if _result:
		return _result.to_dict()
	return {}


## Get the result as JSON string.
func get_result_json() -> String:
	if _result:
		return _result.to_json()
	return "{}"


## Write JSON output to a file.
func _write_to_file(json_output: String) -> void:
	# Handle relative paths by making them absolute from project root
	var path := _output_path
	if (
		not path.begins_with("/")
		and not path.begins_with("res://")
		and not path.begins_with("user://")
	):
		# Get the project root directory (where project.godot is)
		var project_root := ProjectSettings.globalize_path("res://")
		path = project_root.path_join(_output_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_output)
		file.close()
	else:
		push_error(
			"JsonReporter: Could not write to file: %s (resolved: %s)" % [_output_path, path]
		)
		# Fall back to stdout
		print(json_output)
