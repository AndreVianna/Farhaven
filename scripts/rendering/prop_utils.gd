class_name PropUtils
extends RefCounted

## Shared utilities for ResourceRenderer and PropLabelRenderer.
## Provides resource type → entry_id reverse lookup and tile offset calculation.

const _Catalog = preload("res://scripts/scanner/catalog.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

## Offset scale factor: maps normalized [-1,1] to world units
const OFFSET_SCALE: float = 0.4

## Cached reverse lookup: resource type → catalog entry_id
static var _type_to_entry: Dictionary = {}

## Reverse lookup: resource type → catalog entry_id.
static func get_entry_id_for_type(type: StringName) -> StringName:
	if _type_to_entry.is_empty():
		for res_type in _Catalog.RESOURCE_TO_ENTRY:
			_type_to_entry[res_type] = _Catalog.RESOURCE_TO_ENTRY[res_type]
	return _type_to_entry.get(type, &"")

## Look up the offset and rotation for a specific entry on a tile.
## Returns [Vector2 offset, float rotation_deg]. Falls back to zero.
static func get_prop_placement(tile: Resource, entry_id: StringName) -> Array:
	if tile == null:
		return [Vector2.ZERO, 0.0]
	for rn in tile.resource_nodes:
		var rn_entry_id: StringName = get_entry_id_for_type(rn.type)
		if rn_entry_id == entry_id:
			return [rn.offset, rn.rotation_deg]
	return [Vector2.ZERO, 0.0]

## Convert normalized offset to world-space offset.
static func offset_to_world(offset: Vector2, hex_size: float) -> Vector2:
	return Vector2(offset.x * hex_size * OFFSET_SCALE, offset.y * hex_size * OFFSET_SCALE)
