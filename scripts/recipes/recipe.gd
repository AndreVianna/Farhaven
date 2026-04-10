class_name Recipe
extends ScriptBase

## Declarative classification for UI grouping and runtime filtering.
enum Kind { ASSEMBLE, TRANSFORM, BREAKDOWN, COMBINE }

## Recipe kind — Assemble, Transform, Breakdown, or Combine.
@export var kind: Kind = Kind.ASSEMBLE

## Inputs consumed when the recipe resolves (Array of RecipeInput).
@export var inputs: Array[Resource] = []

## Outputs produced when the recipe resolves (Array of RecipeOutput).
## Each rolls independently against its prob field.
@export var outputs: Array[Resource] = []
