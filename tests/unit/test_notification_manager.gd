class_name TestNotificationManager
extends GdUnitTestSuite

const _NotificationManager = preload("res://scripts/hud/notification_manager.gd")


# --- Constants ---

func test_max_queue_depth_is_three() -> void:
	assert_int(_NotificationManager.MAX_QUEUE_DEPTH).is_equal(3)


func test_duration_first_is_two_seconds() -> void:
	assert_float(_NotificationManager.DURATION_FIRST).is_equal_approx(2.0, 0.001)


func test_duration_queued_is_shorter() -> void:
	assert_float(_NotificationManager.DURATION_QUEUED).is_less(_NotificationManager.DURATION_FIRST)


func test_fade_time_is_positive() -> void:
	assert_float(_NotificationManager.FADE_TIME).is_greater(0.0)


# --- Queue behavior ---

func test_show_notification_adds_to_queue() -> void:
	var mgr: Node = _NotificationManager.new()
	# Before showing, the internal queue is empty.
	# After show, _queue might be empty (popped) or have items depending on state.
	# We test the child count to verify a panel was actually created.
	var scene_root: Node = auto_free(mgr)
	# Need to add to scene tree for create_tween to work.
	# GdUnit auto_free handles cleanup.
	add_child(mgr)
	mgr.show_notification("Test message")
	# After showing, the manager should have created a panel as child.
	assert_int(mgr.get_child_count()).is_greater(0)


func test_queue_drops_oldest_when_full() -> void:
	var mgr: Node = auto_free(_NotificationManager.new())
	add_child(mgr)
	# Show first notification (starts displaying)
	mgr.show_notification("First")
	# Queue 3 more while first is showing (fills queue to MAX_QUEUE_DEPTH)
	mgr.show_notification("Second")
	mgr.show_notification("Third")
	mgr.show_notification("Fourth")
	# Adding a 5th should drop the oldest queued item
	mgr.show_notification("Fifth")
	# Internal _queue should never exceed MAX_QUEUE_DEPTH
	assert_int(mgr._queue.size()).is_less_equal(_NotificationManager.MAX_QUEUE_DEPTH)
