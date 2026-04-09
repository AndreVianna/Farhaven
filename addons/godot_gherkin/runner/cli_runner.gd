extends RefCounted
## Command-line interface for running Gherkin tests.
##
## Self-reference for headless mode compatibility
const GherkinCLIScript = preload("res://addons/godot_gherkin/runner/cli_runner.gd")
const GherkinTestRunnerScript = preload("res://addons/godot_gherkin/runner/test_runner.gd")
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
const GherkinParserScript = preload("res://addons/godot_gherkin/core/gherkin_parser.gd")
const TestResultScript = preload("res://addons/godot_gherkin/runner/test_result.gd")
const ConsoleReporterScript = preload(
	"res://addons/godot_gherkin/runner/reporters/console_reporter.gd"
)
const JsonReporterScript = preload("res://addons/godot_gherkin/runner/reporters/json_reporter.gd")
const FileScannerScript = preload("res://addons/godot_gherkin/util/file_scanner.gd")
##
## Parses command-line arguments and orchestrates test execution.
## Designed for headless execution with AI assistants and CI/CD systems.

## Exit codes
const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1
const EXIT_ERROR := 2

var _runner: GherkinTestRunnerScript
var _reporter: Variant  # ConsoleReporter or JsonReporter
var _scene_tree: SceneTree = null

## Configuration from CLI args
var features_path: String = "res://tests/features"
var steps_path: String = "res://tests/steps"
var specific_feature: String = ""
var tags: Array[String] = []
var format: String = "console"
var output_path: String = ""
var verbose: bool = false
var dry_run: bool = false
var fail_fast: bool = false
var no_color: bool = false
var list_steps: bool = false


func _init(scene_tree: SceneTree = null) -> void:
	_scene_tree = scene_tree


## Run tests with the given command-line arguments.
## Returns exit code (0 = success, 1 = failures, 2 = error).
func run(args: PackedStringArray) -> int:
	# Parse arguments
	var parse_result := _parse_args(args)
	if parse_result != EXIT_SUCCESS:
		return parse_result

	# Create runner
	_runner = GherkinTestRunnerScript.new(_scene_tree)
	_runner.features_path = features_path
	_runner.steps_path = steps_path
	_runner.tag_filter = tags
	_runner.fail_fast = fail_fast

	# Create reporter
	_create_reporter()

	# Connect signals
	_runner.run_started.connect(_on_run_started)
	_runner.feature_started.connect(_on_feature_started)
	_runner.feature_completed.connect(_on_feature_completed)
	_runner.scenario_started.connect(_on_scenario_started)
	_runner.scenario_completed.connect(_on_scenario_completed)
	_runner.run_completed.connect(_on_run_completed)

	# Handle dry run
	if dry_run:
		return _do_dry_run()

	# Handle list steps
	if list_steps:
		return _do_list_steps()

	# Run tests
	var result: TestResultScript.SuiteResult

	if specific_feature:
		# Load steps first (run_all does this internally, but run_feature_file does not)
		_runner.load_steps()
		# Run specific feature
		var feature_result := await _runner.run_feature_file(specific_feature)
		result = TestResultScript.SuiteResult.new()
		result.feature_results.append(feature_result)
		result.total_duration_ms = feature_result.duration_ms
	else:
		# Run all features
		result = await _runner.run_all()

	# Report results
	_reporter.report_results(result)

	# Return appropriate exit code
	if result.is_passed():
		return EXIT_SUCCESS
	return EXIT_FAILURE


## Parse command-line arguments.
func _parse_args(args: PackedStringArray) -> int:
	var i := 0

	while i < args.size():
		var arg := args[i]

		match arg:
			"--feature", "-f":
				i += 1
				if i >= args.size():
					_print_error("--feature requires a path argument")
					return EXIT_ERROR
				specific_feature = args[i]

			"--features":
				i += 1
				if i >= args.size():
					_print_error("--features requires a path argument")
					return EXIT_ERROR
				features_path = args[i]

			"--steps":
				i += 1
				if i >= args.size():
					_print_error("--steps requires a path argument")
					return EXIT_ERROR
				steps_path = args[i]

			"--tags", "-t":
				i += 1
				if i >= args.size():
					_print_error("--tags requires a tag argument")
					return EXIT_ERROR
				tags.append(args[i])

			"--format":
				i += 1
				if i >= args.size():
					_print_error("--format requires a format argument (console, json)")
					return EXIT_ERROR
				format = args[i]

			"--output", "-o":
				i += 1
				if i >= args.size():
					_print_error("--output requires a path argument")
					return EXIT_ERROR
				output_path = args[i]

			"--verbose", "-v":
				verbose = true

			"--dry-run":
				dry_run = true

			"--list-steps":
				list_steps = true

			"--fail-fast":
				fail_fast = true

			"--no-color":
				no_color = true

			"--help", "-h":
				_print_help()
				return EXIT_ERROR

			_:
				if arg.begins_with("-"):
					_print_error("Unknown option: %s" % arg)
					return EXIT_ERROR

		i += 1

	return EXIT_SUCCESS


