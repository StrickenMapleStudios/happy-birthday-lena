extends Node3D

@export var cutscene_camera_path: NodePath = ^"CutsceneCamera"
@export var player_anchor_path: NodePath = ^"PlayerCutsceneAnchor"
@export var return_player_to_origin_after_cutscene := false
@export var preserve_player_height_during_cutscene := true


func get_cutscene_camera() -> Camera3D:
	return get_node_or_null(cutscene_camera_path) as Camera3D


func get_player_cutscene_anchor() -> Node3D:
	return get_node_or_null(player_anchor_path) as Node3D


func should_return_player_to_origin_after_cutscene() -> bool:
	return return_player_to_origin_after_cutscene


func should_preserve_player_height_during_cutscene() -> bool:
	return preserve_player_height_during_cutscene
