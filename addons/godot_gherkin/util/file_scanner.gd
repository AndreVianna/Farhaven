extends RefCounted
## Discovers .feature files and step definition files in the project.
##
## Self-reference for headless mode compatibility
const FileScannerScript = preload("res://addons/godot_gherkin/util/file_scanner.gd")


## Find all .feature files in the given directory (recursively).
func find_feature_files(base_path: String) -> Array[String]:
	return _scan_directory(base_path, "*.feature")


## Find all step definition files in the given directory (recursively).
func find_step_files(base_path: String) -> Array[String]:
	return _scan_directory(base_path, "*_steps.gd")


## Scan a directory for files matching a pattern.
func _scan_directory(path: String, pattern: String) -> Array[String]:
	var results: Array[String] = []

	var dir := DirAccess.open(path)
	if not dir:
		push_warning("FileScanner: Could not open directory: %s" % path)
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			# Skip hidden directories
			if not file_name.begins_with("."):
				results.append_array(_scan_directory(full_path, pattern))
		elif _matches_pattern(file_name, pattern):
			results.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return results


## Check if a filename matches a glob pattern.
func _matches_pattern(file_name: String, pattern: String) -> bool:
	# Simple glob matching for *.ext and *_suffix.ext patterns
	if pattern.begins_with("*"):
		var suffix := pattern.substr(1)
		return file_name.ends_with(suffix)
	if pattern.ends_with("*"):
		var prefix := pattern.substr(0, pattern.length() - 1)
		return file_name.begins_with(prefix)
	return file_name == pattern


## Read a file's contents as a string.
static func read_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("FileScanner: Could not read file: %s" % path)
		return ""
	return file.get_as_text()


## Check if a file exists.
static func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## Check if a directory exists.
static func dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)
