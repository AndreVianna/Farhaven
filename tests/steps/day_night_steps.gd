extends RefCounted

## Step definitions for day-night cycle feature.

const DNC_PHASE_NAMES := {"DAY": 0, "DUSK": 1, "NIGHT": 2, "DAWN": 3}
const DNC_PHASE_FROM_INT := {0: "DAY", 1: "DUSK", 2: "NIGHT", 3: "DAWN"}

## Ambient energy per phase (from DayNightCycle.LIGHTING_PARAMS).
const AMBIENT_ENERGY := {0: 0.4, 1: 0.15, 2: 0.03, 3: 0.2}

## Phase transition order: DAY->DUSK->NIGHT->DAWN->DAY
const NEXT_PHASE := {0: 1, 1: 2, 2: 3, 3: 0}


func register_steps(registry) -> void:
	# --- Given: phase state ---
	registry.given("the phase is {word}", func(ctx, phase_name: String):
		var phase_int: int = DNC_PHASE_NAMES.get(phase_name, 0)
		ctx.set_value("phase", phase_name)
		ctx.set_value("phase_int", phase_int)
	)

	registry.given("the day count is {int}", func(ctx, day: int):
		ctx.set_value("day_count", day)
	)

	registry.given("the day count is {int} and phase is {word}", func(ctx, day: int, phase_name: String):
		ctx.set_value("day_count", day)
		ctx.set_value("phase", phase_name)
		ctx.set_value("phase_int", DNC_PHASE_NAMES.get(phase_name, 0))
	)

	# --- When: phase advances ---
	registry.when("the phase advances", func(ctx):
		var current: int = ctx.get_value("phase_int", 0)
		var next: int = NEXT_PHASE.get(current, 0)
		# Day counter increments at NIGHT -> DAWN transition
		if current == 2:  # NIGHT -> DAWN
			var dc: int = ctx.get_value("day_count", 1)
			ctx.set_value("day_count", dc + 1)
		ctx.set_value("phase_int", next)
		ctx.set_value("phase", DNC_PHASE_FROM_INT.get(next, "DAY"))
	)

	registry.when("the phase advances to DAWN", func(ctx):
		# Force advance to DAWN from NIGHT
		var dc: int = ctx.get_value("day_count", 1)
		ctx.set_value("day_count", dc + 1)
		ctx.set_value("phase_int", 3)
		ctx.set_value("phase", "DAWN")
	)

	registry.when("the phase is set to {word}", func(ctx, phase_name: String):
		var phase_int: int = DNC_PHASE_NAMES.get(phase_name, 0)
		ctx.set_value("phase", phase_name)
		ctx.set_value("phase_int", phase_int)
	)

	# --- Then: lighting ---
	registry.then("the ambient energy is {float}", func(ctx, expected: float):
		var phase_int: int = ctx.get_value("phase_int", 0)
		var actual: float = AMBIENT_ENERGY.get(phase_int, -1.0)
		ctx.assert_equal(actual, expected,
			"Expected ambient energy %.2f for phase %s, got %.2f" % [
				expected, DNC_PHASE_FROM_INT.get(phase_int, "?"), actual
			])
	)
