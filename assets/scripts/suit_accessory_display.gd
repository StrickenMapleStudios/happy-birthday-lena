@tool
extends Node3D

class_name SuitAccessoryDisplay

@export var suits_root_path: NodePath = ^"Suits"
@export var visible_top_level_nodes: Array[StringName] = []
@export_range(0.0, 2.0, 0.01) var bob_height := 0.0
@export_range(0.0, 10.0, 0.01) var bob_speed := 1.5
@export_range(-10.0, 10.0, 0.01) var rotation_speed := 0.0

var _base_position := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_base_position = position
	_apply_visibility()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_visibility()

	if not is_zero_approx(rotation_speed):
		rotate_y(rotation_speed * delta)

	if bob_height > 0.0:
		_time += delta * bob_speed
		position = _base_position + Vector3(0.0, sin(_time) * bob_height, 0.0)


func _apply_visibility() -> void:
	var suits_root := get_node_or_null(suits_root_path)
	if suits_root == null:
		return

	for child in suits_root.get_children():
		if child is Node3D:
			(child as Node3D).visible = visible_top_level_nodes.has(StringName(child.name))
