extends CharacterBody3D

const WALKING_TURN_SPEED := 6.0
const RUNNING_TURN_SPEED := 9.0
const ANIMATION_WALKING := "Walking"
const ANIMATION_RUNNING := "Running"
const ANIMATION_EVENT_METHOD := &"handle_event"
const WALKING_SPEED_SCALE := 2.0
const RUNNING_SPEED_SCALE := 5.0
const EVENT_FOOTSTEP := &"footstep"
const FOOTSTEP_SOUND_ID := &"footstep_grass"
const PREPARED_FOOTSTEP_META := &"prepared_footstep_events"
const FOOTSTEP_EVENT_TIMINGS := {
	ANIMATION_WALKING: [0.18, 0.68],
	ANIMATION_RUNNING: [0.16, 0.66],
}

const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_MOVE_FORWARD := "move_forward"
const ACTION_MOVE_BACK := "move_back"
const ACTION_SPEED_UP := "speed_up"

const STATE_IDLE := "Idle"
const STATE_WALKING := "Walking"
const STATE_RUNNING := "Running"
const PREPARED_SPEED_SCALE_META := &"prepared_speed_scale"
const CHARACTER_IDENTITY_PATH := ^"CharacterIdentity"
const MAX_COLLISION_SLIDES := 4

@onready var model: Node3D = $Model
@onready var animation_tree: AnimationTree = $Model/AnimationPlayer/AnimationTree
@onready var dialogue_animation_tree: AnimationTree = $Model/AnimationPlayer/DialogueAnimationTree
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer

var _playback: AnimationNodeStateMachinePlayback
var _current_state := StringName()
var _root_motion_track_path := NodePath()
var _controls_enabled := true
var _dialogue_animation_mode_active := false
var _saved_animation_tree: AnimationTree


func _ready() -> void:
	_ensure_input_map()
	add_to_group(&"player_character")
	if animation_player == null or animation_tree == null:
		push_warning("Player character is missing AnimationPlayer/AnimationTree. Locomotion animation setup was skipped.")
		return
	animation_tree.active = true
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = false
	_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_prepare_locomotion_animation(ANIMATION_WALKING, WALKING_SPEED_SCALE, STATE_WALKING)
	_prepare_locomotion_animation(ANIMATION_RUNNING, RUNNING_SPEED_SCALE, STATE_RUNNING)
	_configure_root_motion_track()
	_sync_animation_flags(false, false)
	_travel_to(STATE_IDLE)


func _process(delta: float) -> void:
	if not _controls_enabled:
		_sync_animation_flags(false, false)
		_update_animation_state(false, false)
		return

	var input := Input.get_vector(
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT,
		ACTION_MOVE_FORWARD,
		ACTION_MOVE_BACK
	)
	var is_moving := input.length_squared() > 0.0
	var speed_up := is_moving and Input.is_action_pressed(ACTION_SPEED_UP)

	_sync_animation_flags(is_moving, speed_up)
	_update_animation_state(is_moving, speed_up)

	if is_moving:
		var direction := Vector3(-input.x, 0.0, -input.y).normalized()
		_rotate_towards(direction, delta)

	_apply_root_motion()


func _update_animation_state(is_moving: bool, speed_up: bool) -> void:
	if not is_moving:
		_travel_to(STATE_IDLE)
		return

	if not speed_up:
		_travel_to(STATE_WALKING)
		return

	_travel_to(STATE_RUNNING)


func _travel_to(state_name: StringName) -> void:
	if _playback == null or _current_state == state_name:
		return

	_current_state = state_name
	_playback.travel(state_name)


func _sync_animation_flags(is_moving: bool, speed_up: bool) -> void:
	if animation_tree == null:
		return
	animation_tree.set("parameters/conditions/Moving", is_moving)
	animation_tree.set("parameters/conditions/SpeedUp", speed_up)


func _rotate_towards(direction: Vector3, delta: float) -> void:
	var target_rotation := atan2(direction.x, direction.z)
	var target_basis := Basis.from_euler(Vector3(0.0, target_rotation, 0.0))
	var turn_weight := clampf(delta * _get_current_turn_speed(), 0.0, 1.0)
	var current_transform := global_transform
	current_transform.basis = current_transform.basis.orthonormalized().slerp(target_basis, turn_weight)
	global_transform = current_transform


func _get_current_turn_speed() -> float:
	match _current_state:
		STATE_RUNNING:
			return RUNNING_TURN_SPEED
		_:
			return WALKING_TURN_SPEED


func _prepare_locomotion_animation(animation_name: StringName, speed_scale: float, _state_name: StringName) -> void:
	if animation_player == null:
		return
	var library: AnimationLibrary = animation_player.get_animation_library("")
	if library == null:
		return

	var animation_key := StringName(animation_name)
	var source_animation: Animation = library.get_animation(animation_key)
	if source_animation == null:
		return

	if source_animation.has_meta(PREPARED_SPEED_SCALE_META):
		_ensure_footstep_events(source_animation, animation_name)
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
	_ensure_footstep_events(animation, animation_name)
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
	if animation_tree == null:
		return
	if animation_tree.root_motion_track.is_empty():
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


func handle_event(event_name: StringName) -> void:
	match event_name:
		EVENT_FOOTSTEP:
			_play_footstep()


