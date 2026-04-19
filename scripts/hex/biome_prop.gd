class_name BiomeProp
extends Resource

## One entry in a biome's natural-prop distribution table. Drives the
## Map Editor "Populate" command and any future runtime spawners: given
## a tile that passes every condition, the populator rolls `frequency`
## and, on success, spawns N copies where N is a uniform random int in
## `grouping_range`.
##
## Conditions are evaluated against each candidate tile:
##  * `elevation_range` — tile elevation must lie in [x, y] inclusive.
##  * `near_biomes` — at least one of the six axial neighbors must have
##    a biome id in the list. Empty list = unconstrained.
##  * `not_near_biomes` — none of the six axial neighbors may have a
##    biome id in the list.
##  * `near_props` — at least one axial neighbor tile must already
##    contain a prop whose type is in the list. Order matters in the
##    populator (minerals → liquids → oozes → fungi → flora → fauna)
##    so later-category entries can depend on props placed earlier.
##  * `not_near_props` — no axial neighbor may contain a listed prop.
##
## Keep the schema flat (explicit fields, not nested condition objects)
## so Godot's @export introspection and the JS editor can both round-
## trip the data without hand-rolling a discriminated union.

## Which PropDef to spawn. Must match a registered id, e.g. &"P00001".
@export var prop_id: StringName = &""

## Probability in [0, 1] that a qualifying tile receives this prop.
## 1.0 = every qualifying tile, 0.0 = never.
@export var frequency: float = 1.0

## Min/max instance count per qualifying tile (inclusive, uniform).
## Vector2i(1, 1) means always exactly one instance.
@export var grouping_range: Vector2i = Vector2i(1, 1)

## Inclusive elevation window the tile must sit in.
## Default covers the full supported elevation span.
@export var elevation_range: Vector2i = Vector2i(-100, 100)

## Tile qualifies only when at least one axial neighbor carries one of
## these biome ids. Empty list disables the constraint.
@export var near_biomes: Array[StringName] = []

## Tile disqualifies when any axial neighbor carries one of these
## biome ids. Empty list disables the constraint.
@export var not_near_biomes: Array[StringName] = []

## Tile qualifies only when at least one axial neighbor already
## contains a prop whose type is in this list. Empty list disables.
@export var near_props: Array[StringName] = []

## Tile disqualifies when any axial neighbor contains a prop whose
## type is in this list. Empty list disables the constraint.
@export var not_near_props: Array[StringName] = []
