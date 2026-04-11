class_name JournalPanel
extends PanelContainer

## In-game Journal panel (task-075b).
##
## Shown as the right-hand side of LogCombinedPanel (alongside Catalog).
##
## Layout:
##   VBox
##     Header: title + counter + close button (close button is hidden when
##             embedded inside a CombinedPanel, same pattern as CatalogPanel).
##     CategoryFilterRow: "All" / "Chapter" / "Lore" / "Tutorial" toggle buttons
##     HSplit:
##       EntryList (ScrollContainer → VBox of Button rows)
##       DetailView (title, date_added, body)
##
## Data flow:
##   _ready() → connect to Journal.journal_entry_added → populate from
##   Journal.get_unlocked_ids() + JournalEntryRegistry.get_entry(id).
##
## Category filter:
##   Single active filter (StringName). &"" means "All". Re-populates the
##   list on change. Filtering is done against the registry's category field.
##
## Detail view:
##   Shows the body of the JournalEntry Gear resource. Uses the dedicated
##   `body` field (not long_description). Falls back to long_description then
##   short_description when body is empty.

## Registry injected for testing; falls back to the JournalEntryRegistry autoload.
var _registry: Node = null
## Journal injected for testing; falls back to the Journal autoload.
var _journal: Node = null

## Active category filter. &"" means "show all".
var _active_filter: StringName = &""

## Currently selected entry id, or &"" if nothing selected.
var _selected_id: StringName = &""

## Known filter categories — order matters for the UI row.
const FILTER_CATEGORIES: Array[StringName] = [&"", &"chapter", &"lore", &"tutorial"]
const FILTER_LABELS: Dictionary = {
	&"": "All",
	&"chapter": "Chapter",
	&"lore": "Lore",
	&"tutorial": "Tutorial",
}

# --- Nodes ---
var _title_label: Label
var _counter_label: Label
var _close_button: Button
var _filter_row: HBoxContainer
var _entry_list: VBoxContainer
var _detail_title: Label
var _detail_date: Label
var _detail_body: Label
var _detail_empty: Label

## Filter button lookup keyed by filter StringName.
var _filter_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	_resolve_dependencies()
	_build_ui_if_needed()
	_connect_journal_signal()
	_refresh()


# --- Public API (mirrors CatalogPanel so LogCombinedPanel can embed it) ---

signal panel_opened()


func set_registry(registry: Node) -> void:
	_registry = registry
	if is_inside_tree():
		_refresh()


func set_journal(journal: Node) -> void:
	# Duck-typed: tolerate any Node. Check has_signal before disconnecting
	# so a test double without the signal doesn't crash.
	if _journal != null and _journal.has_signal(&"journal_entry_added"):
		if _journal.journal_entry_added.is_connected(_on_journal_entry_added):
			_journal.journal_entry_added.disconnect(_on_journal_entry_added)
	_journal = journal
	if is_inside_tree():
		_connect_journal_signal()
		_refresh()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	visible = true
	_refresh()
	panel_opened.emit()


func close() -> void:
	visible = false


# --- Dependency resolution ---

func _resolve_dependencies() -> void:
	if _journal == null:
		_journal = _get_autoload(&"Journal")
	if _registry == null:
		_registry = _get_autoload(&"JournalEntryRegistry")


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null


func _connect_journal_signal() -> void:
	if _journal == null:
		return
	# Duck-typed: a Journal without the signal (test double, future refactor)
	# is tolerated — we just don't wire anything up.
	if not _journal.has_signal(&"journal_entry_added"):
		return
	if not _journal.journal_entry_added.is_connected(_on_journal_entry_added):
		_journal.journal_entry_added.connect(_on_journal_entry_added)


# --- UI construction ---
# Built programmatically if @onready nodes are missing (e.g. when scene is
# instanced via .new() in tests instead of the .tscn).

