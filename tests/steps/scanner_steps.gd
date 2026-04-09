extends RefCounted

## Step definitions for scanner feature.
## Uses context dictionaries instead of Catalog class to avoid autoload chain.

## Knowledge states (mirroring Catalog.KnowledgeState).
const UNKNOWN := 0
const ENCOUNTERED := 1
const CATALOGED := 2


func register_steps(registry) -> void:
	# --- Given: scanner state ---
	registry.given("an uncataloged prop {string} on a neighboring tile", func(ctx, entry_id: String):
		var knowledge: Dictionary = {}
		knowledge[StringName(entry_id)] = UNKNOWN
		ctx.set_value("knowledge", knowledge)
		ctx.set_value("scan_target", StringName(entry_id))
		ctx.set_value("scan_in_range", false)
	)

	registry.given("a scan in progress for {string} with duration {float}", func(ctx, entry_id: String, duration: float):
		ctx.set_value("scan_target", StringName(entry_id))
		ctx.set_value("scan_progress", 0.0)
		ctx.set_value("scan_duration", duration)
		ctx.set_value("is_scanning", true)
		if not ctx.has_value("knowledge"):
			ctx.set_value("knowledge", {})
	)

	registry.given("a scan in progress for {string}", func(ctx, entry_id: String):
		ctx.set_value("scan_target", StringName(entry_id))
		ctx.set_value("scan_progress", 0.5)
		ctx.set_value("scan_duration", 2.0)
		ctx.set_value("is_scanning", true)
		if not ctx.has_value("knowledge"):
			ctx.set_value("knowledge", {})
	)

	# --- When: scanner events ---
	registry.when("the player enters scan range", func(ctx):
		ctx.set_value("scan_in_range", true)
		ctx.set_value("is_scanning", true)
		ctx.set_value("scan_progress", 0.0)
	)

	registry.when("{float} seconds elapse", func(ctx, seconds: float):
		var progress: float = ctx.get_value("scan_progress", 0.0)
		var duration: float = ctx.get_value("scan_duration", 2.0)
		progress += seconds
		if progress >= duration:
			progress = duration
			ctx.set_value("scan_completed", true)
			var knowledge: Dictionary = ctx.get_value("knowledge", {})
			var target: StringName = ctx.get_value("scan_target", &"")
			if target != &"":
				knowledge[target] = CATALOGED
				ctx.set_value("knowledge", knowledge)
			ctx.set_value("is_scanning", false)
		ctx.set_value("scan_progress", progress)
	)

	registry.when("the player moves out of scan range", func(ctx):
		ctx.set_value("scan_in_range", false)
		ctx.set_value("is_scanning", false)
		ctx.set_value("scan_progress", 0.0)
		ctx.set_value("scan_interrupted", true)
	)

	# --- Then: scanner assertions ---
	registry.then("a scan is in progress for {string}", func(ctx, entry_id: String):
		var is_scanning: bool = ctx.get_value("is_scanning", false)
		var target: StringName = ctx.get_value("scan_target", &"")
		ctx.assert_true(is_scanning, "Expected scan to be in progress")
		ctx.assert_equal(String(target), entry_id,
			"Expected scan target '%s', got '%s'" % [entry_id, target])
	)

	registry.then("the scan completes", func(ctx):
		var completed: bool = ctx.get_value("scan_completed", false)
		ctx.assert_true(completed, "Expected scan to complete")
	)

	registry.then("the scan is interrupted", func(ctx):
		var interrupted: bool = ctx.get_value("scan_interrupted", false)
		ctx.assert_true(interrupted, "Expected scan to be interrupted")
	)

	registry.then("the scan progress is {int}", func(ctx, expected: int):
		var progress: float = ctx.get_value("scan_progress", -1.0)
		ctx.assert_equal(progress, float(expected),
			"Expected scan progress %.1f, got %.1f" % [float(expected), progress])
	)
