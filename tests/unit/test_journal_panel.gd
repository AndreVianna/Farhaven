class_name TestJournalPanel
extends GdUnitTestSuite

## Unit tests for JournalPanel (task-075b).
##
## Uses a stub Journal node + the real JournalEntryRegistry autoload
## populated via register_entry(). No .tres files required.

const _JournalPanelScene = preload("res://scenes/ui/journal_panel.tscn")
const _JournalEntry = preload("res://scripts/journal/journal_entry.gd")

## Minimal fake that mirrors Journal's public contract used by the panel.
class FakeJournal extends Node:
	signal journal_entry_added(entry_id: StringName)
	var _unlocked: Array[StringName] = []

	func add_entry(id: StringName) -> void:
		if _unlocked.has(id):
			return
		_unlocked.append(id)
		journal_entry_added.emit(id)

	func get_unlocked_ids() -> Array[StringName]:
		var copy: Array[StringName] = []
		for i in _unlocked:
			copy.append(i)
		return copy


var _panel: JournalPanel = null
var _fake_journal: FakeJournal = null


func before_test() -> void:
	if JournalEntryRegistry.has_method("clear"):
		JournalEntryRegistry.clear()
	_fake_journal = FakeJournal.new()
	add_child(_fake_journal)
	_panel = _JournalPanelScene.instantiate()
	add_child(_panel)
	# Inject fake Journal (bypasses the autoload lookup).
	_panel.set_journal(_fake_journal)


func after_test() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if is_instance_valid(_fake_journal):
		_fake_journal.queue_free()
	_fake_journal = null
	if JournalEntryRegistry.has_method("clear"):
		JournalEntryRegistry.clear()


# --- Helpers ---

func _make_entry(id: StringName, display_name: String, category: StringName, body: String = "") -> Resource:
	var entry = _JournalEntry.new()
	entry.id = id
	entry.display_name = display_name
	entry.category = category
	entry.body = body if body != "" else "Body of %s." % display_name
	entry.day_added = 1
	return entry


func _register(id: StringName, display_name: String, category: StringName, body: String = "") -> Resource:
	var entry := _make_entry(id, display_name, category, body)
	JournalEntryRegistry.register_entry(entry)
	return entry


func _get_entry_list_rows() -> Array:
	var rows: Array = []
	for child in _panel._entry_list.get_children():
		if child is Button:
			rows.append(child)
	return rows


# --- Visibility / toggle ---

func test_panel_starts_hidden() -> void:
	assert_bool(_panel.visible).is_false()


func test_panel_open_makes_visible() -> void:
	_panel.open()
	assert_bool(_panel.visible).is_true()


func test_panel_close_hides() -> void:
	_panel.open()
	_panel.close()
	assert_bool(_panel.visible).is_false()


func test_panel_toggle_opens_and_closes() -> void:
	_panel.toggle()
	assert_bool(_panel.visible).is_true()
	_panel.toggle()
	assert_bool(_panel.visible).is_false()


# --- Population from Journal.get_unlocked_ids() ---

func test_panel_populates_from_unlocked_ids_on_ready() -> void:
	_register(&"J00001", "First", &"chapter")
	_register(&"J00002", "Second", &"lore")
	_fake_journal.add_entry(&"J00001")
	_fake_journal.add_entry(&"J00002")
	# Trigger a refresh by re-setting journal now that entries are registered.
	_panel.set_journal(_fake_journal)
	_panel.open()
	assert_int(_get_entry_list_rows().size()).is_equal(2)


func test_panel_empty_when_no_unlocks() -> void:
	_register(&"J00001", "First", &"chapter")
	_panel.open()
	assert_int(_get_entry_list_rows().size()).is_equal(0)


# --- Signal: journal_entry_added ---

func test_new_unlock_adds_row_via_signal() -> void:
	_register(&"J00001", "First", &"chapter")
	_panel.open()
	assert_int(_get_entry_list_rows().size()).is_equal(0)
	_fake_journal.add_entry(&"J00001")
	assert_int(_get_entry_list_rows().size()).is_equal(1)


