extends Node3D

const FOLLOW_ANGLE_LERP_SPEED := 4.0
const FOLLOW_POSITION_LERP_SPEED := 3.0
const ROTATION_LERP_SPEED := 6.0
const LOOK_LERP_SPEED := 4.0
const FOCUS_HEIGHT := 1.6
const BASE_FOV := 52.0
const RUN_TILT_OFFSET := 0.55
const RUN_TOWARD_TILT_MULTIPLIER := 1.35
const RUN_AWAY_TILT_MULTIPLIER := 0.65
const TILT_BOOST_START_SPEED := 1.5
const TILT_BOOST_MAX_SPEED := 6.0
const RUN_TOWARD_FOV_BOOST := 6.0
const ANGLE_LOOK_AHEAD := 0.08
const MIN_DIRECTION_LENGTH_SQUARED := 0.0001
const MIN_LOOK_FORWARD_DISTANCE := 3.0
const MIN_TARGET_MOVE_DISTANCE := 0.02

@export var target_path: NodePath = ^"../PlayerCharacter"
@export var lap_track_path: NodePath = ^"../LapTrack"
@export_enum("Inner", "Outer") var lane_side := 1

var _target: Node3D
var _lap_track: LapTrack
var _lane_path: Path3D
var _curve: Curve3D
var _game_camera: Camera3D
var _last_target_position := Vector3.ZERO
var _look_height_offset := 0.0
var _fov_offset := 0.0
var _smoothed_focus_point := Vector3.ZERO
var _target_progress := 0.0
var _movement_direction_sign := 1.0
var _track_direction_sign := 1.0
var _is_initialized := false
var _follow_active := false
var _camera_radius := 0.0
var _camera_height := 0.0
var _camera_angle_offset := 0.0
var _camera_angle := 0.0
var _last_progress_sample_position := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_node_or_null(target_path) as Node3D
	_lap_track = get_node_or_null(lap_track_path) as LapTrack
	_game_camera = $GameCamera

	if _target == null or _lap_track == null or _game_camera == null:
		set_process(false)
		return

	_lane_path = _lap_track.get_lane_path(lane_side)
	_curve = _lane_path.curve if _lane_path != null else null
	if _curve == null:
		set_process(false)
		return

	call_deferred("_initialize_from_track_state")


func _process(delta: float) -> void:
	if _target == null or _curve == null or _lane_path == null or not _is_initialized:
		return
	if not _follow_active:
		return

	_update_target_progress()
	_update_camera_transform(delta)


func activate_game_camera() -> void:
	if _game_camera != null:
		_game_camera.current = true


func set_follow_active(value: bool) -> void:
	_follow_active = value


func _initialize_from_track_state() -> void:
	if _target == null or _curve == null or _lane_path == null or _game_camera == null:
		return

	_target_progress = _get_closest_progress_for_target()
	_track_direction_sign = _infer_track_direction_sign(_target_progress)
	_movement_direction_sign = _track_direction_sign

	var target_angle := _get_angle_for_progress(_target_progress)
	var target_local_position := _lap_track.to_local(_target.global_position)
	_camera_radius = Vector2(target_local_position.x, target_local_position.z).length()
	_camera_height = target_local_position.y
	_camera_angle = target_angle
	_camera_angle_offset = 0.0
	global_position = _target.global_position

	_last_target_position = _target.global_position
	_last_progress_sample_position = _target.global_position
	_smoothed_focus_point = _target.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
	_is_initialized = true


func _update_target_progress() -> void:
	var current_target_position := _target.global_position
	var planar_motion := current_target_position - _last_progress_sample_position
	planar_motion.y = 0.0
	if planar_motion.length() < MIN_TARGET_MOVE_DISTANCE:
		return

	var previous_progress := _target_progress
	_target_progress = _get_closest_progress_for_target()
	var progress_delta := _get_wrapped_progress_delta(previous_progress, _target_progress)
	if absf(progress_delta) > 0.001:
		_movement_direction_sign = sign(progress_delta)
	_last_progress_sample_position = current_target_position


