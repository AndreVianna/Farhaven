class_name RecipeInput
extends Resource

## Reference to a prop or tag.
## - Prop ID: e.g. "P00020" — exact match
## - Tag: e.g. "&BURNABLE" or "&BURNABLE.log" — prefix "&" marks it as a tag
##   (fungible match against any prop carrying the tag)
@export var ref: String = ""

## How many of the prop are consumed.
@export var count: int = 1

## True: input must be in player's inventory (player must "hold" it).
## False: input can be in the world, accessible to the player (within reach).
@export var must_hold: bool = false


## Returns true if `ref` references a tag (starts with "&") rather than a prop ID.
func is_tag() -> bool:
	return ref.begins_with("&")


## Returns the tag name without the "&" prefix, or empty string if not a tag.
func get_tag() -> StringName:
	if is_tag():
		return StringName(ref.substr(1))
	return &""
