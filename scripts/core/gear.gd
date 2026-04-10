class_name Gear
extends Resource

## Base entity for all game objects in Farhaven.
## Every Gear has an id, display_name, and optional descriptions.
## Subtypes: Script (executable), Element (world data), Cutscene, JournalEntry.

## Unique identifier, e.g. &"R00001", &"P00010".
@export var id: StringName = &""

## Human-readable name shown in UI.
@export var display_name: String = ""

## One-line summary for tooltips and lists.
@export var short_description: String = ""

## Full description for detail panels and journal entries.
@export var long_description: String = ""
