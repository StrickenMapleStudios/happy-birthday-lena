@tool
extends Node

const ROOM_LAYER_MASK := 1 << 1

@export var target_path: NodePath = ^"../MysteryRoom"


func _enter_tree() -> void:
	_apply_isolation()


func _ready() -> void:
	_apply_isolation()


func _apply_isolation() -> void:
	var target := get_node_or_null(target_path)
	if target == null:
		return
	_apply_to_branch(target)


func _apply_to_branch(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = ROOM_LAYER_MASK

	if node is Light3D:
		(node as Light3D).light_cull_mask = ROOM_LAYER_MASK

	for child in node.get_children():
		_apply_to_branch(child)
