extends Node
class_name GatherSound

## Placeholder sound hook for auto-gather and crafting feedback.
## Currently a silent stub — call play_gather_ding() or play_craft_success()
## to trigger the hook. Assign real AudioStream resources later.

signal gather_ding_played
signal craft_success_played

var _gather_player: AudioStreamPlayer = null
var _craft_player: AudioStreamPlayer = null


func _ready() -> void:
	_gather_player = AudioStreamPlayer.new()
	_gather_player.bus = &"Master"
	_gather_player.volume_db = -6.0
	_gather_player.name = "GatherPlayer"
	add_child(_gather_player)

	_craft_player = AudioStreamPlayer.new()
	_craft_player.bus = &"Master"
	_craft_player.volume_db = -3.0
	_craft_player.name = "CraftPlayer"
	add_child(_craft_player)


## Play gather ding. Emits gather_ding_played even if no stream is loaded (hook).
func play_gather_ding() -> void:
	if _gather_player != null and _gather_player.stream != null:
		_gather_player.play()
	gather_ding_played.emit()


## Play craft success sound. Emits craft_success_played even if no stream is loaded.
func play_craft_success() -> void:
	if _craft_player != null and _craft_player.stream != null:
		_craft_player.play()
	craft_success_played.emit()


## Set the gather ding audio stream resource.
func set_gather_stream(stream: AudioStream) -> void:
	if _gather_player != null:
		_gather_player.stream = stream


## Set the craft success audio stream resource.
func set_craft_stream(stream: AudioStream) -> void:
	if _craft_player != null:
		_craft_player.stream = stream
