extends Node3D

## PropRenderer — MultiMeshInstance3D pools for 3D prop meshes.
## One pool per PropDef from PropRegistry, keyed by StringName (prop type id).
## Signal-driven: subscribes to HexGrid map_generated,
## prop_depleted, prop_respawned signals.
## On prop_depleted: swap mesh variant (tree→stump, rock→rubble).
## On prop_respawned: swap back to original mesh.

const _HexMath = preload("res://scripts/hex/hex_math.gd")
const _HexGrid = preload("res://scripts/hex/hex_grid.gd")
const _PlacementPreset = preload("res://scripts/data/capabilities/placement_preset.gd")
const _CollisionHelper = preload("res://scripts/core/collision_helper.gd")

# --- Constants ---

## Fallback Y offset if mesh height can't be determined.
const PROP_Y_OFFSET: float = 0.3

## Lower bound on the scale applied to any rendered prop instance.
## Sibling copies of scatter presets multiply variant_scale by
## sibling_scale (0.3–1.0) and a 0.85× jitter, which could drop the
## effective scale below 0.1 for small authored meshes. At a
## realistic camera distance that pushes the mesh sub-pixel and the
## GPU rasterizer silently skips it — so the tile looks empty even
## though the instance is in the MultiMesh. Floor keeps tiny props
## visible without changing authored scales; raise this constant if
## ground-cover ever looks sparse again.
const MIN_RENDER_SCALE: float = 0.35

## Initial capacity of each MultiMesh pool. Each pool allocates this
## many slots up front. DO NOT grow it mid-populate: Godot's
## MultiMesh.instance_count setter erases every existing instance's
## transform when the buffer is reallocated, so a grow-on-demand
## strategy silently wipes everything added before the grow and the
## player sees "half the props are missing at spawn but fine after
## walking away and back" (Andre diagnosed this on 2026-04-19 with
## radius 5 vs 7 vs 10 — growth was always triggering on the later
## radii and eating the near-player instances that had already been
## written).
##
## Dimensioned to cover a densely-populated radius-60 window with
## Dense scatter (~15k instances per variant pool worst-case) plus
## ~10% headroom. 16384 × 64 B = 1 MB per pool variant.
const INITIAL_INSTANCES: int = 16384


## Fallback streaming radius used before GameSettings is loaded.
## Overridden by `set_stream_radius()` (called from main.gd once
## game_settings.tres is read). Keeps GPU instance count bounded
## by O(radius²) independent of map size.
const DEFAULT_STREAM_RADIUS: int = 20

## Active streaming radius. Writable via set_stream_radius so the
## main bootstrap or a future settings menu can retune without
## touching the renderer's internals.
var _stream_radius: int = DEFAULT_STREAM_RADIUS

## Default collision streaming radius used before GameSettings loads.
## Overridden by set_collision_radius() from main._apply_render_settings.
## Smaller than render radius on purpose: MultiMesh draws are cheap, a
## StaticBody3D per scattered prop is not. 0 disables collision streaming
## entirely (useful for tests, debug, or "feather-light" modes).
const DEFAULT_COLLISION_RADIUS: int = 8

## Active collision streaming radius.
var _collision_radius: int = DEFAULT_COLLISION_RADIUS

## Per-pool frustum-cull AABB. Godot's default MultiMeshInstance3D
## bounding box is derived from the mesh, not the live instance
## transforms — so rotating the camera could cull the entire pool
## when the local origin fell outside the frustum even though the
## instances spanned the map. An oversized AABB disables the node-
## level cull; Godot still frustum-culls individual instances on
## the GPU via the MultiMesh shader.
const _POOL_CULL_AABB: AABB = AABB(Vector3(-1000, -200, -1000), Vector3(2000, 400, 2000))

## HEX_SIZE for offset calculation
const HEX_SIZE: float = 3.0

# --- State ---

## Primary MultiMeshInstance3D per prop type id — the "variant 0" pool.
## Existing API (get_pool_visible_count, get_pool_mesh, etc.) points at this.
var _pools: Dictionary = {}

## Additional MMI pools for variants 1+ of a prop.
## `_variant_pools[pool_id]` → Array[MultiMeshInstance3D] (length = variants-1,
## empty for single-variant props).
var _variant_pools: Dictionary = {}

## Variant-aware Y offsets — `_variant_y_offsets[pool_id]` → Array[float].
## Index 0 corresponds to _pools[pool_id] (variant 0), rest match _variant_pools.
var _variant_y_offsets: Dictionary = {}

## Variant-aware scale factors — `_variant_scales[pool_id]` → Array[float].
## Mirrors MeshVariant.scale. Applied to each instance's transform basis
## and scales the effective y_offset. Always positive finite (NaN/≤0
## inputs fall back to 1.0 during pool creation).
var _variant_scales: Dictionary = {}

## Normal mesh variants per prop type id (variant 0 only — for API compat).
var _normal_meshes: Dictionary = {}

## Depleted mesh variants per prop type id (variant 0 only — for API compat).
var _depleted_meshes: Dictionary = {}

## Normal colors per prop type id (for undimmed state)
var _pool_colors: Dictionary = {}

## Per-pool Y offset (center-to-bottom distance of the mesh) — variant 0 only.
var _pool_y_offsets: Dictionary = {}

## Tile coords -> Array of {prop_type: StringName, pool: StringName,
##   variant: int, instance_idx: int, depleted: bool}
var _tile_entries: Dictionary = {}

## Reference to HexGrid (allows override in tests)
var _grid: Node = null

## Tiles currently materialized into the MultiMesh pools. Tracked so
## we can diff against `STREAM_RADIUS` as the player moves and only
## touch the add/remove delta instead of re-sweeping the whole map.
var _streamed_tiles: Dictionary = {}

## Tile coords → Array[StaticBody3D] holding every collision body emitted
## for the scattered natural props on that tile. Parallel to but
## independent of `_tile_entries` (visual MultiMesh) because the
## collision window may be much smaller than the render window.
var _collision_bodies: Dictionary = {}

## Container Node3D that parents all StaticBody3D collision bodies so
## PropRenderer's immediate children stay clean (just the MMI pools).
## Created on first use.
var _collision_root: Node3D = null

## Per-stream-event memo for `_compute_prop_scatter` results. Cleared
## at the top of every streaming entry point (_stream_around and
## _stream_collision_around) so the visual + collision paths share
## one scatter computation per (coords, sub_hex, prop_type) within
## the same stream cycle. Deterministic seed guarantees the cached
## and uncached values are identical; the cache exists solely to
## dedupe the ~30 µs per-call cost that otherwise runs twice for
## every tile inside both windows.
var _scatter_cache: Dictionary = {}

