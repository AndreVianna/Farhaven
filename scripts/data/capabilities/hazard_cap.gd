class_name HazardCap
extends Resource

## HazardCap — environmental hazard capability for a biome.
##
## Paired with per-tile `HexTile.temperature` (0-4). When a biome has
## this cap attached, SurvivalSystem reads each second's elapsed time
## and applies `damage_type`-tagged drain to the player's stats using
## the array field matching the tile's temperature level (1..4).
## Level 0 = no damage, no drain.
##
## All damage/drain values are per-second magnitudes. Health damage is
## subtracted from HP. thirst_drain and hunger_drain are subtracted
## from their respective meters (always non-negative here — the sign
## flip happens in SurvivalSystem).
##
## Level 4 values should be large enough to kill the player in
## ~1 second (e.g. health_damage[3] ≈ hp_max) so a misstep into lava
## or a summit gap is lethal but gives a brief window to back out.

## Damage kind tag — used by resistances, protection items, and
## armor interactions. Current values: "heat", "cold",
## "hypoxia", "poison", "acid", "oxygen_drain". Add new tags
## as new hazard kinds are introduced; SurvivalSystem does a lookup
## on this tag to pick the default affected stat and the damage
## resolution pipeline.
@export var damage_type: StringName = &"heat"

## Health (HP) lost per second at each temperature level [1,2,3,4].
## Level 0 is implicit (no damage). Default is the Heat preset —
## Andre's canonical example from the design discussion.
@export var health_damage: Array[int] = [0, 5, 15, 50]

## Thirst meter lost per second at each temperature level [1,2,3,4].
## Heat biomes drain thirst; cold biomes typically leave this at 0.
@export var thirst_drain: Array[int] = [5, 14, 25, 35]

## Hunger meter lost per second at each temperature level [1,2,3,4].
## Cold biomes drain hunger; heat biomes typically leave this at 0.
@export var hunger_drain: Array[int] = [0, 0, 0, 0]

## Oxygen meter lost per second at each temperature level [1,2,3,4].
## Underwater / high-altitude / stale-atmosphere biomes drain oxygen.
## Other hazard types typically leave this at 0.
@export var oxygen_drain: Array[int] = [0, 0, 0, 0]
