class_name StatusDiscoveriesSection
extends VBoxContainer

## Discoveries sub-section for the Status combined panel (task-082).
## Shows cataloged / total counts from a Catalog (RefCounted, duck-typed).
## Refreshes on entry_cataloged and entry_encountered signals when connected.

var _catalog = null              # Catalog instance or test double
var _count_label: Label = null
var _cataloged_connected: bool = false
var _encountered_connected: bool = false


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var header := Label.new()
	header.name = "DiscoveriesHeader"
	header.text = "DISCOVERIES"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95, 1.0))
	add_child(header)

	var sep := HSeparator.new()
	add_child(sep)

	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.text = "Cataloged: 0 / 0"
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95, 1.0))
	add_child(_count_label)


# --- Public API ---

func set_catalog(cat) -> void:
	_disconnect_catalog_signals()
	_catalog = cat
	_connect_catalog_signals()
	_refresh()


# --- Accessors for tests ---

func get_count_label() -> Label:
	return _count_label


# --- Internals ---

func _connect_catalog_signals() -> void:
	if _catalog == null:
		return
	if _catalog.has_signal("entry_cataloged"):
		if not _catalog.entry_cataloged.is_connected(_on_entry_cataloged):
			_catalog.entry_cataloged.connect(_on_entry_cataloged)
			_cataloged_connected = true
	if _catalog.has_signal("entry_encountered"):
		if not _catalog.entry_encountered.is_connected(_on_entry_encountered):
			_catalog.entry_encountered.connect(_on_entry_encountered)
			_encountered_connected = true


func _disconnect_catalog_signals() -> void:
	if _catalog == null:
		return
	if _cataloged_connected and _catalog.has_signal("entry_cataloged"):
		if _catalog.entry_cataloged.is_connected(_on_entry_cataloged):
			_catalog.entry_cataloged.disconnect(_on_entry_cataloged)
	if _encountered_connected and _catalog.has_signal("entry_encountered"):
		if _catalog.entry_encountered.is_connected(_on_entry_encountered):
			_catalog.entry_encountered.disconnect(_on_entry_encountered)
	_cataloged_connected = false
	_encountered_connected = false


func _refresh() -> void:
	if _count_label == null:
		return
	var cataloged: int = 0
	var total: int = 0
	if _catalog != null:
		if _catalog.has_method("get_discovery_count"):
			cataloged = int(_catalog.get_discovery_count())
		if _catalog.has_method("get_total_count"):
			total = int(_catalog.get_total_count())
	_count_label.text = "Cataloged: %d / %d" % [cataloged, total]


func _on_entry_cataloged(_entry_id: StringName, _bucket: int) -> void:
	_refresh()


func _on_entry_encountered(_entry_id: StringName, _label: String) -> void:
	_refresh()
