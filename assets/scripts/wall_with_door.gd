extends Node3D

@export var model_root_path: NodePath = ^"Model"
@export_range(-180.0, 180.0, 1.0) var right_door_opened_yaw_degrees := -105.0
@export_range(-180.0, 180.0, 1.0) var left_door_opened_yaw_degrees := 105.0
@export_range(0.1, 12.0, 0.1) var open_duration_seconds := 3.6

var _doors_opened := false


func open_doors() -> void:
	if _doors_opened:
		return

	var model_root := get_node_or_null(model_root_path) as Node3D
	if model_root == null:
		push_warning("WallWithDoor is missing its model root.")
		return

	var right_pivot := _find_named_node_3d_recursive(model_root, ["pivot", "rightdoor"])
	var left_pivot := _find_named_node_3d_recursive(model_root, ["pivot", "leftdoor"])
	if right_pivot == null or left_pivot == null:
		push_warning("WallWithDoor is missing left/right door pivots.")
		return

	_doors_opened = true
	_tween_global_y_rotation(right_pivot, right_door_opened_yaw_degrees)
	_tween_global_y_rotation(left_pivot, left_door_opened_yaw_degrees)


func _tween_global_y_rotation(pivot: Node3D, delta_degrees: float) -> void:
	if pivot == null:
		return

	var start_y := pivot.global_rotation.y
	var target_y := start_y + deg_to_rad(delta_degrees)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pivot, ^"global_rotation:y", target_y, open_duration_seconds)


func _find_named_node_3d_recursive(root: Node, required_tokens: Array[String]) -> Node3D:
	if root == null:
		return null

	var root_as_node_3d := root as Node3D
	if root_as_node_3d != null:
		var normalized_name := root_as_node_3d.name.to_lower()
		var matches_all_tokens := true
		for token in required_tokens:
			if normalized_name.find(token) == -1:
				matches_all_tokens = false
				break
		if matches_all_tokens:
			return root_as_node_3d

	for child in root.get_children():
		var match := _find_named_node_3d_recursive(child, required_tokens)
		if match != null:
			return match

	return null
