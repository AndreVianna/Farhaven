class_name Recipe
extends ScriptBase

## Inputs consumed when the recipe resolves (Array of RecipeInput).
@export var inputs: Array[Resource] = []

## Outputs produced when the recipe resolves (Array of RecipeOutput).
## Each rolls independently against its prob field.
@export var outputs: Array[Resource] = []
