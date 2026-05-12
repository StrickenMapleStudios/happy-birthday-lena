extends Node

class_name NpcFriendFollowStateComponent

const DIALOGUE_STATE_GROUP := &"dialogue_state_components"

@export var target_group: StringName = &"player_character"
@export var turn_speed := 7.5
@export var follow_distance := 2.8
@export var stop_distance := 1.9
@export var repath_distance := 0.75
@export var side_offset := 0.9
@export var avoidance_enabled := true
@export var is_friend := false

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var _target_actor: Node3D
var _follow_paused := false
var _last_requested_target := Vector3.INF


func _ready() -> void:
	add_to_group(DIALOGUE_STATE_GROUP)
	if navigation_agent != null:
		navigation_agent.avoidance_enabled = avoidance_enabled


func _physics_process(delta: float) -> void:
	var actor := get_parent() as CharacterBody3D
	if actor == null:
		return

	if not is_friend or _follow_paused:
		_stop_following(actor, delta)
		return

	if not is_instance_valid(_target_actor):
		_target_actor = _find_target_actor()
	if not is_instance_valid(_target_actor):
		_stop_following(actor, delta)
		return

	var desired_target := _get_follow_target_position()
	if desired_target == Vector3.INF:
		_stop_following(actor, delta)
		return

	if _last_requested_target == Vector3.INF or _last_requested_target.distance_to(desired_target) >= repath_distance:
		navigation_agent.target_position = desired_target
		_last_requested_target = desired_target

	var planar_delta := desired_target - actor.global_position
	planar_delta.y = 0.0
	if planar_delta.length() <= stop_distance:
		_stop_following(actor, delta)
		return

	if navigation_agent.is_navigation_finished():
		_stop_following(actor, delta)
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var move_direction := next_path_position - actor.global_position
	move_direction.y = 0.0
	if move_direction.length_squared() <= 0.0001:
		_stop_following(actor, delta)
		return

	move_direction = move_direction.normalized()
	_apply_follow_navigation(actor, move_direction)


func become_friend() -> void:
	is_friend = true
	_follow_paused = false
	_target_actor = _find_target_actor()
	_last_requested_target = Vector3.INF


func pause_following() -> void:
	_follow_paused = true
	_last_requested_target = Vector3.INF


func resume_following() -> void:
	if not is_friend:
		return

	_follow_paused = false
	_target_actor = _find_target_actor()
	_last_requested_target = Vector3.INF


func _find_target_actor() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null

	var candidates := tree.get_nodes_in_group(target_group)
	for candidate in candidates:
		if candidate is Node3D:
			return candidate as Node3D

	return null


func _get_follow_target_position() -> Vector3:
	if not is_instance_valid(_target_actor):
		return Vector3.INF

	var target_position := _target_actor.global_position
	target_position.y = (get_parent() as Node3D).global_position.y
	return target_position


func _stop_following(actor: CharacterBody3D, _delta: float) -> void:
	_apply_follow_navigation(actor, Vector3.ZERO)


func _apply_follow_navigation(actor: CharacterBody3D, direction: Vector3) -> void:
	if actor != null and actor.has_method("set_follow_navigation"):
		actor.call("set_follow_navigation", direction, turn_speed)