func test_new_unlock_updates_counter() -> void:
	_register(&"J00001", "First", &"chapter")
	_panel.open()
	_fake_journal.add_entry(&"J00001")
	assert_str(_panel._counter_label.text).contains("1")


# --- Detail view ---

func test_detail_view_empty_when_no_selection() -> void:
	_register(&"J00001", "First", &"chapter")
	_fake_journal.add_entry(&"J00001")
	_panel.set_journal(_fake_journal)
	_panel.open()
	assert_bool(_panel._detail_empty.visible).is_true()
	assert_bool(_panel._detail_body.visible).is_false()


func test_clicking_entry_shows_body_in_detail_view() -> void:
	_register(&"J00001", "First Chapter", &"chapter", "This is the body text.")
	_fake_journal.add_entry(&"J00001")
	_panel.set_journal(_fake_journal)
	_panel.open()
	var rows := _get_entry_list_rows()
	assert_int(rows.size()).is_equal(1)
	rows[0].pressed.emit()
	assert_str(_panel._detail_body.text).is_equal("This is the body text.")
	assert_bool(_panel._detail_body.visible).is_true()
	assert_bool(_panel._detail_empty.visible).is_false()


func test_clicking_entry_shows_title_in_detail_view() -> void:
	_register(&"J00001", "First Chapter", &"chapter")
	_fake_journal.add_entry(&"J00001")
	_panel.set_journal(_fake_journal)
	_panel.open()
	_get_entry_list_rows()[0].pressed.emit()
	assert_str(_panel._detail_title.text).is_equal("First Chapter")


func test_detail_view_falls_back_to_long_description_when_body_empty() -> void:
	var entry := _make_entry(&"J00001", "Fallback", &"lore", "")
	entry.body = ""
	entry.long_description = "Long desc fallback."
	JournalEntryRegistry.register_entry(entry)
	_fake_journal.add_entry(&"J00001")
	_panel.set_journal(_fake_journal)
	_panel.open()
	_get_entry_list_rows()[0].pressed.emit()
	assert_str(_panel._detail_body.text).is_equal("Long desc fallback.")


# --- Category filter ---

func test_filter_restricts_visible_entries() -> void:
	_register(&"J00001", "Chap1", &"chapter")
	_register(&"J00002", "Lore1", &"lore")
	_register(&"J00003", "Tut1", &"tutorial")
	_fake_journal.add_entry(&"J00001")
	_fake_journal.add_entry(&"J00002")
	_fake_journal.add_entry(&"J00003")
	_panel.set_journal(_fake_journal)
	_panel.open()

	assert_int(_get_entry_list_rows().size()).is_equal(3)

	# Apply chapter filter.
	_panel._on_filter_pressed(&"chapter")
	assert_int(_get_entry_list_rows().size()).is_equal(1)

	_panel._on_filter_pressed(&"lore")
	assert_int(_get_entry_list_rows().size()).is_equal(1)

	# Back to all.
	_panel._on_filter_pressed(&"")
	assert_int(_get_entry_list_rows().size()).is_equal(3)


func test_filter_clears_selection_when_hidden() -> void:
	_register(&"J00001", "Chap1", &"chapter", "chapter body")
	_register(&"J00002", "Lore1", &"lore", "lore body")
	_fake_journal.add_entry(&"J00001")
	_fake_journal.add_entry(&"J00002")
	_panel.set_journal(_fake_journal)
	_panel.open()
	# Select the chapter entry.
	for row in _get_entry_list_rows():
		if String(row.get_meta("entry_id")) == "J00001":
			row.pressed.emit()
			break
	assert_str(_panel._detail_body.text).is_equal("chapter body")
	# Switch to lore — chapter should no longer be visible, detail should clear.
	_panel._on_filter_pressed(&"lore")
	assert_bool(_panel._detail_empty.visible).is_true()
	assert_bool(_panel._detail_body.visible).is_false()


# --- Registry injection fallback ---

func test_panel_handles_missing_registry_entry_gracefully() -> void:
	# Unlock an id the registry does not know about.
	_fake_journal.add_entry(&"J99999")
	_panel.set_journal(_fake_journal)
	_panel.open()
	# Shows the row with fallback label — should not crash.
	assert_int(_get_entry_list_rows().size()).is_equal(1)
