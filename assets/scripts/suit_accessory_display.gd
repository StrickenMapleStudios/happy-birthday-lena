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

	var visible_nodes := {}
	for node_name in visible_top_level_nodes:
		_mark_visible_nodes(suits_root, String(node_name), visible_nodes)

	_apply_visibility_recursive(suits_root, visible_nodes)


func _mark_visible_nodes(root: Node, target_name: String, visible_nodes: Dictionary) -> void:
	var target := root.find_child(target_name, true, false)
	if target == null:
		return

	var current: Node = target
	while current != null and current != root:
		visible_nodes[current] = true
		current = current.get_parent()


func _apply_visibility_recursive(root: Node, visible_nodes: Dictionary) -> void:
	for child in root.get_children():
		var child_3d := child as Node3D
		if child_3d != null:
			child_3d.visible = visible_nodes.has(child)

		_apply_visibility_recursive(child, visible_nodes)
