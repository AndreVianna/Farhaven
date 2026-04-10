class_name Inventory
extends RefCounted

## Inventory data layer — owned by Player, not in scene tree.
## Manages prop/consumable slots and 4 fixed tool slots.
## Weight-based capacity: each item has a weight from its PORTABLE capability.
## Items are still stored in slots with max_stack limits, but the primary
## constraint for add/remove is weight, not slot count.
## Uses preload because tests can be parsed before class_name registration completes.

const _PropDef = preload("res://scripts/data/prop_def.gd")

signal inventory_changed()
signal item_added(type: StringName, amount: int)
signal item_removed(type: StringName, amount: int)
signal inventory_full(type: StringName, rejected: int)
signal item_used(type: StringName)
signal tool_changed(slot: StringName, new_tool: StringName, old_tool: StringName)

## All items (gathered resources, consumables, tools) are PropDefs loaded by
## PropRegistry from data/props/*.tres. No hardcoded item configuration.

var _slots: Array[Dictionary]
var _base_slots: int = 12
var _bonus_slots: int = 0

## Weight-based capacity (primary constraint).
var capacity_weight: float = 50.0
var _current_weight: float = 0.0

## Tool slots store PropDef ids (prefixed, e.g. &"P00204" for survival_knife).
## Defaults are empty — starting tools are applied from map's starting_loadout.
var _tool_slots: Dictionary = {
	&"axe":      &"",
	&"pickaxe":  &"",
	&"weapon":   &"",
	&"scanner":  &"",
}


func _init() -> void:
	_slots.resize(_base_slots)
	for i in _base_slots:
		_slots[i] = { "type": &"", "quantity": 0 }


# --- Weight helpers ---

## Get the weight of one unit of a prop type.
## Items without PORTABLE capability default to 1.0 for backward compat.
func _get_item_weight(type: StringName) -> float:
	var def: _PropDef = PropRegistry.get_def(type)
	if def != null and def.portable != null:
		return def.portable.size
	return 1.0


## Returns the current total weight of all items in the inventory.
func get_current_weight() -> float:
	return _current_weight


## Returns the maximum weight capacity.
func get_capacity_weight() -> float:
	return capacity_weight


## Returns remaining weight capacity.
func get_remaining_capacity() -> float:
	return capacity_weight - _current_weight


## Returns a display string like "32.5 / 50.0".
func get_weight_display() -> String:
	return "%.1f / %.1f" % [_current_weight, capacity_weight]


## Returns items grouped by type with count and total weight per stack.
func get_stacks() -> Array[Dictionary]:
	var stacks: Dictionary = {}
	for slot in _slots:
		if slot["type"] == &"":
			continue
		var t: StringName = slot["type"]
		if stacks.has(t):
			stacks[t]["count"] += slot["quantity"]
		else:
			stacks[t] = { "type": t, "count": slot["quantity"] }
	var result: Array[Dictionary] = []
	for key in stacks:
		var entry: Dictionary = stacks[key]
		var w: float = _get_item_weight(entry["type"])
		entry["weight_per_unit"] = w
		entry["total_weight"] = w * entry["count"]
		result.append(entry)
	return result


## Recompute _current_weight from slot contents. Used after load.
func _recompute_weight() -> void:
	_current_weight = 0.0
	for slot in _slots:
		if slot["type"] != &"":
			_current_weight += _get_item_weight(slot["type"]) * slot["quantity"]


# --- Resource/Consumable API ---

func add_item(type: StringName, amount: int = 1) -> int:
	var def: _PropDef = PropRegistry.get_def(type)
	if def == null:
		return 0
	if def.tool_slot != &"":
		# Tools must use set_tool — reject from prop slots
		return 0

	var unit_weight: float = _get_item_weight(type)

	# Reject entirely if a single unit exceeds total capacity
	if unit_weight > capacity_weight:
		inventory_full.emit(type, amount)
		return 0

	# Determine how many we can fit by weight
	var max_by_weight: int
	if unit_weight <= 0.0:
		max_by_weight = amount
	else:
		max_by_weight = int(floor((capacity_weight - _current_weight) / unit_weight))

	if max_by_weight <= 0:
		inventory_full.emit(type, amount)
		return 0

	# Respect both weight limit and slot availability
	var to_add: int = mini(amount, max_by_weight)
	var max_stack: int = def.max_stack
	var remaining: int = to_add

	# Fill partial stacks first
	for slot in _slots:
		if remaining <= 0:
			break
		if slot["type"] == type and slot["quantity"] < max_stack:
			var space: int = max_stack - slot["quantity"]
			var chunk: int = mini(space, remaining)
			slot["quantity"] += chunk
			remaining -= chunk

	# Fill empty slots
	for slot in _slots:
		if remaining <= 0:
			break
		if slot["type"] == &"":
			var chunk: int = mini(max_stack, remaining)
			slot["type"] = type
			slot["quantity"] = chunk
			remaining -= chunk

	var added: int = to_add - remaining
	if added > 0:
		_current_weight += unit_weight * added
		item_added.emit(type, added)
		inventory_changed.emit()
	var rejected: int = amount - added
	if rejected > 0:
		inventory_full.emit(type, rejected)
	return added


