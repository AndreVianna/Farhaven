class_name RecipeOutput
extends Resource

## PropDef id of the produced prop (e.g. &"00010" for wood).
@export var prop_ref: StringName

## How many are produced on success.
@export var count: int = 1

## Independent probability of this output being produced (0.0–1.0).
@export var prob: float = 1.0
