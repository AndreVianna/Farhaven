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

## Pending build info: recipe_id → {coords, sub_hex}.
## Tracks where each in-flight build recipe should place its output.
var _pending_builds: Dictionary = {}


func _ready() -> void:
	if _grid == null:
		_grid = _get_autoload(&"HexGrid")
	if _runtime == null:
		_runtime = _get_autoload(&"RecipeRuntime")
	_connect_runtime()


func _connect_runtime() -> void:
	if _runtime != null:
		if not _runtime.is_connected("recipe_resolved", _on_recipe_resolved):
			_runtime.recipe_resolved.connect(_on_recipe_resolved)


## Enter placement mode with a build recipe.
func enter_placement_mode(recipe: _Recipe) -> void:
	_selected_recipe = recipe
	placement_mode_entered.emit(recipe.id)


## Exit placement mode without building.
func exit_placement_mode() -> void:
	_selected_recipe = null
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

	# Validate sub-hex footprint availability (no overlapping props).
	var output_type: StringName = _get_output_prop_type()
	var footprint: Array[Vector2i] = _get_footprint(output_type, sub_hex)
	if _has_footprint_overlap(tile, footprint):
		structure_build_failed.emit(&"footprint_overlap")
		exit_placement_mode()
		return false

	# Store build info BEFORE calling try_start_recipe so the resolve
	# callback can find it even for instant (time=0) recipes.
	var recipe_id: StringName = _selected_recipe.id
	_pending_builds[recipe_id] = {
		"coords": coords,
		"sub_hex": sub_hex,
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

		# Compute footprint at the target sub-hex position.
		var fp: Array[Vector2i] = []
		if def.placeable != null and not def.placeable.footprint.is_empty():
			for offset: Vector2i in def.placeable.footprint:
				fp.append(sub_hex + offset)
		else:
			fp.append(sub_hex)

		# Place structure prop on tile.
		var tile: Resource = _grid.get_tile(coords)
		if tile != null:
			var blocks: bool = def.placeable.blocks_movement if def.placeable != null else false
			var structure: _Prop = _Prop.create_structure(prop_ref, blocks, sub_hex, fp)
			structure.origin = _Prop.Origin.CRAFTED
			tile.props.append(structure)
			_grid.structure_placed.emit(coords, prop_ref)

			# Storage Chest effect: increase inventory capacity_weight.
			if prop_ref == &"00104" and player != null:
				var inv = _get_player_inventory(player)
				if inv != null:
					inv.capacity_weight += 50.0


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


func _get_footprint(prop_type: StringName, anchor: Vector2i) -> Array[Vector2i]:
	var def = PropRegistry.get_def(prop_type)
	if def != null and def.placeable != null and not def.placeable.footprint.is_empty():
		var result: Array[Vector2i] = []
		for offset: Vector2i in def.placeable.footprint:
			result.append(anchor + offset)
		return result
	return [anchor]


func _has_footprint_overlap(tile: Resource, footprint: Array[Vector2i]) -> bool:
	for prop in tile.props:
		# Check if any existing prop's sub-hex overlaps with our footprint.
		var existing_fp: Array[Vector2i] = []
		if prop.footprint.size() > 0:
			existing_fp = prop.footprint
		else:
			existing_fp = [prop.sub_hex]
		for existing_pos: Vector2i in existing_fp:
			if footprint.has(existing_pos):
				return true
	return false


func _get_player_inventory(player: Node):
	if player.has_method("get_inventory"):
		return player.get_inventory()
	if "inventory" in player:
		return player.inventory
	return null


func _get_autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null(NodePath(p_name))
	return null
