extends CharacterBody3D

const WALKING_TURN_SPEED := 6.0
const RUNNING_TURN_SPEED := 9.0
const ANIMATION_IDLE := "Idle"
const ANIMATION_WALKING := "Walking"
const ANIMATION_RUNNING := "Running"
const WALKING_SPEED_SCALE := 2.0
const RUNNING_SPEED_SCALE := 5.0
const CHARACTER_IDENTITY_PATH := ^"CharacterIdentity"
const HEAD_POLE_MODIFIER_PATH := ^"Model/Rig/Skeleton3D/HeadPoleModifier"
const FRIEND_FOLLOW_STATE_PATH := ^"FriendFollowState"
const LOOK_TRACKING_PATH := ^"LookTracking"
const PREPARED_SPEED_SCALE_META := &"prepared_speed_scale"
const STATE_IDLE := &"Idle"
const STATE_WALKING := &"Walking"
const STATE_RUNNING := &"Running"
const MAX_COLLISION_SLIDES := 4

@export var visual_root_path: NodePath = ^"Model/Rig"
@export var player_dialogue_anchor_path: NodePath = ^"PlayerDialogueAnchor"

@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var animation_tree: AnimationTree = $Model/AnimationPlayer/AnimationTree
@onready var dialogue_animation_tree: AnimationTree = $Model/AnimationPlayer/DialogueAnimationTree

var _playback: AnimationNodeStateMachinePlayback
var _dialogue_animation_mode_active := false
var _follow_movement_active := false
var _follow_running_active := false
var _follow_direction := Vector3.ZERO
var _follow_turn_speed := WALKING_TURN_SPEED
var _current_state := StringName()
var _root_motion_track_path := NodePath()
var _saved_animation_tree: AnimationTree
var _saved_companion_dialogue_transform := Transform3D.IDENTITY
var _external_motion_enabled := false


func _ready() -> void:
	if animation_tree != null:
		animation_tree.active = true
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = false
	_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_prepare_locomotion_animation(ANIMATION_WALKING, WALKING_SPEED_SCALE)
	_prepare_locomotion_animation(ANIMATION_RUNNING, RUNNING_SPEED_SCALE)
	_configure_root_motion_track()
	_travel_to(STATE_IDLE)


func _process(delta: float) -> void:
	if _dialogue_animation_mode_active:
		return

	_update_follow_animation_state()
	if not _follow_movement_active or _follow_direction.is_zero_approx():
		return

	_rotate_towards(_follow_direction, delta)
	if _external_motion_enabled:
		return

	_apply_root_motion()


func set_character_visible(value: bool) -> void:
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if visual_root != null:
		visual_root.visible = value


func enter_dialogue_animation_mode(_is_talking: bool) -> void:
	if dialogue_animation_tree == null:
		return

	_pause_friend_following()

	if not _dialogue_animation_mode_active:
		_saved_animation_tree = _get_active_animation_tree(dialogue_animation_tree)
		if _saved_animation_tree != null:
			_saved_animation_tree.active = false
		_dialogue_animation_mode_active = true

	dialogue_animation_tree.active = true
	_reset_head_look_immediately()


func exit_dialogue_animation_mode() -> void:
	if dialogue_animation_tree == null or not _dialogue_animation_mode_active:
		return

	dialogue_animation_tree.active = false

	if _saved_animation_tree != null:
		_saved_animation_tree.active = true
	elif animation_player != null and animation_player.has_animation(ANIMATION_IDLE):
		animation_player.play(ANIMATION_IDLE)

	_saved_animation_tree = null
	_dialogue_animation_mode_active = false
	_resume_friend_following()
	_update_follow_animation_state()


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
	var character_identity := get_node_or_null(CHARACTER_IDENTITY_PATH)
	if character_identity != null and character_identity.has_method("get_dialogue_speaker_name"):
		var dialogue_name := String(character_identity.call("get_dialogue_speaker_name")).strip_edges()
		if not dialogue_name.is_empty():
			return dialogue_name

	return name


func set_follow_navigation(direction: Vector3, turn_speed: float = WALKING_TURN_SPEED, is_running: bool = false) -> void:
	_follow_turn_speed = turn_speed
	_follow_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO
	_follow_movement_active = _follow_direction != Vector3.ZERO
	_follow_running_active = _follow_movement_active and is_running
	_update_look_tracking_state()


func set_external_motion_enabled(value: bool) -> void:
	_external_motion_enabled = value


func consume_root_motion_distance() -> float:
	if animation_tree == null or animation_tree.root_motion_track.is_empty():
		return 0.0

	var root_motion: Vector3 = animation_tree.get_root_motion_position()
	root_motion.y = 0.0
	return root_motion.length()


func pause_as_follower_during_dialogue() -> void:
	_saved_companion_dialogue_transform = global_transform
	_pause_friend_following()
	set_character_visible(false)


