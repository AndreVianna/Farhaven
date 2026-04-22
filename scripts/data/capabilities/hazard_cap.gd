class_name HazardCap
extends Resource

## HazardCap — environmental hazard capability for a biome.
##
## Paired with per-tile `HexTile.temperature` (0–4). When a biome has
## a HazardCap attached, SurvivalSystem reads the tile's temperature
## and the cap's `type` to decide which stat to drain and how fast,
## via the HAZARD_CONFIG tables. When the cap is null, temperature
## is ignored (tile is thermally neutral).
##
## Kept deliberately small for now. Future expansion points: per-cap
## drain curves (array of 5 floats), per-cap damage tables, specific
## stat overrides, affected damage tags, protection item tags. Add
## those here when concrete need arises — don't speculate.

## What kind of hazard this biome inflicts. SurvivalSystem uses this
## to pick the stat that drains:
##   &"heat" — drains thirst + HP (Volcanic biome)
##   &"cold" — drains hunger + HP (Alpine biome)
## Other tags (&"radiation", &"toxic", …) are reserved for later.
@export var type: StringName = &"heat"
