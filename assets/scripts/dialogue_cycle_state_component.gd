extends Node

class_name DialogueCycleStateComponent

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"

@export var who_are_you_loop_count := 0
@export var who_are_you_break_threshold := 10


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)


func record_who_are_you_loop() -> void:
	who_are_you_loop_count += 1


func reset_who_are_you_loop() -> void:
	who_are_you_loop_count = 0
