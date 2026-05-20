extends Node3D

class_name BoneDeltaFollower3D

@export var skeleton_path: NodePath
@export var bone_name: StringName = &"head"

var _skeleton: Skeleton3D
var _bone_idx := -1
var _initial_bone_parent_transform := Transform3D.IDENTITY
var _initial_local_transform := Transform3D.IDENTITY
var _initialized := false


func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		push_warning("BoneDeltaFollower3D could not find skeleton at '%s'." % [String(skeleton_path)])
		return

	_bone_idx = _find_bone_case_insensitive(_skeleton, String(bone_name))
	if _bone_idx < 0:
		push_warning("BoneDeltaFollower3D could not find bone '%s'." % [String(bone_name)])
		return

	_initial_local_transform = transform
	if _skeleton.has_signal("skeleton_updated"):
		_skeleton.connect("skeleton_updated", Callable(self, "_on_skeleton_updated"))
	set_process(true)


func _process(_delta: float) -> void:
	if not _initialized:
		_capture_initial_state()
		return

	_apply_bone_delta()


func _on_skeleton_updated() -> void:
	if not _initialized:
		_capture_initial_state()
		return

	_apply_bone_delta()


func _capture_initial_state() -> void:
	if _skeleton == null or _bone_idx < 0:
		return

	_initial_local_transform = transform
	_initial_bone_parent_transform = _get_bone_transform_in_parent_space()
	_initialized = true


func _apply_bone_delta() -> void:
	if _skeleton == null or _bone_idx < 0 or not _initialized:
		return

	var current_bone_parent_transform := _get_bone_transform_in_parent_space()
	var delta_transform := current_bone_parent_transform * _initial_bone_parent_transform.affine_inverse()
	transform = delta_transform * _initial_local_transform


func _get_bone_transform_in_parent_space() -> Transform3D:
	var bone_in_skeleton_space := _skeleton.get_bone_global_pose(_bone_idx)
	return _skeleton.transform * bone_in_skeleton_space


func _find_bone_case_insensitive(skeleton: Skeleton3D, target_bone_name: String) -> int:
	var lowered_target := target_bone_name.to_lower()
	for bone_idx in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone_idx).to_lower() == lowered_target:
			return bone_idx

	return -1
