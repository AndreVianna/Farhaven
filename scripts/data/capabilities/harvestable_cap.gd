class_name HarvestableCap
extends Resource

## HarvestableCap — prop can be harvested for items, and optionally
## respawns after meeting conditions.
##
## `yields` lists possible outputs. Each yield is a HarvestYield resource
## with item_id, amount, and optional conditions. A single harvest action
## produces all yields whose conditions are satisfied.
##
## `respawn_conditions` controls when a depleted prop returns. Encoded
## as StringName "type:value" pairs (same format as HarvestYield.conditions):
##   &"time_elapsed:2_days"  — returns 2 in-game days after depletion
##   &"season:wet"           — only respawns in wet season
## Empty list = never respawns (mineral deposits, permanent structures).

@export var yields: Array[HarvestYield] = []
@export var respawn_conditions: Array[StringName] = []