# --- Frame-amortized streaming queues ---
#
# Adding tiles' worth of MultiMesh instances + StaticBody3Ds all in one
# frame produced a ~1s spike per hex crossing (reported by Andre
# 2026-04-19). The work is real — even with only 14 delta tiles, each
# tile's scatter compute + per-copy MultiMesh writes + per-copy
# StaticBody3D allocation + scene-tree insertion add up.
#
# The fix: queue the ADD side of streaming and process a bounded
# batch per _process tick. Evictions stay synchronous — evicted tiles
# must disappear immediately to avoid lingering ghost instances past
# the window boundary. Visually, newly-entered tiles fade in over a
# few frames at the far edge of the window, which is where the
# player's peripheral vision is least sensitive anyway.

## Max tiles added to the visual MultiMesh pools per frame. Tuned so
## the per-frame work stays under ~4 ms on the current assets; the
## queue drains in a handful of frames after a hex cross (~14 tiles
## delta → 4 frames at 60 Hz, imperceptible).
const VISUAL_TILES_PER_FRAME: int = 4

## Max tiles that receive StaticBody3D collision bodies per frame.
## Lower than visual because each body + shape allocation is heavier
## than a MultiMesh instance write.
const COLLISION_TILES_PER_FRAME: int = 2

## FIFO queue of tile coords awaiting visual materialization.
var _pending_visual_tiles: Array[Vector2i] = []

## Set form of _pending_visual_tiles for O(1) membership test during
## re-queueing / eviction. Keys are Vector2i coords, values unused.
var _pending_visual_set: Dictionary = {}

## FIFO queue of tile coords awaiting collision body construction.
var _pending_collision_tiles: Array[Vector2i] = []

## Set form of _pending_collision_tiles (see _pending_visual_set).
var _pending_collision_set: Dictionary = {}

## Player node — source of the `player_moved` signal that drives
## streaming. Late-bound via `_connect_player_signals` because the
## Player is a sibling of this renderer in the scene tree and isn't
## guaranteed to exist at _ready time.
var _player: Node = null


func _ready() -> void:
	if _grid == null:
		_grid = HexGrid
	_create_pools()
	_connect_signals()


## Drain the pending-add queues a bounded number of tiles per frame.
## Eviction happens synchronously inside _stream_*_around so stale
## instances never linger past one frame; ADDs are what we amortize
## because their per-tile cost (scatter compute + MultiMesh writes +
## StaticBody3D allocation + scene-tree insert) is the real spike.
func _process(_delta: float) -> void:
	if not _pending_visual_tiles.is_empty():
		var budget: int = VISUAL_TILES_PER_FRAME
		while budget > 0 and not _pending_visual_tiles.is_empty():
			var coords: Vector2i = _pending_visual_tiles.pop_front()
			_pending_visual_set.erase(coords)
			if _streamed_tiles.has(coords):
				continue  # raced with another stream event; already done
			_add_props_for_tile(coords, false)
			_streamed_tiles[coords] = true
			budget -= 1
	if not _pending_collision_tiles.is_empty():
		var cbudget: int = COLLISION_TILES_PER_FRAME
		while cbudget > 0 and not _pending_collision_tiles.is_empty():
			var coords: Vector2i = _pending_collision_tiles.pop_front()
			_pending_collision_set.erase(coords)
			if _collision_bodies.has(coords):
				continue
			_build_collision_for_tile(coords)
			cbudget -= 1


func _create_pools() -> void:
	for def in PropRegistry.get_all():
		# Collect live mesh variants in priority order:
		# 1. PlaceableCap.meshes[*].scene — authored variants
		# 2. def.mesh — legacy single-mesh field (as variant 0)
		# Props with no meshes are skipped; they will not render.
		var variant_meshes: Array[Mesh] = []
		var variant_y_offsets: Array[float] = []
		var variant_scales: Array[float] = []

		if def.placeable != null and def.placeable.meshes != null:
			for mv_entry in def.placeable.meshes:
				var mv: MeshVariant = mv_entry as MeshVariant
				if mv == null or mv.scene == null:
					continue
				var extracted: Array = _extract_mesh_from_scene(mv.scene)
				if extracted[0] != null:
					variant_meshes.append(extracted[0])
					variant_y_offsets.append(extracted[1])
					# Positive finite scale only — rejects NaN, ±inf, 0, negatives.
					var s: float = mv.scale if (is_finite(mv.scale) and mv.scale > 0.0) else 1.0
					variant_scales.append(s)

		if variant_meshes.is_empty() and def.mesh != null:
			variant_meshes.append(def.mesh)
			variant_y_offsets.append(PROP_Y_OFFSET)
			variant_scales.append(1.0)

		if variant_meshes.is_empty():
			# Prop has no visible mesh — skip pool creation.
			# Emit a warning so authors notice silently-skipped PropDefs
			# (easy to hit by creating a PropDef with a PlaceableCap but
			# forgetting to author a MeshVariant.scene).
			push_warning("PropRenderer: prop '%s' has no meshes — will not render" % def.id)
			continue

		# Depleted mesh (same for all variants for now).
		var depleted_mesh_res: Mesh
		if def.harvestable != null and def.harvestable.depleted_meshes != null \
				and def.harvestable.depleted_meshes.size() > 0:
			var depleted_mv: MeshVariant = def.harvestable.depleted_meshes[0] as MeshVariant
			if depleted_mv != null and depleted_mv.scene != null:
				var extracted_d: Array = _extract_mesh_from_scene(depleted_mv.scene)
				depleted_mesh_res = extracted_d[0]
		if depleted_mesh_res == null and def.depleted_mesh != null:
			depleted_mesh_res = def.depleted_mesh
		# If still null, depleted state will reuse the primary mesh.

		_normal_meshes[def.id] = variant_meshes[0]
		_depleted_meshes[def.id] = depleted_mesh_res
		_pool_y_offsets[def.id] = variant_y_offsets[0]
		_variant_y_offsets[def.id] = variant_y_offsets.duplicate()
		_variant_scales[def.id] = variant_scales.duplicate()

		# Real meshes carry their own PBR materials — use WHITE so
		# material_override doesn't tint them.
		var color: Color = Color.WHITE
		_pool_colors[def.id] = color

		# Primary pool (variant 0).
		_create_pool(def.id, variant_meshes[0], color, true)

		# Additional pools for variants 1+.
		var extra_pools: Array[MultiMeshInstance3D] = []
		for vi: int in range(1, variant_meshes.size()):
			var extra_mmi: MultiMeshInstance3D = _build_variant_pool(def.id, vi, variant_meshes[vi], color, true)
			extra_pools.append(extra_mmi)
		_variant_pools[def.id] = extra_pools


