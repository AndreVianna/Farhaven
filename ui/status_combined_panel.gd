class_name StatusCombinedPanel
extends CombinedPanel

## STATUS panel: Left = Status (placeholder), Right = Inventory (existing).

const _InventoryPanelScene = preload("res://scenes/ui/inventory_panel.tscn")

var _inventory_panel: InventoryPanel = null


func _init() -> void:
	super("STATUS", "INVENTORY")


func _build_left_content(parent: VBoxContainer) -> void:
	var placeholder := CombinedPanel.create_placeholder("STATUS", "Status")
	parent.add_child(placeholder)


func _build_right_content(parent: VBoxContainer) -> void:
	_inventory_panel = _InventoryPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_inventory_panel, parent)


func _on_opened() -> void:
	if _inventory_panel != null:
		_inventory_panel.open()


# --- Pass-through API ---

func set_inventory(inv) -> void:
	if _inventory_panel != null:
		_inventory_panel.set_inventory(inv)


func set_catalog(cat) -> void:
	if _inventory_panel != null:
		_inventory_panel.set_catalog(cat)


func get_inventory_panel() -> InventoryPanel:
	return _inventory_panel
