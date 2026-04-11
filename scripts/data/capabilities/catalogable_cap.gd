class_name CatalogableCap
extends Resource

@export var scan_time: float = 1.0
@export var show_as_anomaly: bool = false  # Override: force this entry into the "Anomalies" group
@export var icon: Texture2D = null          # Catalog icon (currently null for all)
@export var properties: Dictionary = {}     # {"edible": false, "toxic": false, "resource_type": "wood"}