func _ensure_footstep_events(animation: Animation, animation_name: StringName) -> void:
	if animation == null or animation.has_meta(PREPARED_FOOTSTEP_META):
		return

	var step_times: Array = FOOTSTEP_EVENT_TIMINGS.get(animation_name, [])
	if step_times.is_empty():
		return

	var track_index := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track_index, NodePath("."))

	for normalized_time in step_times:
		var event_time := clampf(
			animation.length * normalized_time,
			0.0,
			maxf(animation.length - 0.001, 0.0)
		)
		animation.track_insert_key(track_index, event_time, {
			"method": ANIMATION_EVENT_METHOD,
			"args": [EVENT_FOOTSTEP],
		})

	animation.set_meta(PREPARED_FOOTSTEP_META, true)


func _play_footstep() -> void:
	if not _controls_enabled or _dialogue_animation_mode_active:
		return
	if _current_state == STATE_IDLE:
		return

	AudioService.play_sound(FOOTSTEP_SOUND_ID)


func set_controls_enabled(value: bool) -> void:
	_controls_enabled = value
	if not value:
		_sync_animation_flags(false, false)
		_update_animation_state(false, false)


func set_character_visible(value: bool) -> void:
	model.visible = value


func enter_dialogue_animation_mode(_is_talking: bool) -> void:
	if dialogue_animation_tree == null:
		return

	if not _dialogue_animation_mode_active:
		_saved_animation_tree = _get_active_animation_tree(dialogue_animation_tree)
		if _saved_animation_tree != null:
			_saved_animation_tree.active = false
		_dialogue_animation_mode_active = true

	dialogue_animation_tree.active = true


func exit_dialogue_animation_mode() -> void:
	if dialogue_animation_tree == null or not _dialogue_animation_mode_active:
		return

	dialogue_animation_tree.active = false

	if _saved_animation_tree != null:
		_saved_animation_tree.active = true

	_saved_animation_tree = null
	_dialogue_animation_mode_active = false


func get_dialogue_camera_mount() -> Node3D:
	return $DialogueSpeakerPivot


func get_dialogue_speaker_name() -> String:
	var character_identity := get_node_or_null(CHARACTER_IDENTITY_PATH)
	if character_identity != null and character_identity.has_method("get_dialogue_speaker_name"):
		var dialogue_name := String(character_identity.call("get_dialogue_speaker_name")).strip_edges()
		if not dialogue_name.is_empty():
			return dialogue_name

	return name


func face_towards_position(target_position: Vector3) -> void:
	var offset := target_position - global_position
	offset.y = 0.0
	if offset.is_zero_approx():
		return

	var target_rotation := atan2(offset.x, offset.z)
	var current_transform := global_transform
	current_transform.basis = Basis.from_euler(Vector3(0.0, target_rotation, 0.0))
	global_transform = current_transform


func _get_active_animation_tree(excluded_tree: AnimationTree) -> AnimationTree:
	for child in animation_player.get_children():
		var tree := child as AnimationTree
		if tree == null or tree == excluded_tree:
			continue
		if tree.active:
			return tree

	return null


func _ensure_input_map() -> void:
	_ensure_action(ACTION_MOVE_LEFT)
	_ensure_action(ACTION_MOVE_RIGHT)
	_ensure_action(ACTION_MOVE_FORWARD)
	_ensure_action(ACTION_MOVE_BACK)
	_ensure_action(ACTION_SPEED_UP)

	if InputMap.action_get_events(ACTION_MOVE_LEFT).is_empty():
		_add_key_event(ACTION_MOVE_LEFT, KEY_A)
		_add_key_event(ACTION_MOVE_LEFT, KEY_LEFT)
		_add_joypad_motion_event(ACTION_MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0)

	if InputMap.action_get_events(ACTION_MOVE_RIGHT).is_empty():
		_add_key_event(ACTION_MOVE_RIGHT, KEY_D)
		_add_key_event(ACTION_MOVE_RIGHT, KEY_RIGHT)
		_add_joypad_motion_event(ACTION_MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0)

	if InputMap.action_get_events(ACTION_MOVE_FORWARD).is_empty():
		_add_key_event(ACTION_MOVE_FORWARD, KEY_W)
		_add_key_event(ACTION_MOVE_FORWARD, KEY_UP)
		_add_joypad_motion_event(ACTION_MOVE_FORWARD, JOY_AXIS_LEFT_Y, -1.0)

	if InputMap.action_get_events(ACTION_MOVE_BACK).is_empty():
		_add_key_event(ACTION_MOVE_BACK, KEY_S)
		_add_key_event(ACTION_MOVE_BACK, KEY_DOWN)
		_add_joypad_motion_event(ACTION_MOVE_BACK, JOY_AXIS_LEFT_Y, 1.0)

	if InputMap.action_get_events(ACTION_SPEED_UP).is_empty():
		_add_key_event(ACTION_SPEED_UP, KEY_SHIFT)
		_add_joypad_motion_event(ACTION_SPEED_UP, JOY_AXIS_TRIGGER_RIGHT, 1.0)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


func _add_key_event(action_name: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)


func _add_joypad_motion_event(action_name: StringName, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)
