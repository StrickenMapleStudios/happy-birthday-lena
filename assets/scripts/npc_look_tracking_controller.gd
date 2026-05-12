extends Area3D

class_name NpcLookTrackingController

@export var settings: NpcLookTrackingSettings
@export var tracked_node_path: NodePath = ^".."
@export var collision_shape_path: NodePath = ^"CollisionShape3D"

var _tracked_bodies: Array[Node3D] = []
var _tracking_enabled := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	monitorable = false
	_refresh_configuration()


func _physics_process(delta: float) -> void:
	if settings == null:
		return

	_seed_tracked_bodies_from_overlaps()
	_prune_tracked_bodies()


func set_tracking_enabled(value: bool) -> void:
	_tracking_enabled = value
	if not value:
		_tracked_bodies.clear()


func refresh_tracking_configuration() -> void:
	_refresh_configuration()


func _is_tracking_active() -> bool:
	return _tracking_enabled and settings != null and settings.enabled


func _refresh_configuration() -> void:
	if settings == null:
		return

	var collision_shape: CollisionShape3D = get_node_or_null(collision_shape_path) as CollisionShape3D
	if collision_shape == null:
		return

	var cylinder_shape: CylinderShape3D = collision_shape.shape as CylinderShape3D
	if cylinder_shape == null:
		cylinder_shape = CylinderShape3D.new()
		collision_shape.shape = cylinder_shape

	cylinder_shape.radius = settings.tracking_distance
	cylinder_shape.height = settings.tracking_height
	collision_shape.position.y = settings.tracking_height * 0.5


func _on_body_entered(body: Node) -> void:
	var body_3d := body as Node3D
	if body_3d == null or not _is_target_body(body_3d):
		return

	if _tracked_bodies.has(body_3d):
		return

	_tracked_bodies.append(body_3d)


func _on_body_exited(body: Node) -> void:
	var body_3d := body as Node3D
	if body_3d == null:
		return

	_tracked_bodies.erase(body_3d)


func _prune_tracked_bodies() -> void:
	for index in range(_tracked_bodies.size() - 1, -1, -1):
		var body := _tracked_bodies[index]
		if not is_instance_valid(body):
			_tracked_bodies.remove_at(index)


func _seed_tracked_bodies_from_overlaps() -> void:
	for body in get_overlapping_bodies():
		var body_3d := body as Node3D
		if body_3d == null or not _is_target_body(body_3d):
			continue
		if _tracked_bodies.has(body_3d):
			continue

		_tracked_bodies.append(body_3d)


func _find_best_target() -> Node3D:
	var tracked_node: Node3D = _get_tracked_node()
	if tracked_node == null:
		return null

	var best_target: Node3D
	var best_distance_squared: float = INF
	for candidate in _tracked_bodies:
		if not _is_candidate_in_front(candidate, tracked_node):
			continue

		var distance_squared: float = tracked_node.global_position.distance_squared_to(candidate.global_position)
		if distance_squared >= best_distance_squared:
			continue

		best_target = candidate
		best_distance_squared = distance_squared

	return best_target


func _is_candidate_in_front(candidate: Node3D, tracked_node: Node3D) -> bool:
	var to_candidate: Vector3 = candidate.global_position - tracked_node.global_position
	to_candidate.y = 0.0
	if to_candidate.is_zero_approx():
		return true

	var forward: Vector3 = tracked_node.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.is_zero_approx():
		return true

	var min_dot: float = cos(deg_to_rad(settings.horizontal_fov_degrees * 0.5))
	return forward.dot(to_candidate.normalized()) >= min_dot


func _get_tracked_node() -> Node3D:
	return get_node_or_null(tracked_node_path) as Node3D


func get_tracked_node() -> Node3D:
	return _get_tracked_node()


func get_current_target_world_position() -> Vector3:
	var target: Node3D = _find_best_target() if _is_tracking_active() else null
	if target == null:
		return Vector3.INF

	return target.global_position + Vector3.UP * settings.target_height_offset


func _is_target_body(body: Node3D) -> bool:
	if settings == null:
		return false

	return settings.target_group == StringName() or body.is_in_group(settings.target_group)
