extends RefCounted
## Built-in and custom parameter type definitions for Cucumber Expressions.
##
## Self-reference for headless mode compatibility
const ParameterTypesScript = preload("res://addons/godot_gherkin/steps/parameter_types.gd")
##
## Parameter types define how to match and transform step parameters.


## Represents a parameter type with regex pattern and transformer function.
class ParameterType:
	extends RefCounted
	var name: String = ""
	var regex: String = ""
	var transformer: Callable

	func _init(p_name: String, p_regex: String, p_transformer: Callable) -> void:
		name = p_name
		regex = p_regex
		transformer = p_transformer

	func transform(value: String) -> Variant:
		if transformer.is_valid():
			return transformer.call(value)
		return value


## Built-in parameter types as static constants.

## Integer: matches -?[0-9]+
static var int_type := ParameterType.new("int", "-?\\d+", func(s: String) -> int: return s.to_int())

## Float: matches -?[0-9]*\.?[0-9]+
static var float_type := ParameterType.new(
	"float", "-?\\d*\\.?\\d+", func(s: String) -> float: return s.to_float()
)

## Word: matches a single non-whitespace word
static var word_type := ParameterType.new("word", "\\S+", func(s: String) -> String: return s)

## String: matches text in single or double quotes
## Uses non-capturing group (?:...) to avoid nested capture group issues
## when multiple {string} parameters appear in a single step pattern.
static var string_type := ParameterType.new(
	"string",
	"[\"'](?:[^\"']*)[\"']",
	func(s: String) -> String:
		# Strip surrounding quotes
		if s.length() >= 2:
			if (
				(s.begins_with('"') and s.ends_with('"'))
				or (s.begins_with("'") and s.ends_with("'"))
			):
				return s.substr(1, s.length() - 2)
		return s
)

## Any: matches any text (greedy)
static var any_type := ParameterType.new("any", ".*", func(s: String) -> String: return s)

## Anonymous: same as any, used for {}
static var anonymous_type := ParameterType.new("", ".*", func(s: String) -> String: return s)


## Registry for parameter types, including custom types.
class ParameterTypeRegistry:
	extends RefCounted
	var _types: Dictionary = {}

	func _init() -> void:
		# Register built-in types
		register(ParameterTypesScript.int_type)
		register(ParameterTypesScript.float_type)
		register(ParameterTypesScript.word_type)
		register(ParameterTypesScript.string_type)
		register(ParameterTypesScript.any_type)
		register(ParameterTypesScript.anonymous_type)

	## Register a parameter type.
	func register(param_type: ParameterTypesScript.ParameterType) -> void:
		_types[param_type.name] = param_type

	## Get a parameter type by name.
	func get_type(name: String) -> ParameterTypesScript.ParameterType:
		return _types.get(name)

	## Check if a type exists.
	func has_type(name: String) -> bool:
		return _types.has(name)

	## Define a custom parameter type.
	func define_type(name: String, regex: String, transformer: Callable) -> void:
		register(ParameterTypesScript.ParameterType.new(name, regex, transformer))

	## Get all registered type names.
	func get_type_names() -> Array[String]:
		var names: Array[String] = []
		for key in _types.keys():
			names.append(key)
		return names


## Global singleton registry instance.
static var _global_registry: ParameterTypeRegistry = null


## Get the global parameter type registry.
static func get_registry() -> ParameterTypeRegistry:
	if not _global_registry:
		_global_registry = ParameterTypeRegistry.new()
	return _global_registry


## Define a custom parameter type globally.
static func define_parameter_type(name: String, regex: String, transformer: Callable) -> void:
	get_registry().define_type(name, regex, transformer)
