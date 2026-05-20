extends Node

class_name GiantsIntroDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"

@export var has_asked_who_they_are := false


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)


func mark_who_they_are_asked() -> void:
	has_asked_who_they_are = true
