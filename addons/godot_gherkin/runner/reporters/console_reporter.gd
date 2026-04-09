extends RefCounted
## Human-readable console output reporter.
##
## Self-reference for headless mode compatibility
const ConsoleReporterScript = preload(
	"res://addons/godot_gherkin/runner/reporters/console_reporter.gd"
)
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
const TestResultScript = preload("res://addons/godot_gherkin/runner/test_result.gd")
const SnippetGeneratorScript = preload("res://addons/godot_gherkin/util/snippet_generator.gd")
##
## Displays test results with optional ANSI colors for terminal output.

var use_colors: bool = true
var verbose: bool = false

## ANSI color codes
const RESET := "\u001b[0m"
const GREEN := "\u001b[32m"
const RED := "\u001b[31m"
const YELLOW := "\u001b[33m"
const CYAN := "\u001b[36m"
const DIM := "\u001b[2m"
const BOLD := "\u001b[1m"

## Status symbols
const PASS_SYMBOL := "\u2713"  # Check mark
const FAIL_SYMBOL := "\u2717"  # X mark
const SKIP_SYMBOL := "-"
const PENDING_SYMBOL := "?"


func _init(colors: bool = true, p_verbose: bool = false) -> void:
	use_colors = colors
	verbose = p_verbose


## Report start of test run.
func report_start(feature_count: int) -> void:
	_print("\n%s" % _colorize("Running %d feature(s)...\n" % feature_count, CYAN))


## Report feature start.
func report_feature_start(feature: GherkinASTScript.Feature) -> void:
	_print("%s %s" % [_colorize("Feature:", BOLD), feature.name])


## Report feature completion.
func report_feature_complete(result: TestResultScript.FeatureResult) -> void:
	if not verbose:
		return
	_print("")  # Extra line after feature


## Report scenario start.
func report_scenario_start(scenario: GherkinASTScript.Scenario) -> void:
	if verbose:
		_print("  %s %s" % [_colorize("Scenario:", BOLD), scenario.name])


## Report scenario completion.
func report_scenario_complete(result: TestResultScript.ScenarioResult) -> void:
	if verbose:
		# Check if we need to show Background section
		var in_background := true
		var background_shown := false

		# Print step details
		for step in result.step_results:
			# Show Background header when first background step appears
			if step.is_background and not background_shown:
				_print("    %s" % _colorize("Background:", DIM))
				background_shown = true
			elif not step.is_background and in_background:
				in_background = false

			var symbol := _get_status_symbol(step.status)
			var color := _get_status_color(step.status)
			var indent := "      " if step.is_background else "    "
			_print("%s%s %s %s" % [indent, _colorize(symbol, color), step.keyword, step.step_text])

			if step.status == TestResultScript.Status.FAILED and step.step_source:
				_print(
					"%s  %s" % [indent, _colorize("Step definition: %s" % step.step_source, DIM)]
				)

			if step.error_message:
				_print("%s  %s" % [indent, _colorize(step.error_message, RED)])
	else:
		# Compact output - just show pass/fail for scenario
		var symbol := _get_status_symbol(result.status)
		var color := _get_status_color(result.status)

		var scenario_suffix := ""
		if result.background_failed:
			scenario_suffix = _colorize(" (Background failed)", YELLOW)

		_print(
			(
				"  %s %s %s%s"
				% [
					_colorize(symbol, color),
					_colorize("Scenario:", DIM),
					result.scenario_name,
					scenario_suffix
				]
			)
		)

		if result.status == TestResultScript.Status.FAILED:
			# Find the failed step and show its source
			for step in result.step_results:
				if step.status == TestResultScript.Status.FAILED and step.step_source:
					_print("    %s" % _colorize("Step definition: %s" % step.step_source, DIM))
					break
			if result.error_message:
				_print("    %s" % _colorize(result.error_message, RED))


## Report full suite results.
func report_results(result: TestResultScript.SuiteResult) -> void:
	_print("")

	# Summary line
	var passed := result.passed_scenarios()
	var failed := result.failed_scenarios()
	var total := result.total_scenarios()

	var summary_parts: Array[String] = []
	summary_parts.append("%d scenarios" % total)

	if passed > 0:
		summary_parts.append(_colorize("%d passed" % passed, GREEN))
	if failed > 0:
		summary_parts.append(_colorize("%d failed" % failed, RED))

	var skipped := result.skipped_scenarios()
	if skipped > 0:
		summary_parts.append(_colorize("%d skipped" % skipped, YELLOW))

	_print(", ".join(summary_parts))

	# Steps summary
	var step_parts: Array[String] = []
	step_parts.append("%d steps" % result.total_steps())
	if result.passed_steps() > 0:
		step_parts.append(_colorize("%d passed" % result.passed_steps(), GREEN))
	if result.failed_steps() > 0:
		step_parts.append(_colorize("%d failed" % result.failed_steps(), RED))

	_print(", ".join(step_parts))

	# Duration
	_print(_colorize("Finished in %.2fs" % (result.total_duration_ms / 1000.0), DIM))

	# Undefined steps with snippets
	if result.undefined_steps.size() > 0:
		_print("")
		_print(_colorize("Undefined steps:", YELLOW))
		for step in result.undefined_steps:
			_print("  - %s" % step)

		_print("")
		_print(_colorize("Suggested step definitions:", CYAN))
		_print("")
		for step in result.undefined_steps:
			var snippet := SnippetGeneratorScript.generate_snippet(step)
			_print(snippet)
			_print("")

	_print("")


## Get the status symbol.
func _get_status_symbol(status: TestResultScript.Status) -> String:
	match status:
		TestResultScript.Status.PASSED:
			return PASS_SYMBOL
		TestResultScript.Status.FAILED:
			return FAIL_SYMBOL
		TestResultScript.Status.SKIPPED:
			return SKIP_SYMBOL
		TestResultScript.Status.PENDING, TestResultScript.Status.UNDEFINED:
			return PENDING_SYMBOL
		_:
			return "?"


## Get the color for a status.
func _get_status_color(status: TestResultScript.Status) -> String:
	match status:
		TestResultScript.Status.PASSED:
			return GREEN
		TestResultScript.Status.FAILED:
			return RED
		TestResultScript.Status.SKIPPED:
			return YELLOW
		TestResultScript.Status.PENDING, TestResultScript.Status.UNDEFINED:
			return YELLOW
		_:
			return RESET


## Apply ANSI color to text.
func _colorize(text: String, color: String) -> String:
	if use_colors:
		return color + text + RESET
	return text


## Print a line.
func _print(text: String) -> void:
	print(text)
