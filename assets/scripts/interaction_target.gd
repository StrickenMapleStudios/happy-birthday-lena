extends Area3D

class_name InteractionTarget

@export var dialogue_camera_mount_path: NodePath = ^"../DialogueCameraMount/CameraMount"
@export var player_dialogue_anchor_path: NodePath = ^"../PlayerDialogueAnchor"
@export var interaction_enabled := true


func is_interaction_available() -> bool:
	return interaction_enabled


func get_dialogue_camera_mount() -> Node3D:
	return get_node_or_null(dialogue_camera_mount_path) as Node3D


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D
