extends Node

const RESULT_NONE := &""

var _race_started := false
var _pending_return := false
var _return_scene_path := ""
var _return_player_transform := Transform3D.IDENTITY
var _return_npc_path := NodePath()
var _race_id := &""
var _result: StringName = RESULT_NONE


func start_race(return_scene_path: String, player_transform: Transform3D, npc_path: NodePath, race_id: StringName = &"") -> void:
	_race_started = true
	_pending_return = false
	_return_scene_path = return_scene_path
	_return_player_transform = player_transform
	_return_npc_path = npc_path
	_race_id = race_id
	_result = RESULT_NONE


func finish_race(result: StringName) -> void:
	if not _race_started:
		return

	_pending_return = true
	_result = result


func get_return_scene_path(default_scene_path: String = "") -> String:
	if _return_scene_path.is_empty():
		return default_scene_path

	return _return_scene_path


func get_active_race_id(default_race_id: StringName = &"") -> StringName:
	if _race_id.is_empty():
		return default_race_id

	return _race_id


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
		"race_id": _race_id,
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
	_race_id = &""
	_result = RESULT_NONE
