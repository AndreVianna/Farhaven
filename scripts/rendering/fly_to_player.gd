extends Node3D
class_name FlyToPlayer

## Spawns a temporary sprite that tweens from a prop world position
## to the Player's CURRENT position over ~0.3s, then queue_frees itself.
## Used as visual feedback on auto_gather_completed.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _HexGrid = preload("res://scripts/hex/hex_grid.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
## Uses preload because tests can be parsed before class_name registration completes.
const _PropDef = preload("res://scripts/data/prop_def.gd")

## Duration of the fly-to-player tween in seconds.
const FLY_DURATION: float = 0.3

## Vertical arc height for a slight parabolic effect.
const ARC_HEIGHT: float = 2.0

## Default color when a prop type has no PropDef.
const DEFAULT_COLOR: Color = Color.WHITE

var _player: Node = null


func setup(player: Node) -> void:
	_player = player


## Spawn a fly-to-player particle from the given coordinates.
## coords: axial hex coordinates of the gathered prop.
## prop_type: type of prop (for color).
## grid: HexGrid or mock with axial_to_world.
func spawn_fly(coords: Vector2i, prop_type: StringName, grid: Node) -> void:
	if _player == null:
		return

	var world_2d: Vector2 = grid.axial_to_world(coords)
	var tile: Resource = grid.get_tile(coords) if grid.has_method("get_tile") else null
	# Find the prop's sub-hex offset to start from prop position (not hex center)
	var prop_offset := Vector2.ZERO
	if tile != null:
		for prop in tile.get_props():
			if prop.type == prop_type:
				prop_offset = _HexMath.sub_axial_to_world(prop.sub_hex)
				break

	var wx: float = world_2d.x + prop_offset.x
	var wz: float = world_2d.y + prop_offset.y
	var elevation_y: float = 0.0
	if grid != null and grid.has_method("get_terrain_y"):
		elevation_y = grid.get_terrain_y(wx, wz)
	elif tile != null:
		elevation_y = float(tile.elevation) * _HexGrid.ELEVATION_STEP
	var start_pos := Vector3(wx, elevation_y + 0.6, wz)

	var sprite := _create_sprite(prop_type)
	sprite.position = start_pos
	add_child(sprite)

	_tween_to_player(sprite, start_pos)


func _create_sprite(prop_type: StringName) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_instance.mesh = sphere

	var mat := StandardMaterial3D.new()
	# TODO: tint by yield type once the icon system lands. For now a neutral color.
	mat.albedo_color = DEFAULT_COLOR
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
