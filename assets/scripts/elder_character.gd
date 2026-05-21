extends "res://assets/scripts/npc_character.gd"

const ELDER_STATE_NAME := &"LeaningOnCane"
const ELDER_ANIMATION_CANDIDATES := [
	&"leaningoncane",
	&"LeaningOnCane",
	&"Leaningoncane",
	&"Leaning_On_Cane",
]
const ELDER_DIALOGUE_RESOURCE := preload("res://assets/dialogue/elder_stars.dialogue")
const ELDER_REWARD_SOURCE_ID := &"elder_constellation_reward"
const ELDER_REWARD_MARKER_ID := &"elder_constellation_reward_marker"
const BRASS_KEY_ITEM := preload("res://assets/data/items/brass_key_item.tres")
const DEFAULT_TARGET_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"
const FRIEND_FOLLOWERS_GROUP := &"friendly_followers"
const FOLLOWER_DIALOGUE_ORDER := [
	"НеЛена",
	"АнтиЛена",
	"АнтиНеЛена",
	"НеАнтиЛена",
	"Хиёри",
]
const FOLLOWER_PIVOT_OFFSET := 0.35

@export var interaction_target_path: NodePath = ^"InteractionTarget"
@export var elder_dialogue_state_path: NodePath = ^"ElderStarsDialogueState"

var _pending_constellation_reward := false


func _ready() -> void:
	CharacterAnimationLibrary.apply_to(animation_player)
	if animation_tree != null:
		animation_tree.active = true
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = false

	_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_configure_elder_trees()
	_sync_dialogue_setup()


func get_dialogue_speaker_name() -> String:
	return "Старец"


func refresh_dialogue_state() -> void:
	var dialogue_state := get_node_or_null(elder_dialogue_state_path) as ElderStarsDialogueState
	if dialogue_state != null:
		dialogue_state.refresh_follower_count()
	_sync_dialogue_setup()


func get_interaction_target() -> InteractionTarget:
	return get_node_or_null(interaction_target_path) as InteractionTarget


func queue_constellation_reward() -> void:
	_pending_constellation_reward = true


func try_grant_pending_reward() -> bool:
	if not _pending_constellation_reward:
		return false

	_pending_constellation_reward = false
	var dialogue_state := get_node_or_null(elder_dialogue_state_path) as ElderStarsDialogueState
	if dialogue_state == null or not dialogue_state.can_grant_constellation_reward():
		return false
	if RewardService == null:
		return false

	return bool(
		RewardService.call(
			"grant_reward",
			ELDER_REWARD_SOURCE_ID,
			ELDER_REWARD_MARKER_ID,
			BRASS_KEY_ITEM,
			1,
			DEFAULT_TARGET_SCENE_PATH
		)
	)


func handle_dialogue_finished(_resource: DialogueResource) -> void:
	_sync_dialogue_setup()


func resolve_dialogue_speaker(character_name: String) -> Node3D:
	var normalized_name := character_name.strip_edges().to_lower()
	if normalized_name.is_empty():
		return null

	if normalized_name == get_dialogue_speaker_name().strip_edges().to_lower():
		return self

	for follower in get_ordered_dialogue_followers():
		if _get_actor_dialogue_name(follower).to_lower() == normalized_name:
			return follower

	return null


func resolve_dialogue_speaker_for_line(character_name: String, _dialogue_line: DialogueLine) -> Node3D:
	return resolve_dialogue_speaker(character_name)


func contains_dialogue_speaker(speaker: Node3D) -> bool:
	if speaker == self:
		return true

	for follower in get_ordered_dialogue_followers():
		if follower == speaker:
			return true

	return false


func should_keep_followers_visible_during_dialogue() -> bool:
	return not get_ordered_dialogue_followers().is_empty()


func get_dialogue_pivot_offset_for_actor(actor: Node3D) -> Vector3:
	if actor == null or actor == self:
		return Vector3.ZERO

	var delta := actor.global_position - global_position
	delta.y = 0.0
	if delta.is_zero_approx():
		return Vector3.ZERO

	var side := signf(delta.dot(global_transform.basis.x))
	if is_zero_approx(side):
		return Vector3.ZERO

	return Vector3(side * FOLLOWER_PIVOT_OFFSET, 0.0, 0.0)


func get_ordered_dialogue_followers() -> Array[Node3D]:
	var tree := get_tree()
	if tree == null:
		return []

	var followers: Array[Node3D] = []
	for actor in tree.get_nodes_in_group(FRIEND_FOLLOWERS_GROUP):
		var follower := actor as Node3D
		if follower == null or not is_instance_valid(follower):
			continue
		if _get_follower_order_index(follower) < FOLLOWER_DIALOGUE_ORDER.size():
			followers.append(follower)

	followers.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _get_follower_order_index(a) < _get_follower_order_index(b)
	)
	return followers


func _update_follow_animation_state() -> void:
	if _dialogue_animation_mode_active:
		return

	_travel_to(ELDER_STATE_NAME)


func _configure_elder_trees() -> void:
	if animation_player == null:
		return

	var elder_animation := _find_elder_animation_name()
	if elder_animation.is_empty():
		elder_animation = &"leaningoncane"

	_set_tree_animation(animation_tree, elder_animation)
	_set_tree_animation(dialogue_animation_tree, elder_animation)


func _sync_dialogue_setup() -> void:
	var interaction_target := get_interaction_target()
	var dialogue_state := get_node_or_null(elder_dialogue_state_path) as ElderStarsDialogueState
	if interaction_target == null or dialogue_state == null:
		return

	interaction_target.dialogue_resource = ELDER_DIALOGUE_RESOURCE
	interaction_target.dialogue_start_title = String(dialogue_state.get_dialogue_start_title())


func _set_tree_animation(tree: AnimationTree, animation_name: StringName) -> void:
	if tree == null:
		return

	var state_machine := tree.tree_root as AnimationNodeStateMachine
	if state_machine == null:
		return

	var animation_node := state_machine.get_node(ELDER_STATE_NAME) as AnimationNodeAnimation
	if animation_node != null:
		animation_node.animation = animation_name


func _find_elder_animation_name() -> StringName:
	if animation_player == null:
		return StringName()

	var animation_names := animation_player.get_animation_list()
	for animation_name in ELDER_ANIMATION_CANDIDATES:
		if animation_name in animation_names:
			return animation_name

	for animation_name in animation_names:
		var lowered_name := String(animation_name).to_lower()
		if lowered_name.contains("lean") and lowered_name.contains("cane"):
			return animation_name

	return StringName()


func _get_actor_dialogue_name(actor: Node3D) -> String:
	if actor == null:
		return ""

	if actor.has_method("get_npc_dialogue_name"):
		return String(actor.call("get_npc_dialogue_name")).strip_edges()
	if actor.has_method("get_dialogue_speaker_name"):
		return String(actor.call("get_dialogue_speaker_name")).strip_edges()

	return actor.name.strip_edges()


func _get_follower_order_index(actor: Node3D) -> int:
	var follower_name := _get_actor_dialogue_name(actor)
	var index := FOLLOWER_DIALOGUE_ORDER.find(follower_name)
	if index >= 0:
		return index

	return FOLLOWER_DIALOGUE_ORDER.size()
