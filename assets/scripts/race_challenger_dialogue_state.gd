extends Node

class_name RaceChallengerDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"

var _pending_race_start := false


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)


func request_race_start() -> void:
	_pending_race_start = true


func consume_pending_race_start() -> bool:
	var should_start := _pending_race_start
	_pending_race_start = false
	return should_start
