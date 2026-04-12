class_name ContainerCap
extends Resource

## CONTAINER capability — declares a prop as a grid-based storage container
## (delivery-006f Tetris model). Containers hold items authored with
## PortableCap.slot_shape. The grid is a rectangular `grid_width x grid_height`
## region of 1x1 cells. Items are packed into the grid like sprite tetris —
## irregular shapes, 90-degree rotation, no stacking (1 prop = 1 shape).
##
## Defaults: 30 x 40 = 1200 cells — the player backpack starter size. Chests
## and pouches override these to smaller grids (e.g. 15 x 15 storage chest,
## 6 x 6 small pouch) in their own PropDef .tres files.
##
## The previous float `capacity_size` field was removed in task-089 — old
## .tres files carry it as an unknown field (harmless warning) until
## task-095 rewrites them with proper grid dimensions.
##
## accepts_filter restricts which prop tags may be stored in this container
## (empty = accepts everything). Unchanged by the tetris rewrite.
@export var grid_width: int = 30
@export var grid_height: int = 40
@export var accepts_filter: Array[StringName] = []

## TODO(task-090): delete this stub once the grid engine + callers migrate.
## Delivery-006f replaced the float `capacity_size` field with
## `grid_width * grid_height` cell dimensions. Legacy callers that still read
## `container.capacity_size` get back the total cell count (treated as a
## float size unit) so they keep working during the transitional state.
## Writes to this property fall back to reconstructing a square-ish grid —
## legacy test data that sets `capacity_size = 50.0` will end up with a
## 50-cell grid. Authors should migrate to `grid_width` / `grid_height` in
## task-095 and stop touching this property entirely.
var capacity_size: float:
	get:
		return float(grid_width * grid_height)
	set(value):
		var total_cells: int = int(max(0.0, value))
		if total_cells <= 0:
			grid_width = 0
			grid_height = 0
			return
		# Reconstruct a near-square grid from the requested cell count so that
		# legacy tests that only care about total capacity keep a sane shape.
		var side: int = int(ceil(sqrt(float(total_cells))))
		grid_width = side
		grid_height = int(ceil(float(total_cells) / float(side)))
