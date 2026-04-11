class_name CutsceneDef extends Gear

## Cutscene definition — metadata for a playable cutscene clip.
## Looked up by ID from `data/cutscenes/*.tres`, played by CutsceneManager.
## Engine plumbing only — actual video files and content come in delivery-007.
##
## Inherits id, display_name, short_description, long_description from Gear.
## Use C-prefixed ids (e.g. &"C00001").

## Path to the media file, relative to res:// (e.g. "media/cutscenes/intro.ogv").
## May be empty during authoring — CutsceneManager handles missing files gracefully.
@export var video_path: String = ""

## ID of a GameEvent that triggers this cutscene when fired, or &"" if none.
## Resolved at runtime via EventRegistry; editor surfaces this as a dropdown.
@export var trigger_event: StringName = &""

## Optional preview duration in seconds. Purely informational (used by the
## editor to show length). Real playback length is determined by the media file.
@export var duration_seconds: int = 0
