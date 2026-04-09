# GodotGherkin

A Behavior-Driven Development (BDD) testing framework for Godot 4.3+ using Gherkin syntax.

## Quick Start

1. Create a test runner `tests/run_tests.gd`:

```gdscript
#!/usr/bin/env -S godot --headless --script
extends SceneTree

const GherkinCLIScript = preload("res://addons/godot_gherkin/runner/cli_runner.gd")

func _init() -> void:
    var cli := GherkinCLIScript.new(self)
    var exit_code := await cli.run(OS.get_cmdline_user_args())
    quit(exit_code)
```

2. Run tests:

```bash
godot --headless --script tests/run_tests.gd
```

## Documentation

Full documentation: https://github.com/Akdr/GodotGherkin

## License

MIT License - See [LICENSE](LICENSE)
