class_name GearCombinedPanel
extends CombinedPanel

## GEAR panel: Left = Crafting (existing), Right = Build (real panel).

const _CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")
const _BuildPanelScene = preload("res://scenes/ui/build_panel.tscn")

var _crafting_panel: CraftingPanel = null
var _build_panel: PanelContainer = null


func _init() -> void:
	super("CRAFTING", "BUILD")


func _build_left_content(parent: VBoxContainer) -> void:
	_crafting_panel = _CraftingPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_crafting_panel, parent)


func _build_right_content(parent: VBoxContainer) -> void:
	_build_panel = _BuildPanelScene.instantiate()
	CombinedPanel.embed_sub_panel(_build_panel, parent)


func _on_opened() -> void:
	if _crafting_panel != null:
		_crafting_panel.open()
	if _build_panel != null:
		_build_panel.open()


# --- Pass-through API ---

func set_crafting_system(sys: Node) -> void:
	if _crafting_panel != null:
		_crafting_panel.set_crafting_system(sys)


func set_inventory(inv) -> void:
	if _crafting_panel != null:
		_crafting_panel.set_inventory(inv)
	if _build_panel != null:
		_build_panel.set_inventory(inv)


func set_building_system(sys: Node) -> void:
	if _build_panel != null:
		_build_panel.set_building_system(sys)


func get_crafting_panel() -> CraftingPanel:
	return _crafting_panel


func get_build_panel() -> PanelContainer:
	return _build_panel
