class_name PlaceableCap
extends Resource

## PlaceableCap — prop can be placed in the world as a physical object.
## Multi-cell footprints reserve additional sub-hexes for placement validation.
## Collision and visual bounds come from the mesh(es), not the footprint.

## Sub-hex footprint (cols × rows). Default single sub-hex (1×1).
## Used for placement validation with multi-cell structures.
@export var footprint: Vector2i = Vector2i(1, 1)

## Visual variants — the renderer picks one per instance for variety.
## Empty array is allowed during content authoring; the prop falls back
## to placeholder_mesh_type until a real mesh is authored.
@export var meshes: Array[MeshVariant] = []
