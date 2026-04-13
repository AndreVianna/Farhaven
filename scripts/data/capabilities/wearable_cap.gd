class_name WearableCap
extends Resource

## WEARABLE capability — declares a prop as equippable on a specific body
## slot. Equipped wearables are displayed on the BodySchemaWidget in the
## status panel; some (e.g. a backpack's ContainerCap) affect gameplay
## beyond visual presence.
##
## Delivery-006j expanded the slot enum from 9 broad regions to 22
## granular slots with explicit left/right pairs. A prop can only occupy
## one slot at a time — a symmetric pair (e.g. matching vambraces) is
## modeled as two PropDef instances, one per slot.

enum Place {
	HEAD,
	FACE,
	NECK,
	LEFT_SHOULDER,
	RIGHT_SHOULDER,
	LEFT_CHEST,
	RIGHT_CHEST,
	BACK,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_FOREARM,
	RIGHT_FOREARM,
	LEFT_HAND,
	RIGHT_HAND,
	ABDOMEN,
	LUMBAR,
	LEFT_THIGH,
	RIGHT_THIGH,
	LEFT_LEG,
	RIGHT_LEG,
	LEFT_FOOT,
	RIGHT_FOOT,
}

## Total number of body slots. Used by UI widgets to preallocate / validate.
const PLACE_COUNT: int = 22

@export var place: Place = Place.BACK


## Return the stable string identifier for a Place value. Used for save
## files, BDD scenarios, and keying BodySchemaWidget regions — must stay
## stable across releases since it appears in serialized data.
static func place_to_string(p: Place) -> StringName:
	match p:
		Place.HEAD: return &"head"
		Place.FACE: return &"face"
		Place.NECK: return &"neck"
		Place.LEFT_SHOULDER: return &"left_shoulder"
		Place.RIGHT_SHOULDER: return &"right_shoulder"
		Place.LEFT_CHEST: return &"left_chest"
		Place.RIGHT_CHEST: return &"right_chest"
		Place.BACK: return &"back"
		Place.LEFT_ARM: return &"left_arm"
		Place.RIGHT_ARM: return &"right_arm"
		Place.LEFT_FOREARM: return &"left_forearm"
		Place.RIGHT_FOREARM: return &"right_forearm"
		Place.LEFT_HAND: return &"left_hand"
		Place.RIGHT_HAND: return &"right_hand"
		Place.ABDOMEN: return &"abdomen"
		Place.LUMBAR: return &"lumbar"
		Place.LEFT_THIGH: return &"left_thigh"
		Place.RIGHT_THIGH: return &"right_thigh"
		Place.LEFT_LEG: return &"left_leg"
		Place.RIGHT_LEG: return &"right_leg"
		Place.LEFT_FOOT: return &"left_foot"
		Place.RIGHT_FOOT: return &"right_foot"
	return &""


## Inverse of place_to_string. Returns -1 when the id does not match any
## known slot — callers should treat that as a hard error, not fall back
## to a default, because silent misrouting of equipped items is worse
## than a crash.
static func string_to_place(s: StringName) -> int:
	match s:
		&"head": return Place.HEAD
		&"face": return Place.FACE
		&"neck": return Place.NECK
		&"left_shoulder": return Place.LEFT_SHOULDER
		&"right_shoulder": return Place.RIGHT_SHOULDER
		&"left_chest": return Place.LEFT_CHEST
		&"right_chest": return Place.RIGHT_CHEST
		&"back": return Place.BACK
		&"left_arm": return Place.LEFT_ARM
		&"right_arm": return Place.RIGHT_ARM
		&"left_forearm": return Place.LEFT_FOREARM
		&"right_forearm": return Place.RIGHT_FOREARM
		&"left_hand": return Place.LEFT_HAND
		&"right_hand": return Place.RIGHT_HAND
		&"abdomen": return Place.ABDOMEN
		&"lumbar": return Place.LUMBAR
		&"left_thigh": return Place.LEFT_THIGH
		&"right_thigh": return Place.RIGHT_THIGH
		&"left_leg": return Place.LEFT_LEG
		&"right_leg": return Place.RIGHT_LEG
		&"left_foot": return Place.LEFT_FOOT
		&"right_foot": return Place.RIGHT_FOOT
	return -1
