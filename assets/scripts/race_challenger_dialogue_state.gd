extends Node

class_name RaceChallengerDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"
const POST_RACE_DEFAULT_TITLE := &"post_race_win_pending_reward"
const POST_RACE_REWARD_CLAIMED_TITLE := &"post_race_win_reward_claimed"

var _pending_race_start := false


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)


func request_race_start() -> void:
	_pending_race_start = true


func consume_pending_race_start() -> bool:
	var should_start := _pending_race_start
	_pending_race_start = false
	return should_start


func get_post_race_win_title(has_claimed_reward: bool) -> StringName:
	return POST_RACE_REWARD_CLAIMED_TITLE if has_claimed_reward else POST_RACE_DEFAULT_TITLE