func resume_as_follower_after_dialogue() -> void:
	global_transform = _saved_companion_dialogue_transform
	set_character_visible(true)
	_resume_friend_following()


func _get_active_animation_tree(excluded_tree: AnimationTree) -> AnimationTree:
	for child in animation_player.get_children():
		var tree := child as AnimationTree
		if tree == null or tree == excluded_tree:
			continue
		if tree.active:
			return tree

	return null


func _reset_head_look_immediately() -> void:
	var head_pole_modifier := get_node_or_null(HEAD_POLE_MODIFIER_PATH)
	if head_pole_modifier != null and head_pole_modifier.has_method("reset_head_rotation_immediately"):
		head_pole_modifier.call("reset_head_rotation_immediately")


func _update_follow_animation_state() -> void:
	if _dialogue_animation_mode_active:
		return

	if _follow_movement_active:
		if _follow_running_active:
			_travel_to(STATE_RUNNING)
			return
		_travel_to(STATE_WALKING)
		return

	_travel_to(STATE_IDLE)


func _pause_friend_following() -> void:
	var friend_follow_state := get_node_or_null(FRIEND_FOLLOW_STATE_PATH)
	if friend_follow_state != null and friend_follow_state.has_method("pause_following"):
		friend_follow_state.call("pause_following")
	set_follow_navigation(Vector3.ZERO)


func _resume_friend_following() -> void:
	var friend_follow_state := get_node_or_null(FRIEND_FOLLOW_STATE_PATH)
	if friend_follow_state != null and friend_follow_state.has_method("resume_following"):
		friend_follow_state.call("resume_following")
	_update_look_tracking_state()


func _travel_to(state_name: StringName) -> void:
	if _playback == null or _current_state == state_name:
		return

	_current_state = state_name
	_playback.travel(state_name)


func _rotate_towards(direction: Vector3, delta: float) -> void:
	var target_rotation := atan2(direction.x, direction.z)
	var target_basis := Basis.from_euler(Vector3(0.0, target_rotation, 0.0))
	var turn_weight := clampf(delta * _follow_turn_speed, 0.0, 1.0)
	var current_transform := global_transform
	current_transform.basis = current_transform.basis.orthonormalized().slerp(target_basis, turn_weight)
	global_transform = current_transform


func _prepare_locomotion_animation(animation_name: StringName, speed_scale: float) -> void:
	var library: AnimationLibrary = animation_player.get_animation_library("")
	if library == null:
		return

	var animation_key := StringName(animation_name)
	var source_animation: Animation = library.get_animation(animation_key)
	if source_animation == null:
		return

	if source_animation.has_meta(PREPARED_SPEED_SCALE_META):
		if _root_motion_track_path.is_empty():
			var existing_root_track_index := _find_root_position_track(source_animation)
			if existing_root_track_index >= 0:
				_root_motion_track_path = source_animation.track_get_path(existing_root_track_index)
		return

	var animation: Animation = source_animation.duplicate(true) as Animation
	if animation == null:
		return

	for track_index in animation.get_track_count():
		var key_count := animation.track_get_key_count(track_index)
		for key_index in key_count:
			var key_time := animation.track_get_key_time(track_index, key_index)
			animation.track_set_key_time(track_index, key_index, key_time / speed_scale)

	animation.length = source_animation.length / speed_scale
	animation.set_meta(PREPARED_SPEED_SCALE_META, speed_scale)
	library.remove_animation(animation_key)
	library.add_animation(animation_key, animation)
	if _root_motion_track_path.is_empty():
		var root_track_index := _find_root_position_track(animation)
		if root_track_index >= 0:
			_root_motion_track_path = animation.track_get_path(root_track_index)


func _find_root_position_track(animation: Animation) -> int:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue

		var track_path := String(animation.track_get_path(track_index))
		if track_path.begins_with("Rig"):
			return track_index

	return -1


func _configure_root_motion_track() -> void:
	if animation_tree == null or _root_motion_track_path.is_empty():
		return

	animation_tree.root_motion_track = _root_motion_track_path


func _apply_root_motion() -> void:
	if animation_tree == null or animation_tree.root_motion_track.is_empty():
		return

	var root_motion: Vector3 = animation_tree.get_root_motion_position()
	root_motion.y = 0.0
	if root_motion.is_zero_approx():
		return

	var remaining_motion := global_transform.basis * root_motion
	for _slide_index in range(MAX_COLLISION_SLIDES):
		if remaining_motion.is_zero_approx():
			break

		var collision := move_and_collide(remaining_motion)
		if collision == null:
			break

		remaining_motion = collision.get_remainder().slide(collision.get_normal())


func _update_look_tracking_state() -> void:
	var look_tracking := get_node_or_null(LOOK_TRACKING_PATH)
	if look_tracking != null and look_tracking.has_method("set_tracking_enabled"):
		look_tracking.call("set_tracking_enabled", not _follow_movement_active)
