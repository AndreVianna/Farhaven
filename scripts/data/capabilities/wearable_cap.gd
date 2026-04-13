class_name WearableCap
extends Resource

## WEARABLE capability — declares a prop as equippable on a specific body slot.
## A wearable prop lives on the player (or another creature) instead of inside
## a container's grid. When the prop also has ContainerCap, equipping it makes
## that container the active inventory surface (e.g. a backpack's grid becomes
## the player's inventory).

enum Place {
	BACK,
	WAIST,
	TORSO,
	LEG,
	ARMS,
	HEAD,
	NECK,
	FEET,
	HANDS,
}

@export var place: Place = Place.BACK
