extends Node3D

@export var lap_track_path: NodePath = ^"LapTrack"
@export var player_path: NodePath = ^"PlayerCharacter"
@export var npc_runner_path: NodePath = ^"NpcRunner"
@export var npc_lane_runner_path: NodePath = ^"NpcLaneRunner"
@export_enum("Inner", "Outer") var player_lane := 0
@export_enum("Inner", "Outer") var npc_lane := 1


func _ready() -> void:
	var lap_track: LapTrack = get_node_or_null(lap_track_path) as LapTrack
	if lap_track == null:
		return

	var player: CharacterBody3D = get_node_or_null(player_path) as CharacterBody3D
	var npc_runner: CharacterBody3D = get_node_or_null(npc_runner_path) as CharacterBody3D

	if player != null:
		_place_actor_on_lane(player, lap_track, player_lane)

	if npc_runner != null:
		_place_actor_on_lane(npc_runner, lap_track, npc_lane)
		_disable_npc_interaction(npc_runner)

	var lane_runner: Node = get_node_or_null(npc_lane_runner_path)
	if lane_runner != null:
		lane_runner.set("lane_side", npc_lane)
		if lane_runner.has_method("restart"):
			lane_runner.call("restart")


func _place_actor_on_lane(actor: CharacterBody3D, lap_track: LapTrack, lane: int) -> void:
	var marker: Marker3D = lap_track.get_lane_marker(lane)
	if marker == null:
		return

	actor.global_position = marker.global_position
	var direction: Vector3 = lap_track.get_lane_forward_direction(lane)
	if actor.has_method("face_towards_position"):
		actor.call("face_towards_position", actor.global_position + direction)


func _disable_npc_interaction(actor: CharacterBody3D) -> void:
	var interaction_target: Area3D = actor.get_node_or_null(^"InteractionTarget") as Area3D
	if interaction_target != null:
		interaction_target.monitoring = false
		interaction_target.monitorable = false
		interaction_target.collision_layer = 0
		interaction_target.collision_mask = 0
		interaction_target.set("interaction_enabled", false)

	var look_tracking: Area3D = actor.get_node_or_null(^"LookTracking") as Area3D
	if look_tracking != null:
		look_tracking.monitoring = false
		look_tracking.monitorable = false
		look_tracking.collision_layer = 0
		look_tracking.collision_mask = 0
		if look_tracking.has_method("set_tracking_enabled"):
			look_tracking.call("set_tracking_enabled", false)

	var friend_follow_state: Node = actor.get_node_or_null(^"FriendFollowState")
	if friend_follow_state != null:
		friend_follow_state.set_process(false)
		friend_follow_state.set_physics_process(false)
		friend_follow_state.set_process_internal(false)
		friend_follow_state.set_physics_process_internal(false)