func _build_ui_if_needed() -> void:
	# If the scene already provided our nodes, skip.
	if _title_label != null and is_instance_valid(_title_label):
		return
	_title_label = get_node_or_null("VBox/Header/TitleLabel")
	if _title_label != null:
		_counter_label = get_node_or_null("VBox/Header/CounterLabel")
		_close_button = get_node_or_null("VBox/Header/CloseButton")
		_filter_row = get_node_or_null("VBox/FilterRow")
		_entry_list = get_node_or_null("VBox/Split/LeftScroll/EntryList")
		_detail_title = get_node_or_null("VBox/Split/DetailMargin/DetailVBox/DetailTitle")
		_detail_date = get_node_or_null("VBox/Split/DetailMargin/DetailVBox/DetailDate")
		_detail_body = get_node_or_null("VBox/Split/DetailMargin/DetailVBox/DetailScroll/DetailBody")
		_detail_empty = get_node_or_null("VBox/Split/DetailMargin/DetailVBox/DetailEmpty")
		_populate_filter_row_from_scene()
		_wire_scene_signals()
		return
	# Fallback: build programmatically.
	_build_ui_programmatic()


func _build_ui_programmatic() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.border_width_top = 2
	style.border_color = Color(0.40, 0.40, 0.50, 0.8)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 56)
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "JOURNAL"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_counter_label = Label.new()
	_counter_label.name = "CounterLabel"
	_counter_label.text = "0 entries"
	_counter_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_counter_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(96, 96)
	_close_button.add_theme_font_size_override("font_size", 36)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_filter_row = HBoxContainer.new()
	_filter_row.name = "FilterRow"
	_filter_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_filter_row)
	_populate_filter_row_programmatic()

	var split := HBoxContainer.new()
	split.name = "Split"
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 8)
	vbox.add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.name = "LeftScroll"
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.4
	split.add_child(left_scroll)

	_entry_list = VBoxContainer.new()
	_entry_list.name = "EntryList"
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.add_theme_constant_override("separation", 4)
	left_scroll.add_child(_entry_list)

	var detail_margin := MarginContainer.new()
	detail_margin.name = "DetailMargin"
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.size_flags_stretch_ratio = 0.6
	detail_margin.add_theme_constant_override("margin_left", 12)
	detail_margin.add_theme_constant_override("margin_right", 12)
	detail_margin.add_theme_constant_override("margin_top", 4)
	detail_margin.add_theme_constant_override("margin_bottom", 4)
	split.add_child(detail_margin)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "DetailVBox"
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(detail_vbox)

	_detail_title = Label.new()
	_detail_title.name = "DetailTitle"
	_detail_title.add_theme_font_size_override("font_size", 26)
	detail_vbox.add_child(_detail_title)

	_detail_date = Label.new()
	_detail_date.name = "DetailDate"
	_detail_date.add_theme_font_size_override("font_size", 16)
	_detail_date.modulate = Color(0.7, 0.7, 0.75)
	detail_vbox.add_child(_detail_date)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(detail_scroll)

	_detail_body = Label.new()
	_detail_body.name = "DetailBody"
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_body.add_theme_font_size_override("font_size", 18)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail_body)

	_detail_empty = Label.new()
	_detail_empty.name = "DetailEmpty"
	_detail_empty.text = "Select an entry."
	_detail_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_empty.add_theme_font_size_override("font_size", 20)
	_detail_empty.modulate = Color(0.5, 0.5, 0.6, 0.7)
	detail_vbox.add_child(_detail_empty)


func _populate_filter_row_programmatic() -> void:
	for cat in FILTER_CATEGORIES:
		var btn := Button.new()
		btn.text = FILTER_LABELS[cat]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(96, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_filter_pressed.bind(cat))
		_filter_row.add_child(btn)
		_filter_buttons[cat] = btn
	_update_filter_button_state()


func _populate_filter_row_from_scene() -> void:
	if _filter_row == null:
		return
	for child in _filter_row.get_children():
		if child is Button:
			var btn: Button = child
			var meta_name := StringName(btn.get_meta("category", &""))
			btn.toggle_mode = true
			if not btn.pressed.is_connected(_on_filter_pressed):
				btn.pressed.connect(_on_filter_pressed.bind(meta_name))
			_filter_buttons[meta_name] = btn
	_update_filter_button_state()


func _wire_scene_signals() -> void:
	if _close_button != null and not _close_button.pressed.is_connected(close):
		_close_button.pressed.connect(close)


# --- Data population ---

