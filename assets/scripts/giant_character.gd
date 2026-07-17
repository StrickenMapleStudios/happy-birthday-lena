extends Node3D

const CharacterAnimationLibrary = preload("res://assets/scripts/character_animation_library.gd")
const CharacterAnimationTreeFactory = preload("res://assets/scripts/character_animation_tree_factory.gd")
const GAMEPLAY_COLLISION_GROUP := &"gameplay_collision_state_receivers"

@export var visual_root_path: NodePath = ^"Model"
@export var interaction_target_path: NodePath = ^"InteractionRig/InteractionTarget"
@export var dialogue_camera_mount_path: NodePath = ^"InteractionRig/DialogueSpeakerPivot"
@export var player_dialogue_anchor_path: NodePath = ^"InteractionRig/PlayerDialogueAnchor"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var dialogue_speaker_name := "Р“РёРіР°РЅС‚"
@export var interaction_enabled := false
@export var gameplay_collision_body_path: NodePath = ^"GameplayCollisionBody"

@onready var look_tracking: NpcLookTrackingController = $LookTracking
@onready var head_pole_modifier: GiantHeadPoleModifier = $Model/Rig/Skeleton3D/HeadPoleModifier
@onready var dialogue_animation_tree: AnimationTree = null
@onready var _gameplay_collision_body: StaticBody3D = get_node_or_null(gameplay_collision_body_path) as StaticBody3D

var _gameplay_collision_shapes: Array[CollisionShape3D] = []
var _gameplay_collision_enabled := false
var _character_visible := true


func _ready() -> void:
	add_to_group(GAMEPLAY_COLLISION_GROUP)
	var animation_player := get_node_or_null(^"Model/AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		var restored_trees := CharacterAnimationTreeFactory.ensure_locomotion_trees(animation_player)
		dialogue_animation_tree = restored_trees.get("dialogue_animation_tree") as AnimationTree
		CharacterAnimationLibrary.apply_to(animation_player)
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = true
		_set_dialogue_animation_condition(false)
	_cache_gameplay_collision_shapes()
	_apply_gameplay_collision_state()

	var interaction_target := get_node_or_null(interaction_target_path) as InteractionTarget
	if interaction_target == null:
		return

	interaction_target.dialogue_resource = dialogue_resource
	interaction_target.dialogue_start_title = dialogue_start_title
	interaction_target.interaction_enabled = interaction_enabled


func set_character_visible(value: bool) -> void:
	_character_visible = value
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if visual_root != null:
		visual_root.visible = value
	_apply_gameplay_collision_state()


func set_gameplay_collision_enabled(value: bool) -> void:
	_gameplay_collision_enabled = value
	_apply_gameplay_collision_state()


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


func enter_secretly_dancing_mode() -> void:
	_set_dialogue_animation_condition(false)
	_set_secretly_dancing_condition(true)

	if look_tracking != null:
		look_tracking.set_tracking_enabled(false)
	if head_pole_modifier != null:
		head_pole_modifier.reset_head_rotation_immediately()


func exit_secretly_dancing_mode() -> void:
	_set_secretly_dancing_condition(false)
	_set_dialogue_animation_condition(false)


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


func _set_secretly_dancing_condition(is_playing: bool) -> void:
	if dialogue_animation_tree == null:
		return

	dialogue_animation_tree.set("parameters/conditions/PlaySecretlyDancing", is_playing)
	dialogue_animation_tree.set("parameters/conditions/StopSecretlyDancing", not is_playing)


func _cache_gameplay_collision_shapes() -> void:
	_gameplay_collision_shapes.clear()
	if _gameplay_collision_body == null:
		return

	for child in _gameplay_collision_body.get_children():
		if child is CollisionShape3D:
			_gameplay_collision_shapes.append(child as CollisionShape3D)


func _apply_gameplay_collision_state() -> void:
	var is_enabled := _gameplay_collision_enabled and _character_visible
	for collision_shape in _gameplay_collision_shapes:
		if collision_shape != null:
			collision_shape.disabled = not is_enabled
