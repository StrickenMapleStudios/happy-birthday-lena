extends Node

class_name GiantsIntroDialogueState

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"
const BRASS_KEY_ITEM_ID := &"brass_key"
const REQUIRED_KEY_COUNT := 3

@export var has_asked_who_they_are := false

var has_all_required_keys := false
var has_special_passage_granted := false
var _answered_riddle_1_correctly := false
var _answered_riddle_2_correctly := false
var _answered_riddle_3_correctly := false


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)
	_refresh_required_keys_status()


func mark_who_they_are_asked() -> void:
	has_asked_who_they_are = true


func reset_riddle_progress() -> void:
	_refresh_required_keys_status()
	has_special_passage_granted = false
	_answered_riddle_1_correctly = false
	_answered_riddle_2_correctly = false
	_answered_riddle_3_correctly = false


func mark_riddle_1_correct() -> void:
	_answered_riddle_1_correctly = true


func mark_riddle_2_correct() -> void:
	_answered_riddle_2_correctly = true


func mark_riddle_3_correct() -> void:
	_answered_riddle_3_correctly = true


func mark_special_passage_granted() -> void:
	has_special_passage_granted = true


func _refresh_required_keys_status() -> void:
	var inventory := _get_game_inventory()
	if inventory == null:
		has_all_required_keys = false
		return

	has_all_required_keys = inventory.count_item_quantity(BRASS_KEY_ITEM_ID) >= REQUIRED_KEY_COUNT


func should_open_gates() -> bool:
	return has_special_passage_granted or (
		_answered_riddle_1_correctly
		and _answered_riddle_2_correctly
		and _answered_riddle_3_correctly
	)


func _get_game_inventory() -> InventoryData:
	var tree := get_tree()
	if tree == null:
		return null

	var game := tree.current_scene
	if game == null or not game.has_method("get_inventory_data"):
		return null

	return game.call("get_inventory_data") as InventoryData
