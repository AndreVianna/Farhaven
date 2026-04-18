class_name CatalogableCap
extends Resource

## CatalogableCap — marks a prop as scannable, with data the player learns
## upon scanning (catalog entry).
##
## The `properties` dictionary is free-form but MUST follow a per-category
## schema. Props of the same category (plant, mineral, etc.) use identical
## keys so the in-game catalog UI can render consistent fields.
##
## ---------------------------------------------------------------------------
## Plant schema (biome: any plant-type prop)
## ---------------------------------------------------------------------------
##   energy_source:      String  "light" | "chemical" | "mixed" | "parasitic"
##   internal_transport: String  "none" | "vessels"
##   shape_symmetry:     String  "radial" | "directional" | "irregular"
##   growth_form:        String  "tree" | "column" | "ground_cover" | "rosette" | "clinger"
##   rigidity:           String  "rigid" | "flexible" | "pressure_filled" | "brittle"
##   edibility_level:    int     0-10  (0=inert, 5=processable, 10=high-density)
##   toxicity_level:     int     0-10  (0=inert, 4=contact, 10=systemic)
##   hydration_level:    int     0-10  (relative yield, 0=dry, 10=water-rich)
##
## ---------------------------------------------------------------------------
## Mineral schema (any mineral-type prop)
## ---------------------------------------------------------------------------
##   crystal_form:       String  "geometric" | "irregular" | "formless"
##   crystal_pattern:    String  "cubic" | "tetragonal" | "hexagonal" | "trigonal"
##                               | "orthorhombic" | "monoclinic" | "triclinic" | "none"
##   hardness:           int     1-10  (Mohs scale)
##   breaking_behavior:  String  "shatters" | "bends" | "stretches" | "slices" | "springs_back"
##   surface_shine:      String  "metallic" | "glassy" | "diamond_like" | "waxy" | "dull"
##   light_transmission: String  "clear" | "diffused" | "blocked"
##   fluorescence:       bool
##   piezoelectricity:   bool
##   radioactivity:      bool
##   density:            float   0.01-100  (relative, 1.0 = water, 100 = super-dense)

@export var scan_time: float = 1.0
@export var show_as_anomaly: bool = false  # Override: force this entry into the "Anomalies" group
@export var icon: Texture2D = null          # Catalog icon (currently null for all)
@export var properties: Dictionary = {}     # See schema comment above — per-category keys required
