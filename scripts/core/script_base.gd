class_name ScriptBase
extends Gear

## Base class for executable game logic (Recipes, Events).
## Carries conditions, effects, actions, and duration.

const _Predicate = preload("res://scripts/recipes/predicate.gd")
const _RecipeEffect = preload("res://scripts/recipes/recipe_effect.gd")
const _RecipeCondition = preload("res://scripts/recipes/recipe_condition.gd")

## Conditions that must be true for execution (Array of RecipeCondition).
@export var conditions: Array[Resource] = []

## Non-prop effects applied on resolve (Array of RecipeEffect).
@export var effects: Array[Resource] = []

## Player verbs that trigger this script. Empty = passive (auto-fires when conditions met).
@export var actions: Array[StringName] = []

## Duration in seconds between trigger and resolution. 0 = instant.
@export var duration: float = 0.0
