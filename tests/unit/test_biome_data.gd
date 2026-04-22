extends GdUnitTestSuite
class_name TestBiomeData

const BIOME_PATHS: Array[String] = [
	"res://data/biomes/B00001.tres",
	"res://data/biomes/B00002.tres",
	"res://data/biomes/B00003.tres",
	"res://data/biomes/B00004.tres",
	"res://data/biomes/B00005.tres",
	"res://data/biomes/B00006.tres",
	"res://data/biomes/B00007.tres",
	"res://data/biomes/B00008.tres",
]

func test_all_biomes_load_without_error() -> void:
	for path in BIOME_PATHS:
		var biome: BiomeData = load(path)
		assert_object(biome).is_not_null()

func test_all_biomes_have_fallback_color() -> void:
	# Even biomes that define terrain_textures must keep a fallback solid
	# color so the renderer has something to show if a texture fails to load.
	for path in BIOME_PATHS:
		var biome: BiomeData = load(path)
		assert_float(biome.color.a).is_greater(0.0)
		assert_bool(biome.color.r == 0.0 and biome.color.g == 0.0 and biome.color.b == 0.0).is_false()

func test_terrain_textures_is_array() -> void:
	# Either empty (fallback to color) or populated with Texture2D entries.
	for path in BIOME_PATHS:
		var biome: BiomeData = load(path)
		assert_bool(biome.terrain_textures is Array).is_true()
		for tex in biome.terrain_textures:
			assert_object(tex).is_not_null()

const ALLOWED_HAZARD_TYPES: Array[StringName] = [
	&"heat", &"cold", &"asphyxiation", &"poison", &"acid",
]

func test_hazard_caps_are_well_formed() -> void:
	# BiomeData.hazard is either null (thermally neutral biome) or a
	# HazardCap with a recognized damage_type and three parallel drain
	# arrays of identical length ≥ 1.
	for path in BIOME_PATHS:
		var biome: BiomeData = load(path)
		if biome.hazard == null:
			continue
		var cap: Resource = biome.hazard
		assert_bool(ALLOWED_HAZARD_TYPES.has(cap.damage_type)).is_true()
		var n: int = cap.health_damage.size()
		assert_int(n).is_greater(0)
		assert_int(cap.thirst_drain.size()).is_equal(n)
		assert_int(cap.hunger_drain.size()).is_equal(n)
