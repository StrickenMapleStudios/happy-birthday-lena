extends Node3D

const FOLLOW_LERP_SPEED := 4.0
const LOOK_LERP_SPEED := 4.0
const FOCUS_HEIGHT := 1.6
const BASE_FOV := 60.0
const RUN_TILT_OFFSET := 0.55
const RUN_TOWARD_TILT_MULTIPLIER := 1.35
const RUN_AWAY_TILT_MULTIPLIER := 0.65
const TILT_BOOST_START_SPEED := 1.5
const TILT_BOOST_MAX_SPEED := 6.0
const RUN_TOWARD_FOV_BOOST := 6.0
const PAUSE_FOCUS_DURATION := 0.5
const PAUSE_FOCUS_OFFSET := Vector3(0.0, 4.6, 6.9)
const PAUSE_FOCUS_FOV_OFFSET := -3.0
const LABYRINTH_TRANSITION_DURATION := 0.6
const LABYRINTH_MOUSE_SENSITIVITY := 0.0035
const LABYRINTH_PITCH_LIMIT := deg_to_rad(75.0)
const LABYRINTH_FOV := 82.0
signal labyrinth_view_yaw_changed(yaw: float)

@export var target_path: NodePath = ^"../character"

enum CameraMode {
	FOLLOW,
	LABYRINTH,
}

var _target: Node3D
var _game_camera: Camera3D
var _last_target_position := Vector3.ZERO
var _look_height_offset: float = 0.0
var _fov_offset: float = 0.0
var _pause_focus_weight: float = 0.0
var _smoothed_target_position := Vector3.ZERO
var _smoothed_focus_point := Vector3.ZERO
var _default_camera_local_position := Vector3.ZERO
var _pause_focus_tween: Tween
var _labyrinth_transition_tween: Tween
var _camera_mode := CameraMode.FOLLOW
var _labyrinth_blend := 0.0
var _labyrinth_yaw := 0.0
var _labyrinth_pitch := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_node_or_null(target_path) as Node3D
	_game_camera = $GameCamera

	activate_game_camera()

	if _target == null or _game_camera == null:
		return

	_default_camera_local_position = _game_camera.position
	_smoothed_target_position = _target.global_position
	_last_target_position = _target.global_position
	_smoothed_focus_point = _target.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
	_update_camera(1.0)


func _process(delta: float) -> void:
	if _target == null:
		return

	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _camera_mode != CameraMode.LABYRINTH:
		return
	if _labyrinth_blend <= 0.0:
		return
	if not (event is InputEventMouseMotion):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	var mouse_motion := event as InputEventMouseMotion
	_labyrinth_yaw -= mouse_motion.relative.x * LABYRINTH_MOUSE_SENSITIVITY
	_labyrinth_pitch = clampf(
		_labyrinth_pitch - mouse_motion.relative.y * LABYRINTH_MOUSE_SENSITIVITY,
		-LABYRINTH_PITCH_LIMIT,
		LABYRINTH_PITCH_LIMIT
	)
	labyrinth_view_yaw_changed.emit(_labyrinth_yaw)
	get_viewport().set_input_as_handled()


func _update_camera(delta: float) -> void:
	var target_position: Vector3 = _target.global_position
	var desired_position: Vector3 = target_position
	var follow_weight: float = minf(delta * FOLLOW_LERP_SPEED, 1.0)
	_smoothed_target_position = _smoothed_target_position.lerp(desired_position, follow_weight)
	global_position = _smoothed_target_position

	var move_delta: Vector3 = target_position - _last_target_position
	_last_target_position = target_position

	var desired_look_height_offset: float = 0.0
	var desired_fov_offset: float = 0.0
	var planar_delta: Vector2 = Vector2(move_delta.x, move_delta.z)
	if planar_delta.length_squared() > 0.000001:
		var planar_speed := planar_delta.length() / maxf(delta, 0.000001)
		var move_direction: Vector2 = planar_delta.normalized()
		var to_camera: Vector2 = Vector2(
			_game_camera.global_position.x - target_position.x,
			_game_camera.global_position.z - target_position.z
		).normalized()
		var move_toward_camera: float = move_direction.dot(to_camera)
		var speed_weight := inverse_lerp(
			TILT_BOOST_START_SPEED,
			TILT_BOOST_MAX_SPEED,
			planar_speed
		)
		var tilt_weight := move_toward_camera * speed_weight
		if tilt_weight > 0.0:
			desired_look_height_offset = -RUN_TILT_OFFSET * RUN_TOWARD_TILT_MULTIPLIER * tilt_weight
			desired_fov_offset = RUN_TOWARD_FOV_BOOST * tilt_weight
		elif tilt_weight < 0.0:
			desired_look_height_offset = -RUN_TILT_OFFSET * RUN_AWAY_TILT_MULTIPLIER * tilt_weight

	var look_weight: float = minf(delta * LOOK_LERP_SPEED, 1.0)
	_look_height_offset = lerpf(_look_height_offset, desired_look_height_offset, look_weight)
	_fov_offset = lerpf(_fov_offset, desired_fov_offset, look_weight)

	_game_camera.position = _default_camera_local_position.lerp(PAUSE_FOCUS_OFFSET, _pause_focus_weight)

	var focus_point: Vector3 = target_position + Vector3(0.0, FOCUS_HEIGHT + _look_height_offset, 0.0)
	_smoothed_focus_point = _smoothed_focus_point.lerp(focus_point, look_weight)
	_game_camera.fov = BASE_FOV + _fov_offset + (PAUSE_FOCUS_FOV_OFFSET * _pause_focus_weight)
	_game_camera.look_at(_smoothed_focus_point, Vector3.UP)

	var follow_camera_transform := _game_camera.global_transform
	var follow_camera_fov := _game_camera.fov
	if _labyrinth_blend <= 0.0:
		return

	var labyrinth_transform := _get_labyrinth_camera_transform()
	_game_camera.global_transform = follow_camera_transform.interpolate_with(labyrinth_transform, _labyrinth_blend)
	_game_camera.fov = lerpf(follow_camera_fov, LABYRINTH_FOV, _labyrinth_blend)


