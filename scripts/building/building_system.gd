extends Node

## Thin UX wrapper for structure placement. Manages placement mode and
## delegates material consumption + structure creation to RecipeRuntime.
## Node child of Player.

const _Recipe = preload("res://scripts/recipes/recipe.gd")
const _RecipeRuntime = preload("res://scripts/recipes/recipe_runtime.gd")
const _WorldContext = preload("res://scripts/recipes/world_context.gd")
const _Prop = preload("res://scripts/hex/prop.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")
const _Inventory = preload("res://scripts/inventory/inventory.gd")
const _CollisionHelper = preload("res://scripts/core/collision_helper.gd")
const _HexMath = preload("res://scripts/hex/hex_math.gd")

## Emitted when a build attempt fails validation before reaching RecipeRuntime.
signal structure_build_failed(reason: StringName)
## Emitted when entering placement mode.
signal placement_mode_entered(recipe_id: StringName)
## Emitted when exiting placement mode.
signal placement_mode_exited()

## The currently selected build recipe (null when not placing).
var _selected_recipe: _Recipe = null

## Injectable dependencies for testing.
var _grid: Node = null
var _runtime: Node = null
## Injectable renderer reference for highlights (scene node, not autoload).
var _renderer: Node = null
## Injectable HUD reference for placement label.
var _hud: Node = null

## Pending build info: recipe_id → {coords, sub_hex}.
## Tracks where each in-flight build recipe should place its output.
var _pending_builds: Dictionary = {}


func _ready() -> void:
	if _grid == null:
		_grid = _get_autoload(&"HexGrid")
	if _runtime == null:
		_runtime = _get_autoload(&"RecipeRuntime")
	if _renderer == null:
		_renderer = _find_renderer()
	if _hud == null:
		_hud = _find_hud()
	_connect_runtime()
	_connect_tile_entered()
	# Use lowest process_priority so _unhandled_input runs first during placement.
	process_priority = -100


func _connect_runtime() -> void:
	if _runtime != null:
		if not _runtime.is_connected("recipe_resolved", _on_recipe_resolved):
			_runtime.recipe_resolved.connect(_on_recipe_resolved)


func _connect_tile_entered() -> void:
	if _grid != null and _grid.has_signal("tile_entered"):
		if not _grid.is_connected("tile_entered", _on_tile_entered):
			_grid.tile_entered.connect(_on_tile_entered)


## Enter placement mode with a build recipe.
func enter_placement_mode(recipe: _Recipe) -> void:
	_selected_recipe = recipe
	placement_mode_entered.emit(recipe.id)
	_update_highlights()
	_show_placement_label(recipe)


## Exit placement mode without building.
func exit_placement_mode() -> void:
	_selected_recipe = null
	_clear_highlights()
	_hide_placement_label()
	placement_mode_exited.emit()


## Returns true if the system is currently in placement mode.
func is_placing() -> bool:
	return _selected_recipe != null


## Returns the currently selected build recipe, or null.
func get_selected_recipe() -> _Recipe:
	return _selected_recipe


## Attempt to place a structure at the given tile coordinates.
## Returns true if the recipe was successfully started, false on validation failure.
func try_place_at(coords: Vector2i, sub_hex: Vector2i = Vector2i.ZERO) -> bool:
	if _selected_recipe == null:
		structure_build_failed.emit(&"no_recipe_selected")
		return false

	if _grid == null:
		structure_build_failed.emit(&"no_grid")
		return false

	var tile: Resource = _grid.get_tile(coords)
	if tile == null:
		structure_build_failed.emit(&"invalid_tile")
		exit_placement_mode()
		return false

	# Validate tile is not water.
	if tile.biome == _HexTile.Biome.WATER:
		structure_build_failed.emit(&"water_tile")
		exit_placement_mode()
		return false

	# Validate sub-hex occupancy (no overlapping props at same sub-hex).
	if _has_sub_hex_overlap(tile, sub_hex):
		structure_build_failed.emit(&"sub_hex_occupied")
		exit_placement_mode()
		return false

	# Snap placement to nearest SSH center for 32cm precision.
	var world_pos: Vector2 = _HexMath.prop_world_position(coords, sub_hex)
	var ssh_result: Dictionary = _HexMath.snap_to_ssh(world_pos, coords)
	var snapped_sub_hex: Vector2i = ssh_result["sub_hex"]
	var snapped_ssh: Vector2i = ssh_result["ssh"]

	# Store build info BEFORE calling try_start_recipe so the resolve
	# callback can find it even for instant (time=0) recipes.
	var recipe_id: StringName = _selected_recipe.id
	_pending_builds[recipe_id] = {
		"coords": coords,
		"sub_hex": snapped_sub_hex,
		"ssh": snapped_ssh,
	}

	# Build WorldContext with the target tile.
	var player: Node = get_parent()
	var ctx := _WorldContext.new()
	ctx.player = player
	ctx.tile = tile
	if _grid != null:
		ctx.grid = _grid

	# Delegate to RecipeRuntime for material validation and consumption.
	if _runtime == null:
		_pending_builds.erase(recipe_id)
		structure_build_failed.emit(&"no_runtime")
		exit_placement_mode()
		return false

	var pending = _runtime.try_start_recipe(_selected_recipe, ctx)
	if pending == null:
		_pending_builds.erase(recipe_id)
		structure_build_failed.emit(&"recipe_failed")
		exit_placement_mode()
		return false

	exit_placement_mode()
	return true


