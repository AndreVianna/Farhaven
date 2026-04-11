class_name TestJournalEntryRegistry
extends GdUnitTestSuite

## Tests for the JournalEntryRegistry autoload (task-075b).
##
## The autoload scans res://data/journal/ on _ready(). In Wave 1 that
## directory is empty / non-existent, so these tests exercise the
## in-memory register_entry() helper to populate fixtures.

const _JournalEntry = preload("res://scripts/journal/journal_entry.gd")


func before_test() -> void:
	# Ensure a clean registry per test — other tests may have populated it.
	if JournalEntryRegistry.has_method("clear"):
		JournalEntryRegistry.clear()


func after_test() -> void:
	if JournalEntryRegistry.has_method("clear"):
		JournalEntryRegistry.clear()


# --- Helpers ---

func _make_entry(id: StringName, display_name: String, category: StringName) -> Resource:
	var entry = _JournalEntry.new()
	entry.id = id
	entry.display_name = display_name
	entry.category = category
	entry.body = "Body text for %s." % display_name
	return entry


# --- Empty registry ---

func test_empty_registry_has_no_ids() -> void:
	var ids := JournalEntryRegistry.get_all_ids()
	assert_int(ids.size()).is_equal(0)


func test_empty_registry_get_entry_returns_null() -> void:
	var entry = JournalEntryRegistry.get_entry(&"J00001")
	assert_object(entry).is_null()


func test_empty_registry_has_entry_false() -> void:
	assert_bool(JournalEntryRegistry.has_entry(&"J00001")).is_false()


func test_empty_registry_category_filter_empty() -> void:
	var entries := JournalEntryRegistry.get_entries_by_category(&"lore")
	assert_int(entries.size()).is_equal(0)


# --- After manual injection ---

func test_register_entry_adds_to_registry() -> void:
	var entry := _make_entry(&"J00001", "First Chapter", &"chapter")
	JournalEntryRegistry.register_entry(entry)
	assert_bool(JournalEntryRegistry.has_entry(&"J00001")).is_true()


func test_get_entry_returns_injected_entry() -> void:
	var entry := _make_entry(&"J00001", "First Chapter", &"chapter")
	JournalEntryRegistry.register_entry(entry)
	var retrieved = JournalEntryRegistry.get_entry(&"J00001")
	assert_object(retrieved).is_not_null()
	assert_str(retrieved.display_name).is_equal("First Chapter")


func test_get_all_ids_returns_injected_ids() -> void:
	JournalEntryRegistry.register_entry(_make_entry(&"J00001", "One", &"chapter"))
	JournalEntryRegistry.register_entry(_make_entry(&"J00002", "Two", &"lore"))
	var ids := JournalEntryRegistry.get_all_ids()
	assert_int(ids.size()).is_equal(2)
	assert_bool(ids.has(&"J00001")).is_true()
	assert_bool(ids.has(&"J00002")).is_true()


func test_register_entry_ignores_null() -> void:
	JournalEntryRegistry.register_entry(null)
	assert_int(JournalEntryRegistry.get_all_ids().size()).is_equal(0)


# --- Category filtering ---

func test_get_entries_by_category_filters_correctly() -> void:
	JournalEntryRegistry.register_entry(_make_entry(&"J00001", "Ch1", &"chapter"))
	JournalEntryRegistry.register_entry(_make_entry(&"J00002", "Ch2", &"chapter"))
	JournalEntryRegistry.register_entry(_make_entry(&"J00003", "Lore1", &"lore"))
	JournalEntryRegistry.register_entry(_make_entry(&"J00004", "Tut1", &"tutorial"))

	var chapters := JournalEntryRegistry.get_entries_by_category(&"chapter")
	assert_int(chapters.size()).is_equal(2)

	var lore := JournalEntryRegistry.get_entries_by_category(&"lore")
	assert_int(lore.size()).is_equal(1)
	assert_str(lore[0].display_name).is_equal("Lore1")

	var tutorials := JournalEntryRegistry.get_entries_by_category(&"tutorial")
	assert_int(tutorials.size()).is_equal(1)


func test_get_entries_by_category_unknown_category_empty() -> void:
	JournalEntryRegistry.register_entry(_make_entry(&"J00001", "Ch1", &"chapter"))
	var nothing := JournalEntryRegistry.get_entries_by_category(&"nonexistent")
	assert_int(nothing.size()).is_equal(0)


# --- Clear ---

func test_clear_removes_all_entries() -> void:
	JournalEntryRegistry.register_entry(_make_entry(&"J00001", "One", &"chapter"))
	JournalEntryRegistry.register_entry(_make_entry(&"J00002", "Two", &"lore"))
	JournalEntryRegistry.clear()
	assert_int(JournalEntryRegistry.get_all_ids().size()).is_equal(0)
