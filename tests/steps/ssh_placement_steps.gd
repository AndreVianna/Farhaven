extends RefCounted

## Step definitions for SSH grid placement feature.
## Tests snap_to_ssh math and multi-structure coexistence on a tile.
## Uses HexMath directly (no autoload dependency).

const _HexMath = preload("res://scripts/hex/hex_math.gd")


func register_steps(registry) -> void:
	# --- Given ---
	registry.given("a tile at {int}, {int}", func(ctx, col: int, row: int):
		var tile_coords := Vector2i(col, row)
		ctx.set_value("tile_coords", tile_coords)
		ctx.set_value("tile_structures", [])
	)

	# --- When ---
	registry.when("a structure is placed at world position near an SSH center", func(ctx):
		var tile_coords: Vector2i = ctx.get_value("tile_coords", Vector2i.ZERO)
		# Pick a world position slightly offset from tile center (simulates imprecise placement)
		var tile_world: Vector2 = _HexMath.axial_to_world(tile_coords)
		var offset := Vector2(0.05, 0.03)  # small offset to test snapping
		var requested_pos: Vector2 = tile_world + offset
		var snap_result: Dictionary = _HexMath.snap_to_ssh(requested_pos, tile_coords)
		ctx.set_value("requested_pos", requested_pos)
		ctx.set_value("snapped_pos", snap_result["snapped_world"])
		ctx.set_value("snap_result", snap_result)
	)

	registry.when("a campfire is placed at SSH {int}, {int}", func(ctx, sq: int, sr: int):
		var tile_coords: Vector2i = ctx.get_value("tile_coords", Vector2i.ZERO)
		var structures: Array = ctx.get_value("tile_structures", [])
		var ssh_coords := Vector2i(sq, sr)
		var world_pos: Vector2 = _HexMath.full_position_to_world(tile_coords, Vector2i.ZERO, ssh_coords)
		structures.append({
			"type": "P00101",
			"name": "campfire",
			"ssh": ssh_coords,
			"world_pos": world_pos,
		})
		ctx.set_value("tile_structures", structures)
	)

	registry.when("a torch is placed at SSH {int}, {int}", func(ctx, sq: int, sr: int):
		var tile_coords: Vector2i = ctx.get_value("tile_coords", Vector2i.ZERO)
		var structures: Array = ctx.get_value("tile_structures", [])
		var ssh_coords := Vector2i(sq, sr)
		var world_pos: Vector2 = _HexMath.full_position_to_world(tile_coords, Vector2i.ZERO, ssh_coords)
		structures.append({
			"type": "P00102",
			"name": "torch",
			"ssh": ssh_coords,
			"world_pos": world_pos,
		})
		ctx.set_value("tile_structures", structures)
	)

	# --- Then ---
	registry.then("the structure position is snapped to the nearest SSH center", func(ctx):
		var snap_result: Dictionary = ctx.get_value("snap_result", {})
		ctx.assert_false(snap_result.is_empty(), "Expected snap result to exist")
		# Verify snapped position is a valid SSH within the sub-hex
		var ssh: Vector2i = snap_result.get("ssh", Vector2i(-99, -99))
		ctx.assert_true(_HexMath.is_valid_ssh(ssh),
			"Snapped SSH coords %s must be within valid range (radius 2)" % str(ssh))
	)

	registry.then("the position is within 0.16m of the requested position", func(ctx):
		var requested: Vector2 = ctx.get_value("requested_pos", Vector2.ZERO)
		var snapped: Vector2 = ctx.get_value("snapped_pos", Vector2.ZERO)
		var dist: float = requested.distance_to(snapped)
		# SSH_SIZE is ~0.16m, so max snap distance should be within one SSH diameter
		ctx.assert_less_or_equal(dist, _HexMath.SSH_SIZE,
			"Snap distance %.4f exceeds SSH_SIZE %.4f" % [dist, _HexMath.SSH_SIZE])
	)

	registry.then("both structures exist on the tile", func(ctx):
		var structures: Array = ctx.get_value("tile_structures", [])
		ctx.assert_equal(structures.size(), 2,
			"Expected 2 structures on tile, got %d" % structures.size())
		# Verify they are at different SSH positions
		var ssh_0: Vector2i = structures[0].get("ssh", Vector2i.ZERO)
		var ssh_1: Vector2i = structures[1].get("ssh", Vector2i.ZERO)
		ctx.assert_not_equal(ssh_0, ssh_1,
			"Expected structures at different SSH positions, both at %s" % str(ssh_0))
	)
