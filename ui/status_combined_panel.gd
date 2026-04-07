class_name StatusCombinedPanel
extends CombinedPanel

## STATUS panel: Left = Status (placeholder), Right = Inventory (existing).

const _InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")

var _inventory_panel: PanelContainer = null


func _init() -> void:
	super("STATUS", "INVENTORY")


func _build_left_content(parent: Control) -> void:
	parent.add_child(CombinedPanel.create_placeholder("(Status — Coming Soon)"))


func _build_right_content(parent: Control) -> void:
	_inventory_panel = _InventoryPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_inventory_panel, parent)


func _on_opened() -> void:
	# Trigger refresh on the inventory sub-panel when the combined panel opens
	if _inventory_panel != null:
		_inventory_panel.open()
		# Keep it visible (open() sets visible=true and refreshes)


# --- Pass-through API ---

func set_inventory(inv) -> void:
	if _inventory_panel != null:
		_inventory_panel.set_inventory(inv)


func set_catalog(cat) -> void:
	if _inventory_panel != null:
		_inventory_panel.set_catalog(cat)


func get_inventory_panel() -> PanelContainer:
	return _inventory_panel
