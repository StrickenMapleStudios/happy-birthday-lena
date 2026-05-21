extends Node

class_name CakeDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"
const BLACK_SCREEN_HOLD_SECONDS := 1.0


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)


func hold_black_screen_before_credits() -> void:
	await SceneTransition.hold_black_screen(BLACK_SCREEN_HOLD_SECONDS)
