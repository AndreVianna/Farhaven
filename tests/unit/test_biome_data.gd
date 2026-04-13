extends GdUnitTestSuite
class_name TestBiomeData

const BIOME_PATHS: Array[String] = [
	"res://data/biomes/B00001.tres",
	"res://data/biomes/B00002.tres",
	"res://data/biomes/B00003.tres",
	"res://data/biomes/B00004.tres",
	"res://data/biomes/B00005.tres",
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
