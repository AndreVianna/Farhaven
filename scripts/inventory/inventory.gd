class_name Inventory
extends RefCounted

## Inventory data layer — owned by Player, not in scene tree.
## Manages prop/consumable slots and 4 fixed tool slots.

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

## Tool slots store PropDef ids (numeric, e.g. &"00204" for survival_knife).
var _tool_slots: Dictionary = {
	&"axe":      &"",
	&"pickaxe":  &"",
	&"weapon":   &"00204",  # survival_knife
	&"scanner":  &"00205",  # scanner
}


func _init() -> void:
	_slots.resize(_base_slots)
	for i in _base_slots:
		_slots[i] = { "type": &"", "quantity": 0 }


# --- Resource/Consumable API ---

func add_item(type: StringName, amount: int = 1) -> int:
	var def: PropDef = PropRegistry.get_def(type)
	if def == null:
		return 0
	if def.tool_slot != &"":
		# Tools must use set_tool — reject from prop slots
		return 0
	var max_stack: int = def.max_stack
	var remaining: int = amount

	# Fill partial stacks first
	for slot in _slots:
		if remaining <= 0:
			break
		if slot["type"] == type and slot["quantity"] < max_stack:
			var space: int = max_stack - slot["quantity"]
			var to_add: int = mini(space, remaining)
			slot["quantity"] += to_add
			remaining -= to_add

	# Fill empty slots
	for slot in _slots:
		if remaining <= 0:
			break
		if slot["type"] == &"":
			var to_add: int = mini(max_stack, remaining)
			slot["type"] = type
			slot["quantity"] = to_add
			remaining -= to_add

	var added: int = amount - remaining
	if added > 0:
		item_added.emit(type, added)
		inventory_changed.emit()
	if remaining > 0:
		inventory_full.emit(type, remaining)
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
	for slot in _slots:
		if slot["type"] == &"":
			return false
		# Check for partial stack using PropDef.max_stack
		var def: PropDef = PropRegistry.get_def(slot["type"])
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
		"tools": tools_data,
		"slots": slots_data,
	}


func load_save_data(data: Dictionary) -> void:
	_bonus_slots = data.get("bonus_slots", 0)
	var total: int = _base_slots + _bonus_slots
	_slots.clear()
	_slots.resize(total)
	for i in total:
		_slots[i] = { "type": &"", "quantity": 0 }

	var slots_data: Array = data.get("slots", [])
	for i in mini(slots_data.size(), total):
		var entry: Dictionary = slots_data[i]
		_slots[i]["type"] = StringName(entry.get("type", ""))
		_slots[i]["quantity"] = entry.get("quantity", 0)

	var tools_data: Dictionary = data.get("tools", {})
	for key in tools_data:
		_tool_slots[StringName(key)] = StringName(tools_data[key])
