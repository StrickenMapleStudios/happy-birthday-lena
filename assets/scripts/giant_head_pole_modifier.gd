extends SkeletonModifier3D

class_name GiantHeadPoleModifier

@export var settings: NpcLookTrackingSettings
@export var look_tracking_controller_path: NodePath

var _head_bone_idx := -1
var _smoothed_pose_rotation := Quaternion.IDENTITY
var _smoothed_pose_initialized := false
var _last_update_time_usec := 0


func _ready() -> void:
	_validate_bone_name()


func reset_head_rotation_immediately() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return

	if _head_bone_idx < 0:
		_validate_bone_name()
	if _head_bone_idx < 0:
		return

	var animated_pose_rotation: Quaternion = skeleton.get_bone_pose_rotation(_head_bone_idx)
	_smoothed_pose_rotation = animated_pose_rotation
	_smoothed_pose_initialized = true
	_last_update_time_usec = 0
	skeleton.set_bone_pose_rotation(_head_bone_idx, animated_pose_rotation)


func _validate_bone_name() -> void:
	_head_bone_idx = -1
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or settings == null or settings.rig_head_bone_name == StringName():
		return

	_head_bone_idx = skeleton.find_bone(String(settings.rig_head_bone_name))
	if _head_bone_idx < 0:
		_head_bone_idx = _find_bone_case_insensitive(skeleton, String(settings.rig_head_bone_name))


func _find_bone_case_insensitive(skeleton: Skeleton3D, bone_name: String) -> int:
	var target_name := bone_name.to_lower()
	for bone_idx in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone_idx).to_lower() == target_name:
			return bone_idx

	return -1


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or settings == null:
		return

	if _head_bone_idx < 0:
		_validate_bone_name()
	if _head_bone_idx < 0:
		return

	var delta := _get_modifier_delta()
	var animated_pose_rotation := skeleton.get_bone_pose_rotation(_head_bone_idx)
	var desired_pose_rotation := animated_pose_rotation
	var controller := _get_look_tracking_controller()
	if controller != null:
		var target_world_position: Vector3 = controller.call("get_current_target_world_position")
		if target_world_position != Vector3.INF:
			desired_pose_rotation = _get_target_pose_rotation(animated_pose_rotation, target_world_position)
			if _should_rotate_instantly(controller):
				_smoothed_pose_rotation = desired_pose_rotation
				_smoothed_pose_initialized = true
				skeleton.set_bone_pose_rotation(_head_bone_idx, desired_pose_rotation)
				return

	if not _smoothed_pose_initialized:
		_smoothed_pose_rotation = animated_pose_rotation
		_smoothed_pose_initialized = true

	var weight := clampf(delta * settings.rotation_follow_speed, 0.0, 1.0)
	_smoothed_pose_rotation = _smoothed_pose_rotation.slerp(desired_pose_rotation, weight)
	skeleton.set_bone_pose_rotation(_head_bone_idx, _smoothed_pose_rotation)


func _get_target_pose_rotation(animated_pose_rotation: Quaternion, target_world_position: Vector3) -> Quaternion:
	var controller := _get_look_tracking_controller()
	if controller == null:
		return animated_pose_rotation

	var tracked_node := controller.call("get_tracked_node") as Node3D
	if tracked_node == null:
		return animated_pose_rotation

	var target_local_to_actor := tracked_node.to_local(target_world_position)
	if target_local_to_actor.is_zero_approx():
		return animated_pose_rotation

	var horizontal_distance := Vector2(target_local_to_actor.x, target_local_to_actor.z).length()
	var yaw := atan2(target_local_to_actor.x, target_local_to_actor.z)
	yaw = clampf(yaw, -deg_to_rad(settings.max_yaw_degrees), deg_to_rad(settings.max_yaw_degrees))

	var pitch := 0.0
	if horizontal_distance > 0.0001:
		pitch = atan2(target_local_to_actor.y, horizontal_distance)
	var max_pitch_up := deg_to_rad(settings.max_pitch_up_degrees)
	var max_pitch_down := deg_to_rad(settings.max_pitch_down_degrees)
	pitch = clampf(pitch, -max_pitch_up, max_pitch_down)

	# Giants use the same yaw axis as NPCs, but pitch has to be applied on
	# the third local axis to read as a downward nod rather than a side tilt.
	var delta_basis := Basis.from_euler(Vector3(yaw, 0.0, pitch))
	return animated_pose_rotation * delta_basis.get_rotation_quaternion()


func _get_modifier_delta() -> float:
	var current_time_usec := Time.get_ticks_usec()
	if _last_update_time_usec <= 0:
		_last_update_time_usec = current_time_usec
		return 1.0 / 60.0

	var delta_usec := maxi(current_time_usec - _last_update_time_usec, 0)
	_last_update_time_usec = current_time_usec
	return clampf(float(delta_usec) / 1000000.0, 0.0, 0.25)


func _get_look_tracking_controller() -> Node:
	var controller := get_node_or_null(look_tracking_controller_path)
	if controller == null:
		return null

	if not controller.has_method("get_current_target_world_position"):
		return null
	if not controller.has_method("get_tracked_node"):
		return null

	return controller


func _should_rotate_instantly(controller: Node) -> bool:
	if controller == null or not controller.has_method("should_rotate_instantly"):
		return false

	return bool(controller.call("should_rotate_instantly"))
