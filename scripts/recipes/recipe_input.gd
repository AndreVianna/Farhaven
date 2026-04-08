class_name RecipeInput
extends Resource

## Prop ref (PropDef id, e.g. &"00020") or tag (e.g. &"BURNABLE.log").
## Whether this is a ref or tag is determined by is_tag.
@export var ref_or_tag: StringName

## How many of the prop are consumed.
@export var count: int = 1

## Where the input is drawn from:
## &"player_inventory" (default), &"container", &"world_tile", &"world_anywhere".
@export var source: StringName = &"player_inventory"

## True if ref_or_tag is a tag (fungible match), false if exact prop ref.
@export var is_tag: bool = false
