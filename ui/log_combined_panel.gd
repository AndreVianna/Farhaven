class_name LogCombinedPanel
extends CombinedPanel

## LOG panel: Left = Catalog (existing), Right = Journal (placeholder).

const _CatalogPanelScene = preload("res://scenes/ui/catalog_panel.tscn")

var _catalog_panel: PanelContainer = null


func _init() -> void:
	super("CATALOG", "JOURNAL")


func _build_left_content(parent: Control) -> void:
	_catalog_panel = _CatalogPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_catalog_panel, parent)


func _build_right_content(parent: Control) -> void:
	parent.add_child(CombinedPanel.create_placeholder("(Journal — Coming Soon)"))


func _on_opened() -> void:
	# Trigger refresh on the catalog sub-panel when the combined panel opens
	if _catalog_panel != null:
		_catalog_panel.open()


# --- Pass-through API ---

func set_catalog(cat) -> void:
	if _catalog_panel != null:
		_catalog_panel.set_catalog(cat)


func get_catalog_panel() -> PanelContainer:
	return _catalog_panel
