class_name CatalogEntryUI
extends PanelContainer

## Single catalog entry row: icon placeholder + name + description + properties.
## Supports two display modes:
##   - CATALOGED: full info (name, description, properties)
##   - ENCOUNTERED: "Unidentified Fauna (Hostile/Shy)" with no details
## Builds itself programmatically — no child scene required.

const CATEGORY_COLORS: Dictionary = {
	0: Color(0.3, 0.7, 0.3),   # FLORA
	1: Color(0.8, 0.3, 0.3),   # FAUNA
	2: Color(0.6, 0.6, 0.6),   # MINERAL
	3: Color(0.5, 0.3, 0.8),   # ANOMALY
}

const ENCOUNTERED_COLOR: Color = Color(0.7, 0.5, 0.1)  # Warning amber

var _icon_rect: ColorRect
var _name_label: Label
var _desc_label: Label
var _props_label: Label
var _is_encountered: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0, 100)


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 0.85)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.40, 0.6)
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	_icon_rect = ColorRect.new()
	_icon_rect.custom_minimum_size = Vector2(72, 72)
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_icon_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 18)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_desc_label)

	_props_label = Label.new()
	_props_label.add_theme_font_size_override("font_size", 16)
	_props_label.modulate = Color(0.80, 0.80, 0.80)
	vbox.add_child(_props_label)


## Setup for CATALOGED entries — full info display.
## Accepts a PropDef whose `catalogable` capability provides the catalog data.
func setup(entry: Resource) -> void:
	_is_encountered = false
	_name_label.text = entry.display_name
	# Prefer long description; fall back to short description.
	var desc: String = ""
	if entry.long_description != "":
		desc = entry.long_description
	elif entry.short_description != "":
		desc = entry.short_description
	_desc_label.text = desc
	_props_label.text = _format_properties(entry)
	var cat: int = 0
	if entry.catalogable != null:
		cat = entry.catalogable.category
	_icon_rect.color = CATEGORY_COLORS.get(cat, Color(0.5, 0.5, 0.5))


## Setup for ENCOUNTERED entries — minimal display, no details.
func setup_encountered(label: String) -> void:
	_is_encountered = true
	_name_label.text = "⚠️ Unidentified Fauna (%s)" % label
	_desc_label.text = ""
	_props_label.text = ""
	_icon_rect.color = ENCOUNTERED_COLOR


func is_encountered() -> bool:
	return _is_encountered


func _format_properties(entry: Resource) -> String:
	var parts: Array[String] = []
	if entry.catalogable == null:
		return ""
	var props: Dictionary = entry.catalogable.properties
	match entry.catalogable.category:
		0:  # FLORA
			if props.get("edible", false):
				parts.append("Edible")
			if props.get("toxic", false):
				parts.append("Toxic")
			var res: StringName = props.get("prop_type", &"")
			if res != &"":
				parts.append("Prop: %s" % String(res).replace("_", " "))
		1:  # FAUNA
			if props.get("hostile", false):
				parts.append("Hostile")
			else:
				parts.append("Passive")
			var dmg: int = props.get("damage", 0)
			if dmg > 0:
				parts.append("DMG %d" % dmg)
		2:  # MINERAL
			var res: StringName = props.get("prop_type", &"")
			if res != &"":
				parts.append(String(res).capitalize())
			var tool: StringName = props.get("tool_required", &"")
			if tool != &"":
				parts.append("Needs: %s" % String(tool).replace("_", " "))
		3:  # ANOMALY
			parts.append("Anomaly")
	return " · ".join(parts)
