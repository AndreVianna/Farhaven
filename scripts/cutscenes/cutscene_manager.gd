extends Node

## CutsceneManager — autoload that plays cutscene videos fullscreen with a skip button.
## Added to project.godot as autoload AFTER Journal, BEFORE SaveManager.
##
## Wave 1 scaffolding (delivery-006c, task-074): engine plumbing only. Scans
## `data/cutscenes/*.tres` at ready time and builds an id → CutsceneDef lookup.
## When `play(id)` is called, spawns a fullscreen CanvasLayer with a
## VideoStreamPlayer and a Skip button, plays the referenced video, and emits
## `cutscene_finished(id, skipped)` when playback ends naturally or is skipped.
##
## Single-playback policy: while a cutscene is already playing, additional
## `play()` calls are rejected (return false). Callers that need to interrupt
## must call `skip()` first.
##
## Uses preload because autoloads initialize before class_name registration.

const _CutsceneDef = preload("res://scripts/data/cutscene_def.gd")
const CUTSCENES_PATH := "res://data/cutscenes/"

## Layer index for the overlay CanvasLayer — high enough to sit above HUD.
const OVERLAY_LAYER := 100

## Emitted when a cutscene finishes playing. `skipped` is true if the user
## pressed the skip button or `ui_cancel`, false if the video ended naturally
## or the cutscene was unplayable (missing video file, etc.).
signal cutscene_finished(cutscene_id: StringName, skipped: bool)

## Cutscene id (e.g. &"C00001") → CutsceneDef resource.
var _defs: Dictionary = {}

## Currently-playing cutscene id, or &"" when idle.
var _current_id: StringName = &""

## Overlay CanvasLayer created while a cutscene is playing. Null when idle.
var _overlay: CanvasLayer = null

## VideoStreamPlayer inside the overlay. Null when idle.
var _video_player: VideoStreamPlayer = null

## Skip Button inside the overlay. Null when idle.
var _skip_button: Button = null


func _ready() -> void:
	_scan_cutscenes()


func _scan_cutscenes() -> void:
	var dir := DirAccess.open(CUTSCENES_PATH)
	if dir == null:
		# Cutscene directory may not exist yet during authoring — that's fine.
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(CUTSCENES_PATH + fname)
			if res is _CutsceneDef:
				assert(String(res.id).begins_with("C"),
					"CutsceneManager: cutscene id '%s' must start with 'C' prefix" % res.id)
				_defs[res.id] = res
		fname = dir.get_next()


## Injectable setter for testing — replaces the scanned dictionary so tests
## don't need real .tres files on disk.
func set_defs_for_test(defs: Dictionary) -> void:
	_defs = defs


## Returns the CutsceneDef with the given id, or null if not found.
func get_def(cutscene_id: StringName) -> _CutsceneDef:
	return _defs.get(cutscene_id, null)


## Returns true while a cutscene is currently playing.
func is_playing() -> bool:
	return _current_id != &""


## Looks up the CutsceneDef by id, creates a fullscreen overlay with a
## VideoStreamPlayer and a Skip button, and starts playback. Returns true if
## playback started, false if the id is unknown, the video cannot be loaded,
## or another cutscene is already playing.
func play(cutscene_id: StringName) -> bool:
	if is_playing():
		push_warning("CutsceneManager: play() rejected — '%s' already playing" % _current_id)
		return false
	if cutscene_id == &"":
		return false
	var def := get_def(cutscene_id)
	if def == null:
		push_warning("CutsceneManager: unknown cutscene id '%s'" % cutscene_id)
		return false

	# Build overlay node tree.
	_overlay = CanvasLayer.new()
	_overlay.name = "CutsceneOverlay"
	_overlay.layer = OVERLAY_LAYER

	# Fullscreen black background + video.
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(root)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoStreamPlayer"
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.finished.connect(_on_video_finished)
	root.add_child(_video_player)

	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "Skip"
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Nudge the button inward from the corner so it isn't flush against the edge.
	_skip_button.offset_left = -96.0
	_skip_button.offset_right = -16.0
	_skip_button.offset_top = 16.0
	_skip_button.offset_bottom = 48.0
	_skip_button.pressed.connect(skip)
	root.add_child(_skip_button)

	# Attach overlay to the scene tree.
	var parent := _get_overlay_parent()
	if parent != null:
		parent.add_child(_overlay)
	else:
		# Fallback: add as child of this autoload so tests without a main loop
		# can still exercise the playback lifecycle.
		add_child(_overlay)

	# Try to load the referenced video stream. Missing/invalid files fail
	# gracefully — we still mark the cutscene as "playing" so callers can skip
	# out, but natural-end will not fire because there is no stream.
	if def.video_path != "":
		var resource_path := def.video_path
		if not resource_path.begins_with("res://"):
			resource_path = "res://" + resource_path
		if ResourceLoader.exists(resource_path):
			var stream := load(resource_path)
			if stream is VideoStream:
				_video_player.stream = stream
				_video_player.play()
			else:
				push_warning("CutsceneManager: '%s' is not a VideoStream" % resource_path)
		else:
			push_warning("CutsceneManager: video file '%s' not found" % resource_path)

	_current_id = cutscene_id
	return true


## Stops the current cutscene (if any) and emits cutscene_finished with
## skipped=true. No-op when idle.
func skip() -> void:
	if not is_playing():
		return
	var id := _current_id
	_teardown_overlay()
	_current_id = &""
	cutscene_finished.emit(id, true)


## Called when the VideoStreamPlayer emits its `finished` signal (natural end).
## Emits cutscene_finished with skipped=false.
func _on_video_finished() -> void:
	if not is_playing():
		return
	var id := _current_id
	_teardown_overlay()
	_current_id = &""
	cutscene_finished.emit(id, false)


## Esc / ui_cancel triggers skip while a cutscene is playing.
func _unhandled_input(event: InputEvent) -> void:
	if not is_playing():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


func _teardown_overlay() -> void:
	if _video_player != null:
		if _video_player.is_playing():
			_video_player.stop()
		if _video_player.finished.is_connected(_on_video_finished):
			_video_player.finished.disconnect(_on_video_finished)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_video_player = null
	_skip_button = null


## Returns the node that should parent the overlay. Prefers the scene tree
## root; falls back to null when running outside a live tree (rare).
func _get_overlay_parent() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root
	return null