func remove_item(type: StringName, amount: int = 1) -> int:
	var remaining: int = amount
	# Reverse-order to minimize fragmentation
	for i in range(_slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: Dictionary = _slots[i]
		if slot["type"] == type:
			var to_remove: int = mini(slot["quantity"], remaining)
			slot["quantity"] -= to_remove
			remaining -= to_remove
			if slot["quantity"] == 0:
				slot["type"] = &""

	var removed: int = amount - remaining
	if removed > 0:
		_current_weight -= _get_item_weight(type) * removed
		# Guard against floating-point drift below zero
		if _current_weight < 0.0:
			_current_weight = 0.0
		item_removed.emit(type, removed)
		inventory_changed.emit()
	return removed


func has_item(type: StringName, amount: int = 1) -> bool:
	return get_count(type) >= amount


func get_count(type: StringName) -> int:
	var total: int = 0
	for slot in _slots:
		if slot["type"] == type:
			total += slot["quantity"]
	return total


func get_slots() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for slot in _slots:
		copy.append(slot.duplicate())
	return copy


func is_full() -> bool:
	# Weight-based: full if remaining capacity is less than the smallest
	# possible item weight. Use a small epsilon to account for float drift.
	if _current_weight >= capacity_weight:
		return true
	# Also full if no slot space remains (all occupied and at max_stack)
	for slot in _slots:
		if slot["type"] == &"":
			return false
		var def: _PropDef = PropRegistry.get_def(slot["type"])
		if def != null and slot["quantity"] < def.max_stack:
			return false
	return true


func get_max_slots() -> int:
	return _base_slots + _bonus_slots


func get_used_slot_count() -> int:
	var count: int = 0
	for slot in _slots:
		if slot["type"] != &"":
			count += 1
	return count


func use_item(type: StringName) -> bool:
	if not has_item(type):
		return false
	remove_item(type, 1)  # remove_item already emits inventory_changed
	item_used.emit(type)
	return true


func expand(additional_slots: int) -> void:
	_bonus_slots += additional_slots
	for i in additional_slots:
		_slots.append({ "type": &"", "quantity": 0 })
	inventory_changed.emit()


# --- Tool API ---

func get_tool(slot: StringName) -> StringName:
	return _tool_slots.get(slot, &"")


func set_tool(slot: StringName, tool: StringName) -> StringName:
	var old: StringName = _tool_slots.get(slot, &"")
	_tool_slots[slot] = tool
	tool_changed.emit(slot, tool, old)
	inventory_changed.emit()
	return old


func has_tool_for(slot: StringName) -> bool:
	return _tool_slots.get(slot, &"") != &""


# --- Save / Load ---

func get_save_data() -> Dictionary:
	var slots_data: Array = []
	for slot in _slots:
		slots_data.append({ "type": str(slot["type"]), "quantity": slot["quantity"] })
	var tools_data: Dictionary = {}
	for key in _tool_slots:
		tools_data[str(key)] = str(_tool_slots[key])
	return {
		"bonus_slots": _bonus_slots,
		"capacity_weight": capacity_weight,
		"tools": tools_data,
		"slots": slots_data,
	}


func load_save_data(data: Dictionary) -> void:
	_bonus_slots = int(data.get("bonus_slots", 0))
	capacity_weight = float(data.get("capacity_weight", 50.0))
	var slots_data: Array = data.get("slots", [])
	var total: int = _base_slots + _bonus_slots

	# Preserve all saved slots even if bonus_slots was missing or smaller than
	# the slots array — expand capacity to avoid silent data loss.
	if slots_data.size() > total:
		push_warning(
			"Inventory.load_save_data: saved %d slots but total is %d — expanding capacity" \
				% [slots_data.size(), total]
		)
		total = slots_data.size()
		_bonus_slots = total - _base_slots

	_slots.clear()
	_slots.resize(total)
	for i in total:
		_slots[i] = { "type": &"", "quantity": 0 }

	for i in mini(slots_data.size(), total):
		var entry: Dictionary = slots_data[i]
		_slots[i]["type"] = StringName(entry.get("type", ""))
		_slots[i]["quantity"] = int(entry.get("quantity", 0))

	var tools_data: Dictionary = data.get("tools", {})
	for key in tools_data:
		_tool_slots[StringName(key)] = StringName(tools_data[key])

	# Recompute weight from loaded inventory contents
	_recompute_weight()
