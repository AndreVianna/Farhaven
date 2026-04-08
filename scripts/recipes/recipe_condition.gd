class_name RecipeCondition
extends Resource

## The predicate that must be satisfied.
@export var predicate: Predicate

## If true, the predicate is re-checked every tick during recipe execution
## and the recipe cancels if it becomes false. If false, checked only at start.
@export var must_sustain: bool = false
