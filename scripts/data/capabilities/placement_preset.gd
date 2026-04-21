class_name PlacementPreset
extends Resource

## PlacementPreset — scatter rules for rendering a Prop instance.
## A single authored Prop is expanded into 1-19 rendered copies at render
## time, distributed across the sub-sub-hex (SSH) grid within the
## Prop.sub_hex cell. Each preset defines the base count and the scale
## multiplier applied to sibling copies (the center copy renders at full
## scale). All rendered copies also receive seeded-random variant, ±15%
## scale jitter, and 0-360° rotation.

enum Preset {
	## 1 instance at the sub-hex center. Default for boulders, structures,
	## and any prop that should be authored precisely rather than scattered.
	SINGLE,

	## 7 instances: center + 6 random SSH positions. scatter_scale 0.5.
	## Default for scatterable plants and minor flora.
	NORMAL,

	## 13 instances: center + 12 random. scatter_scale 0.5.
	## Thick vegetation / busy growth.
	DENSE,

	## 7 instances. scatter_scale 0.3. Small satellites around a parent —
	## "young growth" or "mother-and-sprouts" visuals.
	SPROUTING,

	## 13 instances. scatter_scale 1.0. Uniform coverage, no apparent
	## "center" — pasture, moss fields, ore clusters.
	SPREAD,

	## 19 instances filling every SSH position. scatter_scale 1.0.
	## Maximum density — saturated ground cover, tightly packed fields.
	FULL,
}


## Base instance count for a preset before ±2 jitter is applied.
## Clamped to [1, 19] after jitter at runtime.
static func get_count(preset: int) -> int:
	match preset:
		Preset.SINGLE:    return 1
		Preset.NORMAL:    return 7
		Preset.DENSE:     return 13
		Preset.SPROUTING: return 7
		Preset.SPREAD:    return 13
		Preset.FULL:      return 19
	return 1


## Multiplier applied to every non-center (sibling) rendered copy on top
## of the per-instance ±15% jitter. Unused for SINGLE (no siblings).
static func get_sibling_scale(preset: int) -> float:
	match preset:
		Preset.SINGLE:    return 0.0
		Preset.NORMAL:    return 0.5
		Preset.DENSE:     return 0.5
		Preset.SPROUTING: return 0.3
		Preset.SPREAD:    return 1.0
		Preset.FULL:      return 1.0
	return 1.0


## Human-readable preset name for the editor UI.
static func get_label(preset: int) -> String:
	match preset:
		Preset.SINGLE:    return "Single"
		Preset.NORMAL:    return "Normal"
		Preset.DENSE:     return "Dense"
		Preset.SPROUTING: return "Sprouting"
		Preset.SPREAD:    return "Spread"
		Preset.FULL:      return "Full"
	return "Unknown"


## True when variant / scale / rotation overrides are effective for a
## Prop instance with the given effective placement preset. Scatter
## presets ignore the overrides because applying them only to the center
## copy (while siblings stay procedural) breaks the visual illusion.
static func supports_instance_overrides(preset: int) -> bool:
	return preset == Preset.SINGLE
