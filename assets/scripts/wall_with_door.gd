extends Node3D

@export var model_root_path: NodePath = ^"Model"
@export_range(-180.0, 180.0, 1.0) var right_door_opened_yaw_degrees := -105.0
@export_range(-180.0, 180.0, 1.0) var left_door_opened_yaw_degrees := 105.0
@export_range(0.1, 12.0, 0.1) var open_duration_seconds := 3.6

var _doors_opened := false
var _right_pivot: Node3D
var _left_pivot: Node3D
var _right_door_closed_yaw := 0.0
var _left_door_closed_yaw := 0.0


func _ready() -> void:
	_cache_door_pivots()
	_ensure_mesh_colliders()


func open_doors() -> void:
	if _doors_opened or not _ensure_door_pivots():
		return

	_doors_opened = true
	_tween_global_y_rotation(_right_pivot, _right_door_closed_yaw + deg_to_rad(right_door_opened_yaw_degrees))
	_tween_global_y_rotation(_left_pivot, _left_door_closed_yaw + deg_to_rad(left_door_opened_yaw_degrees))


func close_doors() -> void:
	if not _doors_opened or not _ensure_door_pivots():
		return

	_doors_opened = false
	_tween_global_y_rotation(_right_pivot, _right_door_closed_yaw)
	_tween_global_y_rotation(_left_pivot, _left_door_closed_yaw)


func close_doors_immediately() -> void:
	if not _ensure_door_pivots():
		return

	_doors_opened = false
	_right_pivot.global_rotation.y = _right_door_closed_yaw
	_left_pivot.global_rotation.y = _left_door_closed_yaw


func are_doors_open() -> bool:
	return _doors_opened


func _tween_global_y_rotation(pivot: Node3D, target_y: float) -> void:
	if pivot == null:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pivot, ^"global_rotation:y", target_y, open_duration_seconds)


func _cache_door_pivots() -> void:
	var model_root := get_node_or_null(model_root_path) as Node3D
	if model_root == null:
		push_warning("WallWithDoor is missing its model root.")
		return

	_right_pivot = _find_named_node_3d_recursive(model_root, ["pivot", "rightdoor"])
	_left_pivot = _find_named_node_3d_recursive(model_root, ["pivot", "leftdoor"])
	if _right_pivot == null or _left_pivot == null:
		push_warning("WallWithDoor is missing left/right door pivots.")
		return

	_right_door_closed_yaw = _right_pivot.global_rotation.y
	_left_door_closed_yaw = _left_pivot.global_rotation.y


func _ensure_door_pivots() -> bool:
	if _right_pivot != null and _left_pivot != null:
		return true

	_cache_door_pivots()
	return _right_pivot != null and _left_pivot != null


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


func _ensure_mesh_colliders() -> void:
	var model_root := get_node_or_null(model_root_path) as Node3D
	if model_root == null:
		return

	for mesh_instance in _collect_mesh_instances(model_root):
		if _has_trimesh_collision_child(mesh_instance):
			continue

		mesh_instance.create_trimesh_collision()
		var body := _find_static_body_child(mesh_instance)
		if body != null:
			body.collision_layer = 1
			body.collision_mask = 0


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root == null:
		return result

	for child in root.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		result.append_array(_collect_mesh_instances(child))

	return result


func _has_trimesh_collision_child(mesh_instance: MeshInstance3D) -> bool:
	for child in mesh_instance.get_children():
		var body := child as StaticBody3D
		if body == null:
			continue

		for shape_node in body.get_children():
			var collision_shape := shape_node as CollisionShape3D
			if collision_shape == null or collision_shape.shape == null:
				continue
			if (
				collision_shape.shape is ConcavePolygonShape3D
				or collision_shape.shape is ConvexPolygonShape3D
			):
				return true

	return false


func _find_static_body_child(node: Node) -> StaticBody3D:
	for child in node.get_children():
		var body := child as StaticBody3D
		if body != null:
			return body

	return null
