extends Node

class_name LapTrackManager

const NORMAL_GAME_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"
const LAP_REWARD_SOURCE_ID := &"lap_finish_reward"
const LAP_REWARD_MARKER_ID := &"lap_finish_reward_marker"
const BRASS_KEY_ITEM := preload("res://assets/data/items/brass_key_item.tres")
const RACE_RESULT_WIN := &"win"
const RACE_RESULT_LOSE := &"lose"

@export var lap_track_path: NodePath = ^"../LapTrack"
@export var player_path: NodePath = ^"../PlayerCharacter"
@export var npc_runner_path: NodePath = ^"../NpcRunner"
@export var npc_lane_runner_path: NodePath = ^"../NpcLaneRunner"
@export var countdown_ui_path: NodePath = ^"../LapCountdownUi"
@export var lap_counter_ui_path: NodePath = ^"../LapCounterUi"
@export_enum("Inner", "Outer") var player_lane := 0
@export_enum("Inner", "Outer") var npc_lane := 1
@export_range(1, 12, 1) var total_laps := 1
@export_range(0.1, 4.0, 0.05) var finish_slowdown_duration := 1.35
@export_range(0.1, 4.0, 0.05) var finish_fade_duration := 1.1
@export var auto_place_player_on_lane := false
@export var auto_place_npc_on_lane := false

var _lap_track: LapTrack
var _player: CharacterBody3D
var _npc_runner: CharacterBody3D
var _npc_lane_runner: Node
var _countdown_ui: LapCountdownUi
var _lap_counter_ui: LapCounterUi
var _race_finished := false
var _countdown_active := false
var _race_active := false
var _completed_laps := 0
var _npc_completed_laps := 0
var _checkpoint_visited: Array[bool] = []
var _connected_start_trigger: Area3D
var _connected_checkpoint_triggers: Array[Area3D] = []
var _finish_sequence_running := false
var _time_scale_tween: Tween
var _player_won := true


func _ready() -> void:
	Engine.time_scale = 1.0
	_lap_track = get_node_or_null(lap_track_path) as LapTrack
	_player = get_node_or_null(player_path) as CharacterBody3D
	_npc_runner = get_node_or_null(npc_runner_path) as CharacterBody3D
	_npc_lane_runner = get_node_or_null(npc_lane_runner_path)
	_countdown_ui = get_node_or_null(countdown_ui_path) as LapCountdownUi
	_lap_counter_ui = get_node_or_null(lap_counter_ui_path) as LapCounterUi

	if _lap_track == null:
		return

	_place_actors_on_lanes()
	_connect_track_triggers()
	_connect_npc_runner_signals()
	_reset_checkpoint_progress()
	_refresh_lap_counter()
	call_deferred("_start_race")


func _exit_tree() -> void:
	_kill_time_scale_tween()
	Engine.time_scale = 1.0


func _start_race() -> void:
	if _player == null:
		return

	_completed_laps = 0
	_npc_completed_laps = 0
	_race_finished = false
	_countdown_active = true
	_race_active = false
	_player_won = true
	_reset_checkpoint_progress()
	_refresh_lap_counter()
	_set_race_motion_enabled(false)
	if _countdown_ui != null:
		var go_callable := Callable(self, "_on_countdown_go_released")
		if not _countdown_ui.go_released.is_connected(go_callable):
			_countdown_ui.go_released.connect(go_callable)
		await _countdown_ui.play_countdown()
	else:
		_on_countdown_go_released()
	_countdown_active = false
	print("Lap race started. Total laps: %d" % total_laps)


func _place_actors_on_lanes() -> void:
	if auto_place_player_on_lane and _player != null:
		_place_actor_on_lane(_player, _lap_track, player_lane)

	if auto_place_npc_on_lane and _npc_runner != null:
		_place_actor_on_lane(_npc_runner, _lap_track, npc_lane)

	if _npc_runner != null:
		_disable_npc_interaction(_npc_runner)

	if _npc_lane_runner != null:
		_npc_lane_runner.set("lane_side", npc_lane)
		if _npc_lane_runner.has_method("restart"):
			_npc_lane_runner.call("restart")


func _connect_track_triggers() -> void:
	if _lap_track == null:
		return

	var start_trigger := _lap_track.get_start_trigger()
	var start_trigger_callable := Callable(self, "_on_start_trigger_body_entered")
	if start_trigger != null and not start_trigger.body_entered.is_connected(start_trigger_callable):
		start_trigger.body_entered.connect(start_trigger_callable)
	_connected_start_trigger = start_trigger

	_connected_checkpoint_triggers.clear()
	var checkpoints: Array[Area3D] = _lap_track.get_checkpoint_triggers()
	_checkpoint_visited.resize(checkpoints.size())
	for checkpoint_index in range(checkpoints.size()):
		_checkpoint_visited[checkpoint_index] = false
		var checkpoint: Area3D = checkpoints[checkpoint_index]
		var checkpoint_callable := Callable(self, "_on_checkpoint_trigger_body_entered").bind(checkpoint_index)
		if checkpoint != null and not checkpoint.body_entered.is_connected(checkpoint_callable):
			checkpoint.body_entered.connect(checkpoint_callable)
		_connected_checkpoint_triggers.append(checkpoint)


