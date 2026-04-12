class_name TestJournal
extends GdUnitTestSuite

## Unit tests for the Journal autoload (task-084c).
##
## Journal is a 100-line autoload that tracks unlocked JournalEntry ids.
## Contract (per task-083 template):
##   - add_entry(id) is idempotent — second call with the same id returns false
##     and does NOT re-emit journal_entry_added.
##   - Empty StringName id returns false with no signal.
##   - Save/load round-trip restores the unlocked set exactly.
##
## These tests target the global Journal autoload and reset its internal
## _unlocked dictionary before/after each case to keep runs hermetic.

const _JournalScript = preload("res://scripts/journal/journal.gd")
const _GameEvent = preload("res://scripts/core/event.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")


# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_test() -> void:
	Journal._unlocked.clear()


func after_test() -> void:
	Journal._unlocked.clear()


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_state_empty() -> void:
	assert_int(Journal.get_unlocked_ids().size()).is_equal(0)


func test_is_unlocked_false_before_add() -> void:
	assert_bool(Journal.is_unlocked(&"J00001")).is_false()


# ---------------------------------------------------------------------------
# add_entry — happy path
# ---------------------------------------------------------------------------

func test_add_entry_returns_true_for_new_id() -> void:
	var result := Journal.add_entry(&"J00001")
	assert_bool(result).is_true()


func test_add_entry_marks_entry_unlocked() -> void:
	Journal.add_entry(&"J00001")
	assert_bool(Journal.is_unlocked(&"J00001")).is_true()


func test_add_entry_multiple_distinct_ids() -> void:
	assert_bool(Journal.add_entry(&"J00001")).is_true()
	assert_bool(Journal.add_entry(&"J00002")).is_true()
	assert_bool(Journal.add_entry(&"J00003")).is_true()
	assert_int(Journal.get_unlocked_ids().size()).is_equal(3)


func test_get_unlocked_ids_contains_added_ids() -> void:
	Journal.add_entry(&"J00001")
	Journal.add_entry(&"J00002")
	var ids := Journal.get_unlocked_ids()
	assert_bool(ids.has(&"J00001")).is_true()
	assert_bool(ids.has(&"J00002")).is_true()


# ---------------------------------------------------------------------------
# add_entry — idempotency
# ---------------------------------------------------------------------------

func test_add_entry_duplicate_returns_false() -> void:
	Journal.add_entry(&"J00001")
	var result := Journal.add_entry(&"J00001")
	assert_bool(result).is_false()


func test_add_entry_duplicate_does_not_increase_count() -> void:
	Journal.add_entry(&"J00001")
	var count_before := Journal.get_unlocked_ids().size()
	Journal.add_entry(&"J00001")
	assert_int(Journal.get_unlocked_ids().size()).is_equal(count_before)


# ---------------------------------------------------------------------------
# add_entry — empty id
# ---------------------------------------------------------------------------

func test_add_entry_empty_id_returns_false() -> void:
	var result := Journal.add_entry(&"")
	assert_bool(result).is_false()


func test_add_entry_empty_id_does_not_affect_count() -> void:
	Journal.add_entry(&"")
	assert_int(Journal.get_unlocked_ids().size()).is_equal(0)


func test_add_entry_empty_id_does_not_emit_signal() -> void:
	var monitor := monitor_signals(Journal, false)
	Journal.add_entry(&"")
	await assert_signal(monitor).is_not_emitted("journal_entry_added")


# ---------------------------------------------------------------------------
# Signal — journal_entry_added
# ---------------------------------------------------------------------------

func test_journal_entry_added_emits_on_new_id() -> void:
	var monitor := monitor_signals(Journal, false)
	Journal.add_entry(&"J00001")
	await assert_signal(monitor).is_emitted("journal_entry_added", [&"J00001"])


func test_journal_entry_added_does_not_reemit_on_duplicate() -> void:
	Journal.add_entry(&"J00001")  # first add, outside monitor window
	var monitor := monitor_signals(Journal, false)
	Journal.add_entry(&"J00001")  # duplicate — should not re-emit
	await assert_signal(monitor).is_not_emitted("journal_entry_added")


func test_journal_entry_added_fires_once_per_unique_add() -> void:
	var monitor := monitor_signals(Journal, false)
	Journal.add_entry(&"J00001")
	Journal.add_entry(&"J00002")
	Journal.add_entry(&"J00001")  # duplicate, no re-emit
	await assert_signal(monitor).is_emitted("journal_entry_added", [&"J00001"])
	await assert_signal(monitor).is_emitted("journal_entry_added", [&"J00002"])


