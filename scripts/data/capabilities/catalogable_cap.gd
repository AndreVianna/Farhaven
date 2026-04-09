class_name CatalogableCap
extends Resource
@export var scan_time: float = 1.0
@export var display_tag: StringName = &""      # "flora", "fauna", "minerals", "anomalies" — UI grouping
@export var category: int = 0                   # Catalog.CatalogCategory enum value (FLORA=0, FAUNA=1, MINERAL=2, ANOMALY=3)
@export var display_name: String = ""           # "Thornwood Tree", "Berry Bush" — shown in catalog UI
@export var description: String = ""            # Flavor text shown in catalog detail
@export var icon: Texture2D = null              # Catalog icon (currently null for all)
@export var properties: Dictionary = {}         # {"edible": false, "toxic": false, "resource_type": "wood"}
