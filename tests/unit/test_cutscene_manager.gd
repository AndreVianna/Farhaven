class_name TestCutsceneManager
extends GdUnitTestSuite

## Unit tests for CutsceneManager (task-074).
## Tests play/skip lifecycle, signal emission, single-playback policy, and
## injection of CutsceneDefs (bypassing the res:// scan).

const _CutsceneManager = preload("res://scripts/cutscenes/cutscene_manager.gd")
const _CutsceneDef = preload("res://scripts/data/cutscene_def.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _mgr: Node

## Signal capture state.
var _finished_id: StringName = &""
var _finished_skipped: bool = false
var _finished_count: int = 0


func _make_def(p_id: StringName, p_video_path: String = "") -> _CutsceneDef:
	var def := _CutsceneDef.new()
	def.id = p_id
	def.display_name = "Test Cutscene %s" % p_id
	def.video_path = p_video_path
	return def


func _on_cutscene_finished(cutscene_id: StringName, skipped: bool) -> void:
	_finished_id = cutscene_id
	_finished_skipped = skipped
	_finished_count += 1


func before_test() -> void:
	_mgr = _CutsceneManager.new()
	# Attach under the test suite so get_tree() works during play().
	add_child(_mgr)
	_mgr.cutscene_finished.connect(_on_cutscene_finished)
	_finished_id = &""
	_finished_skipped = false
	_finished_count = 0


func after_test() -> void:
	if _mgr != null:
		if is_instance_valid(_mgr):
			_mgr.queue_free()
		_mgr = null


# ---------------------------------------------------------------------------
# play() — id lookup
# ---------------------------------------------------------------------------

func test_play_returns_false_for_unknown_cutscene_id() -> void:
	_mgr.set_defs_for_test({})
	var started: bool = _mgr.play(&"C99999")
	assert_bool(started).is_false()
	assert_bool(_mgr.is_playing()).is_false()


func test_play_returns_false_for_empty_id() -> void:
	_mgr.set_defs_for_test({&"C00001": _make_def(&"C00001")})
	var started: bool = _mgr.play(&"")
	assert_bool(started).is_false()
	assert_bool(_mgr.is_playing()).is_false()


func test_play_returns_true_for_valid_cutscene() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})

	var started: bool = _mgr.play(&"C00001")
	assert_bool(started).is_true()
	assert_bool(_mgr.is_playing()).is_true()


func test_play_creates_video_player_and_skip_button() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})
	_mgr.play(&"C00001")

	assert_object(_mgr._overlay).is_not_null()
	assert_object(_mgr._video_player).is_not_null()
	assert_object(_mgr._skip_button).is_not_null()
	assert_int(_mgr._overlay.layer).is_equal(_CutsceneManager.OVERLAY_LAYER)
	assert_str(_mgr._skip_button.text).is_equal("Skip")


# ---------------------------------------------------------------------------
# Single-playback policy
# ---------------------------------------------------------------------------

func test_play_while_already_playing_returns_false() -> void:
	var def_a := _make_def(&"C00001")
	var def_b := _make_def(&"C00002")
	_mgr.set_defs_for_test({def_a.id: def_a, def_b.id: def_b})

	var first: bool = _mgr.play(&"C00001")
	var second: bool = _mgr.play(&"C00002")

	assert_bool(first).is_true()
	assert_bool(second).is_false()
	# First cutscene is still the one playing.
	assert_str(String(_mgr._current_id)).is_equal(String(&"C00001"))


# ---------------------------------------------------------------------------
# skip() — emits cutscene_finished with skipped=true
# ---------------------------------------------------------------------------

func test_skip_emits_cutscene_finished_with_skipped_true() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})
	_mgr.play(&"C00001")

	_mgr.skip()

	assert_int(_finished_count).is_equal(1)
	assert_str(String(_finished_id)).is_equal(String(&"C00001"))
	assert_bool(_finished_skipped).is_true()
	assert_bool(_mgr.is_playing()).is_false()


func test_skip_when_idle_is_noop() -> void:
	_mgr.skip()
	assert_int(_finished_count).is_equal(0)
	assert_bool(_mgr.is_playing()).is_false()


# ---------------------------------------------------------------------------
# Natural end — emits cutscene_finished with skipped=false
# ---------------------------------------------------------------------------

func test_natural_end_emits_cutscene_finished_with_skipped_false() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})
	_mgr.play(&"C00001")

	# Simulate the VideoStreamPlayer.finished signal firing — no real video
	# file in the test, so we invoke the handler directly.
	_mgr._on_video_finished()

	assert_int(_finished_count).is_equal(1)
	assert_str(String(_finished_id)).is_equal(String(&"C00001"))
	assert_bool(_finished_skipped).is_false()
	assert_bool(_mgr.is_playing()).is_false()


# ---------------------------------------------------------------------------
# Cleanup — overlay torn down after finish
# ---------------------------------------------------------------------------

func test_overlay_cleared_after_skip() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})
	_mgr.play(&"C00001")
	_mgr.skip()

	assert_object(_mgr._overlay).is_null()
	assert_object(_mgr._video_player).is_null()
	assert_object(_mgr._skip_button).is_null()


func test_overlay_cleared_after_natural_end() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})
	_mgr.play(&"C00001")
	_mgr._on_video_finished()

	assert_object(_mgr._overlay).is_null()
	assert_object(_mgr._video_player).is_null()
	assert_object(_mgr._skip_button).is_null()


# ---------------------------------------------------------------------------
# Replay after skip — should succeed
# ---------------------------------------------------------------------------

func test_can_play_again_after_skip() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})

	_mgr.play(&"C00001")
	_mgr.skip()
	var second: bool = _mgr.play(&"C00001")

	assert_bool(second).is_true()
	assert_bool(_mgr.is_playing()).is_true()
	assert_int(_finished_count).is_equal(1)  # only the first skip emitted


# ---------------------------------------------------------------------------
# get_def lookup
# ---------------------------------------------------------------------------

func test_get_def_returns_injected_def() -> void:
	var def := _make_def(&"C00001")
	_mgr.set_defs_for_test({def.id: def})
	assert_object(_mgr.get_def(&"C00001")).is_same(def)


func test_get_def_returns_null_for_unknown() -> void:
	_mgr.set_defs_for_test({})
	assert_object(_mgr.get_def(&"C99999")).is_null()