func _update_camera_transform(delta: float) -> void:
	var target_angle := _get_angle_for_progress(_target_progress)
	var desired_camera_angle := wrapf(target_angle + _camera_angle_offset, -PI, PI)
	var angle_delta := _get_wrapped_angle_delta(_camera_angle, desired_camera_angle)
	_camera_angle = wrapf(
		_camera_angle + (angle_delta * minf(delta * FOLLOW_ANGLE_LERP_SPEED, 1.0)),
		-PI,
		PI
	)

	var desired_world_position := _lap_track.to_global(
		Vector3(
			sin(_camera_angle) * _camera_radius,
			_camera_height,
			cos(_camera_angle) * _camera_radius
		)
	)
	global_position = global_position.lerp(
		desired_world_position,
		minf(delta * FOLLOW_POSITION_LERP_SPEED, 1.0)
	)

	var tangent := _get_camera_tangent_world(_camera_angle)
	if tangent.length_squared() > MIN_DIRECTION_LENGTH_SQUARED:
		var target_basis := Basis.looking_at(tangent.normalized(), Vector3.UP)
		global_basis = global_basis.slerp(target_basis, minf(delta * ROTATION_LERP_SPEED, 1.0))

	var target_position := _target.global_position
	var move_delta := target_position - _last_target_position
	_last_target_position = target_position

	var desired_look_height_offset := 0.0
	var desired_fov_offset := 0.0
	var planar_delta := Vector2(move_delta.x, move_delta.z)
	if planar_delta.length_squared() > 0.000001:
		var planar_speed := planar_delta.length() / maxf(delta, 0.000001)
		var move_direction := planar_delta.normalized()
		var to_camera := Vector2(
			_game_camera.global_position.x - target_position.x,
			_game_camera.global_position.z - target_position.z
		)
		if to_camera.length_squared() > 0.000001:
			var move_toward_camera := move_direction.dot(to_camera.normalized())
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

	var look_weight := minf(delta * LOOK_LERP_SPEED, 1.0)
	_look_height_offset = lerpf(_look_height_offset, desired_look_height_offset, look_weight)
	_fov_offset = lerpf(_fov_offset, desired_fov_offset, look_weight)

	var focus_point := target_position + Vector3(0.0, FOCUS_HEIGHT + _look_height_offset, 0.0)
	_smoothed_focus_point = _smoothed_focus_point.lerp(focus_point, look_weight)
	_game_camera.fov = BASE_FOV + _fov_offset
	_game_camera.look_at(_get_clamped_focus_point(), Vector3.UP)


func _get_closest_progress_for_target() -> float:
	var lane_local_position := _lane_path.to_local(_target.global_position)
	return _curve.get_closest_offset(lane_local_position)


func _get_angle_for_progress(progress: float) -> float:
	var point_world := _get_world_point(progress)
	var point_local := _lap_track.to_local(point_world)
	return atan2(point_local.x, point_local.z)


func _get_world_point(offset: float) -> Vector3:
	return _lane_path.to_global(_curve.sample_baked(offset, true))


func _get_wrapped_progress_delta(from_offset: float, to_offset: float) -> float:
	var baked_length := maxf(_curve.get_baked_length(), 0.001)
	return wrapf((to_offset - from_offset) + (baked_length * 0.5), 0.0, baked_length) - (baked_length * 0.5)


func _get_wrapped_angle_delta(from_angle: float, to_angle: float) -> float:
	return wrapf((to_angle - from_angle) + PI, 0.0, TAU) - PI


func _infer_track_direction_sign(progress: float) -> float:
	var current_angle := _get_angle_for_progress(progress)
	var next_angle := _get_angle_for_progress(progress + 1.0)
	var angle_delta := _get_wrapped_angle_delta(current_angle, next_angle)
	if absf(angle_delta) <= 0.0001:
		return 1.0
	return sign(angle_delta)


func _get_camera_tangent_world(angle: float) -> Vector3:
	var current_local := Vector3(
		sin(angle) * _camera_radius,
		_camera_height,
		cos(angle) * _camera_radius
	)
	var next_local := Vector3(
		sin(angle + (ANGLE_LOOK_AHEAD * _track_direction_sign)) * _camera_radius,
		_camera_height,
		cos(angle + (ANGLE_LOOK_AHEAD * _track_direction_sign)) * _camera_radius
	)
	var current_world := _lap_track.to_global(current_local)
	var next_world := _lap_track.to_global(next_local)
	var tangent := next_world - current_world
	tangent.y = 0.0
	return tangent


func _get_clamped_focus_point() -> Vector3:
	var camera_position := _game_camera.global_position
	var camera_forward := -global_basis.z
	camera_forward.y = 0.0
	if camera_forward.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		camera_forward = -_game_camera.global_basis.z
		camera_forward.y = 0.0
	if camera_forward.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		camera_forward = Vector3.FORWARD
	camera_forward = camera_forward.normalized()

	var camera_right := camera_forward.cross(Vector3.UP)
	if camera_right.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		camera_right = Vector3.RIGHT
	camera_right = camera_right.normalized()
	var camera_up := Vector3.UP

	var offset := _smoothed_focus_point - camera_position
	var forward_distance := maxf(offset.dot(camera_forward), MIN_LOOK_FORWARD_DISTANCE)
	var right_distance := offset.dot(camera_right)
	var up_distance := offset.dot(camera_up)

	return (
		camera_position
		+ (camera_forward * forward_distance)
		+ (camera_right * right_distance)
		+ (camera_up * up_distance)
	)
