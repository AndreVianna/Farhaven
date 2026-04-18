class_name BodySchemaWidget
extends Control

## Body schema — two humanoid silhouettes (front + back) with 22 equipment
## slot overlays. Equipped PropDefs render as colored spots on top of the
## silhouette, simulating a dressed look; empty slots show the silhouette
## unobstructed.
##
## The silhouette is drawn programmatically with simple shapes (ellipse
## head, trapezoid torso, tapered arms/legs). Slot positions are anchored
## to the silhouette's proportions — if the silhouette art is replaced
## later with a real illustration, only the position dictionary needs to
## be retuned.

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _WearableCap = preload("res://scripts/data/capabilities/wearable_cap.gd")

# Silhouette geometry (front view). Back uses the same proportions.
const BODY_W: int = 120
const BODY_H: int = 280
const GAP: int = 24      # horizontal gap between front and back
const SLOT_RADIUS: int = 9

const SILHOUETTE_COLOR: Color = Color(0.22, 0.22, 0.28, 1.0)
const SILHOUETTE_OUTLINE: Color = Color(0.55, 0.55, 0.68, 1.0)
const BACK_REGION_COLOR: Color = Color(0.28, 0.28, 0.36, 1.0)
const EMPTY_SLOT_COLOR: Color = Color(0.12, 0.12, 0.16, 0.8)
const EMPTY_SLOT_OUTLINE: Color = Color(0.65, 0.65, 0.75, 0.9)
const OVERLAY_ALPHA: float = 0.85
const LABEL_COLOR: Color = Color(0.80, 0.80, 0.88, 1.0)

## Slot positions relative to the widget origin. Back view slots are
## shifted by BODY_W + GAP to the right so they sit next to the front.
const _SLOT_POSITIONS: Dictionary = {
	# Front view (20 slots)
	_WearableCap.Place.HEAD: Vector2(60, 16),
	_WearableCap.Place.FACE: Vector2(60, 32),
	_WearableCap.Place.NECK: Vector2(60, 50),
	_WearableCap.Place.LEFT_SHOULDER: Vector2(38, 60),
	_WearableCap.Place.RIGHT_SHOULDER: Vector2(82, 60),
	_WearableCap.Place.LEFT_CHEST: Vector2(48, 82),
	_WearableCap.Place.RIGHT_CHEST: Vector2(72, 82),
	_WearableCap.Place.LEFT_ARM: Vector2(24, 90),
	_WearableCap.Place.RIGHT_ARM: Vector2(96, 90),
	_WearableCap.Place.LEFT_FOREARM: Vector2(18, 130),
	_WearableCap.Place.RIGHT_FOREARM: Vector2(102, 130),
	_WearableCap.Place.LEFT_HAND: Vector2(16, 160),
	_WearableCap.Place.RIGHT_HAND: Vector2(104, 160),
	_WearableCap.Place.ABDOMEN: Vector2(60, 120),
	_WearableCap.Place.LEFT_THIGH: Vector2(50, 180),
	_WearableCap.Place.RIGHT_THIGH: Vector2(70, 180),
	_WearableCap.Place.LEFT_LEG: Vector2(50, 220),
	_WearableCap.Place.RIGHT_LEG: Vector2(70, 220),
	_WearableCap.Place.LEFT_FOOT: Vector2(50, 260),
	_WearableCap.Place.RIGHT_FOOT: Vector2(70, 260),
	# Back view (2 slots) — offset to the right of the front silhouette.
	_WearableCap.Place.BACK: Vector2(60 + BODY_W + GAP, 90),
	_WearableCap.Place.LUMBAR: Vector2(60 + BODY_W + GAP, 140),
}

var _equipped: Dictionary = {}     # Place (int) → PropDef
var _slot_buttons: Dictionary = {} # Place (int) → Control (tooltip carrier)


func _ready() -> void:
	custom_minimum_size = Vector2(BODY_W * 2 + GAP, BODY_H)
	_build_slot_tooltips()
	queue_redraw()


