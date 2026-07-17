extends Node3D

const CharacterAnimationLibrary = preload("res://assets/scripts/character_animation_library.gd")
const CharacterAnimationTreeFactory = preload("res://assets/scripts/character_animation_tree_factory.gd")
const GAMEPLAY_COLLISION_GROUP := &"gameplay_collision_state_receivers"
const GIANT_LOOK_TRACKING_SETTINGS = preload("res://assets/data/characters/giant_look_tracking.tres")
const GIANT_STATE_IDLE := &"Idle"
const GIANT_STATE_GUARDING := &"Guarding"
const GIANT_STATE_SECRETLY_DANCING := &"SecretlyDancing"

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
@onready var animation_player: AnimationPlayer = get_node_or_null(^"Model/AnimationPlayer") as AnimationPlayer
@onready var dialogue_animation_tree: AnimationTree = null
@onready var _gameplay_collision_body: StaticBody3D = get_node_or_null(gameplay_collision_body_path) as StaticBody3D

var _gameplay_collision_shapes: Array[CollisionShape3D] = []
var _gameplay_collision_enabled := false
var _character_visible := true
var _dialogue_playback: AnimationNodeStateMachinePlayback


func _ready() -> void:
	add_to_group(GAMEPLAY_COLLISION_GROUP)
	var animation_player := get_node_or_null(^"Model/AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		var restored_trees := CharacterAnimationTreeFactory.ensure_locomotion_trees(animation_player)
		dialogue_animation_tree = restored_trees.get("dialogue_animation_tree") as AnimationTree
		CharacterAnimationLibrary.apply_to(animation_player)
	_restore_runtime_scene_overrides()
	_ensure_giant_dialogue_tree()
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = true
		_set_dialogue_animation_condition(false)
		_dialogue_playback = dialogue_animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		_travel_giant_state(GIANT_STATE_IDLE)
	_cache_gameplay_collision_shapes()
	_apply_gameplay_collision_state()

	var interaction_target := get_node_or_null(interaction_target_path) as InteractionTarget
	if interaction_target == null:
		return

	interaction_target.dialogue_resource = dialogue_resource
	interaction_target.dialogue_start_title = dialogue_start_title
	interaction_target.interaction_enabled = interaction_enabled


func _restore_runtime_scene_overrides() -> void:
	var hat := get_node_or_null(^"Model/Rig/Skeleton3D/hat_2") as Node3D
	if hat != null:
		hat.visible = false
	var inner_hat := get_node_or_null(^"Model/Rig/Skeleton3D/hat_2/hat") as Node3D
	if inner_hat != null:
		inner_hat.visible = false

	if look_tracking != null:
		look_tracking.set("settings", GIANT_LOOK_TRACKING_SETTINGS)
		look_tracking.set("monitoring", true)
		look_tracking.set("monitorable", false)
		if look_tracking.has_method("set_tracking_enabled"):
			look_tracking.call("set_tracking_enabled", true)
		if look_tracking.has_method("refresh_tracking_configuration"):
			look_tracking.call("refresh_tracking_configuration")

	if head_pole_modifier != null:
		head_pole_modifier.set("settings", GIANT_LOOK_TRACKING_SETTINGS)
		head_pole_modifier.set("look_tracking_controller_path", ^"../../../../LookTracking")
		head_pole_modifier.set("active", true)
		head_pole_modifier.reset_head_rotation_immediately()


func _ensure_giant_dialogue_tree() -> void:
	if dialogue_animation_tree == null:
		return

	var state_machine := dialogue_animation_tree.tree_root as AnimationNodeStateMachine
	if state_machine != null \
		and state_machine.has_node(GIANT_STATE_GUARDING) \
		and state_machine.has_node(GIANT_STATE_SECRETLY_DANCING):
		return

	var new_state_machine := AnimationNodeStateMachine.new()
	new_state_machine.graph_offset = Vector2(-72.0, -6.0)
	new_state_machine.add_node(&"Start", AnimationNodeOutput.new(), Vector2(160.0, 116.0))
	new_state_machine.add_node(GIANT_STATE_IDLE, _make_giant_animation_node(GIANT_STATE_IDLE), Vector2(364.0, 181.0))
	new_state_machine.add_node(GIANT_STATE_GUARDING, _make_giant_animation_node(GIANT_STATE_GUARDING), Vector2(366.0, 59.0))
	new_state_machine.add_node(GIANT_STATE_SECRETLY_DANCING, _make_giant_animation_node(GIANT_STATE_SECRETLY_DANCING), Vector2(620.0, 120.0))
	new_state_machine.add_transition(&"Start", GIANT_STATE_IDLE, _make_giant_transition(0.0, "", true))
	new_state_machine.add_transition(GIANT_STATE_IDLE, GIANT_STATE_GUARDING, _make_giant_transition(0.0, "InDialogue"))
	new_state_machine.add_transition(GIANT_STATE_GUARDING, GIANT_STATE_IDLE, _make_giant_transition(0.0, "NotInDialogue"))
	new_state_machine.add_transition(GIANT_STATE_IDLE, GIANT_STATE_SECRETLY_DANCING, _make_giant_transition(0.0, "PlaySecretlyDancing"))
	new_state_machine.add_transition(GIANT_STATE_GUARDING, GIANT_STATE_SECRETLY_DANCING, _make_giant_transition(0.0, "PlaySecretlyDancing"))
	new_state_machine.add_transition(GIANT_STATE_SECRETLY_DANCING, GIANT_STATE_IDLE, _make_giant_transition(0.0, "StopSecretlyDancing"))
	dialogue_animation_tree.tree_root = new_state_machine


func _make_giant_animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var animation_node := AnimationNodeAnimation.new()
	animation_node.animation = animation_name
	return animation_node


func _make_giant_transition(
	xfade_time: float,
	advance_condition: String,
	auto_advance: bool = false
) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade_time
	if auto_advance:
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	elif not advance_condition.is_empty():
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		transition.advance_condition = StringName(advance_condition)
	return transition


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
	_travel_giant_state(GIANT_STATE_GUARDING)
	_play_giant_animation(GIANT_STATE_GUARDING)

	if look_tracking != null:
		look_tracking.set_tracking_enabled(true)
	if head_pole_modifier != null:
		head_pole_modifier.reset_head_rotation_immediately()


func exit_dialogue_animation_mode() -> void:
	_set_dialogue_animation_condition(false)
	_travel_giant_state(GIANT_STATE_IDLE)
	_play_giant_animation(GIANT_STATE_IDLE)

	if look_tracking != null:
		look_tracking.set_tracking_enabled(false)
	if head_pole_modifier != null:
		head_pole_modifier.reset_head_rotation_immediately()


func enter_secretly_dancing_mode() -> void:
	_set_dialogue_animation_condition(false)
	_set_secretly_dancing_condition(true)
	_travel_giant_state(GIANT_STATE_SECRETLY_DANCING)
	_play_giant_animation(GIANT_STATE_SECRETLY_DANCING)

	if look_tracking != null:
		look_tracking.set_tracking_enabled(false)
	if head_pole_modifier != null:
		head_pole_modifier.reset_head_rotation_immediately()


func exit_secretly_dancing_mode() -> void:
	_set_secretly_dancing_condition(false)
	_set_dialogue_animation_condition(false)
	_travel_giant_state(GIANT_STATE_IDLE)
	_play_giant_animation(GIANT_STATE_IDLE)


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


func _travel_giant_state(state_name: StringName) -> void:
	if _dialogue_playback == null:
		return

	_dialogue_playback.travel(state_name)


func _play_giant_animation(animation_name: StringName) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		return

	animation_player.play(animation_name)
