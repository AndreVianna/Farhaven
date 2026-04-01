extends Camera3D

## Camera follow — lerp follow with map AABB clamping.
## Attached to Camera3D, sibling of Player (not child).

@export var follow_speed: float = 8.0
@export var offset: Vector3 = Vector3(0, 15, 10)

var _target: Node3D
var _map_bounds: Rect2 = Rect2()
var _has_bounds: bool = false


func _ready() -> void:
	HexGrid.map_generated.connect(_compute_bounds)
	# Auto-find Player sibling in scene tree.
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player != null:
		_target = player


## Set the target node to follow.
func set_follow_target(target: Node3D) -> void:
	_target = target


func _process(delta: float) -> void:
	if _target == null:
		return

	var desired: Vector3 = _target.position + offset

	if _has_bounds:
		desired.x = clampf(desired.x, _map_bounds.position.x, _map_bounds.end.x)
		desired.z = clampf(desired.z, _map_bounds.position.y, _map_bounds.end.y)

	position = position.lerp(desired, follow_speed * delta)


func _compute_bounds() -> void:
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF

	for coords: Vector2i in HexGrid._tiles:
		var world_2d: Vector2 = HexGrid.axial_to_world(coords)
		min_x = minf(min_x, world_2d.x)
		max_x = maxf(max_x, world_2d.x)
		min_z = minf(min_z, world_2d.y)
		max_z = maxf(max_z, world_2d.y)

	# Padding of ~2 tile widths.
	var padding: float = 3.0
	_map_bounds = Rect2(
		min_x - padding,
		min_z - padding,
		(max_x - min_x) + padding * 2.0,
		(max_z - min_z) + padding * 2.0,
	)
	_has_bounds = true