## Invisible button-sized Controls at each slot position exist only so the
## engine has something concrete to hover for tooltips; the visual is
## drawn in _draw() for performance and layout simplicity.
func _build_slot_tooltips() -> void:
	for place in _SLOT_POSITIONS:
		var pos: Vector2 = _SLOT_POSITIONS[place]
		var area := Control.new()
		area.position = pos - Vector2(SLOT_RADIUS, SLOT_RADIUS)
		area.size = Vector2(SLOT_RADIUS * 2, SLOT_RADIUS * 2)
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		area.tooltip_text = String(_WearableCap.place_to_string(place))
		add_child(area)
		_slot_buttons[place] = area


func set_equipped(equipped: Dictionary) -> void:
	_equipped = equipped.duplicate()
	_refresh_tooltips()
	queue_redraw()


func _refresh_tooltips() -> void:
	for place in _slot_buttons:
		var area: Control = _slot_buttons[place]
		var slot_name: String = String(_WearableCap.place_to_string(place))
		var def: _PropDef = _equipped.get(place, null)
		if def != null:
			area.tooltip_text = "%s: %s" % [slot_name, String(def.display_name)]
		else:
			area.tooltip_text = slot_name


func _draw() -> void:
	_draw_front_silhouette(Vector2.ZERO)
	_draw_back_silhouette(Vector2(BODY_W + GAP, 0))
	_draw_slot_overlays()
	_draw_captions()


func _draw_front_silhouette(origin: Vector2) -> void:
	# Head
	_draw_ellipse(origin + Vector2(60, 20), 16.0, 22.0, SILHOUETTE_COLOR)
	_draw_ellipse_outline(origin + Vector2(60, 20), 16.0, 22.0, SILHOUETTE_OUTLINE)
	# Neck
	var neck := Rect2(origin + Vector2(52, 42), Vector2(16, 12))
	draw_rect(neck, SILHOUETTE_COLOR)
	draw_rect(neck, SILHOUETTE_OUTLINE, false, 1.0)
	# Torso trapezoid
	var torso := PackedVector2Array([
		origin + Vector2(32, 54),
		origin + Vector2(88, 54),
		origin + Vector2(76, 160),
		origin + Vector2(44, 160),
	])
	draw_colored_polygon(torso, SILHOUETTE_COLOR)
	draw_polyline(_close(torso), SILHOUETTE_OUTLINE, 1.0)
	# Left arm (shoulder → hand)
	var left_arm := PackedVector2Array([
		origin + Vector2(32, 54),
		origin + Vector2(40, 60),
		origin + Vector2(28, 170),
		origin + Vector2(10, 170),
	])
	draw_colored_polygon(left_arm, SILHOUETTE_COLOR)
	draw_polyline(_close(left_arm), SILHOUETTE_OUTLINE, 1.0)
	# Right arm
	var right_arm := PackedVector2Array([
		origin + Vector2(88, 54),
		origin + Vector2(110, 170),
		origin + Vector2(92, 170),
		origin + Vector2(80, 60),
	])
	draw_colored_polygon(right_arm, SILHOUETTE_COLOR)
	draw_polyline(_close(right_arm), SILHOUETTE_OUTLINE, 1.0)
	# Left leg
	var left_leg := PackedVector2Array([
		origin + Vector2(44, 160),
		origin + Vector2(58, 160),
		origin + Vector2(56, 270),
		origin + Vector2(42, 270),
	])
	draw_colored_polygon(left_leg, SILHOUETTE_COLOR)
	draw_polyline(_close(left_leg), SILHOUETTE_OUTLINE, 1.0)
	# Right leg
	var right_leg := PackedVector2Array([
		origin + Vector2(62, 160),
		origin + Vector2(76, 160),
		origin + Vector2(78, 270),
		origin + Vector2(64, 270),
	])
	draw_colored_polygon(right_leg, SILHOUETTE_COLOR)
	draw_polyline(_close(right_leg), SILHOUETTE_OUTLINE, 1.0)


