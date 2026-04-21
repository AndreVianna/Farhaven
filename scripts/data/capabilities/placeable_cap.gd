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

## Collision shape composition. Each element should be a CollisionShape
## resource describing one primitive (box/cylinder/sphere) with size
## and offset. Multiple shapes compose the full collision volume. An
## empty array means the prop has no collision (walkthrough) — useful
## for decorative props like flat plants or particle-only effects.
@export var collision_shapes: Array[Resource] = []

## Scatter preset — controls how many copies of this prop render per
## placement and at what sibling scale. Stored as int because GDScript
## @export can't store enum values from a sibling class.
## Valid values: PlacementPreset.Preset.*
##   0 SINGLE     — 1 instance at the sub-hex center (default)
##   1 NORMAL     — 7 instances, sibling scale 0.5
##   2 DENSE      — 13 instances, sibling scale 0.5
##   3 SPROUTING  — 7 instances, sibling scale 0.3 (small satellites)
##   4 SPREAD     — 13 instances, sibling scale 1.0 (uniform coverage)
@export var placement: int = 0  # PlacementPreset.Preset.SINGLE

## How much to tilt the prop toward the terrain normal on inclined
## ground. 0.0 keeps the prop strictly vertical (good for tall trees
## that grow upward even on slopes). 1.0 fully aligns the prop's
## local Y axis with the terrain normal at its base (good for ground
## cover, moss, flat fungi — they should lie flat against the
## ground). Intermediate values blend partway.
@export_range(0.0, 1.0, 0.05) var slope_blend: float = 1.0

## Whether this prop may be spawned on sloped hexes during populate.
## Loose rocks, boulders, and other things that would roll downhill
## should set this to false so they only appear on flat ground. Things
## that grow from the soil (grass, moss, flowers, trees) keep this true.
## A tile is considered "sloped" when any neighbor's elevation differs
## from the tile's own by more than 1 unit (no wall between them).
@export var allow_on_slope: bool = true
