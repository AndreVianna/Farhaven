class_name LogCombinedPanel
extends CombinedPanel

## LOG panel: Left = Catalog (existing), Right = Journal (task-075b).

const _CatalogPanelScene = preload("res://scenes/ui/catalog_panel.tscn")
const _JournalPanelScene = preload("res://scenes/ui/journal_panel.tscn")

var _catalog_panel: CatalogPanel = null
var _journal_panel: JournalPanel = null


func _init() -> void:
	super("CATALOG", "JOURNAL")


func _build_left_content(parent: VBoxContainer) -> void:
	_catalog_panel = _CatalogPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_catalog_panel, parent)


func _build_right_content(parent: VBoxContainer) -> void:
	_journal_panel = _JournalPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_journal_panel, parent)


func _on_opened() -> void:
	if _catalog_panel != null:
		_catalog_panel.open()
	if _journal_panel != null:
		_journal_panel.open()


# --- Pass-through API ---

func set_catalog(cat) -> void:
	if _catalog_panel != null:
		_catalog_panel.set_catalog(cat)


func get_catalog_panel() -> CatalogPanel:
	return _catalog_panel


func get_journal_panel() -> JournalPanel:
	return _journal_panel
