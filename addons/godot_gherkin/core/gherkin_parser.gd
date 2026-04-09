extends RefCounted
## Recursive descent parser for Gherkin feature files.
##
## Self-reference for headless mode compatibility
const GherkinParserScript = preload("res://addons/godot_gherkin/core/gherkin_parser.gd")
const GherkinLexerScript = preload("res://addons/godot_gherkin/core/gherkin_lexer.gd")
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
##
## Builds an AST from a token stream produced by GherkinLexer.

var _tokens: Array[GherkinLexerScript.Token] = []
var _current: int = 0
var _errors: Array[String] = []
var _file_path: String = ""


## Parse the given source text and return a Feature AST node.
func parse(source: String, file_path: String = "") -> GherkinASTScript.Feature:
	var lexer := GherkinLexerScript.new()
	_tokens = lexer.tokenize(source)
	_current = 0
	_errors = []
	_file_path = file_path

	return _parse_feature()


## Parse from pre-tokenized tokens.
func parse_tokens(
	tokens: Array[GherkinLexerScript.Token], file_path: String = ""
) -> GherkinASTScript.Feature:
	_tokens = tokens
	_current = 0
	_errors = []
	_file_path = file_path

	return _parse_feature()


## Get any errors encountered during parsing.
func get_errors() -> Array[String]:
	return _errors


## Check if parsing encountered errors.
func has_errors() -> bool:
	return not _errors.is_empty()


# === Parsing Methods ===


## Parse a Feature (top-level construct).
func _parse_feature() -> GherkinASTScript.Feature:
	var feature := GherkinASTScript.Feature.new()
	feature.source_path = _file_path

	# Skip leading empty lines and comments, collect tags
	_skip_empty_and_comments()
	feature.tags = _parse_tags()
	_skip_empty_and_comments()

	# Expect Feature keyword
	if not _check(GherkinLexerScript.TokenType.FEATURE):
		_error("Expected 'Feature:' keyword")
		return feature

	var feature_token := _advance()
	feature.name = feature_token.value
	feature.location = _make_location(feature_token)

	# Parse description (text lines before Background/Scenario/Rule)
	feature.description = _parse_description()

	# Parse optional Background at feature level
	_skip_empty_and_comments()
	if _check(GherkinLexerScript.TokenType.BACKGROUND):
		feature.background = _parse_background()

	# Parse scenarios and rules
	while not _is_at_end():
		_skip_empty_and_comments()

		if _is_at_end():
			break

		if _check(GherkinLexerScript.TokenType.RULE):
			feature.rules.append(_parse_rule())
		elif _check(GherkinLexerScript.TokenType.SCENARIO):
			feature.scenarios.append(_parse_scenario())
		elif _check(GherkinLexerScript.TokenType.SCENARIO_OUTLINE):
			feature.scenarios.append(_parse_scenario_outline())
		elif _check(GherkinLexerScript.TokenType.TAG):
			# Tags for upcoming scenario
			var tags := _parse_tags()
			_skip_empty_and_comments()

			if _check(GherkinLexerScript.TokenType.SCENARIO):
				var scenario := _parse_scenario()
				scenario.tags.append_array(tags)
				feature.scenarios.append(scenario)
			elif _check(GherkinLexerScript.TokenType.SCENARIO_OUTLINE):
				var outline := _parse_scenario_outline()
				outline.tags.append_array(tags)
				feature.scenarios.append(outline)
			elif _check(GherkinLexerScript.TokenType.RULE):
				var rule := _parse_rule()
				rule.tags.append_array(tags)
				feature.rules.append(rule)
			else:
				_advance()  # Skip unexpected token
		else:
			_advance()  # Skip unexpected token

	return feature


## Parse a Rule section.
func _parse_rule() -> GherkinASTScript.Rule:
	var rule := GherkinASTScript.Rule.new()

	var rule_token := _advance()  # Consume RULE token
	rule.name = rule_token.value
	rule.location = _make_location(rule_token)

	# Parse description
	rule.description = _parse_description()

	# Parse optional Background
	_skip_empty_and_comments()
	if _check(GherkinLexerScript.TokenType.BACKGROUND):
		rule.background = _parse_background()

	# Parse scenarios within the rule
	while not _is_at_end() and not _check_structure_boundary():
		_skip_empty_and_comments()

		if _is_at_end() or _check_structure_boundary():
			break

		if _check(GherkinLexerScript.TokenType.SCENARIO):
			rule.scenarios.append(_parse_scenario())
		elif _check(GherkinLexerScript.TokenType.SCENARIO_OUTLINE):
			rule.scenarios.append(_parse_scenario_outline())
		elif _check(GherkinLexerScript.TokenType.TAG):
			var tags := _parse_tags()
			_skip_empty_and_comments()

			if _check(GherkinLexerScript.TokenType.SCENARIO):
				var scenario := _parse_scenario()
				scenario.tags.append_array(tags)
				rule.scenarios.append(scenario)
			elif _check(GherkinLexerScript.TokenType.SCENARIO_OUTLINE):
				var outline := _parse_scenario_outline()
				outline.tags.append_array(tags)
				rule.scenarios.append(outline)
			else:
				break  # Unexpected, exit rule
		else:
			break  # Exit rule on unrecognized content

	return rule