## Called when RecipeRuntime resolves a recipe. Places output structure on tile.
func _on_recipe_resolved(recipe_id: StringName, outputs: Array, _effects: Array) -> void:
	# Only handle recipes we have pending build info for.
	if not _pending_builds.has(recipe_id):
		return

	var build_info: Dictionary = _pending_builds[recipe_id]
	_pending_builds.erase(recipe_id)

	var coords: Vector2i = build_info["coords"]
	var sub_hex: Vector2i = build_info["sub_hex"]
	var ssh: Vector2i = build_info.get("ssh", Vector2i.ZERO)

	if _grid == null:
		return

	var player: Node = get_parent()

	for output: Dictionary in outputs:
		var prop_ref: StringName = StringName(output.get("prop_ref", ""))
		if prop_ref == &"":
			continue

		# Check if output is a placeable structure.
		var def = PropRegistry.get_def(prop_ref)
		if def == null:
			continue
		if def.placeable == null:
			continue
		if not def.has_tag(&"STRUCTURE"):
			continue

		# Remove the structure from player inventory (RecipeRuntime delivered it there).
		if player != null:
			var inv = _get_player_inventory(player)
			if inv != null and inv.has_item(prop_ref, 1):
				inv.remove_item(prop_ref, 1)

		# Place structure prop on tile at SSH-snapped position.
		var tile: Resource = _grid.get_tile(coords)
		if tile != null:
			var structure: _Prop = _Prop.create_structure(prop_ref, sub_hex)
			structure.origin = _Prop.Origin.CRAFTED
			tile.props.append(structure)
			_grid.structure_placed.emit(coords, prop_ref)

			# Storage Chest effect: increase inventory capacity_weight.
			if prop_ref == &"P00104" and player != null:
				var inv = _get_player_inventory(player)
				if inv != null:
					inv.capacity_weight += 50.0


# ---------------------------------------------------------------------------
# Input handling — claims all taps during placement mode
# ---------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if _selected_recipe == null:
		return
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	# Claim the input so it doesn't fall through to scanner/movement.
	get_viewport().set_input_as_handled()
	# Convert screen position to tile coords.
	var coords: Vector2i = _screen_to_axial(touch.position)
	if _is_valid_placement_tile(coords):
		try_place_at(coords, Vector2i.ZERO)
	else:
		# Tap on non-valid tile → cancel placement, no materials consumed.
		exit_placement_mode()


func _screen_to_axial(screen_pos: Vector2) -> Vector2i:
	var camera: Camera3D = _find_camera()
	if camera == null:
		return Vector2i.ZERO
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	if abs(ray_dir.y) < 0.0001:
		return Vector2i.ZERO
	var t: float = -ray_origin.y / ray_dir.y
	var world_3d: Vector3 = ray_origin + ray_dir * t
	if _grid != null and _grid.has_method("world_to_axial"):
		return _grid.world_to_axial(Vector2(world_3d.x, world_3d.z))
	return Vector2i.ZERO


func _find_camera() -> Camera3D:
	# Walk up to World, then find Camera3D sibling.
	var player: Node = get_parent()
	if player == null:
		return null
	var world: Node = player.get_parent()
	if world == null:
		return null
	return world.get_node_or_null("Camera3D") as Camera3D


# ---------------------------------------------------------------------------
# Highlight management
# ---------------------------------------------------------------------------


## Recalculate and display highlights for valid adjacent placement tiles.
func _update_highlights() -> void:
	if _selected_recipe == null:
		return
	var valid_tiles: Array[Vector2i] = get_valid_placement_tiles()
	if _renderer != null and _renderer.has_method("highlight_tiles"):
		_renderer.highlight_tiles(valid_tiles, Color.CYAN)


