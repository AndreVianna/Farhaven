class_name HexMath

## Pure static hex math utility — no state, no dependencies.
## Uses axial coordinates (q, r) stored as Vector2i.
## Flat-top hexagon layout. Follows Red Blob Games conventions.

const HEX_SIZE: float = 3.0

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
