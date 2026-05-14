extends Node3D

const MAIN_MENU_SCENE_PATH := "res://assets/scenes/menu/menu_main.tscn"

@export var lap_track_path: NodePath = ^"LapTrack"
@export var player_path: NodePath = ^"PlayerCharacter"
@export var npc_runner_path: NodePath = ^"NpcRunner"
@export var npc_lane_runner_path: NodePath = ^"NpcLaneRunner"
@export var pause_menu_path: NodePath = ^"PauseMenu"
@export var countdown_ui_path: NodePath = ^"LapCountdownUi"
@export_enum("Inner", "Outer") var player_lane := 0
@export_enum("Inner", "Outer") var npc_lane := 1
@export_range(1, 12, 1) var total_laps := 3

var _lap_track: LapTrack
var _player: CharacterBody3D
var _npc_runner: CharacterBody3D
var _npc_lane_runner: Node
var _pause_menu: Node
var _countdown_ui: LapCountdownUi
var _pause_active := false
var _race_finished := false
var _countdown_active := false
var _race_active := false
var _current_lap := 1
var _checkpoint_visited: Array[bool] = []
var _connected_start_trigger: Area3D
var _connected_checkpoint_triggers: Array[Area3D] = []


func _ready() -> void:
	_lap_track = get_node_or_null(lap_track_path) as LapTrack
	_player = get_node_or_null(player_path) as CharacterBody3D
	_npc_runner = get_node_or_null(npc_runner_path) as CharacterBody3D
	_npc_lane_runner = get_node_or_null(npc_lane_runner_path)
	_pause_menu = get_node_or_null(pause_menu_path)
	_countdown_ui = get_node_or_null(countdown_ui_path) as LapCountdownUi

	if _lap_track == null:
		return

	_place_actors_on_lanes()
	_configure_pause_menu()
	_connect_track_triggers()
	_reset_checkpoint_progress()
	call_deferred("_start_race")


func _unhandled_input(event: InputEvent) -> void:
	if _pause_active:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _place_actors_on_lanes() -> void:
	if _player != null:
		_place_actor_on_lane(_player, _lap_track, player_lane)

	if _npc_runner != null:
		_place_actor_on_lane(_npc_runner, _lap_track, npc_lane)
		_disable_npc_interaction(_npc_runner)

	if _npc_lane_runner != null:
		_npc_lane_runner.set("lane_side", npc_lane)
		if _npc_lane_runner.has_method("restart"):
			_npc_lane_runner.call("restart")


func _configure_pause_menu() -> void:
	if _pause_menu == null:
		return

	var pause_menu_root := _pause_menu.get_node_or_null("MenuRoot") as Control
	if pause_menu_root != null:
		pause_menu_root.visible = false
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	if _pause_menu.has_signal("resume_requested"):
		_pause_menu.connect("resume_requested", Callable(self, "_resume_from_pause"))
	if _pause_menu.has_signal("main_menu_requested"):
		_pause_menu.connect("main_menu_requested", Callable(self, "_return_to_main_menu"))
	if _pause_menu.has_signal("quit_requested"):
		_pause_menu.connect("quit_requested", Callable(self, "_quit_from_pause"))


func _connect_track_triggers() -> void:
	if _lap_track == null:
		return

	var start_trigger := _lap_track.get_start_trigger()
	var start_trigger_callable := Callable(self, "_on_start_trigger_body_entered")
	if start_trigger != null and not start_trigger.body_entered.is_connected(start_trigger_callable):
		start_trigger.body_entered.connect(start_trigger_callable)
	_connected_start_trigger = start_trigger

	_connected_checkpoint_triggers.clear()
	var checkpoints := _lap_track.get_checkpoint_triggers()
	_checkpoint_visited.resize(checkpoints.size())
	for checkpoint_index in range(checkpoints.size()):
		_checkpoint_visited[checkpoint_index] = false
		var checkpoint: Area3D = checkpoints[checkpoint_index]
		var checkpoint_callable := Callable(self, "_on_checkpoint_trigger_body_entered").bind(checkpoint_index)
		if checkpoint != null and not checkpoint.body_entered.is_connected(checkpoint_callable):
			checkpoint.body_entered.connect(checkpoint_callable)
		_connected_checkpoint_triggers.append(checkpoint)


func _start_race() -> void:
	if _player == null:
		return

	_current_lap = 1
	_race_finished = false
	_countdown_active = true
	_race_active = false
	_reset_checkpoint_progress()
	_set_race_motion_enabled(false)
	if _countdown_ui != null:
		await _countdown_ui.play_countdown()
	_countdown_active = false
	_race_active = true
	_set_race_motion_enabled(true)
	print("Lap race started. Lap 1/%d" % total_laps)


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
	if not _race_active or body != _player:
		return
	if checkpoint_index < 0 or checkpoint_index >= _checkpoint_visited.size():
		return
	if _checkpoint_visited[checkpoint_index]:
		return

	_checkpoint_visited[checkpoint_index] = true
	print("Checkpoint %d/%d" % [_get_visited_checkpoint_count(), _checkpoint_visited.size()])


func _on_start_trigger_body_entered(body: Node3D) -> void:
	if not _race_active or body != _player:
		return
	if not _all_checkpoints_visited():
		return

	var completed_lap := _current_lap
	_reset_checkpoint_progress()
	if completed_lap >= total_laps:
		_finish_race()
		return

	_current_lap += 1
	print("Lap %d/%d complete. Starting lap %d/%d." % [completed_lap, total_laps, _current_lap, total_laps])


func _finish_race() -> void:
	_race_active = false
	_race_finished = true
	_set_race_motion_enabled(false)
	print("Lap race finished in %d lap(s)." % total_laps)


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


func _open_pause_menu() -> void:
	if _pause_active or _pause_menu == null:
		return

	_pause_active = true
	get_tree().paused = true
	_pause_menu.call("open")


func _resume_from_pause() -> void:
	if not _pause_active:
		return

	get_tree().paused = false
	_pause_active = false
	if _pause_menu != null:
		_pause_menu.call("close")


func _return_to_main_menu() -> void:
	get_tree().paused = false
	_pause_active = false
	if _pause_menu != null:
		_pause_menu.call("close")
	await SceneTransition.change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _quit_from_pause() -> void:
	get_tree().paused = false
	_pause_active = false
	if _pause_menu != null:
		_pause_menu.call("close")
	get_tree().quit.call_deferred()


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
