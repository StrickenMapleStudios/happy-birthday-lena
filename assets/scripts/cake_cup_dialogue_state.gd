extends Node

class_name CakeCupDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)


func play_cup_reward_cutscene() -> void:
	var host := get_parent()
	if host == null or not host.has_method("play_cup_reward_cutscene"):
		return

	await host.call("play_cup_reward_cutscene")
