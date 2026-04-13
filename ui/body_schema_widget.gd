class_name BodySchemaWidget
extends Control

## Body schema — humanoid silhouette with 22 equipment slot regions.
## Each slot is a small panel whose fill color reflects the equipped
## PropDef's placeholder_color; empty slots show the empty-state swatch.
## Hover / tap reveals the slot name and equipped prop in the tooltip.
##
## The layout is a simple absolute-positioned grid that reads front-to-
## back: head/face/neck at top, torso (chest pair + back in center + abdomen/
## lumbar) in the middle, limbs on the sides, feet at the bottom. A real
## illustration can later replace the rect silhouettes — the slot anchor
## coordinates stay the same.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _WearableCap = preload("res://scripts/data/capabilities/wearable_cap.gd")

## Slot cell visual size (square). The widget's minimum size is derived
## from GRID_COLS * SLOT_SIZE on the horizontal and the deepest row on
## the vertical.
const SLOT_SIZE: int = 32
const GRID_COLS: int = 5
const GRID_ROWS: int = 12

## Empty-slot fill — a neutral swatch that still reads as a distinct
## region so the silhouette stays legible when nothing is equipped.
const EMPTY_COLOR: Color = Color(0.18, 0.18, 0.22, 1.0)
const BORDER_COLOR: Color = Color(0.45, 0.45, 0.55, 0.9)

## Per-slot grid cell offsets. (col, row) — integers so the layout stays
## crisp at any scale factor. Columns 0 and 4 are the outer limbs; 1/3
## are the shoulders/arms/thighs/legs regions; 2 is the midline.
const _SLOT_CELLS: Dictionary = {
	_WearableCap.Place.HEAD: Vector2i(2, 0),
	_WearableCap.Place.FACE: Vector2i(2, 1),
	_WearableCap.Place.NECK: Vector2i(2, 2),
	_WearableCap.Place.LEFT_SHOULDER: Vector2i(1, 3),
	_WearableCap.Place.RIGHT_SHOULDER: Vector2i(3, 3),
	_WearableCap.Place.LEFT_CHEST: Vector2i(1, 4),
	_WearableCap.Place.BACK: Vector2i(2, 4),
	_WearableCap.Place.RIGHT_CHEST: Vector2i(3, 4),
	_WearableCap.Place.LEFT_ARM: Vector2i(0, 5),
	_WearableCap.Place.ABDOMEN: Vector2i(2, 5),
	_WearableCap.Place.RIGHT_ARM: Vector2i(4, 5),
	_WearableCap.Place.LEFT_FOREARM: Vector2i(0, 6),
	_WearableCap.Place.LUMBAR: Vector2i(2, 6),
	_WearableCap.Place.RIGHT_FOREARM: Vector2i(4, 6),
	_WearableCap.Place.LEFT_HAND: Vector2i(0, 7),
	_WearableCap.Place.RIGHT_HAND: Vector2i(4, 7),
	_WearableCap.Place.LEFT_THIGH: Vector2i(1, 8),
	_WearableCap.Place.RIGHT_THIGH: Vector2i(3, 8),
	_WearableCap.Place.LEFT_LEG: Vector2i(1, 9),
	_WearableCap.Place.RIGHT_LEG: Vector2i(3, 9),
	_WearableCap.Place.LEFT_FOOT: Vector2i(1, 10),
	_WearableCap.Place.RIGHT_FOOT: Vector2i(3, 10),
}

var _slot_panels: Dictionary = {}  # Place (int) → Panel
var _equipped: Dictionary = {}     # Place (int) → PropDef


func _ready() -> void:
	custom_minimum_size = Vector2(
		GRID_COLS * SLOT_SIZE,
		GRID_ROWS * SLOT_SIZE
	)
	_build_slot_panels()
	_refresh_panels()


func _build_slot_panels() -> void:
	for place in _SLOT_CELLS:
		var cell: Vector2i = _SLOT_CELLS[place]
		var panel := Panel.new()
		panel.position = Vector2(cell.x * SLOT_SIZE, cell.y * SLOT_SIZE)
		panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.tooltip_text = String(_WearableCap.place_to_string(place))
		_apply_panel_style(panel, EMPTY_COLOR)
		add_child(panel)
		_slot_panels[place] = panel


func _apply_panel_style(panel: Panel, fill: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = BORDER_COLOR
	panel.add_theme_stylebox_override("panel", style)


## Replace the full equipped map. Expected shape: Place (int) → PropDef.
## Unknown keys are ignored. Empty slots are painted with EMPTY_COLOR.
func set_equipped(equipped: Dictionary) -> void:
	_equipped = equipped.duplicate()
	_refresh_panels()


func _refresh_panels() -> void:
	for place in _slot_panels:
		var panel: Panel = _slot_panels[place]
		var def: _PropDef = _equipped.get(place, null)
		var fill: Color = EMPTY_COLOR
		var slot_name: String = String(_WearableCap.place_to_string(place))
		var tooltip: String = slot_name
		if def != null:
			fill = def.placeholder_color
			tooltip = "%s: %s" % [slot_name, String(def.display_name)]
		_apply_panel_style(panel, fill)
		panel.tooltip_text = tooltip


## Testing hook — returns the Panel node backing a Place slot, or null
## when the slot doesn't exist (e.g. called before _ready).
func get_slot_panel(place: int) -> Panel:
	return _slot_panels.get(place, null)
