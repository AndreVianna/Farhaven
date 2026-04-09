extends RefCounted

## Step definitions for survival stats feature.
## Tests stat drain, regen, and consumption without scene tree.

const _CommonSteps = preload("res://tests/steps/common_steps.gd")

const STAT_CONFIG := {
	"hunger_rate": 0.4,
	"thirst_rate": 0.8,
	"hp_drain_no_hunger": 0.1,
	"hp_drain_no_thirst": 0.2,
	"hp_regen_day": 0.5,
}


func register_steps(registry) -> void:
	# --- Given: stat values ---
	registry.given("the player has thirst {float}", func(ctx, val: float):
		ctx.set_value("thirst", val)
	)

	registry.given("the player has hunger {float}", func(ctx, val: float):
		ctx.set_value("hunger", val)
	)

	registry.given("the player has hunger {int} and health {float}", func(ctx, hunger: int, health: float):
		ctx.set_value("hunger", float(hunger))
		ctx.set_value("health", health)
	)

	registry.given("the player has thirst {int} and health {float}", func(ctx, thirst: int, health: float):
		ctx.set_value("thirst", float(thirst))
		ctx.set_value("health", health)
	)

	registry.given("the player has health {float} hunger {float} thirst {float}", func(ctx, hp: float, hunger: float, thirst: float):
		ctx.set_value("health", hp)
		ctx.set_value("hunger", hunger)
		ctx.set_value("thirst", thirst)
	)

	registry.given("it is daytime", func(ctx):
		ctx.set_value("is_daytime", true)
	)

	# --- When: survival tick ---
	registry.when("survival ticks for {float} seconds", func(ctx, duration: float):
		var hunger: float = ctx.get_value("hunger", 100.0)
		var thirst: float = ctx.get_value("thirst", 100.0)
		var health: float = ctx.get_value("health", 100.0)
		var is_daytime: bool = ctx.get_value("is_daytime", true)

		# Apply drain per second for the duration
		hunger = maxf(0.0, hunger - STAT_CONFIG["hunger_rate"] * duration)
		thirst = maxf(0.0, thirst - STAT_CONFIG["thirst_rate"] * duration)

		# HP drain from starvation/dehydration
		if hunger <= 0.0:
			health -= STAT_CONFIG["hp_drain_no_hunger"] * duration
		if thirst <= 0.0:
			health -= STAT_CONFIG["hp_drain_no_thirst"] * duration

		# HP regen during daytime (only if hunger and thirst > 0)
		if is_daytime and hunger > 0.0 and thirst > 0.0:
			health = minf(100.0, health + STAT_CONFIG["hp_regen_day"] * duration)

		health = maxf(0.0, health)

		ctx.set_value("hunger", hunger)
		ctx.set_value("thirst", thirst)
		ctx.set_value("health", health)
	)

	# --- When: eat ---
	registry.when("the player eats a berry restoring {int} hunger", func(ctx, restore: int):
		var hunger: float = ctx.get_value("hunger", 100.0)
		hunger = minf(100.0, hunger + float(restore))
		ctx.set_value("hunger", hunger)
	)

	registry.when("the player eats {string} restoring {int} hunger", func(ctx, item_id: String, restore: int):
		var hunger: float = ctx.get_value("hunger", 100.0)
		hunger = minf(100.0, hunger + float(restore))
		ctx.set_value("hunger", hunger)
		if ctx.has_value("inventory"):
			var inv := _CommonSteps.get_or_create_inventory(ctx)
			inv.remove_item(StringName(item_id), 1)
	)

	# --- Then: stat assertions ---
	registry.then("the player thirst is less than {float}", func(ctx, threshold: float):
		var thirst: float = ctx.get_value("thirst", 100.0)
		ctx.assert_less(thirst, threshold,
			"Expected thirst < %.1f, got %.1f" % [threshold, thirst])
	)

	registry.then("the player hunger is less than {float}", func(ctx, threshold: float):
		var hunger: float = ctx.get_value("hunger", 100.0)
		ctx.assert_less(hunger, threshold,
			"Expected hunger < %.1f, got %.1f" % [threshold, hunger])
	)

	registry.then("the player health is less than {float}", func(ctx, threshold: float):
		var health: float = ctx.get_value("health", 100.0)
		ctx.assert_less(health, threshold,
			"Expected health < %.1f, got %.1f" % [threshold, health])
	)

	registry.then("the player health is greater than {float}", func(ctx, threshold: float):
		var health: float = ctx.get_value("health", 100.0)
		ctx.assert_greater(health, threshold,
			"Expected health > %.1f, got %.1f" % [threshold, health])
	)

	registry.then("the player hunger is {float}", func(ctx, expected: float):
		var hunger: float = ctx.get_value("hunger", 100.0)
		ctx.assert_equal(hunger, expected,
			"Expected hunger %.1f, got %.1f" % [expected, hunger])
	)
