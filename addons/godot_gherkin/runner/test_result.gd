extends RefCounted
## Result data structures for test execution.
##
## Self-reference for headless mode compatibility
const TestResultScript = preload("res://addons/godot_gherkin/runner/test_result.gd")
##
## Provides structured results for steps, scenarios, features, and test suites.

## Status enum for test results.
enum Status {
	PASSED,
	FAILED,
	SKIPPED,
	PENDING,  # Step not yet implemented
	UNDEFINED,  # No matching step definition found
}


## Result of a single step execution.
class StepResult:
	extends RefCounted
	var step_text: String = ""
	var keyword: String = ""
	var status: Status = Status.PASSED
	var error_message: String = ""
	var duration_ms: float = 0.0
	var line: int = 0
	var step_source: String = ""  # Source file of the step definition
	var is_background: bool = false  # Whether this step is from Background

	func is_passed() -> bool:
		return status == Status.PASSED

	func to_dict() -> Dictionary:
		var result := {
			"keyword": keyword,
			"text": step_text,
			"status": Status.keys()[status].to_lower(),
			"duration_ms": duration_ms,
			"error": error_message if error_message else null,
			"line": line,
		}
		if step_source:
			result["step_source"] = step_source
		return result


## Result of a scenario execution.
class ScenarioResult:
	extends RefCounted
	var scenario_name: String = ""
	var feature_name: String = ""
	var tags: Array[String] = []
	var status: Status = Status.PASSED
	var step_results: Array[StepResult] = []
	var error_message: String = ""
	var duration_ms: float = 0.0
	var line: int = 0
	var background_failed: bool = false  # True if failed due to Background step

	func is_passed() -> bool:
		return status == Status.PASSED

	func passed_steps() -> int:
		var count := 0
		for step in step_results:
			if step.is_passed():
				count += 1
		return count

	func failed_steps() -> int:
		var count := 0
		for step in step_results:
			if step.status == Status.FAILED:
				count += 1
		return count

	func to_dict() -> Dictionary:
		var steps_array: Array = []
		for step in step_results:
			steps_array.append(step.to_dict())

		var result := {
			"name": scenario_name,
			"status": Status.keys()[status].to_lower(),
			"duration_ms": duration_ms,
			"steps": steps_array,
			"line": line,
		}

		if tags.size() > 0:
			result["tags"] = tags

		if error_message:
			result["error"] = error_message

		return result


## Result of a feature execution.
class FeatureResult:
	extends RefCounted
	var feature_name: String = ""
	var file_path: String = ""
	var tags: Array[String] = []
	var scenario_results: Array[ScenarioResult] = []
	var duration_ms: float = 0.0

	func is_passed() -> bool:
		return failed_count() == 0

	func passed_count() -> int:
		var count := 0
		for scenario in scenario_results:
			if scenario.is_passed():
				count += 1
		return count

	func failed_count() -> int:
		var count := 0
		for scenario in scenario_results:
			if scenario.status == Status.FAILED:
				count += 1
		return count

	func skipped_count() -> int:
		var count := 0
		for scenario in scenario_results:
			if scenario.status == Status.SKIPPED:
				count += 1
		return count

	func undefined_count() -> int:
		var count := 0
		for scenario in scenario_results:
			if scenario.status == Status.UNDEFINED:
				count += 1
		return count

	func total_steps() -> int:
		var count := 0
		for scenario in scenario_results:
			count += scenario.step_results.size()
		return count

	func passed_steps() -> int:
		var count := 0
		for scenario in scenario_results:
			count += scenario.passed_steps()
		return count

	func failed_steps() -> int:
		var count := 0
		for scenario in scenario_results:
			count += scenario.failed_steps()
		return count

	func to_dict() -> Dictionary:
		var scenarios_array: Array = []
		for scenario in scenario_results:
			scenarios_array.append(scenario.to_dict())

		return {
			"name": feature_name,
			"file": file_path,
			"tags": tags,
			"duration_ms": duration_ms,
			"scenarios": scenarios_array,
			"passed": passed_count(),
			"failed": failed_count(),
		}


## Result of an entire test suite execution.
class SuiteResult:
	extends RefCounted
	var feature_results: Array[FeatureResult] = []
	var total_duration_ms: float = 0.0
	var start_time: int = 0
	var end_time: int = 0
	var undefined_steps: Array[String] = []
	var pending_steps: Array[String] = []

	func is_passed() -> bool:
		return failed_scenarios() == 0 and undefined_steps.is_empty()

	func total_features() -> int:
		return feature_results.size()

	func total_scenarios() -> int:
		var count := 0
		for feature in feature_results:
			count += feature.scenario_results.size()
		return count

	func passed_scenarios() -> int:
		var count := 0
		for feature in feature_results:
			count += feature.passed_count()
		return count

	func failed_scenarios() -> int:
		var count := 0
		for feature in feature_results:
			count += feature.failed_count()
		return count

	func skipped_scenarios() -> int:
		var count := 0
		for feature in feature_results:
			count += feature.skipped_count()
		return count

	func total_steps() -> int:
		var count := 0
		for feature in feature_results:
			count += feature.total_steps()
		return count

	func passed_steps() -> int:
		var count := 0
		for feature in feature_results:
			count += feature.passed_steps()
		return count

	func failed_steps() -> int:
		var count := 0
		for feature in feature_results:
			count += feature.failed_steps()
		return count

	func summary() -> String:
		return (
			"%d scenarios (%d passed, %d failed) in %.2fs"
			% [
				total_scenarios(),
				passed_scenarios(),
				failed_scenarios(),
				total_duration_ms / 1000.0
			]
		)

	func to_dict() -> Dictionary:
		var features_array: Array = []
		for feature in feature_results:
			features_array.append(feature.to_dict())

		return {
			"success": is_passed(),
			"summary":
			{
				"total_scenarios": total_scenarios(),
				"passed": passed_scenarios(),
				"failed": failed_scenarios(),
				"skipped": skipped_scenarios(),
				"duration_ms": total_duration_ms,
			},
			"features": features_array,
			"undefined_steps": undefined_steps,
			"pending_steps": pending_steps,
		}

	func to_json() -> String:
		return JSON.stringify(to_dict(), "  ")
