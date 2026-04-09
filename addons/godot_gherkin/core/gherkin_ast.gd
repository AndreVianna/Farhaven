extends RefCounted
## Abstract Syntax Tree node definitions for Gherkin feature files.
##
## Self-reference for headless mode compatibility
const GherkinASTScript = preload("res://addons/godot_gherkin/core/gherkin_ast.gd")
##
## This file defines all the AST node types used to represent parsed Gherkin
## feature files. All classes extend RefCounted for memory management.


## Represents a source location (line and column) in a feature file.
class Location:
	extends RefCounted
	var line: int = 0
	var column: int = 0

	func _init(p_line: int = 0, p_column: int = 0) -> void:
		line = p_line
		column = p_column

	func _to_string() -> String:
		return "%d:%d" % [line, column]


## Represents a tag (e.g., @smoke, @slow).
class Tag:
	extends RefCounted
	var name: String = ""
	var location: Location = null

	func _init(p_name: String = "", p_location: Location = null) -> void:
		name = p_name
		location = p_location if p_location else Location.new()


## Represents a comment line.
class Comment:
	extends RefCounted
	var text: String = ""
	var location: Location = null

	func _init(p_text: String = "", p_location: Location = null) -> void:
		text = p_text
		location = p_location if p_location else Location.new()


## Represents a single cell in a data table row.
class TableCell:
	extends RefCounted
	var value: String = ""
	var location: Location = null

	func _init(p_value: String = "", p_location: Location = null) -> void:
		value = p_value
		location = p_location if p_location else Location.new()


## Represents a row in a data table.
class TableRow:
	extends RefCounted
	var cells: Array[TableCell] = []
	var location: Location = null

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()

	func get_values() -> Array[String]:
		var values: Array[String] = []
		for cell in cells:
			values.append(cell.value)
		return values


## Represents a data table (used as step argument).
class DataTable:
	extends RefCounted
	var rows: Array[TableRow] = []
	var location: Location = null

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()

	## Returns the header row (first row) values.
	func get_headers() -> Array[String]:
		if rows.is_empty():
			return []
		return rows[0].get_values()

	## Returns data rows (all rows except header).
	func get_data_rows() -> Array[TableRow]:
		if rows.size() <= 1:
			return []
		return rows.slice(1)

	## Returns row count (excluding header).
	func row_count() -> int:
		return maxi(0, rows.size() - 1)


## Represents a doc string (multi-line string argument).
class DocString:
	extends RefCounted
	var content: String = ""
	var media_type: String = ""  # Optional content type (e.g., "json", "xml")
	var delimiter: String = '"""'  # """ or ```
	var location: Location = null

	func _init(p_content: String = "", p_location: Location = null) -> void:
		content = p_content
		location = p_location if p_location else Location.new()


## Represents a step (Given/When/Then/And/But/*).
class Step:
	extends RefCounted
	var keyword: String = ""  # "Given", "When", "Then", "And", "But", "*"
	var text: String = ""
	var argument: Variant = null  # DataTable, DocString, or null
	var location: Location = null

	func _init(p_keyword: String = "", p_text: String = "", p_location: Location = null) -> void:
		keyword = p_keyword
		text = p_text
		location = p_location if p_location else Location.new()

	func has_data_table() -> bool:
		return argument is DataTable

	func has_doc_string() -> bool:
		return argument is DocString

	func get_data_table() -> DataTable:
		return argument as DataTable if argument is DataTable else null

	func get_doc_string() -> DocString:
		return argument as DocString if argument is DocString else null


## Represents a Background section.
class Background:
	extends RefCounted
	var keyword: String = "Background"
	var name: String = ""
	var description: String = ""
	var steps: Array[Step] = []
	var location: Location = null

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()


## Represents an Examples section in a Scenario Outline.
class Examples:
	extends RefCounted
	var keyword: String = "Examples"
	var name: String = ""
	var description: String = ""
	var tags: Array[Tag] = []
	var table: DataTable = null
	var location: Location = null

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()

	func get_headers() -> Array[String]:
		if table:
			return table.get_headers()
		return []

	func row_count() -> int:
		if table:
			return table.row_count()
		return 0


## Represents a Scenario.
class Scenario:
	extends RefCounted
	var keyword: String = "Scenario"
	var name: String = ""
	var description: String = ""
	var tags: Array[Tag] = []
	var steps: Array[Step] = []
	var location: Location = null

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()

	func get_tag_names() -> Array[String]:
		var names: Array[String] = []
		for tag in tags:
			names.append(tag.name)
		return names

	func has_tag(tag_name: String) -> bool:
		for tag in tags:
			if tag.name == tag_name:
				return true
		return false


## Represents a Scenario Outline (parameterized scenario).
class ScenarioOutline:
	extends RefCounted
	var keyword: String = "Scenario Outline"
	var name: String = ""
	var description: String = ""
	var tags: Array[Tag] = []
	var steps: Array[Step] = []
	var examples: Array[Examples] = []
	var location: Location = null

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()

	func get_tag_names() -> Array[String]:
		var names: Array[String] = []
		for tag in tags:
			names.append(tag.name)
		return names

	func has_tag(tag_name: String) -> bool:
		for tag in tags:
			if tag.name == tag_name:
				return true
		return false

	## Returns the total number of scenario instances this outline will generate.
	func get_instance_count() -> int:
		var count := 0
		for example in examples:
			count += example.row_count()
		return count


## Represents a Rule section (Gherkin 6+).
class Rule:
	extends RefCounted
	var keyword: String = "Rule"
	var name: String = ""
	var description: String = ""
	var tags: Array[Tag] = []
	var background: Background = null
	var scenarios: Array = []  # Array of Scenario or ScenarioOutline
	var location: Location = null

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()


## Represents a Feature (top-level Gherkin construct).
class Feature:
	extends RefCounted
	var keyword: String = "Feature"
	var name: String = ""
	var description: String = ""
	var tags: Array[Tag] = []
	var background: Background = null
	var rules: Array[Rule] = []
	var scenarios: Array = []  # Array of Scenario or ScenarioOutline (at feature level)
	var comments: Array[Comment] = []
	var location: Location = null
	var source_path: String = ""  # Path to the .feature file

	func _init(p_location: Location = null) -> void:
		location = p_location if p_location else Location.new()

	func get_tag_names() -> Array[String]:
		var names: Array[String] = []
		for tag in tags:
			names.append(tag.name)
		return names

	func has_tag(tag_name: String) -> bool:
		for tag in tags:
			if tag.name == tag_name:
				return true
		return false

	## Returns all scenarios (including those in rules) as a flat list.
	func get_all_scenarios() -> Array:
		var all_scenarios: Array = []
		all_scenarios.append_array(scenarios)
		for rule in rules:
			all_scenarios.append_array(rule.scenarios)
		return all_scenarios

	## Returns the total count of scenarios and scenario outlines.
	func scenario_count() -> int:
		var count := scenarios.size()
		for rule in rules:
			count += rule.scenarios.size()
		return count
