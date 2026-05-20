extends Area3D

class_name InteractionTarget

@export var dialogue_camera_mount_path: NodePath = ^"../DialogueCameraMount/CameraMount"
@export var player_dialogue_anchor_path: NodePath = ^"../PlayerDialogueAnchor"
@export var interaction_prompt_anchor_path: NodePath = ^"../InteractionPromptAnchor"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var dialogue_variables: Dictionary = {}
@export var interaction_key_text := "E"
@export var interaction_enabled := true
@export var return_player_to_origin_after_dialogue := true
@export var preserve_player_height_during_dialogue := false


func _ready() -> void:
	add_to_group(&"interaction_targets")


func is_interaction_available() -> bool:
	return interaction_enabled


func set_interaction_enabled(value: bool) -> void:
	if interaction_enabled == value:
		return

	interaction_enabled = value
	var actor := get_parent()
	if actor != null:
		SessionStatePersistence.notify_actor_changed(actor)


func get_dialogue_camera_mount() -> Node3D:
	return get_node_or_null(dialogue_camera_mount_path) as Node3D


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D


func get_dialogue_resource() -> DialogueResource:
	return dialogue_resource


func get_dialogue_start_title() -> String:
	return dialogue_start_title


func should_return_player_to_origin_after_dialogue() -> bool:
	return return_player_to_origin_after_dialogue


func should_preserve_player_height_during_dialogue() -> bool:
	return preserve_player_height_during_dialogue


func get_dialogue_game_states() -> Array:
	var states: Array = []
	var variables := dialogue_variables.duplicate(true)
	var actor := get_parent()

	if actor != null:
		if actor.has_method("get_dialogue_speaker_name"):
			variables["speaker_name"] = actor.call("get_dialogue_speaker_name")
		elif not variables.has("speaker_name"):
			variables["speaker_name"] = actor.name

	if not variables.is_empty():
		states.append(variables)

	if actor != null:
		for child in actor.get_children():
			if child.is_in_group(&"dialogue_state_components"):
				states.append(child)

	return states


func get_interaction_prompt_anchor() -> Node3D:
	return get_node_or_null(interaction_prompt_anchor_path) as Node3D


func get_interaction_prompt_position() -> Vector3:
	var anchor := get_interaction_prompt_anchor()
	if anchor != null:
		return anchor.global_position

	return global_position


func get_interaction_key_text() -> String:
	return interaction_key_text
