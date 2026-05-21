extends Node

class_name NpcSessionStateComponent

const SESSION_STATE_GROUP := &"npc_session_state"
const FRIEND_FOLLOWERS_GROUP := &"friendly_followers"
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


func restore_visibility_from_session() -> void:
	_cache_session_identity()
	var actor := get_parent() as Node3D
	if actor == null or not actor.has_method("set_character_visible"):
		return

	var saved_state := GameSessionState.get_npc_state(_session_scene_path, _session_node_path)
	var should_show_character := true
	if actor.is_in_group(FRIEND_FOLLOWERS_GROUP):
		should_show_character = true
	elif saved_state.has("character_visible"):
		should_show_character = bool(saved_state.get("character_visible", true))
	# Visibility saved while follow was paused is dialogue-only and should not persist.
	if bool(saved_state.get("follow_paused", false)):
		should_show_character = true

	actor.call("set_character_visible", should_show_character)


func _capture_state() -> Dictionary:
	var state := {}
	var actor := get_parent() as Node3D
	if actor == null or not actor.is_inside_tree():
		return state

	if not _is_invalid_saved_transform(actor.global_transform):
		state["global_transform"] = actor.global_transform

	var friend_follow_state := get_parent().get_node_or_null(FRIEND_FOLLOW_STATE_PATH)
	var follow_paused := false
	if friend_follow_state != null:
		state["is_friend"] = bool(friend_follow_state.get("is_friend"))
		if friend_follow_state.has_method("is_follow_paused"):
			follow_paused = bool(friend_follow_state.call("is_follow_paused"))
			state["follow_paused"] = follow_paused

	if (
		actor.has_method("is_character_visible")
		and not follow_paused
		and not actor.is_in_group(FRIEND_FOLLOWERS_GROUP)
	):
		state["character_visible"] = bool(actor.call("is_character_visible"))

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
			var transform := saved_transform as Transform3D
			if not _is_invalid_saved_transform(transform):
				actor.global_transform = transform

	var should_show_character := true
	if actor != null and actor.is_in_group(FRIEND_FOLLOWERS_GROUP):
		should_show_character = true
	elif state.has("character_visible"):
		should_show_character = bool(state.get("character_visible", true))
	if bool(state.get("follow_paused", false)) and not should_show_character:
		should_show_character = true
	if actor != null and actor.has_method("set_character_visible"):
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


func _is_invalid_saved_transform(transform: Transform3D) -> bool:
	return transform.origin.is_equal_approx(Vector3.ZERO) and transform.basis.is_equal_approx(Basis.IDENTITY)
