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

@export var interaction_target_path: NodePath = ^"InteractionTarget"
@export var elder_dialogue_state_path: NodePath = ^"ElderStarsDialogueState"

var _pending_constellation_reward := false


func _ready() -> void:
	_restore_animation_trees_if_needed()
	CharacterAnimationLibrary.apply_to(animation_player)
	if animation_tree != null:
		animation_tree.active = true
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = false
	if animation_tree == null:
		push_warning("Elder character is missing AnimationTree. Elder animation setup was skipped.")
		_sync_dialogue_setup()
		return

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

	_ensure_elder_state_machine(animation_tree, elder_animation)
	_ensure_elder_state_machine(dialogue_animation_tree, elder_animation)
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


func _ensure_elder_state_machine(tree: AnimationTree, animation_name: StringName) -> void:
	if tree == null:
		return

	var state_machine := tree.tree_root as AnimationNodeStateMachine
	if state_machine != null and state_machine.has_node(ELDER_STATE_NAME):
		return

	var new_state_machine := AnimationNodeStateMachine.new()
	new_state_machine.graph_offset = Vector2(-72.0, -6.0)
	new_state_machine.add_node(&"Start", AnimationNodeOutput.new(), Vector2(160.0, 116.0))
	new_state_machine.add_node(ELDER_STATE_NAME, _make_elder_animation_node(animation_name), Vector2(372.0, 117.0))
	var start_transition := AnimationNodeStateMachineTransition.new()
	start_transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	new_state_machine.add_transition(&"Start", ELDER_STATE_NAME, start_transition)
	tree.tree_root = new_state_machine


func _make_elder_animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var animation_node := AnimationNodeAnimation.new()
	animation_node.animation = animation_name
	return animation_node