func _draw_back_silhouette(origin: Vector2) -> void:
	# Faint full-body outline so the back view reads as "back of a person",
	# with only the back + lumbar regions rendered solid.
	var outline_color: Color = SILHOUETTE_OUTLINE
	outline_color.a = 0.45
	# Head outline
	_draw_ellipse_outline(origin + Vector2(60, 20), 16.0, 22.0, outline_color)
	# Torso outline
	var torso := PackedVector2Array([
		origin + Vector2(32, 54),
		origin + Vector2(88, 54),
		origin + Vector2(76, 160),
		origin + Vector2(44, 160),
	])
	draw_polyline(_close(torso), outline_color, 1.0)
	# Legs outline
	var left_leg := PackedVector2Array([
		origin + Vector2(44, 160),
		origin + Vector2(58, 160),
		origin + Vector2(56, 270),
		origin + Vector2(42, 270),
	])
	var right_leg := PackedVector2Array([
		origin + Vector2(62, 160),
		origin + Vector2(76, 160),
		origin + Vector2(78, 270),
		origin + Vector2(64, 270),
	])
	draw_polyline(_close(left_leg), outline_color, 1.0)
	draw_polyline(_close(right_leg), outline_color, 1.0)

	# Solid BACK region — upper torso rectangle
	var back_region := Rect2(origin + Vector2(36, 58), Vector2(48, 56))
	draw_rect(back_region, BACK_REGION_COLOR)
	draw_rect(back_region, SILHOUETTE_OUTLINE, false, 1.0)
	# Solid LUMBAR region — lower torso rectangle
	var lumbar_region := Rect2(origin + Vector2(38, 120), Vector2(44, 36))
	draw_rect(lumbar_region, BACK_REGION_COLOR)
	draw_rect(lumbar_region, SILHOUETTE_OUTLINE, false, 1.0)


func _draw_slot_overlays() -> void:
	for place in _SLOT_POSITIONS:
		var pos: Vector2 = _SLOT_POSITIONS[place]
		var def: _PropDef = _equipped.get(place, null)
		if def != null:
			# Equipped: colored disc with alpha so the silhouette bleeds
			# through — simulates a prop visible through clothing layers.
			# TODO: use prop thumbnail/icon once the icon system lands.
			var fill: Color = Color(0.6, 0.6, 0.6)
			fill.a = OVERLAY_ALPHA
			draw_circle(pos, SLOT_RADIUS, fill)
			draw_arc(pos, SLOT_RADIUS, 0.0, TAU, 24, SILHOUETTE_OUTLINE, 1.5)
		else:
			# Empty: hollow marker so players can still see where a slot
			# lives before anything is equipped there.
			draw_circle(pos, SLOT_RADIUS - 1, EMPTY_SLOT_COLOR)
			draw_arc(pos, SLOT_RADIUS, 0.0, TAU, 24, EMPTY_SLOT_OUTLINE, 1.0)


func _draw_captions() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(BODY_W / 2 - 16, BODY_H - 4),
		"FRONT", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, LABEL_COLOR)
	draw_string(font, Vector2(BODY_W + GAP + BODY_W / 2 - 14, BODY_H - 4),
		"BACK", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, LABEL_COLOR)


## Draw a filled ellipse by approximating it with a polygon — Godot's
## CanvasItem lacks a native draw_ellipse, so we sample TAU into segments.
func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	const SEGMENTS: int = 32
	var points := PackedVector2Array()
	for i in SEGMENTS:
		var a: float = float(i) / SEGMENTS * TAU
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, color: Color) -> void:
	const SEGMENTS: int = 32
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var a: float = float(i) / SEGMENTS * TAU
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, 1.0)


## Append the first point to close a polygon for draw_polyline.
func _close(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() == 0:
		return points
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	return closed


## Testing hook — returns the tooltip Control for a Place, or null.
func get_slot_panel(place: int) -> Control:
	return _slot_buttons.get(place, null)
