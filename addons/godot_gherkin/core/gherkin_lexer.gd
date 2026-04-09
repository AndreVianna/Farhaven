extends RefCounted
## Tokenizer for Gherkin feature files.
##
## Self-reference for headless mode compatibility
const GherkinLexerScript = preload("res://addons/godot_gherkin/core/gherkin_lexer.gd")
##
## Converts raw feature file text into a stream of tokens for parsing.

## Token types used by the lexer.
enum TokenType {
	# Structure keywords
	FEATURE,
	RULE,
	BACKGROUND,
	SCENARIO,
	SCENARIO_OUTLINE,
	EXAMPLES,
	# Step keywords
	GIVEN,
	WHEN,
	THEN,
	AND,
	BUT,
	ASTERISK,
	# Other elements
	TAG,
	DOC_STRING,
	TABLE_ROW,
	COMMENT,
	TEXT,
	DESCRIPTION,
	EMPTY_LINE,
	EOF,
}


## Represents a single token from the lexer.
class Token:
	extends RefCounted
	var type: TokenType
	var value: String
	var line: int
	var column: int
	var indent: int

	func _init(
		p_type: TokenType,
		p_value: String = "",
		p_line: int = 0,
		p_column: int = 0,
		p_indent: int = 0
	) -> void:
		type = p_type
		value = p_value
		line = p_line
		column = p_column
		indent = p_indent

	func _to_string() -> String:
		return "Token(%s, %s, line=%d)" % [TokenType.keys()[type], value, line]


## Mapping of Gherkin keywords to token types.
const KEYWORDS := {
	"Feature": TokenType.FEATURE,
	"Rule": TokenType.RULE,
	"Background": TokenType.BACKGROUND,
	"Scenario": TokenType.SCENARIO,
	"Scenario Outline": TokenType.SCENARIO_OUTLINE,
	"Scenario Template": TokenType.SCENARIO_OUTLINE,  # Alias
	"Examples": TokenType.EXAMPLES,
	"Scenarios": TokenType.EXAMPLES,  # Alias
	"Given": TokenType.GIVEN,
	"When": TokenType.WHEN,
	"Then": TokenType.THEN,
	"And": TokenType.AND,
	"But": TokenType.BUT,
	"*": TokenType.ASTERISK,
}

## Step keywords for quick checking.
const STEP_KEYWORDS := ["Given", "When", "Then", "And", "But", "*"]

## Structure keywords that define major sections.
const STRUCTURE_KEYWORDS := [
	"Feature",
	"Rule",
	"Background",
	"Scenario",
	"Scenario Outline",
	"Scenario Template",
	"Examples",
	"Scenarios"
]

var _source: String = ""
var _lines: PackedStringArray = []
var _current_line_idx: int = 0
var _tokens: Array[Token] = []


## Tokenize the given source text and return an array of tokens.
func tokenize(source: String) -> Array[Token]:
	_source = source
	_lines = source.split("\n")
	_current_line_idx = 0
	_tokens = []

	while _current_line_idx < _lines.size():
		var token := _scan_line()
		if token:
			_tokens.append(token)
		_current_line_idx += 1

	_tokens.append(Token.new(TokenType.EOF, "", _lines.size() + 1, 0, 0))
	return _tokens


## Scan a single line and return the appropriate token.
func _scan_line() -> Token:
	var line := _lines[_current_line_idx]
	var line_num := _current_line_idx + 1  # 1-based line numbers

	# Calculate indent (number of leading spaces/tabs)
	var indent := _count_indent(line)
	var trimmed := line.strip_edges(true, false).strip_edges(false, true)

	# Empty line
	if trimmed.is_empty():
		return Token.new(TokenType.EMPTY_LINE, "", line_num, 0, indent)

	# Comment
	if trimmed.begins_with("#"):
		return Token.new(
			TokenType.COMMENT, trimmed.substr(1).strip_edges(), line_num, indent, indent
		)

	# Tag(s)
	if trimmed.begins_with("@"):
		return Token.new(TokenType.TAG, trimmed, line_num, indent, indent)

	# Table row
	if trimmed.begins_with("|"):
		return Token.new(TokenType.TABLE_ROW, trimmed, line_num, indent, indent)

	# Doc string delimiter
	if trimmed.begins_with('"""') or trimmed.begins_with("```"):
		return _scan_doc_string(trimmed, line_num, indent)

	# Check for keywords
	var keyword_token := _try_scan_keyword(trimmed, line_num, indent)
	if keyword_token:
		return keyword_token

	# Plain text (description or continuation)
	return Token.new(TokenType.TEXT, trimmed, line_num, indent, indent)


