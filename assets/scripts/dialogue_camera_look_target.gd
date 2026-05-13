extends Node

class_name DialogueCameraLookTarget

@export var tracked_node_path: NodePath = ^".."
@export var target_height_offset := 0.0
@export var instant_rotation := true

var _tracking_enabled := false
var _target_camera: Camera3D


func set_tracking_enabled(value: bool) -> void:
	_tracking_enabled = value
	if not value:
		_target_camera = null


func set_target_camera(camera: Camera3D) -> void:
	_target_camera = camera


func get_tracked_node() -> Node3D:
	return get_node_or_null(tracked_node_path) as Node3D


func get_current_target_world_position() -> Vector3:
	if not _tracking_enabled or _target_camera == null or not is_instance_valid(_target_camera):
		return Vector3.INF

	return _target_camera.global_position + Vector3.UP * target_height_offset


func should_rotate_instantly() -> bool:
	return instant_rotation
