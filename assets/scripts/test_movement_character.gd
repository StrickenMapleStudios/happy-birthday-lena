extends Node3D

const WALKING_TURN_SPEED := 6.0
const RUNNING_TURN_SPEED := 9.0
const NARUTO_RUNNING_TURN_SPEED := 11.0
const ANIMATION_WALKING := "Walking"
const ANIMATION_RUNNING := "Running"
const ANIMATION_NARUTO_RUNNING := "NarutoRunning"
const WALKING_SPEED_SCALE := 2.0
const RUNNING_SPEED_SCALE := 5.0
const NARUTO_RUNNING_SPEED_SCALE := 7.0
const RUNNING_LOOPS_TO_NARUTO := 10

const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_MOVE_FORWARD := "move_forward"
const ACTION_MOVE_BACK := "move_back"
const ACTION_SPEED_UP := "speed_up"

const STATE_IDLE := "Idle"
const STATE_WALKING := "Walking"
const STATE_RUNNING := "Running"
const STATE_NARUTO_RUNNING := "NarutoRunning"

@onready var animation_tree: AnimationTree = $AnimationPlayer/AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _playback: AnimationNodeStateMachinePlayback
var _current_state := StringName()
var _running_loops := 0
var _previous_running_play_position := 0.0
var _root_motion_track_path := NodePath()


func _ready() -> void:
	_ensure_input_map()
	animation_tree.active = true
	_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_prepare_locomotion_animation(ANIMATION_WALKING, WALKING_SPEED_SCALE, STATE_WALKING)
	_prepare_locomotion_animation(ANIMATION_RUNNING, RUNNING_SPEED_SCALE, STATE_RUNNING)
	_prepare_locomotion_animation(ANIMATION_NARUTO_RUNNING, NARUTO_RUNNING_SPEED_SCALE, STATE_NARUTO_RUNNING)
	_configure_root_motion_track()
	_sync_animation_flags(false, false)
	_travel_to(STATE_IDLE)


func _process(delta: float) -> void:
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
		var direction := Vector3(input.x, 0.0, input.y).normalized()
		_rotate_towards(direction, delta)

	_apply_root_motion()

	_update_running_loops(is_moving, speed_up)


func _update_animation_state(is_moving: bool, speed_up: bool) -> void:
	if not is_moving:
		_travel_to(STATE_IDLE)
		return

	if not speed_up:
		_travel_to(STATE_WALKING)
		return

	if _running_loops >= RUNNING_LOOPS_TO_NARUTO:
		_travel_to(STATE_NARUTO_RUNNING)
		return

	_travel_to(STATE_RUNNING)


func _travel_to(state_name: StringName) -> void:
	if _playback == null or _current_state == state_name:
		return

	_current_state = state_name
	_running_loops = 0
	_previous_running_play_position = 0.0
	_playback.travel(state_name)


func _update_running_loops(is_moving: bool, speed_up: bool) -> void:
	if not is_moving or not speed_up or _current_state != STATE_RUNNING:
		_running_loops = 0
		_previous_running_play_position = 0.0
		return

	var current_animation_position := _get_current_play_position()
	if current_animation_position < _previous_running_play_position:
		_running_loops += 1
	_previous_running_play_position = current_animation_position


func _sync_animation_flags(is_moving: bool, speed_up: bool) -> void:
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
		STATE_NARUTO_RUNNING:
			return NARUTO_RUNNING_TURN_SPEED
		_:
			return WALKING_TURN_SPEED


func _get_current_play_position() -> float:
	if _playback == null:
		return 0.0

	return _playback.get_current_play_position()


func _prepare_locomotion_animation(animation_name: StringName, speed_scale: float, _state_name: StringName) -> void:
	var library: AnimationLibrary = animation_player.get_animation_library("")
	if library == null:
		return

	var animation_key := StringName(animation_name)
	var source_animation: Animation = library.get_animation(animation_key)
	if source_animation == null:
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
	if _root_motion_track_path.is_empty():
		return

	animation_tree.root_motion_track = _root_motion_track_path


func _apply_root_motion() -> void:
	if animation_tree.root_motion_track.is_empty():
		return

	var root_motion: Vector3 = animation_tree.get_root_motion_position()
	root_motion.y = 0.0
	if root_motion.is_zero_approx():
		return

	global_position += global_transform.basis * root_motion


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
