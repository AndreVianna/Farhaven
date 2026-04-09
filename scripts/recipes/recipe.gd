class_name Recipe
extends Resource

## Declarative classification for UI grouping and runtime filtering.
enum Kind { ASSEMBLE, TRANSFORM, BREAKDOWN, COMBINE }

## Unique identifier, e.g. &"00001", &"00003".
@export var id: StringName

## Human-readable name shown in UI, e.g. "Eat Berry", "Chop Small Tree".
@export var display_name: String = ""

## Recipe kind — Assemble, Transform, Breakdown, or Combine.
@export var kind: Kind

## Inputs consumed when the recipe resolves (Array of RecipeInput).
@export var inputs: Array[Resource] = []

## Outputs produced when the recipe resolves (Array of RecipeOutput).
## Each rolls independently against its prob field.
@export var outputs: Array[Resource] = []

## Non-prop effects applied on resolve (Array of RecipeEffect).
## stat deltas, sound, light, etc.
@export var effects: Array[Resource] = []

## Conditions that must be true for the recipe to be eligible (Array of RecipeCondition).
## Each condition has a must_sustain flag controlling re-check during execution.
@export var conditions: Array[Resource] = []

## Player verbs that trigger the recipe. Empty = passive (auto-fires when conditions met).
@export var actions: Array[StringName] = []

## Duration in seconds between trigger and resolution. 0 = instant.
@export var time: float = 0.0

## Predicates for recipe discovery (Array of Predicate). Empty = known from start.
## Recipe enters the player's known list when all predicates become true (permanent).
@export var unlock_when: Array[Resource] = []
