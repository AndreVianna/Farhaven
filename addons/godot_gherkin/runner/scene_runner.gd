extends Node
## Scene-based test runner for GodotGherkin.
##
## Use this runner when you need:
## - Autoloads to be properly initialized
## - class_name identifiers to resolve correctly
## - Full scene tree context for UI testing
##
## Usage:
##   godot --headless res://addons/godot_gherkin/runner/scene_runner.tscn -- [options]
##
## Or create your own test scene that extends this and customize _ready().

const GherkinCLIScript = preload("res://addons/godot_gherkin/runner/cli_runner.gd")


func _ready() -> void:
	# Wait one frame to let autoloads initialize
	await get_tree().process_frame

	# Run tests
	var exit_code := await _run_tests()

	# Quit with the exit code
	get_tree().quit(exit_code)


## Run tests with CLI arguments.
## Override this method to customize test execution.
func _run_tests() -> int:
	var cli := GherkinCLIScript.new(get_tree())

	# Get command-line arguments (everything after --)
	var args := OS.get_cmdline_user_args()

	return await cli.run(args)