## Check whether a MultiMesh pool has room for another instance.
## Growing the pool at runtime is NOT safe — Godot's
## MultiMesh.instance_count setter wipes every existing instance
## transform when the buffer is reallocated. The pool is sized up
## front via INITIAL_INSTANCES; hitting the cap is a logged
## overflow rather than an opportunity to quietly grow.
static func _ensure_pool_capacity(mm: MultiMesh, required: int) -> bool:
	if required <= mm.instance_count:
		return true
	# One-time per-pool warning: if we ever hit the ceiling, either
	# lower biome density (fewer populated tiles, Dense → Normal)
	# or raise INITIAL_INSTANCES. Silent-skip would re-create the
	# original "labels without meshes" bug.
	push_warning("PropRenderer: pool %s hit INITIAL_INSTANCES cap (%d) — some instances will not render." % [mm.resource_name, INITIAL_INSTANCES])
	return false


## DEBUG: when a prop type is listed in DEBUG_FORCE_TINT, swap its
## pool's material for a bright unlit color — useful when diagnosing
## "pool has N instances but I can't see them" bugs. Default empty
## so the imported .glb materials render normally.
const DEBUG_FORCE_TINT: Dictionary = {}

func _maybe_apply_debug_tint(mmi: MultiMeshInstance3D, pool_id: StringName) -> void:
	if not DEBUG_FORCE_TINT.has(pool_id):
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DEBUG_FORCE_TINT[pool_id]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Override the imported material so the instance stands out even
	# against a noisy terrain or through other props. `material_override`
	# on the MMI applies to every instance in the pool.
	mmi.material_override = mat


## Dump per-pool instance counts to the output — useful when
## diagnosing "which prop type is missing?" in a populated map.
## Call from main.gd or a debug console.
func print_pool_stats() -> void:
	var total: int = 0
	for pool_id in _pools.keys():
		var mmi: MultiMeshInstance3D = _pools[pool_id]
		var primary: int = mmi.multimesh.visible_instance_count if mmi != null else 0
		var cap: int = mmi.multimesh.instance_count if mmi != null else 0
		var sum: int = primary
		var extras: Array = _variant_pools.get(pool_id, [])
		var variant_parts: Array = [str(primary) + "/" + str(cap)]
		for ex in extras:
			if ex == null:
				continue
			var v: int = ex.multimesh.visible_instance_count
			var c: int = ex.multimesh.instance_count
			sum += v
			variant_parts.append(str(v) + "/" + str(c))
		total += sum
		print("[PropRenderer] %s  total=%d  variants=[%s]" % [pool_id, sum, ", ".join(variant_parts)])
	print("[PropRenderer] streamed_tiles=%d  total_instances=%d  radius=%d" % [_streamed_tiles.size(), total, _stream_radius])


