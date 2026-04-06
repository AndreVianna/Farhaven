class_name HexMath

## Pure static hex math utility — no state, no dependencies.
## Uses axial coordinates (q, r) stored as Vector2i.
## Flat-top hexagon layout. Follows Red Blob Games conventions.

const HEX_SIZE: float = 3.0
const SUB_HEX_SIZE: float = HEX_SIZE / 5.0  # 0.6

# Flat-top axial neighbor directions (E, NE, NW, W, SW, SE)
const DIRECTIONS = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


static func axial_to_cube(coords: Vector2i) -> Vector3i:
	var q: int = coords.x
	var r: int = coords.y
	return Vector3i(q, -q - r, r)


static func axial_to_world(coords: Vector2i) -> Vector2:
	var q: float = float(coords.x)
	var r: float = float(coords.y)
	var x: float = HEX_SIZE * (3.0 / 2.0 * q)
	var y: float = HEX_SIZE * (sqrt(3.0) / 2.0 * q + sqrt(3.0) * r)
	return Vector2(x, y)


static func world_to_axial(world_pos: Vector2) -> Vector2i:
	var x: float = world_pos.x
	var y: float = world_pos.y
	var fq: float = (2.0 / 3.0 * x) / HEX_SIZE
	var fr: float = (-1.0 / 3.0 * x + sqrt(3.0) / 3.0 * y) / HEX_SIZE
	var fs: float = -fq - fr
	return _cube_round_to_axial(fq, fr, fs)


static func _cube_round_to_axial(fq: float, fr: float, fs: float) -> Vector2i:
	var q: int = roundi(fq)
	var r: int = roundi(fr)
	var s: int = roundi(fs)
	var q_diff: float = absf(float(q) - fq)
	var r_diff: float = absf(float(r) - fr)
	var s_diff: float = absf(float(s) - fs)
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	return Vector2i(q, r)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var ca: Vector3i = axial_to_cube(a)
	var cb: Vector3i = axial_to_cube(b)
	return (abs(ca.x - cb.x) + abs(ca.y - cb.y) + abs(ca.z - cb.z)) / 2


static func get_neighbors(coords: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRECTIONS:
		result.append(coords + (d as Vector2i))
	return result


static func get_tiles_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		var r_min: int = maxi(-radius, -q - radius)
		var r_max: int = mini(radius, -q + radius)
		for r in range(r_min, r_max + 1):
			result.append(center + Vector2i(q, r))
	return result


## Returns the ring of tiles at exactly `radius` steps from `center`.
## Ring has 6*radius tiles for radius >= 1, or [center] for radius 0.
static func get_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	var result: Array[Vector2i] = []
	# Start at SW corner (direction 4 = SW * radius), traverse each side
	var current: Vector2i = center + (DIRECTIONS[4] as Vector2i) * radius
	for i in range(6):
		for _j in range(radius):
			result.append(current)
			current = current + (DIRECTIONS[i] as Vector2i)
	return result


# --- Sub-hex functions ---

## Convert sub-hex axial coords to world offset relative to parent hex center.
## Sub-hexes use POINTY-TOP layout (rotated 30° from main flat-top hexes) so that
## sub-hex rings align with the edges of the parent flat-top hex.
static func sub_axial_to_world(sub_coords: Vector2i) -> Vector2:
	var sq: float = float(sub_coords.x)
	var sr: float = float(sub_coords.y)
	# Pointy-top: x = size * (sqrt(3) * q + sqrt(3)/2 * r), y = size * (3/2 * r)
	var x: float = SUB_HEX_SIZE * (sqrt(3.0) * sq + sqrt(3.0) / 2.0 * sr)
	var y: float = SUB_HEX_SIZE * (3.0 / 2.0 * sr)
	return Vector2(x, y)


## Convert a world offset (relative to hex center) to nearest sub-hex coords.
## Inverse of sub_axial_to_world (pointy-top layout).
static func world_to_sub_axial(offset: Vector2) -> Vector2i:
	var x: float = offset.x
	var y: float = offset.y
	# Pointy-top inverse: q = (sqrt(3)/3 * x - 1/3 * y) / size, r = (2/3 * y) / size
	var fq: float = (sqrt(3.0) / 3.0 * x - 1.0 / 3.0 * y) / SUB_HEX_SIZE
	var fr: float = (2.0 / 3.0 * y) / SUB_HEX_SIZE
	var fs: float = -fq - fr
	return _cube_round_to_axial(fq, fr, fs)


## Check if sub-hex coords are within the valid 19-hex grid (radius 2).
static func is_valid_sub_hex(sub_coords: Vector2i) -> bool:
	return distance(Vector2i.ZERO, sub_coords) <= 2


## Get all 19 valid sub-hex positions (center + ring 1 + ring 2).
static func get_all_sub_hexes() -> Array[Vector2i]:
	return get_tiles_in_range(Vector2i.ZERO, 2)


## Full world position of a prop: main hex center + sub-hex offset.
static func prop_world_position(main_coords: Vector2i, sub_coords: Vector2i) -> Vector2:
	return axial_to_world(main_coords) + sub_axial_to_world(sub_coords)