## Try to match a keyword at the start of the line.
func _try_scan_keyword(trimmed: String, line_num: int, indent: int) -> Token:
	# Check longer keywords first (e.g., "Scenario Outline" before "Scenario")
	var sorted_keywords := KEYWORDS.keys()
	sorted_keywords.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())

	for keyword: String in sorted_keywords:
		# Check for "Keyword:" or "Keyword " pattern
		if trimmed.begins_with(keyword + ":"):
			var value := trimmed.substr(keyword.length() + 1).strip_edges()
			return Token.new(KEYWORDS[keyword], value, line_num, indent, indent)
		if trimmed.begins_with(keyword + " ") and keyword in STEP_KEYWORDS:
			var value := trimmed.substr(keyword.length() + 1).strip_edges()
			return Token.new(KEYWORDS[keyword], value, line_num, indent, indent)
		if trimmed == keyword and keyword in STEP_KEYWORDS:
			# Step keyword with no text (rare but valid)
			return Token.new(KEYWORDS[keyword], "", line_num, indent, indent)

	return null


## Scan a doc string (multi-line string).
func _scan_doc_string(start_line: String, start_line_num: int, indent: int) -> Token:
	var delimiter := '"""' if start_line.begins_with('"""') else "```"
	var media_type := start_line.substr(delimiter.length()).strip_edges()
	var content_lines: PackedStringArray = []

	_current_line_idx += 1

	# Collect lines until closing delimiter
	while _current_line_idx < _lines.size():
		var line := _lines[_current_line_idx]
		var trimmed := line.strip_edges()

		if trimmed == delimiter or trimmed.begins_with(delimiter):
			break

		# Preserve content with original indentation relative to delimiter
		content_lines.append(line)
		_current_line_idx += 1

	# Join content, optionally stripping common indent
	var content := "\n".join(content_lines)
	if media_type:
		content = media_type + "\n" + content

	return Token.new(TokenType.DOC_STRING, content, start_line_num, indent, indent)


## Count the number of leading whitespace characters.
func _count_indent(line: String) -> int:
	var count := 0
	for c in line:
		if c == " ":
			count += 1
		elif c == "\t":
			count += 4  # Treat tabs as 4 spaces
		else:
			break
	return count


## Check if a token type is a step keyword.
static func is_step_keyword(type: TokenType) -> bool:
	return (
		type
		in [
			TokenType.GIVEN,
			TokenType.WHEN,
			TokenType.THEN,
			TokenType.AND,
			TokenType.BUT,
			TokenType.ASTERISK
		]
	)


## Check if a token type is a structure keyword.
static func is_structure_keyword(type: TokenType) -> bool:
	return (
		type
		in [
			TokenType.FEATURE,
			TokenType.RULE,
			TokenType.BACKGROUND,
			TokenType.SCENARIO,
			TokenType.SCENARIO_OUTLINE,
			TokenType.EXAMPLES
		]
	)


## Convert token type to Gherkin keyword string.
static func token_type_to_keyword(type: TokenType) -> String:
	match type:
		TokenType.FEATURE:
			return "Feature"
		TokenType.RULE:
			return "Rule"
		TokenType.BACKGROUND:
			return "Background"
		TokenType.SCENARIO:
			return "Scenario"
		TokenType.SCENARIO_OUTLINE:
			return "Scenario Outline"
		TokenType.EXAMPLES:
			return "Examples"
		TokenType.GIVEN:
			return "Given"
		TokenType.WHEN:
			return "When"
		TokenType.THEN:
			return "Then"
		TokenType.AND:
			return "And"
		TokenType.BUT:
			return "But"
		TokenType.ASTERISK:
			return "*"
		_:
			return ""