func _refresh() -> void:
	if _entry_list == null:
		return
	_clear_entry_list()
	var ids := _get_unlocked_ids()
	var visible_count := 0
	for id in ids:
		var entry := _get_entry(id)
		if not _passes_filter(entry):
			continue
		_add_entry_row(id, entry)
		visible_count += 1
	if _counter_label != null:
		_counter_label.text = _format_counter_text(ids.size(), visible_count)
	# If selection is no longer visible, clear detail view.
	if _selected_id != &"" and not _is_selected_visible():
		_selected_id = &""
	_refresh_detail_view()


func _get_unlocked_ids() -> Array[StringName]:
	if _journal == null:
		return []
	if _journal.has_method("get_unlocked_ids"):
		return _journal.get_unlocked_ids()
	return []


func _get_entry(id: StringName) -> Resource:
	if _registry == null:
		return null
	if _registry.has_method("get_entry"):
		return _registry.get_entry(id)
	return null


func _passes_filter(entry: Resource) -> bool:
	if _active_filter == &"":
		return true
	if entry == null:
		# Unknown entries (missing from registry) only survive the "All" filter.
		return false
	return entry.category == _active_filter


func _clear_entry_list() -> void:
	# Synchronous removal so repeated _refresh() calls in the same frame
	# (e.g. set_journal → open → filter change) don't stack leftover rows
	# (queue_free defers to next frame).
	for child in _entry_list.get_children():
		_entry_list.remove_child(child)
		child.queue_free()


func _add_entry_row(id: StringName, entry: Resource) -> void:
	var row := Button.new()
	row.text = _row_label(id, entry)
	row.custom_minimum_size = Vector2(0, 64)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_font_size_override("font_size", 20)
	row.set_meta("entry_id", id)
	row.pressed.connect(_on_entry_row_pressed.bind(id))
	_entry_list.add_child(row)


func _row_label(id: StringName, entry: Resource) -> String:
	if entry == null:
		return "(%s)" % String(id)
	var name_text: String = entry.display_name if entry.display_name != "" else String(id)
	var cat_suffix: String = ""
	if entry.category != &"":
		cat_suffix = " [%s]" % String(entry.category)
	return "%s%s" % [name_text, cat_suffix]


func _format_counter_text(total: int, visible_entries: int) -> String:
	if _active_filter == &"":
		return "%d entries" % total if total != 1 else "1 entry"
	return "%d of %d" % [visible_entries, total]


func _is_selected_visible() -> bool:
	if _entry_list == null:
		return false
	for child in _entry_list.get_children():
		if child.has_meta("entry_id") and StringName(child.get_meta("entry_id")) == _selected_id:
			return true
	return false


# --- Detail view ---

func _refresh_detail_view() -> void:
	if _detail_body == null:
		return
	if _selected_id == &"":
		_show_detail_empty()
		return
	var entry := _get_entry(_selected_id)
	if entry == null:
		_show_detail_empty()
		return
	_detail_empty.visible = false
	_detail_title.visible = true
	_detail_date.visible = true
	_detail_body.visible = true
	_detail_title.text = entry.display_name if entry.display_name != "" else String(entry.id)
	_detail_date.text = _format_date(entry)
	_detail_body.text = _resolve_body_text(entry)


func _show_detail_empty() -> void:
	_detail_empty.visible = true
	_detail_title.visible = false
	_detail_date.visible = false
	_detail_body.visible = false


func _format_date(entry: Resource) -> String:
	if entry.day_added <= 0:
		return ""
	return "Day %d" % entry.day_added


## Resolve body text. Uses dedicated `body` field first, then falls back to
## long_description then short_description. See Wave 0 note in journal_entry.gd.
func _resolve_body_text(entry: Resource) -> String:
	if "body" in entry and entry.body != "":
		return entry.body
	if entry.long_description != "":
		return entry.long_description
	return entry.short_description


# --- Signal handlers ---

func _on_journal_entry_added(_entry_id: StringName) -> void:
	if is_inside_tree():
		_refresh()


func _on_entry_row_pressed(id: StringName) -> void:
	_selected_id = id
	_refresh_detail_view()


func _on_filter_pressed(category: StringName) -> void:
	_active_filter = category
	_update_filter_button_state()
	_refresh()


func _update_filter_button_state() -> void:
	for key in _filter_buttons:
		var btn: Button = _filter_buttons[key]
		if btn != null and is_instance_valid(btn):
			btn.button_pressed = (key == _active_filter)
