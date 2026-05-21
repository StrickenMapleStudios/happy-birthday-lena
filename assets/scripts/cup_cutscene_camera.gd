extends Camera3D

@export var look_at_target_path: NodePath
@export var look_at_height_offset := 0.12


func snap_to_target() -> void:
	if look_at_target_path.is_empty():
		return

	var target := get_node_or_null(look_at_target_path)
	if target == null:
		return

	var focus_position: Vector3
	if target is CupRewardPresenter:
		focus_position = (target as CupRewardPresenter).get_focus_position()
	elif target is Node3D:
		focus_position = (target as Node3D).global_position
	else:
		return

	focus_position.y += look_at_height_offset
	look_at(focus_position, Vector3.UP)


func _physics_process(_delta: float) -> void:
	if not is_inside_tree() or not current:
		return
	snap_to_target()
