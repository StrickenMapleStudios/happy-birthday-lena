extends Node3D

const FOLLOW_PROGRESS_LERP_SPEED := 4.0
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
const PATH_LOOK_AHEAD_DISTANCE := 1.8
const MIN_BAKED_LENGTH := 0.001
const MIN_DIRECTION_LENGTH_SQUARED := 0.0001
const MIN_LOOK_FORWARD_DISTANCE := 3.0

@export var target_path: NodePath = ^"../PlayerCharacter"
@export var lap_track_path: NodePath = ^"../LapTrack"
@export_enum("Inner", "Outer") var lane_side := 1
@export_range(0.0, 24.0, 0.1) var trail_distance := 8.2

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
var _camera_progress := 0.0
var _camera_target_progress := 0.0
var _movement_direction_sign := 1.0
var _track_direction_sign := 1.0
var _is_initialized := false
var _follow_active := false


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

	_update_progress(delta)
	_update_camera_transform(delta)


func activate_game_camera() -> void:
	if _game_camera != null:
		_game_camera.current = true


func set_follow_active(value: bool) -> void:
	_follow_active = value
	if _follow_active:
		_camera_progress = _get_closest_progress_for_world_position(global_position)
		_camera_target_progress = _get_trailing_progress(_target_progress)


func _initialize_from_track_state() -> void:
	if _target == null or _curve == null or _lane_path == null or _game_camera == null:
		return

	_target_progress = _get_closest_progress_for_target()
	_track_direction_sign = _infer_track_direction_sign(_target_progress)
	_movement_direction_sign = _track_direction_sign
	_camera_progress = _get_closest_progress_for_world_position(global_position)
	_camera_target_progress = _get_trailing_progress(_target_progress)
	_last_target_position = _target.global_position
	_smoothed_focus_point = _target.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
	_is_initialized = true


func _update_progress(delta: float) -> void:
	var baked_length := _get_baked_length()
	var closest_progress := _get_closest_progress_for_target()
	var target_progress_delta := _get_wrapped_delta(_target_progress, closest_progress, baked_length)
	if absf(target_progress_delta) > 0.001:
		_movement_direction_sign = sign(target_progress_delta)
	_target_progress = wrapf(_target_progress + target_progress_delta, 0.0, baked_length)

	_camera_target_progress = _get_trailing_progress(_target_progress)
	var progress_delta := _get_wrapped_delta(_camera_progress, _camera_target_progress, baked_length)
	var follow_weight := minf(delta * FOLLOW_PROGRESS_LERP_SPEED, 1.0)
	_camera_progress = wrapf(_camera_progress + (progress_delta * follow_weight), 0.0, baked_length)


func _update_camera_transform(delta: float) -> void:
	var current_world := _get_world_point(_camera_progress)
	var facing_world := _get_world_point(
		_camera_progress + (PATH_LOOK_AHEAD_DISTANCE * _track_direction_sign)
	)
	var tangent := facing_world - current_world
	tangent.y = 0.0
	if tangent.length_squared() > MIN_DIRECTION_LENGTH_SQUARED:
		var target_basis := Basis.looking_at(tangent.normalized(), Vector3.UP)
		global_basis = global_basis.slerp(target_basis, minf(delta * ROTATION_LERP_SPEED, 1.0))
	global_position = global_position.lerp(
		current_world,
		minf(delta * FOLLOW_POSITION_LERP_SPEED, 1.0)
	)

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


func _snap_to_progress(progress: float) -> void:
	var current_world := _get_world_point(progress)
	var facing_world := _get_world_point(
		progress + (PATH_LOOK_AHEAD_DISTANCE * _track_direction_sign)
	)
	var tangent := facing_world - current_world
	tangent.y = 0.0
	global_position = current_world
	if tangent.length_squared() > MIN_DIRECTION_LENGTH_SQUARED:
		global_basis = Basis.looking_at(tangent.normalized(), Vector3.UP)
	_game_camera.look_at(_get_clamped_focus_point(), Vector3.UP)


func _get_closest_progress_for_target() -> float:
	var lane_local_position := _lane_path.to_local(_target.global_position)
	return _curve.get_closest_offset(lane_local_position)


func _get_closest_progress_for_world_position(world_position: Vector3) -> float:
	var lane_local_position := _lane_path.to_local(world_position)
	return _curve.get_closest_offset(lane_local_position)


func _get_world_point(offset: float) -> Vector3:
	return _lane_path.to_global(_curve.sample_baked(wrapf(offset, 0.0, _get_baked_length()), true))


func _get_baked_length() -> float:
	return maxf(_curve.get_baked_length(), MIN_BAKED_LENGTH)


func _get_trailing_progress(target_progress: float) -> float:
	return wrapf(target_progress + (_movement_direction_sign * trail_distance), 0.0, _get_baked_length())


func _infer_track_direction_sign(progress: float) -> float:
	var current_world := _get_world_point(progress)
	var forward_world := _get_world_point(progress + PATH_LOOK_AHEAD_DISTANCE)
	var tangent := forward_world - current_world
	tangent.y = 0.0
	if tangent.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return 1.0

	var target_forward := -_target.global_basis.z
	target_forward.y = 0.0
	if target_forward.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return 1.0

	return 1.0 if target_forward.normalized().dot(tangent.normalized()) >= 0.0 else -1.0


func _get_clamped_focus_point() -> Vector3:
	var camera_position := _game_camera.global_position
	var camera_forward := -_game_camera.global_basis.z
	var camera_right := _game_camera.global_basis.x
	var camera_up := _game_camera.global_basis.y

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


func _get_wrapped_delta(from_offset: float, to_offset: float, length: float) -> float:
	return wrapf((to_offset - from_offset) + (length * 0.5), 0.0, length) - (length * 0.5)
