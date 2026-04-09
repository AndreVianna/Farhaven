class_name TestWorldContext
extends GdUnitTestSuite

const _WorldContext = preload("res://scripts/recipes/world_context.gd")


# --- Default construction ---

func test_new_context_has_null_player() -> void:
	var ctx := _WorldContext.new()
	assert_object(ctx.player).is_null()


func test_new_context_has_null_tile() -> void:
	var ctx := _WorldContext.new()
	assert_object(ctx.tile).is_null()


func test_new_context_has_null_station() -> void:
	var ctx := _WorldContext.new()
	assert_object(ctx.station).is_null()


func test_new_context_has_null_container() -> void:
	var ctx := _WorldContext.new()
	assert_object(ctx.container).is_null()


func test_new_context_has_empty_world_flags() -> void:
	var ctx := _WorldContext.new()
	assert_int(ctx.world_flags.size()).is_equal(0)


func test_new_context_has_null_catalog() -> void:
	var ctx := _WorldContext.new()
	assert_object(ctx.catalog).is_null()


# --- Static factory ---

func test_create_returns_world_context_instance() -> void:
	var ctx := _WorldContext.create()
	assert_bool(ctx is _WorldContext).is_true()


func test_create_with_null_args_has_null_fields() -> void:
	var ctx := _WorldContext.create(null, null, null)
	assert_object(ctx.player).is_null()
	assert_object(ctx.tile).is_null()
	assert_object(ctx.station).is_null()


func test_create_sets_player() -> void:
	var player := Node.new()
	var ctx := _WorldContext.create(player)
	assert_object(ctx.player).is_same(player)
	player.free()


func test_create_sets_tile() -> void:
	var tile := Resource.new()
	var ctx := _WorldContext.create(null, tile)
	assert_object(ctx.tile).is_same(tile)


func test_create_sets_station() -> void:
	var station := Resource.new()
	var ctx := _WorldContext.create(null, null, station)
	assert_object(ctx.station).is_same(station)


# --- Manual field assignment ---

func test_world_flags_can_be_set() -> void:
	var ctx := _WorldContext.new()
	ctx.world_flags["quest_done"] = true
	assert_bool(ctx.world_flags.has("quest_done")).is_true()
	assert_bool(ctx.world_flags["quest_done"]).is_true()


func test_container_can_be_assigned() -> void:
	var container := Resource.new()
	var ctx := _WorldContext.new()
	ctx.container = container
	assert_object(ctx.container).is_same(container)


func test_catalog_can_be_assigned() -> void:
	var catalog := RefCounted.new()
	var ctx := _WorldContext.new()
	ctx.catalog = catalog
	assert_object(ctx.catalog).is_same(catalog)


func test_grid_can_be_assigned() -> void:
	var grid := Node.new()
	var ctx := _WorldContext.new()
	ctx.grid = grid
	assert_object(ctx.grid).is_same(grid)
	grid.free()


func test_day_night_can_be_assigned() -> void:
	var dn := Node.new()
	var ctx := _WorldContext.new()
	ctx.day_night = dn
	assert_object(ctx.day_night).is_same(dn)
	dn.free()