## Clear all placement highlights.
func _clear_highlights() -> void:
	if _renderer != null and _renderer.has_method("clear_highlights"):
		_renderer.clear_highlights()


## Called when the player enters a new tile — recalculate highlights if placing.
func _on_tile_entered(_coords: Vector2i) -> void:
	if _selected_recipe != null:
		_update_highlights()


## Returns the list of valid tiles for placement (adjacent to player, passable,
## not water).
func get_valid_placement_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _grid == null:
		return result
	var player: Node = get_parent()
	if player == null or not ("current_tile" in player):
		return result
	var player_coords: Vector2i = player.current_tile
	var neighbors: Array[Vector2i] = _grid.get_neighbors(player_coords)
	for n: Vector2i in neighbors:
		if _is_valid_placement_tile(n):
			result.append(n)
	return result


## Check if a tile is valid for placement: exists, passable, not water.
func _is_valid_placement_tile(coords: Vector2i) -> bool:
	if _grid == null:
		return false
	var player: Node = get_parent()
	if player == null or not ("current_tile" in player):
		return false
	# Must be adjacent to player.
	var player_coords: Vector2i = player.current_tile
	var neighbors: Array[Vector2i] = _grid.get_neighbors(player_coords)
	if not neighbors.has(coords):
		return false
	var tile: Resource = _grid.get_tile(coords)
	if tile == null:
		return false
	# Not water.
	if tile.biome == _HexTile.Biome.WATER:
		return false
	# Must be passable from player tile (walkable terrain).
	if _grid.has_method("get_traversal"):
		var traversal: int = _grid.get_traversal(player_coords, coords)
		if traversal == 3:  # BLOCKED
			return false
	return true


# ---------------------------------------------------------------------------
# HUD placement label
# ---------------------------------------------------------------------------


func _show_placement_label(recipe: _Recipe) -> void:
	if _hud != null and _hud.has_method("show_placement_label"):
		var output_type: StringName = _get_recipe_output_type(recipe)
		_hud.show_placement_label(output_type)


func _hide_placement_label() -> void:
	if _hud != null and _hud.has_method("hide_placement_label"):
		_hud.hide_placement_label()


func _get_recipe_output_type(recipe: _Recipe) -> StringName:
	if recipe == null:
		return &""
	for output in recipe.outputs:
		if output.prop_ref != &"":
			return output.prop_ref
	return &""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _get_output_prop_type() -> StringName:
	if _selected_recipe == null:
		return &""
	for output in _selected_recipe.outputs:
		if output.prop_ref != &"":
			return output.prop_ref
	return &""


func _has_sub_hex_overlap(tile: Resource, sub_hex: Vector2i) -> bool:
	for prop in tile.props:
		if prop.sub_hex == sub_hex:
			return true
	return false


## Physics-based overlap check using an Area3D query.
## Returns true if placing the prop at world_pos would overlap existing structures.
## TODO: Full implementation when visual testing is possible. Currently falls back
## to footprint check if physics world is unavailable (headless/test mode).
func _has_collision_overlap(prop_def: Resource, world_pos: Vector3) -> bool:
	# Attempt physics overlap query via direct space state.
	var space_state: PhysicsDirectSpaceState3D = _get_space_state()
	if space_state == null:
		return false  # Fallback: footprint check handles this case

	var collision_shape: CollisionShape3D = _CollisionHelper.create_collision_shape(prop_def)
	if collision_shape.shape == null:
		return false

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(Basis.IDENTITY, world_pos)
	query.collision_mask = 1  # Default layer

	var results: Array[Dictionary] = space_state.intersect_shape(query, 1)
	return results.size() > 0


func _get_space_state() -> PhysicsDirectSpaceState3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var viewport: Viewport = tree.root
	var world_3d: World3D = viewport.find_world_3d()
	if world_3d == null:
		return null
	return world_3d.direct_space_state


func _get_player_inventory(player: Node):
	if player.has_method("get_inventory"):
		return player.get_inventory()
	if "inventory" in player:
		return player.inventory
	return null


func _find_renderer() -> Node:
	# HexGridRenderer is a scene node at World/HexGridRenderer.
	var player: Node = get_parent()
	if player == null:
		return null
	var world: Node = player.get_parent()
	if world == null:
		return null
	return world.get_node_or_null("HexGridRenderer")


func _find_hud() -> Node:
	# HUD is at Main/HUD/HUD.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Main/HUD/HUD")


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