# ---------------------------------------------------------------------------
# Save / load round-trip
# ---------------------------------------------------------------------------

func test_get_save_data_empty_when_nothing_unlocked() -> void:
	var data := Journal.get_save_data()
	assert_bool(data.has("unlocked_entries")).is_true()
	assert_int((data["unlocked_entries"] as Array).size()).is_equal(0)


func test_get_save_data_contains_unlocked_ids() -> void:
	Journal.add_entry(&"J00001")
	Journal.add_entry(&"J00002")
	var data := Journal.get_save_data()
	var entries: Array = data["unlocked_entries"]
	assert_int(entries.size()).is_equal(2)
	assert_bool(entries.has(&"J00001")).is_true()
	assert_bool(entries.has(&"J00002")).is_true()


func test_load_save_data_restores_entries() -> void:
	Journal.load_save_data({"unlocked_entries": [&"J00001", &"J00002", &"J00003"]})
	assert_int(Journal.get_unlocked_ids().size()).is_equal(3)
	assert_bool(Journal.is_unlocked(&"J00001")).is_true()
	assert_bool(Journal.is_unlocked(&"J00002")).is_true()
	assert_bool(Journal.is_unlocked(&"J00003")).is_true()


func test_load_save_data_clears_existing_entries_first() -> void:
	Journal.add_entry(&"J99999")
	Journal.load_save_data({"unlocked_entries": [&"J00001"]})
	assert_int(Journal.get_unlocked_ids().size()).is_equal(1)
	assert_bool(Journal.is_unlocked(&"J00001")).is_true()
	assert_bool(Journal.is_unlocked(&"J99999")).is_false()


func test_load_save_data_handles_missing_entries_key() -> void:
	Journal.add_entry(&"J00001")
	Journal.load_save_data({})  # no "unlocked_entries" key
	assert_int(Journal.get_unlocked_ids().size()).is_equal(0)


func test_load_save_data_accepts_string_ids() -> void:
	# Save format stores StringNames, but JSON round-trip may produce plain strings.
	# The loader wraps StringName() around each element, so strings should work.
	Journal.load_save_data({"unlocked_entries": ["J00001", "J00002"]})
	assert_bool(Journal.is_unlocked(&"J00001")).is_true()
	assert_bool(Journal.is_unlocked(&"J00002")).is_true()


func test_save_load_round_trip_preserves_unlocked_set() -> void:
	Journal.add_entry(&"J00001")
	Journal.add_entry(&"J00004")
	Journal.add_entry(&"J00007")
	var data := Journal.get_save_data()
	Journal._unlocked.clear()
	Journal.load_save_data(data)
	assert_int(Journal.get_unlocked_ids().size()).is_equal(3)
	assert_bool(Journal.is_unlocked(&"J00001")).is_true()
	assert_bool(Journal.is_unlocked(&"J00004")).is_true()
	assert_bool(Journal.is_unlocked(&"J00007")).is_true()


# ---------------------------------------------------------------------------
# Event integration (_on_event_fired handler)
# ---------------------------------------------------------------------------

func _make_event_with_unlock_effect(entry_id: StringName) -> _GameEvent:
	var event := _GameEvent.new()
	event.id = &"E00999"
	event.max_count = 1
	var eff := _RecipeEffect.new()
	eff.kind = &"unlock_journal_entry"
	eff.params = {"entry_id": String(entry_id)}
	event.effects.append(eff)
	return event


func test_on_event_fired_unlocks_entry_from_effect() -> void:
	var event := _make_event_with_unlock_effect(&"J00042")
	Journal._on_event_fired(event.id, event)
	assert_bool(Journal.is_unlocked(&"J00042")).is_true()


func test_on_event_fired_with_null_event_is_safe() -> void:
	# Should not crash, should not unlock anything.
	Journal._on_event_fired(&"E00999", null)
	assert_int(Journal.get_unlocked_ids().size()).is_equal(0)


func test_on_event_fired_ignores_non_matching_effect_kind() -> void:
	var event := _GameEvent.new()
	event.id = &"E00998"
	var eff := _RecipeEffect.new()
	eff.kind = &"grant_recipe"  # different kind — should be ignored by Journal
	eff.params = {"recipe_id": "R00001"}
	event.effects.append(eff)
	Journal._on_event_fired(event.id, event)
	assert_int(Journal.get_unlocked_ids().size()).is_equal(0)


func test_on_event_fired_ignores_empty_entry_id() -> void:
	var event := _make_event_with_unlock_effect(&"")
	Journal._on_event_fired(event.id, event)
	assert_int(Journal.get_unlocked_ids().size()).is_equal(0)
