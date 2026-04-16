class_name HarvestYield
extends Resource

## One possible yield from harvesting a prop. A yield is only produced
## when ALL listed conditions are satisfied.
##
## Conditions are encoded as StringName "type:value" pairs:
##   &"tool:cutting_tool"    — player must have a prop with supports_actions containing "cut"
##   &"tool:hammering_tool"  — player must have a hammering tool
##   &"time_of_day:night"    — only at night
##   &"skill:botany_1"       — player has botany skill level 1+
##   &"weather:rain"         — during rain
##   &"season:wet"           — during wet season
## Empty list = always yields.

@export var item_id: StringName = &""
@export var amount: int = 1
@export var conditions: Array[StringName] = []
