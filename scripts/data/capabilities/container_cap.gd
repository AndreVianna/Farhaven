class_name ContainerCap
extends Resource
@export var capacity_size: float = 0.0
## DEPRECATED — no runtime consumer reads this field. Kept for backward
## compatibility with existing .tres files and level-editor tooling.
## Will be removed once all tooling is migrated.
@export var accepts_filter: Array[StringName] = []