func activate_game_camera() -> void:
	if _game_camera == null:
		return

	_game_camera.current = true


func enter_labyrinth_view() -> void:
	if _target == null or _game_camera == null:
		return

	_camera_mode = CameraMode.LABYRINTH
	_sync_labyrinth_angles_from_camera()
	labyrinth_view_yaw_changed.emit(_labyrinth_yaw)
	_start_labyrinth_transition(1.0)


func exit_labyrinth_view() -> void:
	if _game_camera == null:
		return

	_camera_mode = CameraMode.FOLLOW
	_start_labyrinth_transition(0.0)


func begin_pause_focus() -> void:
	if _game_camera == null:
		return

	_start_pause_focus_tween(1.0)


func end_pause_focus() -> void:
	if _game_camera == null:
		return

	_start_pause_focus_tween(0.0)


func end_pause_focus_and_wait() -> void:
	if _game_camera == null:
		return

	_start_pause_focus_tween(0.0)
	if _pause_focus_tween != null and _pause_focus_tween.is_valid():
		await _pause_focus_tween.finished


func _start_pause_focus_tween(target_weight: float) -> void:
	_kill_pause_focus_tween()
	_pause_focus_tween = create_tween()
	_pause_focus_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pause_focus_tween.set_trans(Tween.TRANS_CUBIC)
	_pause_focus_tween.set_ease(Tween.EASE_OUT)
	_pause_focus_tween.tween_property(self, "_pause_focus_weight", target_weight, PAUSE_FOCUS_DURATION)


func reset_pause_focus_immediately() -> void:
	if _game_camera == null:
		return

	_kill_pause_focus_tween()
	_pause_focus_weight = 0.0
	_game_camera.position = _default_camera_local_position


func _kill_pause_focus_tween() -> void:
	if _pause_focus_tween != null and _pause_focus_tween.is_valid():
		_pause_focus_tween.kill()
	_pause_focus_tween = null


func get_labyrinth_yaw() -> float:
	return _labyrinth_yaw


func _get_labyrinth_camera_transform() -> Transform3D:
	var mount := _get_first_person_mount()
	var position := mount.global_position if mount != null else _target.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
	var yaw_offset := 0.0
	if mount != null:
		yaw_offset = mount.rotation.y
	var basis := Basis.from_euler(Vector3(0.0, _labyrinth_yaw + yaw_offset, 0.0)) * Basis.from_euler(Vector3(_labyrinth_pitch, 0.0, 0.0))
	return Transform3D(basis, position)


func _get_first_person_mount() -> Node3D:
	if _target == null or not _target.has_method("get_first_person_camera_mount"):
		return null

	return _target.call("get_first_person_camera_mount") as Node3D


func _sync_labyrinth_angles_from_camera() -> void:
	var forward := -_game_camera.global_transform.basis.z
	var planar_forward := Vector2(forward.x, forward.z)
	if planar_forward.length_squared() > 0.000001:
		_labyrinth_yaw = atan2(planar_forward.x, planar_forward.y)
	if forward.length_squared() > 0.000001:
		_labyrinth_pitch = clampf(asin(clampf(forward.y, -1.0, 1.0)), -LABYRINTH_PITCH_LIMIT, LABYRINTH_PITCH_LIMIT)


func _start_labyrinth_transition(target_blend: float) -> void:
	_kill_labyrinth_transition_tween()
	_labyrinth_transition_tween = create_tween()
	_labyrinth_transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_labyrinth_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_labyrinth_transition_tween.set_ease(Tween.EASE_OUT)
	_labyrinth_transition_tween.tween_property(self, "_labyrinth_blend", target_blend, LABYRINTH_TRANSITION_DURATION)


func _kill_labyrinth_transition_tween() -> void:
	if _labyrinth_transition_tween != null and _labyrinth_transition_tween.is_valid():
		_labyrinth_transition_tween.kill()
	_labyrinth_transition_tween = null
