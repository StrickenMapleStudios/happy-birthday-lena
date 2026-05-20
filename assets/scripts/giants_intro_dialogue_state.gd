extends Node

class_name GiantsIntroDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"

@export var has_asked_who_they_are := false

var _answered_riddle_1_correctly := false
var _answered_riddle_2_correctly := false
var _answered_riddle_3_correctly := false
var _special_passage_granted := false


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)


func mark_who_they_are_asked() -> void:
	has_asked_who_they_are = true


func reset_riddle_progress() -> void:
	_answered_riddle_1_correctly = false
	_answered_riddle_2_correctly = false
	_answered_riddle_3_correctly = false
	_special_passage_granted = false


func mark_riddle_1_correct() -> void:
	_answered_riddle_1_correctly = true


func mark_riddle_2_correct() -> void:
	_answered_riddle_2_correctly = true


func mark_riddle_3_correct() -> void:
	_answered_riddle_3_correctly = true


func mark_special_passage_granted() -> void:
	_special_passage_granted = true


func should_open_gates() -> bool:
	return _special_passage_granted or (
		_answered_riddle_1_correctly
		and _answered_riddle_2_correctly
		and _answered_riddle_3_correctly
	)
