extends Node3D

class_name LabyrinthArea

signal labyrinth_enter_requested(area: LabyrinthArea)
signal labyrinth_exit_requested(area: LabyrinthArea)

const PLAYER_GROUP := &"player_character"
const COLLIDER_BODY_NAME := ^"LabyrinthColliderBody"
const COLLISION_SHAPE_PREFIX := "LabyrinthCollision_"

@onready var labyrinth_model: Node3D = $LabyrinthModel
@onready var entry_trigger: Area3D = $EntryTrigger
@onready var exit_trigger: Area3D = $ExitTrigger
@onready var return_point: Node3D = $ReturnPoint


func _ready() -> void:
	_ensure_mesh_colliders()
	_connect_trigger(entry_trigger, Callable(self, "_on_entry_trigger_body_entered"))
	_connect_trigger(exit_trigger, Callable(self, "_on_exit_trigger_body_entered"))
	add_to_group(&"labyrinth_areas")


func _on_entry_trigger_body_entered(body: Node3D) -> void:
	if _is_player_body(body):
		labyrinth_enter_requested.emit(self)


func _on_exit_trigger_body_entered(body: Node3D) -> void:
	if _is_player_body(body):
		labyrinth_exit_requested.emit(self)


func _connect_trigger(trigger: Area3D, callback: Callable) -> void:
	if trigger == null:
		return

	if not trigger.body_entered.is_connected(callback):
		trigger.body_entered.connect(callback)


func get_return_transform(body: Node3D = null) -> Transform3D:
	var target_transform := return_point.global_transform if return_point != null else entry_trigger.global_transform
	if body != null:
		target_transform.origin.y = body.global_position.y
	return target_transform


func _ensure_mesh_colliders() -> void:
	var collider_body := get_node_or_null(COLLIDER_BODY_NAME) as StaticBody3D
	if collider_body == null:
		collider_body = StaticBody3D.new()
		collider_body.name = String(COLLIDER_BODY_NAME)
		add_child(collider_body)
		collider_body.owner = owner

	if collider_body.get_child_count() > 0:
		return

	var mesh_instances := _collect_mesh_instances(labyrinth_model)
	var shape_index := 0
	for mesh_instance in mesh_instances:
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue

		var trimesh_shape := mesh.create_trimesh_shape()
		if trimesh_shape == null:
			continue

		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "%s%d" % [COLLISION_SHAPE_PREFIX, shape_index]
		collision_shape.shape = trimesh_shape
		collision_shape.transform = global_transform.affine_inverse() * mesh_instance.global_transform
		collider_body.add_child(collision_shape)
		collision_shape.owner = owner
		shape_index += 1


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root == null:
		return result

	for child in root.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		result.append_array(_collect_mesh_instances(child))

	return result


func _is_player_body(body: Node) -> bool:
	return body != null and body.is_in_group(PLAYER_GROUP)
