class_name JournalEntry extends Gear

## Journal entry — a piece of long-form narrative content unlocked during play.
## Looked up by ID from `data/journal/*.tres`, unlocked via GameEvent effect.
## Engine plumbing only — actual chapter content comes in delivery-007.
##
## Inherits id, display_name, short_description, long_description from Gear.
## Use J-prefixed ids (e.g. &"J00001").
##
## Note: we keep Gear's long_description as the tooltip/summary hook and add a
## dedicated `body` field for the full journal text. This separation lets the
## UI show a short teaser (long_description) and a full-page body on click.

## Full journal body text. Multi-line, can contain line breaks.
@export_multiline var body: String = ""

## Logical bucket for filtering in the journal panel.
## Common values: &"chapter", &"lore", &"tutorial".
@export var category: StringName = &"lore"

## In-game day on which this entry becomes unlockable. 0 = from the start.
## Purely advisory — the actual unlock path is via GameEvent effect.
@export var day_added: int = 0
