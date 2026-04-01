extends GdUnitTestSuite
class_name TestBiomeData

const BIOME_PATHS: Array[String] = [
	"res://data/biomes/crash_site.tres",
	"res://data/biomes/grassland.tres",
	"res://data/biomes/forest.tres",
	"res://data/biomes/rocky.tres",
	"res://data/biomes/water.tres",
]

func test_all_biomes_load_without_error() -> void:
	for path in BIOME_PATHS:
		var biome: BiomeData = load(path)
		assert_object(biome).is_not_null()

func test_all_biomes_have_color_variations() -> void:
	for path in BIOME_PATHS:
		var biome: BiomeData = load(path)
		assert_int(biome.color_variations.size()).is_between(2, 3)

func test_all_color_variations_are_valid() -> void:
	for path in BIOME_PATHS:
		var biome: BiomeData = load(path)
		for c in biome.color_variations:
			# Not fully transparent
			assert_float(c.a).is_greater(0.0)
			# Not pure black
			assert_bool(c.r == 0.0 and c.g == 0.0 and c.b == 0.0).is_false()