func _connect_npc_runner_signals() -> void:
	if _npc_lane_runner == null or not _npc_lane_runner.has_signal("lap_completed"):
		return

	var lap_completed_callable := Callable(self, "_on_npc_lap_completed")
	if not _npc_lane_runner.is_connected("lap_completed", lap_completed_callable):
		_npc_lane_runner.connect("lap_completed", lap_completed_callable)


func _set_race_motion_enabled(is_enabled: bool) -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", is_enabled)

	if _npc_runner != null and _npc_runner.has_method("set_follow_navigation"):
		_npc_runner.call("set_follow_navigation", Vector3.ZERO, 0.0, false)

	if _npc_lane_runner != null:
		_npc_lane_runner.set_process(is_enabled)
		_npc_lane_runner.set_physics_process(is_enabled)
		if is_enabled and _npc_lane_runner.has_method("restart"):
			_npc_lane_runner.call("restart")


func _on_checkpoint_trigger_body_entered(body: Node3D, checkpoint_index: int) -> void:
	if not _race_active or body != _player or _finish_sequence_running:
		return
	if checkpoint_index < 0 or checkpoint_index >= _checkpoint_visited.size():
		return
	if _checkpoint_visited[checkpoint_index]:
		return

	_checkpoint_visited[checkpoint_index] = true
	print("Checkpoint %d/%d" % [_get_visited_checkpoint_count(), _checkpoint_visited.size()])


func _on_start_trigger_body_entered(body: Node3D) -> void:
	if _finish_sequence_running:
		return
	if body != _player:
		return
	if not _race_active:
		return
	if not _all_checkpoints_visited():
		return

	_completed_laps += 1
	_refresh_lap_counter()
	_reset_checkpoint_progress()
	if _completed_laps >= total_laps:
		_finish_race(true)
		return

	print("Lap %d/%d complete." % [_completed_laps, total_laps])


func _finish_race(player_won: bool = true) -> void:
	_race_active = false
	_race_finished = true
	_player_won = player_won
	print("Lap race finished in %d lap(s). Result: %s" % [total_laps, "win" if player_won else "lose"])
	if _finish_sequence_running:
		return
	call_deferred("_run_finish_sequence")


func complete_lap_state(player_won: bool = true) -> void:
	if _finish_sequence_running:
		return

	_race_active = false
	_race_finished = true
	_player_won = player_won
	if player_won:
		_queue_finish_reward()
	call_deferred("_run_finish_sequence")


func _on_countdown_go_released() -> void:
	if _race_active:
		return

	_race_active = true
	_set_race_motion_enabled(true)


func _refresh_lap_counter() -> void:
	if _lap_counter_ui != null:
		_lap_counter_ui.set_progress(_completed_laps, total_laps)


func _reset_checkpoint_progress() -> void:
	for checkpoint_index in range(_checkpoint_visited.size()):
		_checkpoint_visited[checkpoint_index] = false


func _get_visited_checkpoint_count() -> int:
	var visited_count := 0
	for is_visited in _checkpoint_visited:
		if is_visited:
			visited_count += 1
	return visited_count


func _all_checkpoints_visited() -> bool:
	if _checkpoint_visited.is_empty():
		return false

	for is_visited in _checkpoint_visited:
		if not is_visited:
			return false
	return true


func _on_npc_lap_completed(total_completed_laps: int) -> void:
	if not _race_active or _finish_sequence_running:
		return

	_npc_completed_laps = total_completed_laps
	if _npc_completed_laps >= total_laps:
		_finish_race(false)


func _run_finish_sequence() -> void:
	if _finish_sequence_running:
		return

	_finish_sequence_running = true
	if _player_won:
		_queue_finish_reward()
	if LapRaceFlow != null:
		LapRaceFlow.finish_race(RACE_RESULT_WIN if _player_won else RACE_RESULT_LOSE)
	_kill_time_scale_tween()
	_time_scale_tween = create_tween()
	_time_scale_tween.set_ignore_time_scale(true)
	_time_scale_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_time_scale_tween.set_trans(Tween.TRANS_CUBIC)
	_time_scale_tween.set_ease(Tween.EASE_OUT)
	_time_scale_tween.tween_method(
		Callable(self, "_set_finish_time_scale"),
		Engine.time_scale,
		0.0,
		finish_slowdown_duration
	)
	await SceneTransition.change_scene_to_file(NORMAL_GAME_SCENE_PATH, finish_fade_duration, 0.35)


func _queue_finish_reward() -> void:
	if RewardService == null:
		return

	RewardService.call(
		"grant_reward",
		LAP_REWARD_SOURCE_ID,
		LAP_REWARD_MARKER_ID,
		BRASS_KEY_ITEM,
		1,
		NORMAL_GAME_SCENE_PATH
	)


func _set_finish_time_scale(value: float) -> void:
	Engine.time_scale = clampf(value, 0.0, 1.0)


func _kill_time_scale_tween() -> void:
	if _time_scale_tween != null and _time_scale_tween.is_valid():
		_time_scale_tween.kill()
	_time_scale_tween = null


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
