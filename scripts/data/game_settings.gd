class_name GameSettings
extends Resource

## Game-wide configuration loaded at startup. Singleton resource at
## `res://data/game_settings.tres` — there is exactly one instance and
## it carries the choices that live above any single map or save.
##
## NOT a `Gear`: this is engine-level configuration, not something the
## player picks up, displays, or interacts with. No id / display_name /
## descriptions — just the knobs that govern startup.
##
## Precedence when deciding which map to load on startup:
##
##   1. If the current SaveManager save has a non-empty `current_map`,
##      load that. This lets progression override the starting point
##      as the player moves between chapters / scenes.
##   2. Otherwise fall back to `starting_map` below.
##
## `starting_map` is stored as a filename relative to `res://data/maps/`
## (e.g. "ch1.json"), not a full `res://` path, so content authors can
## type the short name in the editor and the engine resolves it.

@export var starting_map: String = "ch1.json"

## View-distance radius (in hex tiles) used by PropRenderer and
## PropLabelRenderer to stream natural props + their markers around
## the player. Tiles outside the radius are evicted from GPU pools;
## tiles entering are repopulated.
##
## Set to 0 to disable streaming entirely — every tile with props
## gets rendered, no matter the distance. Andre's rule: "wherever
## the map says there's a prop, render the prop, always." Expected
## perf scales with map size × per-tile scatter density; tune via
## biome.natural_props frequency / grouping instead of cropping
## the view.
##
## Positive values keep the old streaming behavior (1260 tiles at
## radius 20) for maps where the authored density would otherwise
## overwhelm the GPU.
@export_range(0, 60, 1) var prop_stream_radius: int = 0

## View-distance radius (in hex tiles) used by PropRenderer to spawn
## StaticBody3D collision bodies for natural props around the player.
## Decoupled from prop_stream_radius on purpose: rendering via
## MultiMesh is almost free on GPU, but a StaticBody3D per scattered
## prop hits the PhysicsServer every frame — so collision is kept to
## the player's immediate neighborhood while visuals can extend to
## the horizon.
##
## Default 8 tiles gives ~3s of margin at run speed before the player
## reaches an uncollidable prop. Range [3, 30] — lower than 3 is
## basically "only the tile under the player's feet" and higher than
## 30 defeats the point.
@export_range(3, 30, 1) var prop_collision_radius: int = 8
