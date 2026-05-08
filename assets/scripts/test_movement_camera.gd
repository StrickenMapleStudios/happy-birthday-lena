extends Node3D

const FOLLOW_LERP_SPEED := 4.0
const LOOK_LERP_SPEED := 4.0
const FOCUS_HEIGHT := 1.6
const RUN_TILT_OFFSET := 0.55

@export var target_path: NodePath = ^"../character"

var _target: Node3D
var _last_target_position := Vector3.ZERO
var _look_height_offset: float = 0.0
var _smoothed_target_position := Vector3.ZERO
var _smoothed_focus_point := Vector3.ZERO


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		return

	_smoothed_target_position = _target.global_position
	_last_target_position = _target.global_position
	_smoothed_focus_point = _target.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
	_update_camera(1.0)


func _process(delta: float) -> void:
	if _target == null:
		return

	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var target_position: Vector3 = _target.global_position
	var desired_position: Vector3 = target_position
	var follow_weight: float = minf(delta * FOLLOW_LERP_SPEED, 1.0)
	_smoothed_target_position = _smoothed_target_position.lerp(desired_position, follow_weight)
	global_position = _smoothed_target_position

	var move_delta: Vector3 = target_position - _last_target_position
	_last_target_position = target_position

	var desired_look_height_offset: float = 0.0
	var planar_delta: Vector2 = Vector2(move_delta.x, move_delta.z)
	if planar_delta.length_squared() > 0.000001:
		var move_direction: Vector2 = planar_delta.normalized()
		var to_camera: Vector2 = Vector2(global_position.x - target_position.x, global_position.z - target_position.z).normalized()
		var move_toward_camera: float = move_direction.dot(to_camera)
		desired_look_height_offset = -move_toward_camera * RUN_TILT_OFFSET

	var look_weight: float = minf(delta * LOOK_LERP_SPEED, 1.0)
	_look_height_offset = lerpf(_look_height_offset, desired_look_height_offset, look_weight)

	var focus_point: Vector3 = target_position + Vector3(0.0, FOCUS_HEIGHT + _look_height_offset, 0.0)
	_smoothed_focus_point = _smoothed_focus_point.lerp(focus_point, look_weight)
	$Camera3D.look_at(_smoothed_focus_point, Vector3.UP)
