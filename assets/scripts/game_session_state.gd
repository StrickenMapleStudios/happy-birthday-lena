extends Node

var _inventory_state: Dictionary = {}
var _collected_pickups_by_scene: Dictionary = {}
var _npc_states_by_scene: Dictionary = {}
var _completed_races: Dictionary = {}
var _completed_race_rewards: Dictionary = {}


func reset_session() -> void:
	_inventory_state = {}
	_collected_pickups_by_scene = {}
	_npc_states_by_scene = {}
	_completed_races = {}
	_completed_race_rewards = {}


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


func save_npc_state(scene_path: String, node_path: NodePath, npc_state: Dictionary) -> void:
	if scene_path.is_empty() or node_path.is_empty() or npc_state.is_empty():
		return

	var scene_npcs: Dictionary = _npc_states_by_scene.get(scene_path, {})
	var node_key := String(node_path)
	var merged_state: Dictionary = {}
	var existing_state: Variant = scene_npcs.get(node_key, {})
	if typeof(existing_state) == TYPE_DICTIONARY:
		merged_state = (existing_state as Dictionary).duplicate(true)
	for key in npc_state:
		merged_state[key] = npc_state[key]
	scene_npcs[node_key] = merged_state
	_npc_states_by_scene[scene_path] = scene_npcs


func get_npc_state(scene_path: String, node_path: NodePath) -> Dictionary:
	if scene_path.is_empty() or node_path.is_empty():
		return {}

	var scene_npcs: Dictionary = _npc_states_by_scene.get(scene_path, {})
	var saved_state: Variant = scene_npcs.get(String(node_path), {})
	if typeof(saved_state) != TYPE_DICTIONARY:
		return {}

	return (saved_state as Dictionary).duplicate(true)


func mark_race_reward_completed(race_id: StringName) -> void:
	if race_id.is_empty():
		return

	_completed_race_rewards[race_id] = true


func is_race_reward_completed(race_id: StringName) -> bool:
	if race_id.is_empty():
		return false

	return bool(_completed_race_rewards.get(race_id, false))


func mark_race_completed(race_id: StringName) -> void:
	if race_id.is_empty():
		return

	_completed_races[race_id] = true


func is_race_completed(race_id: StringName) -> bool:
	if race_id.is_empty():
		return false

	return bool(_completed_races.get(race_id, false))
