extends Node3D

@export var cutscene_camera_path: NodePath = ^"CutsceneCamera"


func get_cutscene_camera() -> Camera3D:
	return get_node_or_null(cutscene_camera_path) as Camera3D