## Create the appropriate reporter.
func _create_reporter() -> void:
	match format:
		"json":
			_reporter = JsonReporterScript.new(output_path)
		_:
			_reporter = ConsoleReporterScript.new(not no_color, verbose)


## Do a dry run (list scenarios without executing).
func _do_dry_run() -> int:
	print("Dry run - listing scenarios:\n")

	var file_scanner := FileScannerScript.new()
	var parser := GherkinParserScript.new()
	var feature_files := file_scanner.find_feature_files(features_path)

	for file_path in feature_files:
		var content := FileScannerScript.read_file(file_path)
		var feature := parser.parse(content, file_path)

		print("Feature: %s" % feature.name)
		print("  File: %s" % file_path)

		for scenario in feature.scenarios:
			if scenario is GherkinASTScript.ScenarioOutline:
				var instance_count: int = scenario.get_instance_count()
				print("  - %s (%d examples)" % [scenario.name, instance_count])
			else:
				print("  - %s" % scenario.name)

		print("")

	return EXIT_SUCCESS


## List all registered step definitions.
func _do_list_steps() -> int:
	_runner.load_steps()

	var registry := _runner.get_registry()
	var given_steps := registry.get_given_steps()
	var when_steps := registry.get_when_steps()
	var then_steps := registry.get_then_steps()
	var any_steps := registry.get_any_steps()

	var total := registry.count()
	print("\nRegistered Steps (%d total):\n" % total)

	if given_steps.size() > 0:
		print("Given steps:")
		for step in given_steps:
			var source := step.source_location if step.source_location else "unknown"
			print('  - "%s" (%s)' % [step.pattern, source])
		print("")

	if when_steps.size() > 0:
		print("When steps:")
		for step in when_steps:
			var source := step.source_location if step.source_location else "unknown"
			print('  - "%s" (%s)' % [step.pattern, source])
		print("")

	if then_steps.size() > 0:
		print("Then steps:")
		for step in then_steps:
			var source := step.source_location if step.source_location else "unknown"
			print('  - "%s" (%s)' % [step.pattern, source])
		print("")

	if any_steps.size() > 0:
		print("Universal steps (any keyword):")
		for step in any_steps:
			var source := step.source_location if step.source_location else "unknown"
			print('  - "%s" (%s)' % [step.pattern, source])
		print("")

	return EXIT_SUCCESS


## Signal handlers
func _on_run_started(feature_count: int) -> void:
	_reporter.report_start(feature_count)


func _on_feature_started(feature: GherkinASTScript.Feature) -> void:
	_reporter.report_feature_start(feature)


func _on_feature_completed(result: TestResultScript.FeatureResult) -> void:
	_reporter.report_feature_complete(result)


func _on_scenario_started(scenario: GherkinASTScript.Scenario) -> void:
	_reporter.report_scenario_start(scenario)


func _on_scenario_completed(result: TestResultScript.ScenarioResult) -> void:
	_reporter.report_scenario_complete(result)


func _on_run_completed(_result: TestResultScript.SuiteResult) -> void:
	pass  # Results are reported in run()


## Print an error message.
func _print_error(message: String) -> void:
	printerr("Error: %s" % message)
	printerr("Use --help for usage information.")


## Print help message.
func _print_help() -> void:
	print(
		"""
GodotGherkin - BDD Testing Framework for Godot

Usage:
  godot --headless --script tests/run_tests.gd -- [options]

Options:
  --feature, -f <path>   Run a specific feature file
  --features <path>      Path to features directory (default: res://tests/features)
  --steps <path>         Path to steps directory (default: res://tests/steps)
  --tags, -t <tag>       Filter by tag (can be used multiple times)
                         Use ~@tag to exclude a tag
  --format <type>        Output format: console (default), json
  --output, -o <path>    Write output to file
  --verbose, -v          Show step details
  --dry-run              List scenarios without executing
  --list-steps           List all registered step definitions
  --fail-fast            Stop on first failure
  --no-color             Disable colored output
  --help, -h             Show this help message

Examples:
  # Run all tests
  godot --headless --script tests/run_tests.gd

  # Run specific feature
  godot --headless --script tests/run_tests.gd -- --feature tests/features/login.feature

  # Run with tags
  godot --headless --script tests/run_tests.gd -- --tags @smoke --tags ~@slow

  # JSON output
  godot --headless --script tests/run_tests.gd -- --format json

Exit Codes:
  0  All tests passed
  1  One or more tests failed
  2  Error (invalid arguments, missing files, etc.)
"""
	)
