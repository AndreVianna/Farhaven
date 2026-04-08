class_name WorldContext
extends RefCounted

## Lightweight data bag for predicate evaluation.
## Callers construct with whatever subset of world state they have available.
## Fields left null are fine — individual predicates guard against nil access.

## Player node (for inventory, equipped tool, stats via SurvivalSystem child).
var player: Node = null

## Current HexTile the action is happening on.
var tile: Resource = null

## Current station prop (Prop instance on the tile acting as station), if any.
var station: Resource = null

## Container prop being interacted with (Prop instance with ContainerCap).
var container: Resource = null

## HexGrid autoload ref (for neighbor queries, tile lookups).
var grid: Node = null

## DayNightCycle autoload ref (for time_of_day predicates).
var day_night: Node = null

## Catalog instance (for cataloged predicates).
var catalog: RefCounted = null

## Named world flags (e.g. {"completed_quest_alpha": true}).
var world_flags: Dictionary = {}


## Factory that auto-fills grid/day_night from autoloads.
## Pass null for any parameter you don't have.
static func create(p_player: Node = null, p_tile: Resource = null, p_station: Resource = null) -> WorldContext:
	var ctx := WorldContext.new()
	ctx.player = p_player
	ctx.tile = p_tile
	ctx.station = p_station
	# Auto-fill autoloads — safe even in headless/test (returns null if missing).
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		ctx.grid = tree.root.get_node_or_null("HexGrid")
		ctx.day_night = tree.root.get_node_or_null("DayNightCycle")
	return ctx
