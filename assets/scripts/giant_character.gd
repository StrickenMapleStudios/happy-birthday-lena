extends Node3D

const CharacterAnimationLibrary = preload("res://assets/scripts/character_animation_library.gd")

@export var visual_root_path: NodePath = ^"Model"
@export var interaction_target_path: NodePath = ^"InteractionRig/InteractionTarget"
@export var dialogue_camera_mount_path: NodePath = ^"InteractionRig/DialogueSpeakerPivot"
@export var player_dialogue_anchor_path: NodePath = ^"InteractionRig/PlayerDialogueAnchor"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var dialogue_speaker_name := "Гигант"
@export var interaction_enabled := false

@onready var look_tracking: NpcLookTrackingController = $LookTracking
@onready var head_pole_modifier: GiantHeadPoleModifier = $Model/Rig/Skeleton3D/HeadPoleModifier
@onready var dialogue_animation_tree: AnimationTree = $Model/AnimationPlayer/DialogueAnimationTree


func _ready() -> void:
	CharacterAnimationLibrary.apply_to($Model/AnimationPlayer)
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = true
		_set_dialogue_animation_condition(false)

	var interaction_target := get_node_or_null(interaction_target_path) as InteractionTarget
	if interaction_target == null:
		return

	interaction_target.dialogue_resource = dialogue_resource
	interaction_target.dialogue_start_title = dialogue_start_title
	interaction_target.interaction_enabled = interaction_enabled


func set_character_visible(value: bool) -> void:
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if visual_root != null:
		visual_root.visible = value


func enter_dialogue_animation_mode(_is_talking: bool) -> void:
	_set_dialogue_animation_condition(true)

	if look_tracking != null:
		look_tracking.set_tracking_enabled(true)
	if head_pole_modifier != null:
		head_pole_modifier.reset_head_rotation_immediately()


func exit_dialogue_animation_mode() -> void:
	_set_dialogue_animation_condition(false)

	if look_tracking != null:
		look_tracking.set_tracking_enabled(false)
	if head_pole_modifier != null:
		head_pole_modifier.reset_head_rotation_immediately()


func face_towards_position(target_position: Vector3) -> void:
	var offset := target_position - global_position
	offset.y = 0.0
	if offset.is_zero_approx():
		return

	var scale := global_transform.basis.get_scale()
	var target_rotation := atan2(offset.x, offset.z)
	var current_transform := global_transform
	current_transform.basis = Basis.from_euler(Vector3(0.0, target_rotation, 0.0)).scaled(scale)
	global_transform = current_transform


func get_dialogue_camera_mount() -> Node3D:
	return get_node_or_null(dialogue_camera_mount_path) as Node3D


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D


func get_dialogue_speaker_name() -> String:
	return dialogue_speaker_name.strip_edges()


func set_dialogue_camera_target(target: Node3D) -> void:
	if look_tracking != null:
		look_tracking.set_external_target(target)
	if head_pole_modifier != null:
		head_pole_modifier.reset_head_rotation_immediately()


func _set_dialogue_animation_condition(is_in_dialogue: bool) -> void:
	if dialogue_animation_tree == null:
		return

	dialogue_animation_tree.set("parameters/conditions/InDialogue", is_in_dialogue)
	dialogue_animation_tree.set("parameters/conditions/NotInDialogue", not is_in_dialogue)
