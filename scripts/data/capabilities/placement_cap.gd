class_name PlacementCap
extends Resource

## PlacementCap — scatter configuration for a PropDef. Absent/null on a
## PropDef means scatter = SINGLE (legacy behavior, no scatter).
##
## Authored as a sub_resource on the PropDef next to PlaceableCap. The
## renderer reads `placement` to expand one logical Prop into 1-19
## rendered MultiMesh instances distributed across the SSH grid within
## the Prop's sub_hex cell.
##
## Per-instance overrides (on Prop itself) only take effect when the
## effective placement preset resolves to SINGLE — scatter presets
## distribute copies procedurally and pinning just the center copy would
## break the visual illusion. See `PlacementPreset.supports_instance_overrides`.

const _PlacementPreset = preload("res://scripts/data/capabilities/placement_preset.gd")


## Default scatter preset applied to every instance of the owning
## PropDef. Stored as int because GDScript @export can't store enum
## values from a sibling class. Valid values: PlacementPreset.Preset.*
@export var placement: int = 0  # PlacementPreset.Preset.SINGLE
