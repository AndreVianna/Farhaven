class_name CollisionShape
extends Resource

## CollisionShape — one element of PlaceableCap.collision_shapes.
## Several of these compose a prop's physics body. An empty array on
## the cap means the prop is walkthrough.

## Shape kind. Valid values: &"box" | &"cylinder" | &"sphere".
@export var shape_type: StringName = &"box"

## Shape dimensions. Interpretation depends on shape_type:
##   box      → size = full extents (width, height, depth)
##   cylinder → size = (radius, height, 0)
##   sphere   → size = (radius, 0, 0)
@export var size: Vector3 = Vector3.ONE

## Offset from the prop's anchor (origin) in local space.
@export var offset: Vector3 = Vector3.ZERO
