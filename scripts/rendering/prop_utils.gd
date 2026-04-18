class_name PropUtils
extends RefCounted

## Shared utilities for PropRenderer and PropLabelRenderer.
## Provides prop type → entry_id reverse lookup and tile sub-hex calculation.

const _HexMath = preload("res://scripts/hex/hex_math.gd")

## Legacy offset scale factor: maps normalized [-1,1] to world units.
## Kept for backward compatibility with any remaining callers.
const OFFSET_SCALE: float = 0.4

## Reverse lookup: prop type → catalog entry_id via PropRegistry.
## After catalog merge, the entry_id IS the PropDef id (when catalogable).
static func get_entry_id_for_type(type: StringName) -> StringName:
	var def = PropRegistry.get_def(type)
	if def != null and def.catalogable != null:
		return def.id
	return &""

## Look up the sub_hex position and rotation for a specific entry on a tile.
## Returns [Vector2 world_offset, float rotation_deg]. Falls back to zero.
static func get_prop_placement(tile: Resource, entry_id: StringName) -> Array:
	if tile == null:
		return [Vector2.ZERO, 0.0]
	for prop in tile.get_props():
		var prop_entry_id: StringName = get_entry_id_for_type(prop.type)
		if prop_entry_id == entry_id:
			return [_HexMath.sub_axial_to_world(prop.sub_hex), prop.rotation_deg]
	return [Vector2.ZERO, 0.0]

## Convert sub-hex axial coords to world offset. Replaces offset_to_world.
static func sub_hex_to_world(sub_hex: Vector2i) -> Vector2:
	return _HexMath.sub_axial_to_world(sub_hex)

## Legacy: Convert normalized offset to world-space offset.
## Deprecated — use sub_hex_to_world or HexMath.sub_axial_to_world instead.
static func offset_to_world(offset: Vector2, hex_size: float) -> Vector2:
	return Vector2(offset.x * hex_size * OFFSET_SCALE, offset.y * hex_size * OFFSET_SCALE)


## Visual scale for a prop type, derived from the first authored
## MeshVariant's scale field. Returns 1.0 when no PlaceableCap or valid
## mesh variant exists. Used by attachment renderers (labels, scan
## rings, fly-to-player origin) so their Y offsets track the prop's
## actual visual size instead of floating/sinking for small/large props.
static func get_visual_scale(type: StringName) -> float:
	var def = PropRegistry.get_def(type)
	if def == null or def.placeable == null or def.placeable.meshes == null:
		return 1.0
	for mv_entry in def.placeable.meshes:
		var mv: MeshVariant = mv_entry as MeshVariant
		if mv == null:
			continue
		if is_finite(mv.scale) and mv.scale > 0.0:
			return mv.scale
	return 1.0