## Parse a Background section.
func _parse_background() -> GherkinASTScript.Background:
	var background := GherkinASTScript.Background.new()

	var bg_token := _advance()  # Consume BACKGROUND token
	background.name = bg_token.value
	background.location = _make_location(bg_token)

	# Parse description
	background.description = _parse_description()

	# Parse steps
	background.steps = _parse_steps()

	return background


## Parse a Scenario.
func _parse_scenario() -> GherkinASTScript.Scenario:
	var scenario := GherkinASTScript.Scenario.new()

	var sc_token := _advance()  # Consume SCENARIO token
	scenario.name = sc_token.value
	scenario.location = _make_location(sc_token)

	# Parse description
	scenario.description = _parse_description()

	# Parse steps
	scenario.steps = _parse_steps()

	return scenario


## Parse a Scenario Outline.
func _parse_scenario_outline() -> GherkinASTScript.ScenarioOutline:
	var outline := GherkinASTScript.ScenarioOutline.new()

	var so_token := _advance()  # Consume SCENARIO_OUTLINE token
	outline.name = so_token.value
	outline.location = _make_location(so_token)

	# Parse description
	outline.description = _parse_description()

	# Parse steps
	outline.steps = _parse_steps()

	# Parse Examples sections
	while _check(GherkinLexerScript.TokenType.EXAMPLES) or _check(GherkinLexerScript.TokenType.TAG):
		_skip_empty_and_comments()

		if _check(GherkinLexerScript.TokenType.TAG):
			var tags := _parse_tags()
			_skip_empty_and_comments()

			if _check(GherkinLexerScript.TokenType.EXAMPLES):
				var examples := _parse_examples()
				examples.tags.append_array(tags)
				outline.examples.append(examples)
			else:
				break
		elif _check(GherkinLexerScript.TokenType.EXAMPLES):
			outline.examples.append(_parse_examples())
		else:
			break

	return outline


## Parse an Examples section.
func _parse_examples() -> GherkinASTScript.Examples:
	var examples := GherkinASTScript.Examples.new()

	var ex_token := _advance()  # Consume EXAMPLES token
	examples.name = ex_token.value
	examples.location = _make_location(ex_token)

	# Parse description
	examples.description = _parse_description()

	# Parse table
	if _check(GherkinLexerScript.TokenType.TABLE_ROW):
		examples.table = _parse_data_table()

	return examples


## Parse steps until a non-step token is encountered.
func _parse_steps() -> Array[GherkinASTScript.Step]:
	var steps: Array[GherkinASTScript.Step] = []

	while GherkinLexerScript.is_step_keyword(_peek().type):
		var step := _parse_step()
		if step:
			steps.append(step)

	return steps


## Parse a single step.
func _parse_step() -> GherkinASTScript.Step:
	var step := GherkinASTScript.Step.new()

	var step_token := _advance()
	step.keyword = GherkinLexerScript.token_type_to_keyword(step_token.type)
	step.text = step_token.value
	step.location = _make_location(step_token)

	# Check for step argument (doc string or data table)
	_skip_empty_lines()

	if _check(GherkinLexerScript.TokenType.DOC_STRING):
		step.argument = _parse_doc_string()
	elif _check(GherkinLexerScript.TokenType.TABLE_ROW):
		step.argument = _parse_data_table()

	return step


## Parse a doc string.
func _parse_doc_string() -> GherkinASTScript.DocString:
	var doc := GherkinASTScript.DocString.new()

	var doc_token := _advance()
	doc.location = _make_location(doc_token)

	# Parse content - may include media type on first line
	var content := doc_token.value
	var lines := content.split("\n")

	if lines.size() > 0:
		var first_line := lines[0].strip_edges()
		# Check if first line is a media type (no spaces, starts with letter)
		if first_line and not first_line.contains(" ") and first_line[0].is_valid_identifier():
			doc.media_type = first_line
			lines = lines.slice(1)

	doc.content = "\n".join(lines)

	return doc


