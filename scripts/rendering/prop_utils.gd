class_name PropUtils
extends RefCounted

## Shared utilities for ResourceRenderer and PropLabelRenderer.
## Provides resource type → entry_id reverse lookup and tile sub-hex calculation.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _Prop = preload("res://scripts/hex/prop.gd")

## Legacy offset scale factor: maps normalized [-1,1] to world units.
## Kept for backward compatibility with any remaining callers.
const OFFSET_SCALE: float = 0.4

## Reverse lookup: resource type → catalog entry_id via ResourceRegistry.
static func get_entry_id_for_type(type: StringName) -> StringName:
	var def = ResourceRegistry.get_def(type)
	if def != null:
		return def.catalog_entry
	return &""

## Look up the sub_hex position and rotation for a specific entry on a tile.
## Returns [Vector2 world_offset, float rotation_deg]. Falls back to zero.
static func get_prop_placement(tile: Resource, entry_id: StringName) -> Array:
	if tile == null:
		return [Vector2.ZERO, 0.0]
	for prop in tile.get_resources():
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
