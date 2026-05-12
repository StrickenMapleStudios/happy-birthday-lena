extends SkeletonModifier3D

class_name NpcHeadPoleModifier

@export var settings: NpcLookTrackingSettings
@export var look_tracking_controller_path: NodePath

var _head_bone_idx := -1
var _smoothed_pose_rotation := Quaternion.IDENTITY
var _smoothed_pose_initialized := false
var _last_update_time_usec := 0


func _ready() -> void:
	_validate_bone_name()


func _validate_bone_name() -> void:
	_head_bone_idx = -1
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or settings == null or settings.rig_head_bone_name == StringName():
		return

	_head_bone_idx = skeleton.find_bone(String(settings.rig_head_bone_name))
	if _head_bone_idx < 0:
		_head_bone_idx = _find_bone_case_insensitive(skeleton, String(settings.rig_head_bone_name))
	if _head_bone_idx >= 0:
		return

	push_warning(
		"Look tracking modifier expected bone '%s' on '%s', but it was not found."
		% [String(settings.rig_head_bone_name), skeleton.name]
	)


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

	var delta: float = _get_modifier_delta()
	var animated_pose_rotation: Quaternion = skeleton.get_bone_pose_rotation(_head_bone_idx)
	var desired_pose_rotation: Quaternion = animated_pose_rotation
	var controller: NpcLookTrackingController = _get_look_tracking_controller()
	if controller != null:
		var target_world_position: Vector3 = controller.get_current_target_world_position()
		if target_world_position != Vector3.INF:
			desired_pose_rotation = _get_target_pose_rotation(skeleton, animated_pose_rotation, target_world_position)

	if not _smoothed_pose_initialized:
		_smoothed_pose_rotation = animated_pose_rotation
		_smoothed_pose_initialized = true

	var weight: float = clampf(delta * settings.rotation_follow_speed, 0.0, 1.0)
	_smoothed_pose_rotation = _smoothed_pose_rotation.slerp(desired_pose_rotation, weight)
	skeleton.set_bone_pose_rotation(_head_bone_idx, _smoothed_pose_rotation)


func _get_target_pose_rotation(
	skeleton: Skeleton3D,
	animated_pose_rotation: Quaternion,
	target_world_position: Vector3
) -> Quaternion:
	var controller: NpcLookTrackingController = _get_look_tracking_controller()
	if controller == null:
		return animated_pose_rotation

	var tracked_node: Node3D = controller.get_tracked_node()
	if tracked_node == null:
		return animated_pose_rotation

	var target_local_to_actor: Vector3 = tracked_node.to_local(target_world_position)
	target_local_to_actor.y = 0.0
	if target_local_to_actor.is_zero_approx():
		return animated_pose_rotation

	var yaw: float = atan2(target_local_to_actor.x, target_local_to_actor.z)
	yaw = clampf(yaw, -deg_to_rad(settings.max_yaw_degrees), deg_to_rad(settings.max_yaw_degrees))

	# This rig's head bone has its local X axis aligned closest to world up,
	# so yaw must be applied around local X rather than local Y.
	var delta_basis: Basis = Basis.from_euler(Vector3(yaw, 0.0, 0.0))
	return animated_pose_rotation * delta_basis.get_rotation_quaternion()


func _get_modifier_delta() -> float:
	var current_time_usec: int = Time.get_ticks_usec()
	if _last_update_time_usec <= 0:
		_last_update_time_usec = current_time_usec
		return 1.0 / 60.0

	var delta_usec: int = maxi(current_time_usec - _last_update_time_usec, 0)
	_last_update_time_usec = current_time_usec
	return clampf(float(delta_usec) / 1000000.0, 0.0, 0.25)


func _get_look_tracking_controller() -> NpcLookTrackingController:
	return get_node_or_null(look_tracking_controller_path) as NpcLookTrackingController
