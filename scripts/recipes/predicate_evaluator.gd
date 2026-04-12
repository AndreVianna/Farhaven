class_name PredicateEvaluator
extends RefCounted

## Single source of truth for evaluating condition predicates.
## Dispatches on pred.kind to handler functions.
## Used by Recipe matching (gate), pending recipe ticking (sustain),
## and DiscoveryWatcher (unlock evaluation).

const _PropDef = preload("res://scripts/data/prop_def.gd")
const _HexTile = preload("res://scripts/hex/hex_tile.gd")


## Evaluate a single predicate against a world context. Returns true if satisfied.
static func evaluate(pred: Predicate, ctx: WorldContext) -> bool:
	match pred.kind:
		&"has_tool":
			return _eval_has_tool(pred.params, ctx)
		&"at_station":
			return _eval_at_station(pred.params, ctx)
		&"at_tile_type":
			return _eval_at_tile_type(pred.params, ctx)
		&"player_stat":
			return _eval_player_stat(pred.params, ctx)
		&"player_skill":
			return _eval_player_skill(pred.params, ctx)
		&"player_knows_recipe":
			return _eval_player_knows_recipe(pred.params, ctx)
		&"time_of_day":
			return _eval_time_of_day(pred.params, ctx)
		&"weather":
			return _eval_weather(pred.params, ctx)
		&"biome":
			return _eval_biome(pred.params, ctx)
		&"adjacent_to":
			return _eval_adjacent_to(pred.params, ctx)
		&"prop_state":
			return _eval_prop_state(pred.params, ctx)
		&"world_flag":
			return _eval_world_flag(pred.params, ctx)
		&"animal_nearby":
			return _eval_animal_nearby(pred.params, ctx)
		&"container_has":
			return _eval_container_has(pred.params, ctx)
		&"cataloged":
			return _eval_cataloged(pred.params, ctx)
		_:
			push_warning("PredicateEvaluator: unknown predicate kind '%s' — returning false" % pred.kind)
			return false


# ---------------------------------------------------------------------------
# Handler implementations
# ---------------------------------------------------------------------------


