extends Node

const DEFAULT_TARGET_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"

var _pending_rewards: Array[Dictionary] = []
var _completed_sources: Dictionary = {}


func reset_state() -> void:
	_pending_rewards.clear()
	_completed_sources.clear()


func grant_reward(
	source_id: StringName,
	marker_id: StringName,
	item_data: InventoryItemData,
	quantity: int = 1,
	target_scene_path: String = DEFAULT_TARGET_SCENE_PATH
) -> bool:
	if source_id.is_empty() or marker_id.is_empty() or item_data == null:
		return false
	if _completed_sources.has(source_id) or _has_pending_source(source_id):
		return false

	var current_scene := get_tree().current_scene
	if _can_spawn_in_scene(current_scene, target_scene_path):
		var marker := _find_marker(current_scene, marker_id)
		if marker != null and marker.spawn_reward(item_data, quantity) != null:
			_completed_sources[source_id] = true
			return true

	_pending_rewards.append({
		"source_id": source_id,
		"marker_id": marker_id,
		"item_data": item_data,
		"quantity": max(quantity, 1),
		"target_scene_path": target_scene_path,
	})
	return true


func spawn_pending_rewards(scene_root: Node) -> void:
	if scene_root == null:
		return

	var target_scene_path := _get_scene_path(scene_root)
	if target_scene_path.is_empty():
		return

	var remaining_rewards: Array[Dictionary] = []
	for pending_reward_variant in _pending_rewards:
		var pending_reward: Dictionary = pending_reward_variant
		if String(pending_reward.get("target_scene_path", "")) != target_scene_path:
			remaining_rewards.append(pending_reward)
			continue

		var marker_id: StringName = pending_reward.get("marker_id", &"")
		var marker := _find_marker(scene_root, marker_id)
		if marker == null:
			remaining_rewards.append(pending_reward)
			continue

		var item_data := pending_reward.get("item_data") as InventoryItemData
		var quantity := int(pending_reward.get("quantity", 1))
		if marker.spawn_reward(item_data, quantity) == null:
			remaining_rewards.append(pending_reward)
			continue

		var source_id: StringName = pending_reward.get("source_id", &"")
		_completed_sources[source_id] = true

	_pending_rewards = remaining_rewards


func has_completed_source(source_id: StringName) -> bool:
	return _completed_sources.has(source_id) or _has_pending_source(source_id)


func _has_pending_source(source_id: StringName) -> bool:
	for pending_reward_variant in _pending_rewards:
		var pending_reward: Dictionary = pending_reward_variant
		if pending_reward.get("source_id", &"") == source_id:
			return true
	return false


func _can_spawn_in_scene(scene_root: Node, target_scene_path: String) -> bool:
	return scene_root != null and _get_scene_path(scene_root) == target_scene_path


func _get_scene_path(scene_root: Node) -> String:
	if scene_root == null:
		return ""
	return String(scene_root.scene_file_path)


func _find_marker(scene_root: Node, marker_id: StringName) -> RewardMarker:
	if scene_root == null or marker_id.is_empty():
		return null

	for marker_node in scene_root.get_tree().get_nodes_in_group(&"reward_markers"):
		var marker := marker_node as RewardMarker
		if marker == null or marker.get_tree() != scene_root.get_tree():
			continue
		if not scene_root.is_ancestor_of(marker) and scene_root != marker:
			continue
		if marker.marker_id == marker_id:
			return marker

	return null
