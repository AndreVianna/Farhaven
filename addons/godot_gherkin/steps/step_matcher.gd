extends RefCounted
## Compiles Cucumber Expression patterns to RegEx for step matching.
##
## Self-reference for headless mode compatibility
const StepMatcherScript = preload("res://addons/godot_gherkin/steps/step_matcher.gd")
const ParameterTypesScript = preload("res://addons/godot_gherkin/steps/parameter_types.gd")
##
## Supports:
## - {int}, {float}, {word}, {string}, {any}, {} placeholders
## - Optional text: (s) for plurals
## - Alternation: word1/word2


## Result of pattern compilation.
class CompileResult:
	extends RefCounted
	var regex: RegEx = null
	var param_types: Array[ParameterTypesScript.ParameterType] = []
	var error: String = ""
	var success: bool = false

	static func ok(
		p_regex: RegEx, p_types: Array[ParameterTypesScript.ParameterType]
	) -> CompileResult:
		var result := CompileResult.new()
		result.regex = p_regex
		result.param_types = p_types
		result.success = true
		return result

	static func fail(message: String) -> CompileResult:
		var result := CompileResult.new()
		result.error = message
		result.success = false
		return result


## Result of a step match attempt.
class MatchResult:
	extends RefCounted
	var matched: bool = false
	var arguments: Array = []
	var regex_match: RegExMatch = null

	static func success(args: Array, match_obj: RegExMatch = null) -> MatchResult:
		var result := MatchResult.new()
		result.matched = true
		result.arguments = args
		result.regex_match = match_obj
		return result

	static func failure() -> MatchResult:
		return MatchResult.new()


## Compile a Cucumber Expression pattern to a RegEx.
static func compile_pattern(
	pattern: String, registry: ParameterTypesScript.ParameterTypeRegistry = null
) -> CompileResult:
	if not registry:
		registry = ParameterTypesScript.get_registry()

	var regex_str := "^"
	var param_types: Array[ParameterTypesScript.ParameterType] = []
	var pos := 0
	var length := pattern.length()

	while pos < length:
		var char := pattern[pos]

		# Handle parameter placeholder {type}
		if char == "{":
			var end := pattern.find("}", pos)
			if end == -1:
				return CompileResult.fail("Unclosed parameter placeholder at position %d" % pos)

			var type_name := pattern.substr(pos + 1, end - pos - 1)
			var param_type := registry.get_type(type_name)

			if not param_type:
				return CompileResult.fail("Unknown parameter type: {%s}" % type_name)

			regex_str += "(" + param_type.regex + ")"
			param_types.append(param_type)
			pos = end + 1
			continue

		# Handle optional text (text)
		if char == "(":
			var end := pattern.find(")", pos)
			if end == -1:
				return CompileResult.fail("Unclosed optional group at position %d" % pos)

			var optional_text := pattern.substr(pos + 1, end - pos - 1)
			regex_str += "(?:" + _escape_regex(optional_text) + ")?"
			pos = end + 1
			continue

		# Handle alternation: word1/word2
		if char == "/" and pos > 0 and pos < length - 1:
			# Look backwards to find the word before /
			var before_end := pos
			var before_start := pos - 1
			while before_start >= 0 and _is_word_char(pattern[before_start]):
				before_start -= 1
			before_start += 1

			# Look forwards to find the word after /
			var after_start := pos + 1
			var after_end := after_start
			while after_end < length and _is_word_char(pattern[after_end]):
				after_end += 1

			if before_start < before_end and after_start < after_end:
				var word1 := pattern.substr(before_start, before_end - before_start)
				var word2 := pattern.substr(after_start, after_end - after_start)

				# Remove the first word we already added to regex
				regex_str = regex_str.substr(0, regex_str.length() - word1.length())
				regex_str += "(?:" + _escape_regex(word1) + "|" + _escape_regex(word2) + ")"
				pos = after_end
				continue

		# Escape regex special characters
		if char in ".^$*+?[]\\|()":
			regex_str += "\\" + char
		else:
			regex_str += char

		pos += 1

	regex_str += "$"

	var regex := RegEx.new()
	var err := regex.compile(regex_str)
	if err != OK:
		return CompileResult.fail("Failed to compile regex: %s" % regex_str)

	return CompileResult.ok(regex, param_types)


## Match step text against a compiled pattern.
static func match_step(step_text: String, compiled: CompileResult) -> MatchResult:
	if not compiled.success or not compiled.regex:
		return MatchResult.failure()

	var match_obj := compiled.regex.search(step_text)
	if not match_obj:
		return MatchResult.failure()

	# Extract and transform arguments
	var args: Array = []
	for i in range(compiled.param_types.size()):
		var raw_value := match_obj.get_string(i + 1)
		var param_type := compiled.param_types[i]
		var transformed := param_type.transform(raw_value)
		args.append(transformed)

	return MatchResult.success(args, match_obj)


## Escape special regex characters in a string.
static func _escape_regex(text: String) -> String:
	var result := ""
	for c in text:
		if c in ".^$*+?[]\\|(){}":
			result += "\\" + c
		else:
			result += c
	return result


## Check if a character is a word character (alphanumeric or underscore).
static func _is_word_char(c: String) -> bool:
	if c.length() != 1:
		return false
	var code := c.unicode_at(0)
	return (
		(code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)  # A-Z  # a-z
		or (code >= 48 and code <= 57)  # 0-9
		or code == 95
	)  # _
