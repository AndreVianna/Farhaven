class_name GearCombinedPanel
extends CombinedPanel

## GEAR panel: Left = Crafting (existing), Right = Build (placeholder).

const _CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")

var _crafting_panel: CraftingPanel = null


func _init() -> void:
	super("CRAFTING", "BUILD")


func _build_left_content(parent: VBoxContainer) -> void:
	_crafting_panel = _CraftingPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_crafting_panel, parent)


func _build_right_content(parent: VBoxContainer) -> void:
	var placeholder := CombinedPanel.create_placeholder("BUILD", "Build")
	parent.add_child(placeholder)


func _on_opened() -> void:
	if _crafting_panel != null:
		_crafting_panel.open()


# --- Pass-through API ---

func set_crafting_system(sys: Node) -> void:
	if _crafting_panel != null:
		_crafting_panel.set_crafting_system(sys)


func set_inventory(inv) -> void:
	if _crafting_panel != null:
		_crafting_panel.set_inventory(inv)


func get_crafting_panel() -> CraftingPanel:
	return _crafting_panel
