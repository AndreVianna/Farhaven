#!/usr/bin/env -S godot --headless --script
extends SceneTree

const GherkinCLIScript = preload("res://addons/godot_gherkin/runner/cli_runner.gd")

func _init() -> void:
	var cli := GherkinCLIScript.new(self)
	cli.features_path = "res://tests/features"
	cli.steps_path = "res://tests/steps"
	var exit_code := await cli.run(OS.get_cmdline_user_args())
	quit(exit_code)
