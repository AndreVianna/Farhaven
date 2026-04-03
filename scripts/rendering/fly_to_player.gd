extends Node3D
class_name FlyToPlayer

## Spawns a temporary sprite that tweens from a resource world position
## to the Player's CURRENT position over ~0.3s, then queue_frees itself.
## Used as visual feedback on auto_gather_completed.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _PropUtils = preload("res://scripts/rendering/prop_utils.gd")

## Duration of the fly-to-player tween in seconds.
const FLY_DURATION: float = 0.3

## Vertical arc height for a slight parabolic effect.
const ARC_HEIGHT: float = 2.0

## Color mapping for resource types.
const RESOURCE_COLORS: Dictionary = {
	&"wood": Color(0.4, 0.26, 0.13),
	&"stone": Color(0.6, 0.6, 0.6),
	&"berries": Color(0.85, 0.1, 0.2),
	&"fiber": Color(0.5, 0.75, 0.2),
	&"ore": Color(0.3, 0.3, 0.35),
	&"crystal": Color(0.3, 0.85, 0.95),
	&"toxic_berries": Color(0.6, 0.1, 0.6),
	&"anomaly_fragment": Color(0.9, 0.4, 0.9),
}

var _player: Node = null


func setup(player: Node) -> void:
	_player = player


## Spawn a fly-to-player particle from the given coordinates.
## coords: axial hex coordinates of the gathered resource.
## resource_type: type of resource (for color).
## grid: HexGrid or mock with axial_to_world.
func spawn_fly(coords: Vector2i, resource_type: StringName, grid: Node) -> void:
	if _player == null:
		return

	var world_2d: Vector2 = grid.axial_to_world(coords)
	var tile: Resource = grid.get_tile(coords) if grid.has_method("get_tile") else null
	var elevation_y: float = 0.0
	if tile != null:
		elevation_y = float(tile.elevation) * 0.5

	# Find the resource node's offset to start from prop position (not hex center)
	var prop_offset := Vector2.ZERO
	if tile != null:
		for rn in tile.resource_nodes:
			if rn.type == resource_type:
				prop_offset = _PropUtils.offset_to_world(rn.offset, 3.0)
				break

	var start_pos := Vector3(world_2d.x + prop_offset.x, elevation_y + 0.6, world_2d.y + prop_offset.y)

	var sprite := _create_sprite(resource_type)
	sprite.position = start_pos
	add_child(sprite)

	_tween_to_player(sprite, start_pos)


func _create_sprite(resource_type: StringName) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_instance.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = RESOURCE_COLORS.get(resource_type, Color.WHITE)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat

	return mesh_instance


func _tween_to_player(sprite: MeshInstance3D, start_pos: Vector3) -> void:
	if _player == null:
		sprite.queue_free()
		return

	# Target is the player's CURRENT position at tween start
	var target_pos: Vector3 = _player.position
	var mid_y: float = maxf(start_pos.y, target_pos.y) + ARC_HEIGHT
	var half_dur: float = FLY_DURATION * 0.5

	var tween := create_tween()
	tween.set_parallel(true)

	# XZ movement: linear to player's current position
	tween.tween_property(sprite, "position:x", target_pos.x, FLY_DURATION)
	tween.tween_property(sprite, "position:z", target_pos.z, FLY_DURATION)

	# Y movement: arc up then down
	tween.tween_property(sprite, "position:y", mid_y, half_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_property(sprite, "position:y", target_pos.y, half_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Fade out near end
	tween.tween_property(sprite, "material_override:albedo_color:a", 0.0, FLY_DURATION).set_delay(FLY_DURATION * 0.5)

	# Cleanup
	tween.chain().tween_callback(sprite.queue_free)