## Create an extra MMI for a non-primary variant. Returns the new node.
## Added as a child of this PropRenderer just like `_create_pool` does.
func _build_variant_pool(pool_id: StringName, variant_idx: int, mesh: Mesh, color: Color, is_real_mesh: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = INITIAL_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = mesh

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "PropPool_%s_v%d" % [pool_id, variant_idx]
	# Wide custom AABB so Godot's frustum culler never drops the
	# whole pool when the camera is pointed at the "empty" side of
	# the origin — individual instance culling still happens on
	# the GPU. Covers a 2 km × 2 km footprint which is far larger
	# than any authored map radius × hex size.
	mmi.custom_aabb = _POOL_CULL_AABB
	_maybe_apply_debug_tint(mmi, pool_id)

	if not is_real_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mmi.material_override = mat

	add_child(mmi)
	return mmi


## Pick a variant index [0, count) deterministically from tile coords + sub_hex.
## Same (coords, sub_hex) always yields the same variant so instances stay
## stable across map reloads.
static func _pick_variant(coords: Vector2i, sub_hex: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	var h: int = absi((coords.x * 73856093) ^ (coords.y * 19349663) ^ (sub_hex.x * 83492791) ^ (sub_hex.y * 40503))
	return h % count


## Per-instance jitter derived from coords + sub_hex.
## Returns [scale_factor (0.9..1.1), tilt_x_deg (-5..5), tilt_z_deg (-5..5)].
## Stable across frames/reloads — same input always produces the same output.
static func _compute_jitter(coords: Vector2i, sub_hex: Vector2i) -> Array:
	var h1: int = absi((coords.x * 12345) ^ (coords.y * 67890) ^ (sub_hex.x * 11) ^ (sub_hex.y * 97))
	var h2: int = absi((coords.x * 13) ^ (coords.y * 31) ^ (sub_hex.x * 59) ^ (sub_hex.y * 79))
	var h3: int = absi((coords.x * 37) ^ (coords.y * 41) ^ (sub_hex.x * 43) ^ (sub_hex.y * 47))
	var scale_factor: float = 0.9 + (float(h1 % 1000) / 1000.0) * 0.2
	var tilt_x: float = -5.0 + (float(h2 % 1000) / 1000.0) * 10.0
	var tilt_z: float = -5.0 + (float(h3 % 1000) / 1000.0) * 10.0
	return [scale_factor, tilt_x, tilt_z]


## Fetch the MultiMeshInstance3D for a (pool_id, variant_idx) pair.
## Variant 0 lives in `_pools`; variants 1+ live in `_variant_pools[pool_id]`.
func _get_pool_for_variant(pool_id: StringName, variant_idx: int) -> MultiMeshInstance3D:
	if variant_idx <= 0:
		return _pools.get(pool_id, null)
	var extras: Array = _variant_pools.get(pool_id, [])
	var i: int = variant_idx - 1
	if i < 0 or i >= extras.size():
		return null
	return extras[i]


## Total variant count for a prop (1 = single-variant; N = primary + N-1 extras).
func _get_variant_count(pool_id: StringName) -> int:
	if not _pools.has(pool_id):
		return 0
	var extras: Array = _variant_pools.get(pool_id, [])
	return 1 + extras.size()


## Feature-011: compute a deterministic seed for scatter RNG. Same
## tile + sub_hex + prop_type always produces the same seed → identical
## scatter layout on every reload. Prop type is included so swapping
## one prop for another at the same SH gives a different scatter.
func _compute_scatter_seed(coords: Vector2i, sub_hex: Vector2i, prop_type: StringName) -> int:
	var h: int = 0
	h = h ^ (coords.x * 73856093)
	h = h ^ (coords.y * 19349663)
	h = h ^ (sub_hex.x * 83492791)
	h = h ^ (sub_hex.y * 2654435761)
	h = h ^ hash(prop_type)
	return h & 0x7fffffff


## Feature-011: pick N SSH positions within a sub-hex. Position 0 is
## always ZERO (center). Remaining positions are a seeded-random
## sample of (N-1) SSH cells drawn from the other 18 via Fisher-
## Yates partial shuffle — uniform over all possible subsets, no
## distance-to-ZERO bias. Assumes 1 <= N <= 19.
func _select_ssh_positions(rng: RandomNumberGenerator, n: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i.ZERO]
	if n <= 1:
		return result
	# Build the pool of 18 non-center SSH positions.
	var pool: Array[Vector2i] = []
	for ssh in _HexMath.get_all_sshs():
		if ssh != Vector2i.ZERO:
			pool.append(ssh)
	# Fisher-Yates partial shuffle (seeded) — take the first n-1 items.
	var take: int = mini(n - 1, pool.size())
	for i in range(take):
		var j: int = rng.randi_range(i, pool.size() - 1)
		var tmp: Vector2i = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
		result.append(pool[i])
	return result


func _create_pool(pool_id: StringName, mesh: Mesh, color: Color, is_real_mesh: bool = false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = INITIAL_INSTANCES
	mm.visible_instance_count = 0
	mm.mesh = mesh

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "PropPool_%s" % pool_id
	mmi.custom_aabb = _POOL_CULL_AABB
	_maybe_apply_debug_tint(mmi, pool_id)

	# Real meshes carry their own PBR materials — don't override, let them
	# render natively. Placeholder meshes get a flat unshaded color.
	if not is_real_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mmi.material_override = mat

	add_child(mmi)
	_pools[pool_id] = mmi


## Extract the first Mesh found inside an imported PackedScene (.glb/.gltf/etc).
## The mesh's surface materials come along for free since they're stored in
## the Mesh resource itself.
## Returns [mesh, y_offset] where y_offset is center-to-bottom height derived
## from the mesh's AABB. Returns [null, PROP_Y_OFFSET] if no MeshInstance3D is found.
func _extract_mesh_from_scene(scene: PackedScene) -> Array:
	if scene == null:
		return [null, PROP_Y_OFFSET]
	var root: Node = scene.instantiate()
	if root == null:
		return [null, PROP_Y_OFFSET]
	var mesh_instance: MeshInstance3D = _find_first_mesh_instance(root)
	var mesh: Mesh = null
	var y_offset: float = PROP_Y_OFFSET
	if mesh_instance != null:
		mesh = mesh_instance.mesh
		if mesh != null:
			var aabb: AABB = mesh.get_aabb()
			# Center-to-bottom offset so the prop's anchor sits on the ground.
			y_offset = -aabb.position.y
	root.queue_free()
	return [mesh, y_offset]


## Depth-first search for the first MeshInstance3D in a scene tree.
func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result: MeshInstance3D = _find_first_mesh_instance(child)
		if result != null:
			return result
	return null


# --- Signal wiring ---

func _connect_signals() -> void:
	_connect_grid_signals()
	# Player is a sibling in the World scene, but it may not be wired
	# up by the time the renderer's _ready() runs. Defer to next frame
	# so the scene tree is fully assembled.
	_connect_player_signals.call_deferred()


func _connect_grid_signals() -> void:
	if _grid == null:
		return
	if _grid.has_signal("map_generated"):
		if not _grid.map_generated.is_connected(_on_map_generated):
			_grid.map_generated.connect(_on_map_generated)
	if _grid.has_signal("prop_depleted"):
		if not _grid.prop_depleted.is_connected(_on_prop_depleted):
			_grid.prop_depleted.connect(_on_prop_depleted)
	if _grid.has_signal("prop_respawned"):
		if not _grid.prop_respawned.is_connected(_on_prop_respawned):
			_grid.prop_respawned.connect(_on_prop_respawned)


func _connect_player_signals() -> void:
	if _player == null:
		_player = _find_player()
	if _player == null:
		return
	if _player.has_signal("player_moved"):
		if not _player.player_moved.is_connected(_on_player_moved):
			_player.player_moved.connect(_on_player_moved)
	# Re-anchor to the player's real current_tile now that we have
	# one. The initial map_generated streamed around spawn (or ZERO
	# if spawn wasn't available yet), which could leave the window
	# off-center when the player starts somewhere other than spawn
	# or the player finishes loading position after _ready. Without
	# this, rotating the camera could reveal empty tiles the first
	# stream never touched.
	if "current_tile" in _player:
		_stream_around(_player.current_tile)
		_stream_collision_around(_player.current_tile)


## Set the view-distance radius and restream. Called from main.gd
## after GameSettings loads so the value comes from a single
## authoritative source instead of a hardcoded constant.
func set_stream_radius(radius: int) -> void:
	# 0 is the sentinel for "unlimited — render every tile"; anything
	# negative folds into the same meaning. Clamping to >= 1 would
	# silently disable the unlimited mode the GameSettings field
	# explicitly documents.
	var clamped: int = clampi(radius, 0, 200)
	if clamped == _stream_radius:
		return
	_stream_radius = clamped
	_stream_around(_get_streaming_anchor())


## Update collision streaming radius. 0 disables collision streaming
## entirely (test / debug escape hatch); otherwise clamped to the same
## range the GameSettings field exposes, [3, 30], so engine-side and
## editor-side agree. Unlimited collision would spawn a StaticBody3D
## per scattered prop on every tile, which the PhysicsServer can't
## scale to — there is deliberately no "0 = unlimited" parallel with
## set_stream_radius.
func set_collision_radius(radius: int) -> void:
	var clamped: int
	if radius <= 0:
		clamped = 0
	else:
		clamped = clampi(radius, 3, 30)
	if clamped == _collision_radius:
		return
	_collision_radius = clamped
	_stream_collision_around(_get_streaming_anchor())


## Sibling lookup for the Player node. World.tscn puts Player as a
## direct child of the same parent that hosts this renderer; fall
## back to a tree search if the project layout ever changes.
func _find_player() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var p: Node = parent.get_node_or_null("Player")
	if p != null:
		return p
	# Last-resort: depth-first scan for any node that emits player_moved.
	return _search_node_with_signal(get_tree().get_current_scene(), &"player_moved")


static func _search_node_with_signal(root: Node, sig: StringName) -> Node:
	if root == null:
		return null
	if root.has_signal(sig):
		return root
	for child in root.get_children():
		var found: Node = _search_node_with_signal(child, sig)
		if found != null:
			return found
	return null


# --- Signal handlers ---

func _on_map_generated() -> void:
	# Streaming: only tiles within STREAM_RADIUS of the anchor get
	# materialized. Anchor defaults to spawn because Player may not
	# have a current_tile yet on first map generation; once the
	# player_moved signal fires, _on_player_moved rebases around the
	# real player position.
	# Clear the per-cycle scatter memo so visual + collision share one
	# compute per (coords, sub_hex, type) within this event.
	_scatter_cache.clear()
	var anchor: Vector2i = _get_streaming_anchor()
	_stream_around(anchor)
	_stream_collision_around(anchor)
	# Deferred pool dump — landing in the output a frame later so all
	# instance adds inside _stream_around have settled. Lets Andre see
	# which pools got populated without hunting through the scene tree.
	print_pool_stats.call_deferred()


func _on_player_moved(from: Vector2i, to: Vector2i) -> void:
	# Same-tile re-emissions are filtered upstream by Player, but
	# a defensive guard keeps re-ready scenarios cheap.
	if from == to and _streamed_tiles.size() > 0:
		return
	# Per-cycle memo reset; see _on_map_generated for rationale.
	_scatter_cache.clear()
	_stream_around(to)
	_stream_collision_around(to)


func _on_prop_depleted(coords: Vector2i, prop_type: StringName) -> void:
	_swap_mesh_variant(coords, prop_type, true)


func _on_prop_respawned(coords: Vector2i, prop_type: StringName) -> void:
	_swap_mesh_variant(coords, prop_type, false)


# --- Prop management ---

## Pick the streaming center. Prefers the current player tile; falls
## back to spawn_tile (map-load case) or Vector2i.ZERO.
func _get_streaming_anchor() -> Vector2i:
	if _player != null and "current_tile" in _player:
		return _player.current_tile
	if _grid != null and "spawn_tile" in _grid:
		return _grid.spawn_tile
	return Vector2i.ZERO


## Stream the set of tiles within STREAM_RADIUS of `center` into
## the MultiMesh pools, and evict anything currently streamed that
## falls outside the radius. Uses the existing per-tile add/remove
## plumbing so scatter logic, variants, and dimming all stay
## consistent with the one-shot code path.
func _stream_around(center: Vector2i) -> void:
	if _grid == null:
		return
	var desired: Dictionary = {}
	var ordered: Array[Vector2i] = []
	# Radius 0 (or negative) disables the window — we stream every
	# tile that exists in the grid. Matches Andre's rule: "wherever
	# the map says there's a prop, render it. Always." Performance
	# is expected to come from scatter density + pool capacity
	# tuning, not from culling what the player could otherwise see.
	if _stream_radius <= 0:
		if _grid.has_method("get_all_tiles"):
			for coords in _grid.get_all_tiles():
				desired[coords] = true
				ordered.append(coords)
	elif _grid.has_method("get_tiles_in_range"):
		for coords in _grid.get_tiles_in_range(center, _stream_radius):
			desired[coords] = true
			ordered.append(coords)
	elif _grid.has_method("get_all_tiles"):
		for coords in _grid.get_all_tiles():
			desired[coords] = true
			ordered.append(coords)

	# Near-to-far add order. When a pool hits INITIAL_INSTANCES the
	# overflow gets logged + skipped, so we want the closest tiles
	# to reach the pool first — if any instances get dropped, the
	# casualties are on the far fringe the player can't see up
	# close anyway.
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _HexMath.distance(a, center) < _HexMath.distance(b, center))

	# Evict tiles that left the window. Evict SYNCHRONOUSLY — a tile
	# outside the desired window must stop rendering this frame,
	# otherwise ghost instances trail the player as they move.
	# Also drop any pending-queue entries that no longer qualify.
	for coords in _streamed_tiles.keys():
		if not desired.has(coords):
			_remove_all_props_at(coords)
			_streamed_tiles.erase(coords)
	if not _pending_visual_set.is_empty():
		var next_queue: Array[Vector2i] = []
		for coords in _pending_visual_tiles:
			if desired.has(coords):
				next_queue.append(coords)
			else:
				_pending_visual_set.erase(coords)
		_pending_visual_tiles = next_queue

	# Queue tiles that entered the window (near-to-far order already
	# applied to `ordered`). _process drains the queue a few tiles per
	# frame so a hex cross doesn't burn a whole frame on scatter +
	# instance adds. Already-streamed and already-pending tiles skip.
	for coords in ordered:
		if _streamed_tiles.has(coords):
			continue
		if _pending_visual_set.has(coords):
			continue
		_pending_visual_tiles.append(coords)
		_pending_visual_set[coords] = true


func _add_props_for_tile(coords: Vector2i, dimmed: bool) -> void:
	# Remove existing instances first (re-add with correct state). Skip
	# when nothing is tracked — the O(N*M) _update_instance_index walk
	# inside _remove_all_props_at is wasted work on fresh map loads and
	# the first visit to any tile.
	if _tile_entries.has(coords):
		_remove_all_props_at(coords)

	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	if tile == null:
		return

	for prop in tile.get_props():
		var pool_id: StringName = prop.type
		if not _pools.has(pool_id):
			continue
		var is_depleted: bool = prop.remaining <= 0
		_add_prop_instance(coords, prop, pool_id, dimmed, is_depleted)
	for anomaly in tile.get_anomalies():
		_add_anomaly_instance(coords, tile, anomaly, dimmed)
	# Record that this tile is now visually streamed. Both the normal
	# queue drain (_process) and ad-hoc callers (_rebuild_tile) end up
	# here, so marking inside this function keeps _streamed_tiles in
	# sync regardless of which path ran.
	_streamed_tiles[coords] = true


func _add_anomaly_instance(coords: Vector2i, tile: Resource, anomaly: Resource, dimmed: bool) -> void:
	# Find the anomaly pool by prop type (each PropDef has its own pool)
	var anomaly_pool_id: StringName = anomaly.type
	if not _pools.has(anomaly_pool_id):
		return
	var mmi: MultiMeshInstance3D = _pools[anomaly_pool_id]
	var mm: MultiMesh = mmi.multimesh
	var idx: int = mm.visible_instance_count
	if not _ensure_pool_capacity(mm, idx + 1):
		return

	var world_2d: Vector2 = _HexMath.prop_world_position(coords, anomaly.sub_hex)
	var elevation_y: float = 0.0
	if _grid != null and _grid.has_method("get_terrain_y"):
		elevation_y = _grid.get_terrain_y(world_2d.x, world_2d.y)
	elif tile != null:
		elevation_y = float(tile.elevation) * _HexGrid.ELEVATION_STEP
	# Anomalies use variant 0's scale + y_offset.
	var y_off: float = _pool_y_offsets.get(anomaly_pool_id, PROP_Y_OFFSET)
	var anomaly_scales: Array = _variant_scales.get(anomaly_pool_id, [])
	var anomaly_scale: float = anomaly_scales[0] if anomaly_scales.size() > 0 else 1.0
	var pos := Vector3(world_2d.x, elevation_y + y_off * anomaly_scale, world_2d.y)

	var xform := Transform3D.IDENTITY
	xform = xform.scaled(Vector3.ONE * anomaly_scale)
	xform.origin = pos

	mm.visible_instance_count = idx + 1
	mm.set_instance_transform(idx, xform)
	mm.set_instance_custom_data(idx, Color(1.0 if dimmed else 0.0, 0.0, 0.0, 1.0))
	_update_pool_material(anomaly_pool_id, dimmed)

	if not _tile_entries.has(coords):
		_tile_entries[coords] = []
	_tile_entries[coords].append({
		"prop_type": &"anomaly",
		"pool": anomaly_pool_id,
		"variant": 0,
		"instance_idx": idx,
		"depleted": false,
	})


func _add_prop_instance(coords: Vector2i, rn: Resource, pool_id: StringName, dimmed: bool, depleted: bool) -> void:
	if not _pools.has(pool_id):
		return
	var def: Resource = PropRegistry.get_def(rn.type) if PropRegistry.has_def(rn.type) else null
	var scatter: Array = _compute_prop_scatter(coords, rn, def)
	for s in scatter:
		var variant_idx: int = s["variant_idx"]
		var mmi: MultiMeshInstance3D = _get_pool_for_variant(pool_id, variant_idx)
		if mmi == null:
			continue
		var mm: MultiMesh = mmi.multimesh
		var idx: int = mm.visible_instance_count
		if not _ensure_pool_capacity(mm, idx + 1):
			continue

		var copy_scale: float = s["copy_scale"]
		var rotation_deg: float = s["rotation_deg"]
		var ground_pos: Vector3 = s["ground_position"]
		var y_off: float = s["y_offset"]
		# y_offset scales with copy_scale because the AABB was measured at
		# unit mesh scale.
		var pos := Vector3(ground_pos.x, ground_pos.y + y_off * copy_scale, ground_pos.z)

		var xform := Transform3D.IDENTITY
		xform = xform.scaled(Vector3.ONE * copy_scale)
		xform.basis = xform.basis.rotated(Vector3.UP, deg_to_rad(rotation_deg))
		xform.origin = pos

		mm.visible_instance_count = idx + 1
		mm.set_instance_transform(idx, xform)
		var custom := Color(1.0 if dimmed else 0.0, 1.0 if depleted else 0.0, 0.0, 1.0)
		mm.set_instance_custom_data(idx, custom)
		_update_pool_material(pool_id, dimmed)

		if not _tile_entries.has(coords):
			_tile_entries[coords] = []
		_tile_entries[coords].append({
			"prop_type": rn.type,
			"pool": pool_id,
			"variant": variant_idx,
			"instance_idx": idx,
			"depleted": depleted,
			# Added for feature-011 — group scattered siblings under the
			# same authored sub_hex so _swap_mesh_variant / depletion can
			# affect all copies of the same logical prop.
			"sub_hex": rn.sub_hex,
			"is_center": s["is_center"],
		})


## Compute the deterministic scatter layout for a single prop on a tile.
## Returns an Array of per-copy dicts:
##   {
##     variant_idx: int,
##     copy_scale: float,         # final scale (jitter × sibling × floor applied)
##     rotation_deg: float,
##     ground_position: Vector3,  # (wx, elevation_y, wz) — no y_offset applied
##     y_offset: float,           # pre-scale y_off from the variant
##     is_center: bool,
##   }
##
## Used by BOTH the visual MultiMesh emit path AND the collision body
## emit path, so both paths see an identical scatter — any desync here
## would put StaticBody3Ds where there are no meshes (or vice versa).
## Reason this had to be extracted: the seeded RNG is consumed in a
## specific order (count jitter → ssh Fisher-Yates → per-copy variant →
## per-copy scale_jitter → per-copy rotation), and replicating that
## order in two places is a desync waiting to happen.
func _compute_prop_scatter(coords: Vector2i, rn: Resource, def: Resource) -> Array:
	# Per-stream memo lookup — same (coords, sub_hex, prop_type) inside
	# the same _stream_*_around cycle reuses the first-computed Array
	# instead of recomputing (~30 µs saved per hit).
	var cache_key := "%d,%d:%d,%d:%s" % [
		coords.x, coords.y, rn.sub_hex.x, rn.sub_hex.y, String(rn.type)
	]
	if _scatter_cache.has(cache_key):
		return _scatter_cache[cache_key]

	var out: Array = []

	# Resolve scatter preset from PlaceableCap.placement (feature-011):
	# Effective placement = Prop.placement_override, then
	# PropDef.placeable.placement, then SINGLE (default). Ignore overrides
	# for non-SINGLE presets — the spec says per-instance variant / scale
	# / rotation overrides only apply when the preset resolves to SINGLE,
	# because distributing copies with a pinned center breaks the
	# visual illusion.
	var effective_placement: int = _PlacementPreset.Preset.SINGLE
	if rn.placement_override >= 0:
		effective_placement = rn.placement_override
	elif def != null and def.placeable != null:
		effective_placement = def.placeable.placement
	var preset_count: int = _PlacementPreset.get_count(effective_placement)
	var sibling_scale: float = _PlacementPreset.get_sibling_scale(effective_placement)
	var supports_overrides: bool = _PlacementPreset.supports_instance_overrides(effective_placement)

	# Seeded RNG: deterministic per (tile, sub_hex, prop_type). Same
	# prop in the same cell of the same map always produces identical
	# scatter across reloads, AND the visual + collision paths produce
	# identical results when they both call _compute_prop_scatter.
	var rng := RandomNumberGenerator.new()
	rng.seed = _compute_scatter_seed(coords, rn.sub_hex, rn.type)

	# Actual instance count with ±2 jitter, clamped to [1, 19].
	var actual_count: int = preset_count
	if preset_count > 1:
		actual_count = clampi(preset_count + rng.randi_range(-2, 2), 1, 19)

	# SSH positions: center (0) plus (actual_count - 1) chosen from the
	# remaining 18 via seeded Fisher-Yates partial shuffle.
	var ssh_positions: Array[Vector2i] = _select_ssh_positions(rng, actual_count)

	# Shared tile/elevation context.
	var pool_id: StringName = rn.type
	var world_2d: Vector2 = _HexMath.axial_to_world(coords)
	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	var sub_hex_offset: Vector2 = _HexMath.sub_axial_to_world(rn.sub_hex)
	var center_wx: float = world_2d.x + sub_hex_offset.x
	var center_wz: float = world_2d.y + sub_hex_offset.y
	var variant_count: int = _get_variant_count(pool_id)

	for i in ssh_positions.size():
		var ssh: Vector2i = ssh_positions[i]
		var is_center: bool = (i == 0)

		# Variant: SINGLE + override → pin. Otherwise seeded random.
		var variant_idx: int
		if is_center and supports_overrides and rn.has_variant_override():
			variant_idx = clampi(rn.variant_override, 0, max(variant_count - 1, 0))
		else:
			variant_idx = rng.randi_range(0, max(variant_count - 1, 0))

		var variant_offsets: Array = _variant_y_offsets.get(pool_id, [])
		var y_off: float = variant_offsets[variant_idx] if variant_idx < variant_offsets.size() else _pool_y_offsets.get(pool_id, PROP_Y_OFFSET)
		var variant_scales_arr: Array = _variant_scales.get(pool_id, [])
		var variant_scale: float = variant_scales_arr[variant_idx] if variant_idx < variant_scales_arr.size() else 1.0

		# Per-copy scale: jitter CONSUMED from RNG even when overridden,
		# because the override branch must not shift the per-copy rotation
		# RNG call below.
		var scale_jitter: float = rng.randf_range(0.85, 1.15)
		var copy_scale: float
		if is_center and supports_overrides and rn.has_scale_override():
			copy_scale = rn.scale_override
		else:
			copy_scale = variant_scale * scale_jitter
			if not is_center:
				copy_scale *= sibling_scale
			# Floor to keep tiny authored scales from falling below the
			# GPU's sub-pixel threshold at mid-range camera distance.
			# Author overrides skip the floor so "explicitly tiny" still
			# works for pinned instances.
			if copy_scale < MIN_RENDER_SCALE:
				copy_scale = MIN_RENDER_SCALE

		# Rotation:
		#  - SINGLE center + explicit rotation_override ≥ 0 → override
		#  - SINGLE center without override → authored rotation_deg
		#    (0.0 = face north, which IS an intentional value).
		#  - Scatter siblings / non-center / non-SINGLE → 0-360° seeded.
		var rotation_deg: float
		if is_center and supports_overrides and rn.has_rotation_override():
			rotation_deg = rn.rotation_override
		elif is_center and supports_overrides:
			rotation_deg = rn.rotation_deg
		else:
			rotation_deg = rng.randf() * 360.0

		# Position: tile + sub_hex_offset + ssh_offset; center is ZERO.
		var ssh_offset: Vector2 = Vector2.ZERO
		if ssh != Vector2i.ZERO:
			ssh_offset = _HexMath.ssh_axial_to_world(ssh.x, ssh.y)
		var wx: float = center_wx + ssh_offset.x
		var wz: float = center_wz + ssh_offset.y
		var elevation_y: float = 0.0
		if _grid != null and _grid.has_method("get_terrain_y"):
			elevation_y = _grid.get_terrain_y(wx, wz)
		elif tile != null:
			elevation_y = float(tile.elevation) * _HexGrid.ELEVATION_STEP

		out.append({
			"variant_idx": variant_idx,
			"copy_scale": copy_scale,
			"rotation_deg": rotation_deg,
			"ground_position": Vector3(wx, elevation_y, wz),
			"y_offset": y_off,
			"is_center": is_center,
		})
	_scatter_cache[cache_key] = out
	return out


func _remove_all_props_at(coords: Vector2i) -> void:
	# Always free collision bodies first — independent of whether
	# _tile_entries has a visual record (a tile could be in the
	# collision window but outside the render window, e.g. with a
	# positive prop_stream_radius smaller than prop_collision_radius).
	_free_collision_bodies_at(coords)
	if not _tile_entries.has(coords):
		return
	while _tile_entries.has(coords) and not _tile_entries[coords].is_empty():
		var entries_list: Array = _tile_entries[coords]
		var info: Dictionary = entries_list[entries_list.size() - 1]
		var variant_idx: int = info.get("variant", 0)
		_hide_instance(info.pool, variant_idx, info.instance_idx)
		entries_list.remove_at(entries_list.size() - 1)
	_tile_entries.erase(coords)


func _hide_instance(pool_id: StringName, variant_idx: int, instance_idx: int) -> void:
	var mmi: MultiMeshInstance3D = _get_pool_for_variant(pool_id, variant_idx)
	if mmi == null:
		return
	var mm: MultiMesh = mmi.multimesh
	if instance_idx >= mm.visible_instance_count:
		return
	var last_idx: int = mm.visible_instance_count - 1
	if instance_idx != last_idx:
		var last_xform: Transform3D = mm.get_instance_transform(last_idx)
		var last_custom: Color = mm.get_instance_custom_data(last_idx)
		mm.set_instance_transform(instance_idx, last_xform)
		mm.set_instance_custom_data(instance_idx, last_custom)
		_update_instance_index(pool_id, variant_idx, last_idx, instance_idx)
	mm.visible_instance_count = last_idx


func _update_instance_index(pool_id: StringName, variant_idx: int, old_idx: int, new_idx: int) -> void:
	for coords in _tile_entries:
		var entries_list: Array = _tile_entries[coords]
		for info in entries_list:
			if info.pool == pool_id and info.get("variant", 0) == variant_idx and info.instance_idx == old_idx:
				info.instance_idx = new_idx
				return


func _swap_mesh_variant(coords: Vector2i, prop_type: StringName, to_depleted: bool) -> void:
	if not _tile_entries.has(coords):
		return
	for info in _tile_entries[coords]:
		if info.prop_type == prop_type:
			info.depleted = to_depleted
			# Re-render tile to show swapped mesh
			_rebuild_tile(coords)
			return


func _rebuild_tile(coords: Vector2i) -> void:
	# Determine current fog state
	var tile: Resource = _grid.get_tile(coords) if _grid != null else null
	if tile == null:
		return
	var dimmed: bool = false
	_remove_all_props_at(coords)
	for prop in tile.get_props():
		var pool_id: StringName = prop.type
		if not _pools.has(pool_id):
			continue
		var is_depleted: bool = prop.remaining <= 0
		_add_prop_instance(coords, prop, pool_id, dimmed, is_depleted)
	# Rebuild collision if the tile sits inside the current collision window.
	if _is_in_collision_range(coords):
		_build_collision_for_tile(coords)


# --- Collision streaming ---------------------------------------------------

## True iff the given tile falls inside the current collision window
## around the streaming anchor. `_collision_radius == 0` disables
## collision streaming entirely.
func _is_in_collision_range(coords: Vector2i) -> bool:
	if _collision_radius <= 0:
		return false
	var center: Vector2i = _get_streaming_anchor()
	return _HexMath.distance(coords, center) <= _collision_radius


## Drop collision bodies on tiles that left the collision window;
## queue bodies on tiles that entered. Visual streaming is untouched.
## Eviction is synchronous (stale bodies would collide after the
## player moved on); building is amortized across frames by
## _process().
func _stream_collision_around(center: Vector2i) -> void:
	if _grid == null:
		return
	var desired: Dictionary = {}
	if _collision_radius > 0 and _grid.has_method("get_tiles_in_range"):
		for coords in _grid.get_tiles_in_range(center, _collision_radius):
			desired[coords] = true
	# Evict tiles that left the window (synchronous).
	for coords in _collision_bodies.keys():
		if not desired.has(coords):
			_free_collision_bodies_at(coords)
	# Drop pending-queue entries that no longer qualify.
	if not _pending_collision_set.is_empty():
		var next_queue: Array[Vector2i] = []
		for coords in _pending_collision_tiles:
			if desired.has(coords):
				next_queue.append(coords)
			else:
				_pending_collision_set.erase(coords)
		_pending_collision_tiles = next_queue
	# Queue tiles that entered the window. Near-to-far sort so the
	# player doesn't phase through the closest props while the queue
	# drains from the far fringe inward.
	var to_add: Array[Vector2i] = []
	for coords in desired.keys():
		if _collision_bodies.has(coords):
			continue
		if _pending_collision_set.has(coords):
			continue
		to_add.append(coords)
	to_add.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _HexMath.distance(a, center) < _HexMath.distance(b, center))
	for coords in to_add:
		_pending_collision_tiles.append(coords)
		_pending_collision_set[coords] = true


## Emit StaticBody3D + CollisionShape3D children for every scattered
## natural prop copy on the given tile whose effective shape dimensions
## pass CollisionHelper.MIN_COLLISION_DIM. Called from the collision
## stream path (player moved / radius changed / tile rebuilt).
func _build_collision_for_tile(coords: Vector2i) -> void:
	if _grid == null:
		return
	var tile: Resource = _grid.get_tile(coords)
	if tile == null:
		return
	var bodies: Array = []
	for prop in tile.get_props():
		var def: Resource = PropRegistry.get_def(prop.type) if PropRegistry.has_def(prop.type) else null
		if def == null or def.placeable == null:
			continue
		var shapes: Array = def.placeable.collision_shapes
		if shapes == null or shapes.is_empty():
			continue  # walkthrough prop — skip scatter compute entirely
		var scatter: Array = _compute_prop_scatter(coords, prop, def)
		for i in scatter.size():
			var s: Dictionary = scatter[i]
			var copy_scale: float = s["copy_scale"]
			var collision_nodes: Array[CollisionShape3D] = _CollisionHelper.create_scaled_collision_shapes(def, copy_scale)
			if collision_nodes.is_empty():
				continue  # all shapes below threshold at this scale
			var body := StaticBody3D.new()
			# Use the loop index (stable, unique) rather than scatter.find(s),
			# which was both O(N²) and aliased on duplicate-valued dicts.
			body.name = "PropCollision_%s_%d_%d_%d" % [
				String(prop.type), prop.sub_hex.x, prop.sub_hex.y, i
			]
			var ground: Vector3 = s["ground_position"]
			var y_off: float = s["y_offset"]
			# Mirror the visual's y_off * copy_scale lift so collision
			# geometry sits at the same anchor as the MultiMesh instance.
			# Authored CollisionShape offsets are in mesh-local coords; if
			# a mesh is modeled with its origin at center instead of bottom,
			# skipping this lift would bury the shape under the terrain.
			body.position = Vector3(ground.x, ground.y + y_off * copy_scale, ground.z)
			body.rotation.y = deg_to_rad(s["rotation_deg"])
			for cs_node in collision_nodes:
				body.add_child(cs_node)
			_get_collision_root().add_child(body)
			bodies.append(body)
	if not bodies.is_empty():
		_collision_bodies[coords] = bodies


func _free_collision_bodies_at(coords: Vector2i) -> void:
	if not _collision_bodies.has(coords):
		return
	for body in _collision_bodies[coords]:
		if is_instance_valid(body):
			body.queue_free()
	_collision_bodies.erase(coords)


## Lazy-initialize the container node. Keeping bodies under one parent
## (instead of directly under PropRenderer) makes scene-tree inspection
## cleaner and avoids mixing physics + MMI children.
func _get_collision_root() -> Node3D:
	if _collision_root == null or not is_instance_valid(_collision_root):
		_collision_root = Node3D.new()
		_collision_root.name = "PropCollisionBodies"
		add_child(_collision_root)
	return _collision_root


func _update_pool_material(pool_id: StringName, _dimmed: bool) -> void:
	# Material always uses full color. Darkness handled by shader.
	if not _pools.has(pool_id):
		return
	var mmi: MultiMeshInstance3D = _pools[pool_id]
	var mat: StandardMaterial3D = mmi.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = _pool_colors.get(pool_id, Color.WHITE)


# --- Public API (for testing) ---

func get_pool_visible_count(pool_id) -> int:
	# Accept both StringName and int for backward compatibility with tests
	if pool_id is int:
		var keys: Array = _pools.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return 0
		pool_id = keys[pool_id]
	if not _pools.has(pool_id):
		return 0
	# Sum visible instances across the primary pool and all variant pools.
	var total: int = _pools[pool_id].multimesh.visible_instance_count
	var extras: Array = _variant_pools.get(pool_id, [])
	for mmi: MultiMeshInstance3D in extras:
		if mmi != null:
			total += mmi.multimesh.visible_instance_count
	return total


func get_tile_entries() -> Dictionary:
	return _tile_entries


func get_pool_count() -> int:
	return _pools.size()


func get_pool_mesh(pool_id) -> Mesh:
	if pool_id is int:
		var keys: Array = _pools.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return null
		return _pools[keys[pool_id]].multimesh.mesh
	if not _pools.has(pool_id):
		return null
	return _pools[pool_id].multimesh.mesh


func get_normal_mesh(pool_id) -> Mesh:
	if pool_id is int:
		var keys: Array = _normal_meshes.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return null
		return _normal_meshes[keys[pool_id]]
	return _normal_meshes.get(pool_id, null)


func get_depleted_mesh(pool_id) -> Mesh:
	if pool_id is int:
		var keys: Array = _depleted_meshes.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return null
		return _depleted_meshes[keys[pool_id]]
	return _depleted_meshes.get(pool_id, null)


func get_pool_material_color(pool_id) -> Color:
	if pool_id is int:
		var keys: Array = _pools.keys()
		if pool_id < 0 or pool_id >= keys.size():
			return Color.BLACK
		pool_id = keys[pool_id]
	if not _pools.has(pool_id):
		return Color.BLACK
	var mat: StandardMaterial3D = _pools[pool_id].material_override as StandardMaterial3D
	if mat == null:
		return Color.BLACK
	return mat.albedo_color
