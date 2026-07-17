extends RefCounted

const STATE_START := &"Start"
const STATE_IDLE := &"Idle"
const STATE_WALKING := &"Walking"
const STATE_RUNNING := &"Running"


static func ensure_locomotion_trees(animation_player: AnimationPlayer) -> Dictionary:
	if animation_player == null:
		return {
			"animation_tree": null,
			"dialogue_animation_tree": null,
		}

	var animation_tree := animation_player.get_node_or_null(^"AnimationTree") as AnimationTree
	if animation_tree == null:
		animation_tree = _create_locomotion_tree()
		animation_player.add_child(animation_tree)
		animation_tree.owner = animation_player.owner

	var dialogue_animation_tree := animation_player.get_node_or_null(^"DialogueAnimationTree") as AnimationTree
	if dialogue_animation_tree == null:
		dialogue_animation_tree = _create_dialogue_tree()
		animation_player.add_child(dialogue_animation_tree)
		dialogue_animation_tree.owner = animation_player.owner

	return {
		"animation_tree": animation_tree,
		"dialogue_animation_tree": dialogue_animation_tree,
	}


static func _create_locomotion_tree() -> AnimationTree:
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	tree.root_node = NodePath("../..")
	tree.anim_player = NodePath("..")
	tree.tree_root = _build_locomotion_state_machine()
	return tree


static func _create_dialogue_tree() -> AnimationTree:
	var tree := AnimationTree.new()
	tree.name = "DialogueAnimationTree"
	tree.root_node = NodePath("../..")
	tree.anim_player = NodePath("..")
	tree.tree_root = _build_dialogue_state_machine()
	return tree


static func _build_locomotion_state_machine() -> AnimationNodeStateMachine:
	var state_machine := AnimationNodeStateMachine.new()
	state_machine.graph_offset = Vector2(-39.0, 7.0)
	state_machine.add_node(STATE_START, AnimationNodeOutput.new(), Vector2(186.0, 124.0))
	state_machine.add_node(STATE_IDLE, _make_animation_node(STATE_IDLE), Vector2(414.0, 126.0))
	state_machine.add_node(STATE_WALKING, _make_animation_node(STATE_WALKING), Vector2(678.0, 127.0))
	state_machine.add_node(STATE_RUNNING, _make_animation_node(STATE_RUNNING), Vector2(678.0, 44.0))
	state_machine.add_transition(STATE_START, STATE_IDLE, _make_transition(0.0, true))
	state_machine.add_transition(STATE_IDLE, STATE_WALKING, _make_transition(0.25))
	state_machine.add_transition(STATE_IDLE, STATE_RUNNING, _make_transition(0.25))
	state_machine.add_transition(STATE_WALKING, STATE_IDLE, _make_transition(0.25))
	state_machine.add_transition(STATE_WALKING, STATE_RUNNING, _make_transition(0.25))
	state_machine.add_transition(STATE_RUNNING, STATE_IDLE, _make_transition(0.25))
	state_machine.add_transition(STATE_RUNNING, STATE_WALKING, _make_transition(0.25))
	return state_machine


static func _build_dialogue_state_machine() -> AnimationNodeStateMachine:
	var state_machine := AnimationNodeStateMachine.new()
	state_machine.graph_offset = Vector2(-72.0, -6.0)
	state_machine.add_node(STATE_START, AnimationNodeOutput.new(), Vector2(160.0, 116.0))
	state_machine.add_node(STATE_IDLE, _make_animation_node(STATE_IDLE), Vector2(366.0, 117.0))
	state_machine.add_transition(STATE_START, STATE_IDLE, _make_transition(0.0, true))
	return state_machine


static func _make_animation_node(animation_name: StringName) -> AnimationNodeAnimation:
	var animation_node := AnimationNodeAnimation.new()
	animation_node.animation = animation_name
	return animation_node


static func _make_transition(xfade_time: float, auto_advance: bool = false) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade_time
	if auto_advance:
		transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	return transition
