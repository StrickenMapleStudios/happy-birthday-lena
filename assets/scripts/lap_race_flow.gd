extends Node

const RESULT_NONE := &""

var _race_started := false
var _pending_return := false
var _return_scene_path := ""
var _return_player_transform := Transform3D.IDENTITY
var _return_npc_path := NodePath()
var _result: StringName = RESULT_NONE


func start_race(return_scene_path: String, player_transform: Transform3D, npc_path: NodePath) -> void:
	_race_started = true
	_pending_return = false
	_return_scene_path = return_scene_path
	_return_player_transform = player_transform
	_return_npc_path = npc_path
	_result = RESULT_NONE


func finish_race(result: StringName) -> void:
	if not _race_started:
		return

	_pending_return = true
	_result = result


func has_pending_return(scene_path: String = "") -> bool:
	if not _pending_return:
		return false
	return scene_path.is_empty() or scene_path == _return_scene_path


func consume_return_context(scene_path: String = "") -> Dictionary:
	if not has_pending_return(scene_path):
		return {}

	var context := {
		"scene_path": _return_scene_path,
		"player_transform": _return_player_transform,
		"npc_path": _return_npc_path,
		"result": _result,
	}

	_reset()
	return context


func reset_state() -> void:
	_reset()


func _reset() -> void:
	_race_started = false
	_pending_return = false
	_return_scene_path = ""
	_return_player_transform = Transform3D.IDENTITY
	_return_npc_path = NodePath()
	_result = RESULT_NONE
