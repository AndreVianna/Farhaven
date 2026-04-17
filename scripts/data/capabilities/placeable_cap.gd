class_name PlaceableCap
extends Resource

## PlaceableCap — prop can be placed in the world as a physical object.
## Multi-cell footprints reserve additional sub-hexes for placement validation.
## Collision and visual bounds come from the mesh(es), not the footprint.

## Sub-hex footprint (cols × rows). Default single sub-hex (1×1).
## Used for placement validation with multi-cell structures.
@export var footprint: Vector2i = Vector2i(1, 1)

## Visual variants (MeshVariant resources) — the renderer picks one per
## instance for variety. Array[Resource] is used instead of
## Array[MeshVariant] to avoid class-name resolution order issues with
## custom Resource subclasses. Each element should be a MeshVariant.
## Empty array means the prop is not rendered.
@export var meshes: Array[Resource] = []
