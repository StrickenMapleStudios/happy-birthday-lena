extends "res://assets/scripts/npc_character.gd"

const ELDER_STATE_NAME := &"LeaningOnCane"
const ELDER_ANIMATION_CANDIDATES := [
	&"leaningoncane",
	&"LeaningOnCane",
	&"Leaningoncane",
	&"Leaning_On_Cane",
]


func _ready() -> void:
	CharacterAnimationLibrary.apply_to(animation_player)
	if animation_tree != null:
		animation_tree.active = true
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = false

	_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_configure_elder_trees()
	_travel_to(ELDER_STATE_NAME)


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
