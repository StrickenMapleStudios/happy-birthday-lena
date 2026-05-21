extends Node

class_name NpcSessionStateComponent

const SESSION_STATE_GROUP := &"npc_session_state"
const FRIEND_FOLLOW_STATE_PATH := ^"FriendFollowState"
const DIALOGUE_CYCLE_STATE_PATH := ^"DialogueCycleState"
const INTERACTION_TARGET_PATH := ^"InteractionTarget"

var _session_scene_path := ""
var _session_node_path := NodePath()


func _ready() -> void:
	add_to_group(SESSION_STATE_GROUP)
	call_deferred("_initialize_session_state")


func save_state() -> void:
	if GameSessionState == null or _session_scene_path.is_empty() or _session_node_path.is_empty():
		return

	GameSessionState.save_npc_state(_session_scene_path, _session_node_path, _capture_state())


func _cache_session_identity() -> void:
	var actor := get_parent()
	if actor == null:
		return

	var current_scene := actor.get_tree().current_scene
	if current_scene == null:
		return

	_session_scene_path = String(current_scene.scene_file_path)
	_session_node_path = current_scene.get_path_to(actor)


func _initialize_session_state() -> void:
	_cache_session_identity()
	_restore_state()


func _restore_state() -> void:
	if GameSessionState == null or _session_scene_path.is_empty() or _session_node_path.is_empty():
		return

	var saved_state := GameSessionState.get_npc_state(_session_scene_path, _session_node_path)
	if saved_state.is_empty():
		return

	_apply_state(saved_state)


func _capture_state() -> Dictionary:
	var state := {}
	var actor := get_parent() as Node3D
	if actor != null:
		state["global_transform"] = actor.global_transform
		if actor.has_method("is_character_visible"):
			state["character_visible"] = bool(actor.call("is_character_visible"))

	var friend_follow_state := get_parent().get_node_or_null(FRIEND_FOLLOW_STATE_PATH)
	if friend_follow_state != null:
		state["is_friend"] = bool(friend_follow_state.get("is_friend"))
		if friend_follow_state.has_method("is_follow_paused"):
			state["follow_paused"] = bool(friend_follow_state.call("is_follow_paused"))

	var interaction_target := get_parent().get_node_or_null(INTERACTION_TARGET_PATH) as InteractionTarget
	if interaction_target != null:
		state["interaction_enabled"] = interaction_target.interaction_enabled

	var dialogue_cycle_state := get_parent().get_node_or_null(DIALOGUE_CYCLE_STATE_PATH)
	if dialogue_cycle_state != null:
		state["who_are_you_loop_count"] = int(dialogue_cycle_state.get("who_are_you_loop_count"))

	return state


func _apply_state(state: Dictionary) -> void:
	var actor := get_parent() as Node3D
	if actor != null and state.has("global_transform"):
		var saved_transform: Variant = state.get("global_transform")
		if saved_transform is Transform3D:
			actor.global_transform = saved_transform as Transform3D

	var should_show_character := true
	if state.has("character_visible"):
		should_show_character = bool(state.get("character_visible", true))
	if actor != null and state.has("character_visible") and actor.has_method("set_character_visible"):
		actor.call("set_character_visible", should_show_character)

	var friend_follow_state := get_parent().get_node_or_null(FRIEND_FOLLOW_STATE_PATH)
	if friend_follow_state != null and state.has("is_friend"):
		var should_be_friend := bool(state.get("is_friend", false))
		if should_be_friend and friend_follow_state.has_method("become_friend"):
			friend_follow_state.call("become_friend")
		else:
			friend_follow_state.set("is_friend", should_be_friend)
			if should_be_friend:
				if actor != null and not actor.is_in_group(&"friendly_followers"):
					actor.add_to_group(&"friendly_followers")
			elif actor != null:
				actor.remove_from_group(&"friendly_followers")

		var should_pause_follow := state.has("follow_paused") and bool(state.get("follow_paused", false))
		if state.has("character_visible"):
			should_pause_follow = should_pause_follow or not should_show_character
		if should_pause_follow and friend_follow_state.has_method("pause_following"):
			friend_follow_state.call("pause_following")
		elif should_be_friend and should_show_character and friend_follow_state.has_method("resume_following"):
			friend_follow_state.call("resume_following")

	var interaction_target := get_parent().get_node_or_null(INTERACTION_TARGET_PATH) as InteractionTarget
	if interaction_target != null and state.has("interaction_enabled"):
		interaction_target.set_interaction_enabled(bool(state.get("interaction_enabled", true)))

	var dialogue_cycle_state := get_parent().get_node_or_null(DIALOGUE_CYCLE_STATE_PATH)
	if dialogue_cycle_state != null and state.has("who_are_you_loop_count"):
		dialogue_cycle_state.set("who_are_you_loop_count", int(state.get("who_are_you_loop_count", 0)))
