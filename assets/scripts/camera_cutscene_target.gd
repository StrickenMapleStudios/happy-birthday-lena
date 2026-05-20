extends Node3D

@export var cutscene_camera_path: NodePath = ^"CutsceneCamera"
@export var player_anchor_path: NodePath = ^"PlayerCutsceneAnchor"
@export var dialogue_camera_path: NodePath = ^"DialogueCamera"
@export var dialogue_player_anchor_path: NodePath = ^"PlayerDialogueAnchor"
@export var return_player_to_origin_after_cutscene := false
@export var preserve_player_height_during_cutscene := true
@export var dialogue_speaker_name := "Cake"


func get_cutscene_camera() -> Camera3D:
	return get_node_or_null(cutscene_camera_path) as Camera3D


func get_player_cutscene_anchor() -> Node3D:
	return get_node_or_null(player_anchor_path) as Node3D


func should_return_player_to_origin_after_cutscene() -> bool:
	return return_player_to_origin_after_cutscene


func should_preserve_player_height_during_cutscene() -> bool:
	return preserve_player_height_during_cutscene


func get_dialogue_camera_mount() -> Node3D:
	var dialogue_camera := get_node_or_null(dialogue_camera_path) as Camera3D
	if dialogue_camera != null:
		return dialogue_camera

	return get_cutscene_camera()


func get_dialogue_scene_camera() -> Camera3D:
	var dialogue_camera := get_node_or_null(dialogue_camera_path) as Camera3D
	if dialogue_camera != null:
		return dialogue_camera

	return get_cutscene_camera()


func get_player_dialogue_anchor() -> Node3D:
	var dialogue_player_anchor := get_node_or_null(dialogue_player_anchor_path) as Node3D
	if dialogue_player_anchor != null:
		return dialogue_player_anchor

	return get_player_cutscene_anchor()


func get_dialogue_focus_position() -> Vector3:
	var player_anchor := get_player_dialogue_anchor()
	if player_anchor != null:
		return player_anchor.global_position

	return global_position


func get_dialogue_speaker_name() -> String:
	return dialogue_speaker_name.strip_edges()


func should_use_right_dialogue_pivot(actor: Node3D) -> bool:
	return actor == self


func face_towards_position(_target_position: Vector3) -> void:
	pass