## Parse a data table.
func _parse_data_table() -> GherkinASTScript.DataTable:
	var table := GherkinASTScript.DataTable.new()
	table.location = _make_location(_peek())

	while _check(GherkinLexerScript.TokenType.TABLE_ROW):
		var row := _parse_table_row()
		if row:
			table.rows.append(row)

	return table


## Parse a table row.
func _parse_table_row() -> GherkinASTScript.TableRow:
	var row := GherkinASTScript.TableRow.new()

	var row_token := _advance()
	row.location = _make_location(row_token)

	# Parse cells from the row value (e.g., "| cell1 | cell2 |")
	var row_text := row_token.value.strip_edges()

	# Remove leading and trailing pipes
	if row_text.begins_with("|"):
		row_text = row_text.substr(1)
	if row_text.ends_with("|"):
		row_text = row_text.substr(0, row_text.length() - 1)

	# Split by pipe and trim each cell
	var cell_values := row_text.split("|")
	for cell_value in cell_values:
		var cell := GherkinASTScript.TableCell.new()
		cell.value = cell_value.strip_edges()
		cell.location = row.location
		row.cells.append(cell)

	return row


## Parse tags (one or more @ prefixed items).
func _parse_tags() -> Array[GherkinASTScript.Tag]:
	var tags: Array[GherkinASTScript.Tag] = []

	while _check(GherkinLexerScript.TokenType.TAG):
		var tag_token := _advance()
		var tag_line := tag_token.value

		# Parse multiple tags from a single line (e.g., "@tag1 @tag2")
		var tag_parts := tag_line.split(" ")
		for part in tag_parts:
			part = part.strip_edges()
			if part.begins_with("@"):
				var tag := GherkinASTScript.Tag.new()
				tag.name = part
				tag.location = _make_location(tag_token)
				tags.append(tag)

		_skip_empty_lines()

	return tags


## Parse description text (non-keyword text before steps or sections).
func _parse_description() -> String:
	var description_lines: PackedStringArray = []

	_skip_empty_lines()

	while _check(GherkinLexerScript.TokenType.TEXT):
		var text_token := _advance()
		description_lines.append(text_token.value)

	return "\n".join(description_lines).strip_edges()


# === Helper Methods ===


## Check if current token matches the given type.
func _check(type: GherkinLexerScript.TokenType) -> bool:
	if _is_at_end():
		return false
	return _peek().type == type


## Check if we're at a structure boundary (Rule, Feature, or end).
func _check_structure_boundary() -> bool:
	if _is_at_end():
		return true
	var t := _peek().type
	return t == GherkinLexerScript.TokenType.RULE or t == GherkinLexerScript.TokenType.FEATURE


## Get the current token without advancing.
func _peek() -> GherkinLexerScript.Token:
	if _current >= _tokens.size():
		return GherkinLexerScript.Token.new(GherkinLexerScript.TokenType.EOF)
	return _tokens[_current]


## Get the previous token.
func _previous() -> GherkinLexerScript.Token:
	if _current <= 0:
		return GherkinLexerScript.Token.new(GherkinLexerScript.TokenType.EOF)
	return _tokens[_current - 1]


## Advance to the next token and return the current one.
func _advance() -> GherkinLexerScript.Token:
	if not _is_at_end():
		_current += 1
	return _previous()


## Check if we've reached the end of tokens.
func _is_at_end() -> bool:
	return _current >= _tokens.size() or _peek().type == GherkinLexerScript.TokenType.EOF


## Skip empty lines.
func _skip_empty_lines() -> void:
	while _check(GherkinLexerScript.TokenType.EMPTY_LINE):
		_advance()


## Skip empty lines and comments.
func _skip_empty_and_comments() -> void:
	while (
		_check(GherkinLexerScript.TokenType.EMPTY_LINE)
		or _check(GherkinLexerScript.TokenType.COMMENT)
	):
		_advance()


## Create a Location from a token.
func _make_location(token: GherkinLexerScript.Token) -> GherkinASTScript.Location:
	return GherkinASTScript.Location.new(token.line, token.column)


## Record a parsing error.
func _error(message: String) -> void:
	var token := _peek()
	var location := "%s:%d" % [_file_path, token.line] if _file_path else "line %d" % token.line
	_errors.append("%s: %s" % [location, message])
