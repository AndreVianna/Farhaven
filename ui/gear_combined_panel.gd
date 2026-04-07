class_name GearCombinedPanel
extends CombinedPanel

## GEAR panel: Left = Crafting (existing), Right = Build (placeholder).

const _CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")

var _crafting_panel: PanelContainer = null


func _init() -> void:
	super("CRAFTING", "BUILD")


func _build_left_content(parent: Control) -> void:
	_crafting_panel = _CraftingPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_crafting_panel, parent)


func _build_right_content(parent: Control) -> void:
	parent.add_child(CombinedPanel.create_placeholder("(Build — Coming Soon)"))


func _on_opened() -> void:
	# Trigger refresh on the crafting sub-panel when the combined panel opens
	if _crafting_panel != null:
		_crafting_panel.open()


# --- Pass-through API ---

func set_crafting_system(sys: Node) -> void:
	if _crafting_panel != null:
		_crafting_panel.set_crafting_system(sys)


func set_inventory(inv) -> void:
	if _crafting_panel != null:
		_crafting_panel.set_inventory(inv)


func get_crafting_panel() -> PanelContainer:
	return _crafting_panel
