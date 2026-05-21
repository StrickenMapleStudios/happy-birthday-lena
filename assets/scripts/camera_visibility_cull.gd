extends Node

## Disables rendering and collision when the target leaves the active camera view.
@export var cull_roots: Array[NodePath] = [NodePath(".")]
@export var visibility_margin: float = 2.0

var _notifier: VisibleOnScreenNotifier3D
var _geometry_instances: Array[GeometryInstance3D] = []
var _collision_shapes: Array[CollisionShape3D] = []
var _geometry_visible_states: Array[bool] = []
var _collision_enabled_states: Array[bool] = []
var _is_on_screen := true


func _ready() -> void:
	_collect_targets()
	if _geometry_instances.is_empty() and _collision_shapes.is_empty():
		return

	_notifier = _find_or_create_notifier()
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	call_deferred("_finish_ready")


func _collect_targets() -> void:
	_geometry_instances.clear()
	_collision_shapes.clear()

	for root_path in cull_roots:
		var root := get_node_or_null(root_path)
		if root == null:
			continue
		_collect_from_node(root)


func _finish_ready() -> void:
	if _notifier == null:
		return
	_update_notifier_aabb()
	_apply_on_screen_state(_notifier.is_on_screen())


func _collect_from_node(node: Node) -> void:
	if node is GeometryInstance3D:
		_geometry_instances.append(node as GeometryInstance3D)
	elif node is CollisionShape3D:
		_collision_shapes.append(node as CollisionShape3D)

	for child in node.get_children():
		_collect_from_node(child)


func _find_or_create_notifier() -> VisibleOnScreenNotifier3D:
	var existing := get_node_or_null("VisibleOnScreenNotifier3D") as VisibleOnScreenNotifier3D
	if existing != null:
		return existing

	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.name = "VisibleOnScreenNotifier3D"
	add_child(notifier)
	return notifier


func _update_notifier_aabb() -> void:
	var combined := _compute_world_aabb()
	if combined.size == Vector3.ZERO:
		return

	var local_center := _notifier.to_local(combined.get_center())
	var local_size := combined.size + Vector3.ONE * visibility_margin * 2.0
	_notifier.aabb = AABB(local_center - local_size * 0.5, local_size)


func _compute_world_aabb() -> AABB:
	var has_aabb := false
	var combined := AABB()

	for geometry in _geometry_instances:
		var local_aabb := geometry.get_aabb()
		if local_aabb.size == Vector3.ZERO:
			continue

		var corners: Array[Vector3] = [
			local_aabb.position,
			local_aabb.position + Vector3(local_aabb.size.x, 0.0, 0.0),
			local_aabb.position + Vector3(0.0, local_aabb.size.y, 0.0),
			local_aabb.position + Vector3(0.0, 0.0, local_aabb.size.z),
			local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0.0),
			local_aabb.position + Vector3(local_aabb.size.x, 0.0, local_aabb.size.z),
			local_aabb.position + Vector3(0.0, local_aabb.size.y, local_aabb.size.z),
			local_aabb.end,
		]

		for corner in corners:
			var world_corner := geometry.global_transform * corner
			if not has_aabb:
				combined = AABB(world_corner, Vector3.ZERO)
				has_aabb = true
			else:
				combined = combined.expand(world_corner)

	return combined if has_aabb else AABB()


func _on_screen_entered() -> void:
	_apply_on_screen_state(true)


func _on_screen_exited() -> void:
	_apply_on_screen_state(false)


func _apply_on_screen_state(is_on_screen: bool) -> void:
	if _is_on_screen == is_on_screen:
		return

	_is_on_screen = is_on_screen

	if is_on_screen:
		_restore_visibility()
		_restore_collisions()
	else:
		_cache_and_hide_visibility()
		_cache_and_disable_collisions()


func _cache_and_hide_visibility() -> void:
	_geometry_visible_states.clear()
	for geometry in _geometry_instances:
		_geometry_visible_states.append(geometry.visible)
		geometry.visible = false


func _restore_visibility() -> void:
	for index in _geometry_instances.size():
		_geometry_instances[index].visible = _geometry_visible_states[index]
	_geometry_visible_states.clear()


func _cache_and_disable_collisions() -> void:
	_collision_enabled_states.clear()
	for collision_shape in _collision_shapes:
		_collision_enabled_states.append(not collision_shape.disabled)
		collision_shape.disabled = true


func _restore_collisions() -> void:
	for index in _collision_shapes.size():
		_collision_shapes[index].disabled = not _collision_enabled_states[index]
	_collision_enabled_states.clear()
