extends Node3D

@export var visual_root_path: NodePath = ^"Rig"
@export var player_dialogue_anchor_path: NodePath = ^"PlayerDialogueAnchor"
@export var dialogue_speaker_name := "Villager"


func set_character_visible(value: bool) -> void:
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if visual_root != null:
		visual_root.visible = value


func face_towards_position(target_position: Vector3) -> void:
	var offset := target_position - global_position
	offset.y = 0.0
	if offset.is_zero_approx():
		return

	var target_rotation := atan2(offset.x, offset.z)
	var current_transform := global_transform
	current_transform.basis = Basis.from_euler(Vector3(0.0, target_rotation, 0.0))
	global_transform = current_transform


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D


func get_dialogue_camera_mount() -> Node3D:
	return $DialogueSpeakerPivot


func get_dialogue_speaker_name() -> String:
	return dialogue_speaker_name
