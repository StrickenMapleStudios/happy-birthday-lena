extends Node

signal lap_completed(total_laps: int)

@export var lap_track_path: NodePath = ^"../LapTrack"
@export var runner_path: NodePath = ^"../NpcRunner"
@export_enum("Inner", "Outer") var lane_side := 1
@export_range(0.5, 4.0, 0.05) var root_motion_speed_multiplier := 1.35
@export_range(0.25, 8.0, 0.05) var look_ahead_distance := 1.8
@export_range(0.0, 4.0, 0.05) var runner_height_offset := 0.0

var _lap_track: LapTrack
var _runner: CharacterBody3D
var _lane_path: Path3D
var _curve: Curve3D
var _progress := 0.0
var _completed_laps := 0


func _ready() -> void:
	restart()


func restart() -> void:
	_lap_track = get_node_or_null(lap_track_path) as LapTrack
	_runner = get_node_or_null(runner_path) as CharacterBody3D
	if _lap_track == null or _runner == null:
		set_process(false)
		return

	_lane_path = _lap_track.get_lane_path(lane_side)
	_curve = _lane_path.curve if _lane_path != null else null
	if _curve == null:
		set_process(false)
		return

	set_process(true)
	if _runner.has_method("set_external_motion_enabled"):
		_runner.call("set_external_motion_enabled", true)

	var lane_local_position: Vector3 = _lane_path.to_local(_runner.global_position)
	_progress = _curve.get_closest_offset(lane_local_position)
	_completed_laps = 0
	_snap_runner_to_curve()


func _physics_process(_delta: float) -> void:
	if _curve == null or _runner == null or _lane_path == null:
		return

	var baked_length: float = maxf(_curve.get_baked_length(), 0.001)
	var root_motion_step := 0.0
	if _runner.has_method("consume_root_motion_distance"):
		root_motion_step = float(_runner.call("consume_root_motion_distance"))
	if root_motion_step <= 0.0001:
		return

	var previous_progress := _progress
	_progress = wrapf(_progress + (root_motion_step * root_motion_speed_multiplier), 0.0, baked_length)
	if _progress < previous_progress:
		_completed_laps += 1
		lap_completed.emit(_completed_laps)

	var current_world: Vector3 = _get_world_point(_progress)
	var look_offset: float = wrapf(_progress + look_ahead_distance, 0.0, baked_length)
	var look_world: Vector3 = _get_world_point(look_offset)
	var direction: Vector3 = look_world - current_world
	direction.y = 0.0

	_runner.global_position = current_world + Vector3(0.0, runner_height_offset, 0.0)
	if _runner.has_method("set_follow_navigation"):
		_runner.call("set_follow_navigation", direction, 9.0, true)


func get_completed_laps() -> int:
	return _completed_laps


func _snap_runner_to_curve() -> void:
	var current_world: Vector3 = _get_world_point(_progress)
	var look_world: Vector3 = _get_world_point(_progress + look_ahead_distance)
	var direction: Vector3 = look_world - current_world
	direction.y = 0.0

	_runner.global_position = current_world + Vector3(0.0, runner_height_offset, 0.0)
	if _runner.has_method("face_towards_position"):
		_runner.call("face_towards_position", current_world + direction)
	if _runner.has_method("set_follow_navigation"):
		_runner.call("set_follow_navigation", direction, 9.0, true)


func _get_world_point(offset: float) -> Vector3:
	var baked_length: float = maxf(_curve.get_baked_length(), 0.001)
	var wrapped_offset: float = wrapf(offset, 0.0, baked_length)
	return _lane_path.to_global(_curve.sample_baked(wrapped_offset, true))
