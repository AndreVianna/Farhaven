class_name TestGameEvent
extends GdUnitTestSuite

## Unit tests for GameEvent (task-057).
## Tests count/max_count semantics, is_active, can_fire, fire, reset.

const _GameEvent = preload("res://scripts/core/event.gd")
const _ScriptBase = preload("res://scripts/core/script_base.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_event(p_max_count: int = 1) -> _GameEvent:
	var event := _GameEvent.new()
	event.id = &"test_event"
	event.max_count = p_max_count
	return event


# ---------------------------------------------------------------------------
# Type hierarchy
# ---------------------------------------------------------------------------

func test_game_event_extends_script_base() -> void:
	var event := _make_event()
	assert_bool(event is _ScriptBase).is_true()


# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------

func test_default_count_is_zero() -> void:
	var event := _GameEvent.new()
	assert_int(event.count).is_equal(0)


func test_default_max_count_is_one() -> void:
	var event := _GameEvent.new()
	assert_int(event.max_count).is_equal(1)


# ---------------------------------------------------------------------------
# is_active
# ---------------------------------------------------------------------------

func test_is_active_false_when_count_zero() -> void:
	var event := _make_event()
	assert_bool(event.is_active()).is_false()


func test_is_active_true_when_count_one() -> void:
	var event := _make_event()
	event.count = 1
	assert_bool(event.is_active()).is_true()


func test_is_active_true_when_count_greater_than_one() -> void:
	var event := _make_event(0)
	event.count = 5
	assert_bool(event.is_active()).is_true()


# ---------------------------------------------------------------------------
# can_fire
# ---------------------------------------------------------------------------

func test_can_fire_true_when_count_below_max() -> void:
	var event := _make_event(3)
	event.count = 1
	assert_bool(event.can_fire()).is_true()


func test_can_fire_false_when_count_equals_max() -> void:
	var event := _make_event(3)
	event.count = 3
	assert_bool(event.can_fire()).is_false()


func test_can_fire_false_when_count_exceeds_max() -> void:
	var event := _make_event(2)
	event.count = 5
	assert_bool(event.can_fire()).is_false()


func test_can_fire_always_true_when_max_count_zero_unlimited() -> void:
	var event := _make_event(0)
	event.count = 999
	assert_bool(event.can_fire()).is_true()


# ---------------------------------------------------------------------------
# fire
# ---------------------------------------------------------------------------

func test_fire_increments_count() -> void:
	var event := _make_event(3)
	event.fire()
	assert_int(event.count).is_equal(1)


func test_fire_returns_true_when_can_fire() -> void:
	var event := _make_event(3)
	assert_bool(event.fire()).is_true()


func test_fire_returns_false_when_cannot_fire() -> void:
	var event := _make_event(1)
	event.count = 1
	assert_bool(event.fire()).is_false()


func test_fire_does_not_increment_when_cannot_fire() -> void:
	var event := _make_event(1)
	event.count = 1
	event.fire()
	assert_int(event.count).is_equal(1)


# ---------------------------------------------------------------------------
# reset
# ---------------------------------------------------------------------------

func test_reset_sets_count_to_zero() -> void:
	var event := _make_event(3)
	event.count = 3
	event.reset()
	assert_int(event.count).is_equal(0)


# ---------------------------------------------------------------------------
# Scenario: one-shot (max_count=1)
# ---------------------------------------------------------------------------

func test_one_shot_fires_once_then_stops() -> void:
	var event := _make_event(1)
	assert_bool(event.can_fire()).is_true()
	assert_bool(event.fire()).is_true()
	assert_int(event.count).is_equal(1)
	assert_bool(event.is_active()).is_true()
	assert_bool(event.can_fire()).is_false()
	assert_bool(event.fire()).is_false()
	assert_int(event.count).is_equal(1)


# ---------------------------------------------------------------------------
# Scenario: unlimited (max_count=0)
# ---------------------------------------------------------------------------

func test_unlimited_fires_many_times() -> void:
	var event := _make_event(0)
	for i in range(10):
		assert_bool(event.fire()).is_true()
	assert_int(event.count).is_equal(10)
	assert_bool(event.is_active()).is_true()
	assert_bool(event.can_fire()).is_true()


# ---------------------------------------------------------------------------
# Scenario: limited (max_count=3)
# ---------------------------------------------------------------------------

func test_limited_fires_three_times_then_stops() -> void:
	var event := _make_event(3)
	assert_bool(event.fire()).is_true()
	assert_bool(event.fire()).is_true()
	assert_bool(event.fire()).is_true()
	assert_int(event.count).is_equal(3)
	assert_bool(event.can_fire()).is_false()
	assert_bool(event.fire()).is_false()
	assert_int(event.count).is_equal(3)
