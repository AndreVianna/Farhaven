class_name PortableCap
extends Resource

## PORTABLE capability — declares a prop as carryable and defines the spatial
## footprint it occupies inside a grid inventory (delivery-006f Tetris model).
##
## slot_shape is an array of cell offsets relative to the item's top-left origin
## (0, 0). Each Vector2i is one cell occupied by the item. Shapes may be
## irregular (L, T, blob, line) — not just rectangles. Example shapes:
##
##   Berry (1 cell):  [Vector2i(0, 0)]
##   Stick (3x1):     [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
##   Stone (2x2):     [Vector2i(0, 0), Vector2i(1, 0),
##                     Vector2i(0, 1), Vector2i(1, 1)]
##   Knife (L, ~6):   [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
##                     Vector2i(3, 0), Vector2i(3, 1), Vector2i(2, 1)]
##
## Rotation is handled by the grid engine (task-090), which rotates each cell
## offset by 90 degrees around the origin and re-normalizes to the positive
## quadrant. Each PropDef only authors the base (0 deg) orientation here.
##
## Default is a single-cell shape so props that haven't been migrated yet
## (task-095) still load and occupy exactly one cell. The previous float
## `size` field was removed in task-089 — old .tres files carry it as an
## unknown field (harmless warning) until task-095 rewrites them.
@export var slot_shape: Array[Vector2i] = [Vector2i(0, 0)]
