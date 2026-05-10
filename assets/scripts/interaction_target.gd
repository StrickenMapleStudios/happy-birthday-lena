extends Area3D

class_name InteractionTarget

@export var dialogue_camera_mount_path: NodePath = ^"../DialogueCameraMount/CameraMount"
@export var player_dialogue_anchor_path: NodePath = ^"../PlayerDialogueAnchor"
@export var interaction_prompt_anchor_path: NodePath = ^"../InteractionPromptAnchor"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var interaction_key_text := "E"
@export var interaction_enabled := true
@export_range(0.0, 5.0, 0.05) var interaction_prompt_depth_distance := 0.9


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


func get_interaction_prompt_position(player_position: Vector3) -> Vector3:
	var anchor := get_interaction_prompt_anchor()
	var base_position := global_position
	if anchor != null:
		base_position = anchor.global_position

	var actor := get_parent() as Node3D
	var origin_position := global_position
	var forward := Vector3.FORWARD
	if actor != null:
		origin_position = actor.global_position
		forward = actor.global_transform.basis.z

	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var to_player := player_position - origin_position
	to_player.y = 0.0
	var depth_amount := 0.0
	if not to_player.is_zero_approx():
		depth_amount = to_player.normalized().dot(forward)

	return base_position + forward * depth_amount * interaction_prompt_depth_distance


func get_interaction_prompt_side_sign(camera_position: Vector3) -> float:
	var actor := get_parent() as Node3D
	var origin_position := global_position
	var right := Vector3.RIGHT
	if actor != null:
		origin_position = actor.global_position
		right = actor.global_transform.basis.x

	right.y = 0.0
	if right.is_zero_approx():
		right = Vector3.RIGHT
	else:
		right = right.normalized()

	var to_camera := camera_position - origin_position
	to_camera.y = 0.0
	if to_camera.is_zero_approx():
		return 0.0

	return to_camera.normalized().dot(right)


func get_interaction_key_text() -> String:
	return interaction_key_text
