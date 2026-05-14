extends Node

var _inventory_state: Dictionary = {}
var _collected_pickups_by_scene: Dictionary = {}


func reset_session() -> void:
	_inventory_state = {}
	_collected_pickups_by_scene = {}


func save_inventory_state(inventory_state: Dictionary) -> void:
	_inventory_state = inventory_state.duplicate(true)


func get_inventory_state() -> Dictionary:
	return _inventory_state.duplicate(true)


func mark_pickup_collected(scene_path: String, node_path: NodePath) -> void:
	if scene_path.is_empty() or node_path.is_empty():
		return

	var scene_pickups: Dictionary = _collected_pickups_by_scene.get(scene_path, {})
	scene_pickups[String(node_path)] = true
	_collected_pickups_by_scene[scene_path] = scene_pickups


func is_pickup_collected(scene_path: String, node_path: NodePath) -> bool:
	if scene_path.is_empty() or node_path.is_empty():
		return false

	var scene_pickups: Dictionary = _collected_pickups_by_scene.get(scene_path, {})
	return bool(scene_pickups.get(String(node_path), false))