## has_tool — params: {tool: StringName}
## Check if the player has a tool with matching tool_slot or matching PropDef id equipped.
static func _eval_has_tool(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.player == null:
		push_warning("PredicateEvaluator: 'has_tool' — ctx.player is null, returning false")
		return false
	var tool_id: StringName = StringName(params.get("tool", &""))
	if tool_id == &"":
		return false
	var inv = _get_inventory(ctx.player)
	if inv == null:
		push_warning("PredicateEvaluator: 'has_tool' — player has no inventory, returning false")
		return false
	# Check each tool slot: the equipped tool's PropDef might have tool_slot == tool_id,
	# or the equipped tool's PropDef id itself matches tool_id.
	for slot: StringName in [&"axe", &"pickaxe", &"weapon", &"scanner"]:
		var equipped: StringName = inv.get_tool(slot)
		if equipped == &"":
			continue
		# Direct id match
		if equipped == tool_id:
			return true
		# tool_slot match (e.g. tool_id = "axe", PropDef.tool_slot = "axe")
		if slot == tool_id:
			return true
		# Check PropDef.tool_slot in case the equipped prop has a matching slot name
		var def: _PropDef = ctx.prop_registry.get_def(equipped) if ctx.prop_registry != null else null
		if def != null and def.tool_slot == tool_id:
			return true
	return false


## at_station — params: {tag: StringName}
## Check if ctx.station is non-null AND its PropDef has a StationCap with the given tag.
static func _eval_at_station(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.station == null:
		return false
	var tag: StringName = StringName(params.get("tag", &""))
	if tag == &"":
		return false
	# station is a Prop instance; look up its PropDef via ctx.prop_registry.
	var station_type: StringName = ctx.station.type if "type" in ctx.station else &""
	if station_type == &"":
		return false
	var def: _PropDef = ctx.prop_registry.get_def(station_type) if ctx.prop_registry != null else null
	if def == null or def.station == null:
		return false
	return def.station.station_tags.has(tag)


## at_tile_type — params: {tag: StringName}
## Check ctx.tile.biome matches or has a matching tag.
## Special case: "buildable" means tile is not water (passable for building).
static func _eval_at_tile_type(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.tile == null:
		return false
	var tag: StringName = StringName(params.get("tag", &""))
	if tag == &"":
		return false
	# Special "buildable" check: tile is not water (building-eligible).
	if String(tag).to_lower() == "buildable":
		return ctx.tile.biome != _HexTile.Biome.WATER
	# Match against biome enum name (case-insensitive comparison).
	var biome_name: String = _biome_to_string(ctx.tile.biome).to_lower()
	if String(tag).to_lower() == biome_name:
		return true
	return false


## player_stat — params: {stat: StringName, op: StringName, value: float}
## Query player stats (hp, hunger, thirst) via SurvivalSystem child.
static func _eval_player_stat(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.player == null:
		push_warning("PredicateEvaluator: 'player_stat' — ctx.player is null, returning false")
		return false
	var stat_name: StringName = StringName(params.get("stat", &""))
	var op: StringName = StringName(params.get("op", &""))
	var target_value: float = float(params.get("value", 0.0))
	var survival: Node = _get_survival_system(ctx.player)
	if survival == null:
		push_warning("PredicateEvaluator: 'player_stat' — SurvivalSystem not found, returning false")
		return false
	var current_value: float = 0.0
	match stat_name:
		&"hp", &"health":
			current_value = survival.hp
		&"hunger":
			current_value = survival.hunger
		&"thirst":
			current_value = survival.thirst
		_:
			push_warning("PredicateEvaluator: 'player_stat' — unknown stat '%s', returning false" % stat_name)
			return false
	return _compare(current_value, op, target_value)


## player_skill — STUB (skill system doesn't exist yet).
static func _eval_player_skill(params: Dictionary, _ctx: WorldContext) -> bool:
	push_error("PredicateEvaluator: 'player_skill' predicate not yet implemented — should not be called in current data")
	return false


## player_knows_recipe — STUB for now: return true.
## DiscoveryWatcher (task-050) will implement proper known-recipe checks.
static func _eval_player_knows_recipe(params: Dictionary, _ctx: WorldContext) -> bool:
	# Stub: always return true until DiscoveryWatcher is implemented.
	return true


## time_of_day — params: {phase: StringName}
## Check DayNightCycle.current_phase matches the given phase string.
static func _eval_time_of_day(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.day_night == null:
		push_warning("PredicateEvaluator: 'time_of_day' — ctx.day_night is null, returning false")
		return false
	var phase_str: String = String(params.get("phase", "")).to_upper()
	var current_phase: int = ctx.day_night.current_phase
	# Map phase string to DayNightCycle.TimePhase enum values (0=DAY,1=DUSK,2=NIGHT,3=DAWN).
	var expected_phase: int = -1
	match phase_str:
		"DAY":
			expected_phase = 0  # TimePhase.DAY
		"DUSK":
			expected_phase = 1  # TimePhase.DUSK
		"NIGHT":
			expected_phase = 2  # TimePhase.NIGHT
		"DAWN":
			expected_phase = 3  # TimePhase.DAWN
		_:
			push_warning("PredicateEvaluator: 'time_of_day' — unknown phase '%s', returning false" % phase_str)
			return false
	return current_phase == expected_phase


## weather — STUB (weather system doesn't exist yet).
static func _eval_weather(params: Dictionary, _ctx: WorldContext) -> bool:
	push_error("PredicateEvaluator: 'weather' predicate not yet implemented — should not be called in current data")
	return false


## biome — params: {tag: StringName}
## Check ctx.tile.biome enum name matches the tag.
static func _eval_biome(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.tile == null:
		return false
	var tag: StringName = StringName(params.get("tag", &""))
	if tag == &"":
		return false
	var biome_name: String = _biome_to_string(ctx.tile.biome).to_lower()
	return String(tag).to_lower() == biome_name


## adjacent_to — params: {tag: StringName, count_ge: int}
## Check neighboring tiles via ctx.grid for matching props or tile types.
static func _eval_adjacent_to(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.tile == null or ctx.grid == null:
		return false
	var tag: StringName = StringName(params.get("tag", &""))
	var count_ge: int = int(params.get("count_ge", 1))
	if tag == &"":
		return false
	var neighbors: Array = ctx.grid.get_neighbors(ctx.tile.coords)
	var match_count: int = 0
	for neighbor_coords: Vector2i in neighbors:
		var neighbor_tile = ctx.grid.get_tile(neighbor_coords)
		if neighbor_tile == null:
			continue
		# Check if neighbor tile biome matches
		if _biome_to_string(neighbor_tile.biome).to_lower() == String(tag).to_lower():
			match_count += 1
			if match_count >= count_ge:
				return true
			continue
		# Check if any prop on the neighbor tile has a matching tag or type
		for prop in neighbor_tile.props:
			var prop_type: StringName = prop.type if "type" in prop else &""
			if prop_type == tag:
				match_count += 1
				if match_count >= count_ge:
					return true
				break  # One match per tile is enough
			# Check PropDef tags
			var def: _PropDef = ctx.prop_registry.get_def(prop_type) if ctx.prop_registry != null else null
			if def != null and def.has_tag(tag):
				match_count += 1
				if match_count >= count_ge:
					return true
				break
	return false


## prop_state — params: {prop: StringName, field: StringName, op: StringName, value: Variant}
## Check a specific prop instance's field value.
## Used by cook_meat to check fireplace.is_lit.
static func _eval_prop_state(params: Dictionary, ctx: WorldContext) -> bool:
	var prop_type: StringName = StringName(params.get("prop", &""))
	var field_name: StringName = StringName(params.get("field", &""))
	var op: StringName = StringName(params.get("op", &"eq"))
	var target_value: Variant = params.get("value", null)
	if prop_type == &"" or field_name == &"":
		return false
	# Search for the prop instance on ctx.station, ctx.tile props
	var prop_instance: Resource = _find_prop_instance(prop_type, ctx)
	if prop_instance == null:
		return false
	# Read the field from the prop instance
	if not (field_name in prop_instance):
		push_warning("PredicateEvaluator: 'prop_state' — prop '%s' has no field '%s'" % [prop_type, field_name])
		return false
	var current_value: Variant = prop_instance.get(field_name)
	# For bool/Variant comparisons with eq/ne
	if op == &"eq":
		return _values_equal(current_value, target_value)
	elif op == &"ne":
		return not _values_equal(current_value, target_value)
	# For numeric comparisons
	return _compare(float(current_value), op, float(target_value))


## world_flag — params: {name: StringName, value: Variant}
## Check ctx.world_flags dictionary.
static func _eval_world_flag(params: Dictionary, ctx: WorldContext) -> bool:
	var flag_name: StringName = StringName(params.get("name", &""))
	var expected_value: Variant = params.get("value", true)
	if flag_name == &"":
		return false
	if not ctx.world_flags.has(flag_name):
		return false
	return _values_equal(ctx.world_flags[flag_name], expected_value)


## animal_nearby — STUB (FaunaManager doesn't exist yet).
static func _eval_animal_nearby(params: Dictionary, _ctx: WorldContext) -> bool:
	push_error("PredicateEvaluator: 'animal_nearby' predicate not yet implemented — should not be called in current data")
	return false


## container_has — params: {ref_or_tag: StringName, count_ge: int}
## Check if ctx.container (or ctx.station's container capability) has enough matching props.
static func _eval_container_has(params: Dictionary, ctx: WorldContext) -> bool:
	var ref_or_tag: StringName = StringName(params.get("ref_or_tag", &""))
	var count_ge: int = int(params.get("count_ge", 1))
	if ref_or_tag == &"":
		return false
	# Find the container: either ctx.container directly, or look up station's ContainerCap
	var container_props: Array = _get_container_contents(ctx)
	if container_props.is_empty():
		return false
	var match_count: int = 0
	for item in container_props:
		var item_type: StringName = &""
		if item is Dictionary:
			item_type = StringName(item.get("type", &""))
			match_count += _count_matches(item_type, ref_or_tag, int(item.get("quantity", 1)), ctx.prop_registry)
		elif "type" in item:
			item_type = item.type
			match_count += _count_matches(item_type, ref_or_tag, 1, ctx.prop_registry)
		if match_count >= count_ge:
			return true
	return false


## cataloged — params: {prop: StringName}
## Check ctx.catalog.is_cataloged(prop).
static func _eval_cataloged(params: Dictionary, ctx: WorldContext) -> bool:
	if ctx.catalog == null:
		return false
	var prop_id: StringName = StringName(params.get("prop", &""))
	if prop_id == &"":
		return false
	if ctx.catalog.has_method("is_cataloged"):
		return ctx.catalog.is_cataloged(prop_id)
	return false


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


## Retrieve the inventory from a player node.
static func _get_inventory(player: Node):
	if player.has_method("get_inventory"):
		return player.get_inventory()
	if "inventory" in player:
		return player.inventory
	return null


## Find the SurvivalSystem child node on the player.
static func _get_survival_system(player: Node) -> Node:
	for child in player.get_children():
		if "hp" in child and "hunger" in child and "thirst" in child:
			return child
	return null


## Compare two numeric values with the given operator.
static func _compare(current: float, op: StringName, target: float) -> bool:
	match op:
		&"eq": return is_equal_approx(current, target)
		&"ne": return not is_equal_approx(current, target)
		&"gt": return current > target
		&"ge": return current >= target
		&"lt": return current < target
		&"le": return current <= target
		_:
			push_warning("PredicateEvaluator: unknown comparison op '%s'" % op)
			return false


## Compare two Variant values for equality (handles bool, int, float, StringName, String).
static func _values_equal(a: Variant, b: Variant) -> bool:
	# Handle bool comparisons specially: "true"/"false" strings match bools
	if a is bool or b is bool:
		return _to_bool(a) == _to_bool(b)
	if a is float or b is float:
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)


## Convert a Variant to bool (handles string "true"/"false", ints, bools).
static func _to_bool(v: Variant) -> bool:
	if v is bool:
		return v
	if v is String or v is StringName:
		return String(v).to_lower() == "true"
	return bool(v)


## Convert HexTile.Biome enum to string name.
static func _biome_to_string(biome: int) -> String:
	# HexTile.Biome: 0=CRASH_SITE, 1=GRASSLAND, 2=FOREST, 3=ROCKY, 4=WATER
	match biome:
		0: return "CRASH_SITE"
		1: return "GRASSLAND"
		2: return "FOREST"
		3: return "ROCKY"
		4: return "WATER"
		_: return "UNKNOWN"


## Find a prop instance of the given type on ctx.station or ctx.tile.
static func _find_prop_instance(prop_type: StringName, ctx: WorldContext) -> Resource:
	# Check station first (most common for prop_state)
	if ctx.station != null:
		var st_type: StringName = ctx.station.type if "type" in ctx.station else &""
		if st_type == prop_type:
			return ctx.station
	# Check tile props
	if ctx.tile != null:
		for prop in ctx.tile.props:
			var pt: StringName = prop.type if "type" in prop else &""
			if pt == prop_type:
				return prop
	return null


## Get the contents of the container in scope.
## Looks at ctx.container first, then falls back to station's container_items if available.
static func _get_container_contents(ctx: WorldContext) -> Array:
	# If ctx.container has a container_items array or similar, use it
	if ctx.container != null:
		if "container_items" in ctx.container:
			return ctx.container.container_items
		if "props" in ctx.container:
			return ctx.container.props
	# Fall back to station's container if station has container items
	if ctx.station != null:
		if "container_items" in ctx.station:
			return ctx.station.container_items
		# Check if station type has ContainerCap but items are on the station itself
		if "props" in ctx.station:
			return ctx.station.props
	return []


## Count how many of an item match a ref or tag.
static func _count_matches(item_type: StringName, ref_or_tag: StringName, quantity: int, prop_reg: Node = null) -> int:
	if item_type == &"":
		return 0
	# Direct ref match
	if item_type == ref_or_tag:
		return quantity
	# Tag match: look up PropDef and check tags
	var def: _PropDef = prop_reg.get_def(item_type) if prop_reg != null else null
	if def != null and def.has_tag(ref_or_tag):
		return quantity
	return 0
