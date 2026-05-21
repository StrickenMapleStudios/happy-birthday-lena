extends RefCounted

class_name SessionStatePersistence

const NPC_SESSION_STATE_GROUP := &"npc_session_state"


static func notify_actor_changed(actor: Node) -> void:
	if actor == null:
		return

	for child in actor.get_children():
		if child.is_in_group(NPC_SESSION_STATE_GROUP) and child.has_method("save_state"):
			child.call("save_state")
			return


static func flush_scene_npc_states(scene_root: Node) -> void:
	if scene_root == null:
		return

	for child in scene_root.get_children():
		_flush_npc_states_recursive(child)


static func _flush_npc_states_recursive(node: Node) -> void:
	if node.is_in_group(NPC_SESSION_STATE_GROUP) and node.has_method("save_state"):
		var actor := node.get_parent()
		if actor != null and actor.is_inside_tree():
			node.call("save_state")

	for child in node.get_children():
		_flush_npc_states_recursive(child)
