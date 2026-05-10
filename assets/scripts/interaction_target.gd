extends Area3D

class_name InteractionTarget

@export var dialogue_camera_mount_path: NodePath = ^"../DialogueCameraMount/CameraMount"
@export var player_dialogue_anchor_path: NodePath = ^"../PlayerDialogueAnchor"
@export var interaction_prompt_anchor_path: NodePath = ^"../InteractionPromptAnchor"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var interaction_key_text := "E"
@export var interaction_enabled := true


func _ready() -> void:
	add_to_group(&"interaction_targets")


func is_interaction_available() -> bool:
	return interaction_enabled


func get_dialogue_camera_mount() -> Node3D:
	return get_node_or_null(dialogue_camera_mount_path) as Node3D


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D


func get_dialogue_resource() -> DialogueResource:
	return dialogue_resource


func get_dialogue_start_title() -> String:
	return dialogue_start_title


func get_interaction_prompt_anchor() -> Node3D:
	return get_node_or_null(interaction_prompt_anchor_path) as Node3D


func get_interaction_prompt_position() -> Vector3:
	var anchor := get_interaction_prompt_anchor()
	if anchor != null:
		return anchor.global_position

	return global_position
func get_interaction_key_text() -> String:
	return interaction_key_text
