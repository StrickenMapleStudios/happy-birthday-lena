extends Node3D

const MAIN_MENU_SCENE_PATH := "res://assets/scenes/menu/menu_main.tscn"
const DIALOGUE_PAUSE_MENU_SCENE := preload("res://assets/scenes/ui/dialogue_pause_menu.tscn")
const CUTSCENE_PAUSE_MENU_SCENE := preload("res://assets/scenes/ui/cutscene_pause_menu.tscn")
const LABYRINTH_PAUSE_MENU_SCENE := preload("res://assets/scenes/ui/labyrinth_pause_menu.tscn")
const FOUND_ITEM_POPUP_SCENE := preload("res://assets/scenes/ui/found_item_popup.tscn")

@onready var camera_rig := $CameraRig
@onready var dialogue_pivot_right := $DialoguePivotRight
@onready var dialogue_pivot_left := $DialoguePivotLeft
@onready var dialogue_camera_right: Camera3D = $DialoguePivotRight/DialogueCameraRight
@onready var dialogue_camera_left: Camera3D = $DialoguePivotLeft/DialogueCameraLeft
@onready var game_camera: Camera3D = $CameraRig/GameCamera
@onready var player := $character
@onready var interaction_source: InteractionSource = $character/InteractionSource
@onready var interaction_prompt_controller: InteractionPromptController = $InteractionPromptController
@onready var gameplay_ui_layer: GameplayUiLayer = $GameplayUI
@onready var pause_menu: Node = $PauseMenu
@onready var inventory_ui: InventoryUi = $InventoryUI
@onready var dialogue_manager: Node = Engine.get_singleton("DialogueManager")

const DIALOGUE_BALLOON_SCENE := preload("res://assets/scenes/ui/dialogue_balloon.tscn")
const DIALOGUE_PIVOT_YAW_OFFSET := PI
const AUDIO_PRESET_GAMEPLAY := &"gameplay"
const AUDIO_PRESET_PAUSE := &"pause"
const AUDIO_PRESET_DIALOGUE := &"dialogue"
const AUDIO_PRESET_FADE_DURATION := 0.15
const INVENTORY_TIME_SCALE_DURATION := 0.5
const INVENTORY_TIME_SCALE_CLOSED := 1.0
const INVENTORY_TIME_SCALE_OPEN := 0.0
const DEFAULT_GAME_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"
const LABYRINTH_REWARD_SOURCE_ID := &"labyrinth_exit_reward"
const LABYRINTH_REWARD_MARKER_ID := &"labyrinth_exit_reward_marker"
const LAP_REWARD_SOURCE_ID := &"lap_finish_reward"
const LAP_REWARD_MARKER_ID := &"lap_finish_reward_marker"
const BRASS_KEY_ITEM := preload("res://assets/data/items/brass_key_item.tres")

const CURSOR_MODE_INGAME := Input.MOUSE_MODE_CAPTURED
const CURSOR_MODE_UI := Input.MOUSE_MODE_VISIBLE

enum InputContext {
	GAMEPLAY,
	LABYRINTH,
	DIALOGUE,
	DIALOGUE_RESPONSE_SELECTION,
	DEMONSTRATION,
	CUTSCENE,
	INVENTORY,
	PAUSE,
	TRANSITION,
}

var _interaction_locked := false
var _dialogue_active := false
var _dialogue_response_selection_active := false
var _demonstration_active := false
var _cutscene_active := false
var _cutscene_target: Node
var _dialogue_target: InteractionTarget
var _dialogue_target_actor: Node3D
var _current_dialogue_speaker: Node3D
var _right_pivot_actor: Node3D
var _active_dialogue_balloon: Node
var _active_dialogue_resource: DialogueResource
var _saved_player_transform := Transform3D.IDENTITY
var _restore_player_transform_after_sequence := true
var _pause_active := false
var _pause_transition_locked := false
var _dialogue_pause_menu: Node
var _cutscene_pause_menu: Node
var _labyrinth_pause_menu: Node
var _active_pause_menu: Node
var _inventory_open := false
var _found_item_popup_open := false
var _input_context := InputContext.GAMEPLAY
var _focus_before_pause: WeakRef
var _inventory_data: InventoryData = InventoryData.new()
var _hidden_follower_actors: Array[Node3D] = []
var _queued_reward_demonstration_cameras: Array[WeakRef] = []
var _inventory_time_scale_tween: Tween
var _labyrinth_active := false
var _active_labyrinth_area: LabyrinthArea
var _ignored_labyrinth_entry_area: WeakRef
var _found_item_popup: FoundItemPopup
var _pending_lap_return_context: Dictionary = {}
var _reward_demonstration_start_pending := false
var _pending_reward_grant_context: Dictionary = {}
var _pending_race_resolution_context: Dictionary = {}


func _ready() -> void:
	_set_inventory_time_scale(INVENTORY_TIME_SCALE_CLOSED)
	_set_dialogue_pivots_active(false)
	_refresh_gameplay_world_ui_visibility()
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY)
	add_child(_inventory_data)
	_restore_inventory_from_session_state()
	_inventory_data.inventory_changed.connect(Callable(self, "_save_inventory_to_session_state"))
	_inventory_data.item_added.connect(Callable(self, "_on_inventory_item_added"))
	if interaction_source != null:
		interaction_source.interaction_requested.connect(_on_interaction_requested)
		interaction_source.interaction_target_changed.connect(_on_interaction_target_changed)
	if dialogue_manager != null and not dialogue_manager.is_connected("dialogue_ended", Callable(self, "_on_dialogue_ended")):
		dialogue_manager.connect("dialogue_ended", Callable(self, "_on_dialogue_ended"))
	if pause_menu != null:
		var pause_menu_root := pause_menu.get_node_or_null("MenuRoot") as Control
		if pause_menu_root != null:
			pause_menu_root.visible = false
		_connect_pause_menu_signals(pause_menu)
	_dialogue_pause_menu = DIALOGUE_PAUSE_MENU_SCENE.instantiate()
	var dialogue_pause_menu_root := _dialogue_pause_menu.get_node_or_null("MenuRoot") as Control
	if dialogue_pause_menu_root != null:
		dialogue_pause_menu_root.visible = false
	add_child(_dialogue_pause_menu)
	_connect_pause_menu_signals(_dialogue_pause_menu)
	_cutscene_pause_menu = CUTSCENE_PAUSE_MENU_SCENE.instantiate()
	var cutscene_pause_menu_root := _cutscene_pause_menu.get_node_or_null("MenuRoot") as Control
	if cutscene_pause_menu_root != null:
		cutscene_pause_menu_root.visible = false
	add_child(_cutscene_pause_menu)
	_connect_pause_menu_signals(_cutscene_pause_menu)
	_labyrinth_pause_menu = LABYRINTH_PAUSE_MENU_SCENE.instantiate()
	var labyrinth_pause_menu_root := _labyrinth_pause_menu.get_node_or_null("MenuRoot") as Control
	if labyrinth_pause_menu_root != null:
		labyrinth_pause_menu_root.visible = false
	add_child(_labyrinth_pause_menu)
	_connect_pause_menu_signals(_labyrinth_pause_menu)
	if inventory_ui != null:
		var inventory_menu_root := inventory_ui.get_node_or_null("MenuRoot") as Control
		if inventory_menu_root != null:
			inventory_menu_root.visible = false
		inventory_ui.set_inventory(_inventory_data)
		inventory_ui.close_requested.connect(_close_inventory)
	_found_item_popup = FOUND_ITEM_POPUP_SCENE.instantiate() as FoundItemPopup
	if _found_item_popup != null:
		add_child(_found_item_popup)
		_found_item_popup.close()
		_found_item_popup.continue_requested.connect(_close_found_item_popup)
	_connect_labyrinth_area_signals()
	if camera_rig != null and camera_rig.has_signal("labyrinth_view_yaw_changed"):
		camera_rig.connect("labyrinth_view_yaw_changed", Callable(self, "_on_labyrinth_view_yaw_changed"))
	if RewardService != null:
		if RewardService.has_signal("reward_spawned") and not RewardService.is_connected("reward_spawned", Callable(self, "_on_reward_spawned")):
			RewardService.connect("reward_spawned", Callable(self, "_on_reward_spawned"))
		RewardService.call("spawn_pending_rewards", self)
	_capture_pending_lap_race_return()
	_try_start_reward_demonstration()
	_resume_pending_lap_race_return_if_ready()
	_refresh_cursor_mode()
	_sync_follower_gameplay_state()


func _exit_tree() -> void:
	_kill_inventory_time_scale_tween()
	_set_inventory_time_scale(INVENTORY_TIME_SCALE_CLOSED)


func _unhandled_input(event: InputEvent) -> void:
	if _is_scene_transition_active():
		return

	if _found_item_popup_open:
		return

	if _inventory_open:
		return

	if _demonstration_active:
		return

	if _pause_active or _pause_transition_locked:
		return

	if not _dialogue_active and not _cutscene_active:
		if event.is_action_pressed("inventory_toggle") and not _interaction_locked:
			get_viewport().set_input_as_handled()
			_open_inventory()
			return
		if event.is_action_pressed("ui_cancel") and not _interaction_locked:
			get_viewport().set_input_as_handled()
			_open_pause_menu()
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	get_viewport().set_input_as_handled()
	_open_pause_menu()


func _on_interaction_requested(target: InteractionTarget) -> void:
	if _try_handle_non_dialogue_interaction(target):
		return

	await _start_dialogue_with_target(target)


func can_start_dialogue_with_target(target: InteractionTarget, ignore_interaction_availability: bool = false) -> bool:
	if _interaction_locked or _dialogue_active or _cutscene_active or _labyrinth_active or target == null:
		return false

	if not ignore_interaction_availability and not target.is_interaction_available():
		return false

	if dialogue_manager == null:
		return false

	if target.get_dialogue_resource() == null:
		return false

	if target.get_dialogue_camera_mount() == null:
		return false

	if target.get_player_dialogue_anchor() == null:
		return false

	return true


func request_dialogue_with_target(target: InteractionTarget, ignore_interaction_availability: bool = false) -> void:
	if not can_start_dialogue_with_target(target, ignore_interaction_availability):
		return

	call_deferred("_request_dialogue_with_target_deferred", target, ignore_interaction_availability)


func can_start_cutscene_with_target(target: Node, _ignore_interaction_availability: bool = true) -> bool:
	if _interaction_locked or _dialogue_active or _cutscene_active or _labyrinth_active or target == null:
		return false

	if not target.has_method("get_cutscene_camera"):
		return false
	if not target.has_method("get_player_cutscene_anchor"):
		return false

	var cutscene_camera := target.call("get_cutscene_camera") as Camera3D
	var player_cutscene_anchor := target.call("get_player_cutscene_anchor") as Node3D
	return cutscene_camera != null and player_cutscene_anchor != null


func request_cutscene_with_target(target: Node, ignore_interaction_availability: bool = true) -> void:
	if not can_start_cutscene_with_target(target, ignore_interaction_availability):
		return

	call_deferred("_request_cutscene_with_target_deferred", target, ignore_interaction_availability)


func _request_dialogue_with_target_deferred(
	target: InteractionTarget,
	ignore_interaction_availability: bool = false
) -> void:
	await _start_dialogue_with_target(target, ignore_interaction_availability)


func _request_cutscene_with_target_deferred(target: Node, ignore_interaction_availability: bool = true) -> void:
	await _start_cutscene_with_target(target, ignore_interaction_availability)


func _start_dialogue_with_target(
	target: InteractionTarget,
	ignore_interaction_availability: bool = false
) -> void:
	if not can_start_dialogue_with_target(target, ignore_interaction_availability):
		return

	var dialogue_resource := target.get_dialogue_resource()
	var player_dialogue_anchor: Node3D = target.get_player_dialogue_anchor()
	var restore_player_transform := true
	var preserve_player_height := false
	if target.has_method("should_return_player_to_origin_after_dialogue"):
		restore_player_transform = bool(target.call("should_return_player_to_origin_after_dialogue"))
	if target.has_method("should_preserve_player_height_during_dialogue"):
		preserve_player_height = bool(target.call("should_preserve_player_height_during_dialogue"))

	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	_saved_player_transform = player.global_transform
	_restore_player_transform_after_sequence = restore_player_transform
	await SceneTransition.fade_out()
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_hide_follower_actors_for_dialogue()
	_move_player_to_anchor(player_dialogue_anchor, preserve_player_height)
	_dialogue_target_actor = target.get_parent() as Node3D
	var player_focus_position := target.global_position
	if _dialogue_target_actor != null and _dialogue_target_actor.has_method("get_dialogue_focus_position"):
		player_focus_position = _dialogue_target_actor.call("get_dialogue_focus_position")
	player.face_towards_position(player_focus_position)
	if _dialogue_target_actor != null and _dialogue_target_actor.has_method("face_towards_position"):
		_dialogue_target_actor.call("face_towards_position", player.global_position)
	_dialogue_target = target
	_dialogue_active = true
	_dialogue_response_selection_active = false
	AudioService.apply_mix_preset(AUDIO_PRESET_DIALOGUE, AUDIO_PRESET_FADE_DURATION)
	_set_dialogue_speaker(_dialogue_target_actor)
	_sync_input_context()
	_start_dialogue_balloon(dialogue_resource, target.get_dialogue_start_title())
	await get_tree().process_frame
	await SceneTransition.fade_in()
	_interaction_locked = false
	_sync_input_context()


func _start_cutscene_with_target(target: Node, ignore_interaction_availability: bool = true) -> void:
	if not can_start_cutscene_with_target(target, ignore_interaction_availability):
		return

	var cutscene_camera := target.call("get_cutscene_camera") as Camera3D
	var player_cutscene_anchor := target.call("get_player_cutscene_anchor") as Node3D
	if cutscene_camera == null or player_cutscene_anchor == null:
		return
	var restore_player_transform := false
	var preserve_player_height := true
	if target.has_method("should_return_player_to_origin_after_cutscene"):
		restore_player_transform = bool(target.call("should_return_player_to_origin_after_cutscene"))
	if target.has_method("should_preserve_player_height_during_cutscene"):
		preserve_player_height = bool(target.call("should_preserve_player_height_during_cutscene"))

	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	_saved_player_transform = player.global_transform
	_restore_player_transform_after_sequence = restore_player_transform
	await SceneTransition.fade_out()
	_set_dialogue_pivots_active(false)
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_move_player_to_anchor(player_cutscene_anchor, preserve_player_height)
	_cutscene_active = true
	_cutscene_target = target
	if gameplay_ui_layer != null:
		gameplay_ui_layer.set_cinematic_bars_visible(true)
	cutscene_camera.current = true
	await get_tree().process_frame
	_interaction_locked = false
	_set_input_context(InputContext.CUTSCENE)
	await SceneTransition.fade_in()
	_sync_input_context()


func _exit_cutscene_mode() -> void:
	if _interaction_locked or not _cutscene_active:
		return

	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	await SceneTransition.fade_out()
	_set_dialogue_pivots_active(false)
	if gameplay_ui_layer != null:
		gameplay_ui_layer.set_cinematic_bars_visible(false)
	camera_rig.activate_game_camera()
	if _restore_player_transform_after_sequence:
		player.global_transform = _saved_player_transform
	player.set_controls_enabled(true)
	interaction_source.set_interaction_enabled(true)
	_cutscene_active = false
	_cutscene_target = null
	_restore_player_transform_after_sequence = true
	await get_tree().process_frame
	_interaction_locked = false
	_set_input_context(InputContext.GAMEPLAY)
	await SceneTransition.fade_in()
	_sync_input_context()


func _move_player_to_anchor(anchor: Node3D, preserve_y: bool) -> void:
	if anchor == null:
		return

	var anchor_position := anchor.global_position
	if preserve_y:
		anchor_position.y = player.global_position.y
	player.global_position = anchor_position


func _on_interaction_target_changed(target: InteractionTarget) -> void:
	if interaction_prompt_controller != null:
		interaction_prompt_controller.set_target(target)


func _exit_dialogue_mode(skip_fade_in: bool = false) -> void:
	if _interaction_locked or not _dialogue_active:
		return

	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	_set_active_dialogue_input_enabled(false)
	await SceneTransition.fade_out()
	if is_instance_valid(_active_dialogue_balloon):
		if _active_dialogue_balloon.has_method("close_balloon"):
			_active_dialogue_balloon.call("close_balloon")
		else:
			_active_dialogue_balloon.queue_free()
	_active_dialogue_balloon = null
	_active_dialogue_resource = null
	_restore_dialogue_animation_mode(player)
	_restore_dialogue_animation_mode(_dialogue_target_actor)
	_restore_follower_actors_after_dialogue()
	player.global_transform = _saved_player_transform
	player.set_character_visible(true)
	if is_instance_valid(_dialogue_target_actor) and _dialogue_target_actor.has_method("set_character_visible"):
		_dialogue_target_actor.call("set_character_visible", true)
	_set_dialogue_pivots_active(false)
	camera_rig.activate_game_camera()
	player.set_controls_enabled(true)
	interaction_source.set_interaction_enabled(true)
	_dialogue_active = false
	_dialogue_response_selection_active = false
	_dialogue_target = null
	_dialogue_target_actor = null
	_current_dialogue_speaker = null
	_right_pivot_actor = null
	_restore_player_transform_after_sequence = true
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	await get_tree().process_frame
	if not skip_fade_in:
		await SceneTransition.fade_in()
	_interaction_locked = false
	_sync_input_context()


func _cancel_active_dialogue() -> void:
	if _interaction_locked or not _dialogue_active:
		return

	await _exit_dialogue_mode()


func _open_pause_menu() -> void:
	if (
		_pause_active
		or _interaction_locked
		or _inventory_open
		or _found_item_popup_open
		or pause_menu == null
		or _input_context == InputContext.TRANSITION
		or _is_scene_transition_active()
	):
		return

	_pause_active = true
	_capture_focus_before_pause()
	_active_pause_menu = _get_pause_menu_for_current_context()
	if not _dialogue_active and not _cutscene_active and not _labyrinth_active and camera_rig != null and camera_rig.has_method("begin_pause_focus"):
		camera_rig.call("begin_pause_focus")
	get_tree().paused = true
	AudioService.apply_mix_preset(AUDIO_PRESET_PAUSE, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	if _active_pause_menu != null:
		_active_pause_menu.call("open")


func _resume_from_pause() -> void:
	if not _pause_active:
		return

	get_tree().paused = false
	_pause_active = false
	if _active_pause_menu != null:
		_active_pause_menu.call("close")
	_active_pause_menu = null
	if not _dialogue_active and not _cutscene_active and not _labyrinth_active and camera_rig != null and camera_rig.has_method("end_pause_focus"):
		camera_rig.call("end_pause_focus")
	AudioService.apply_mix_preset(
		AUDIO_PRESET_DIALOGUE if _dialogue_active else AUDIO_PRESET_GAMEPLAY,
		AUDIO_PRESET_FADE_DURATION
	)
	_sync_input_context()
	call_deferred("_restore_focus_after_pause")


func _open_inventory() -> void:
	if _inventory_open or _found_item_popup_open or _interaction_locked or _pause_active or _dialogue_active or _cutscene_active or inventory_ui == null:
		return

	_inventory_open = true
	_tween_inventory_time_scale(INVENTORY_TIME_SCALE_OPEN)
	_capture_focus_before_pause()
	_inventory_data.set_selected_category(InventoryData.CATEGORY_REGULAR)
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_sync_input_context()
	inventory_ui.open()


func _close_inventory() -> void:
	if not _inventory_open:
		return

	_inventory_open = false
	_tween_inventory_time_scale(INVENTORY_TIME_SCALE_CLOSED)
	if inventory_ui != null:
		inventory_ui.close()
	_inventory_data.set_selected_category(InventoryData.CATEGORY_REGULAR)
	player.set_controls_enabled(true)
	interaction_source.set_interaction_enabled(true)
	_sync_input_context()
	call_deferred("_restore_focus_after_pause")


func _exit_dialogue_from_pause() -> void:
	if not _pause_active:
		return

	get_tree().paused = false
	_pause_active = false
	if _active_pause_menu != null:
		_active_pause_menu.call("close")
	_active_pause_menu = null
	AudioService.apply_mix_preset(AUDIO_PRESET_DIALOGUE, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	await _cancel_active_dialogue()


func _exit_cutscene_from_pause() -> void:
	if not _pause_active:
		return

	get_tree().paused = false
	_pause_active = false
	if _active_pause_menu != null:
		_active_pause_menu.call("close")
	_active_pause_menu = null
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	await _exit_cutscene_mode()


func _exit_labyrinth_from_pause() -> void:
	if not _pause_active:
		return

	var labyrinth_area := _active_labyrinth_area
	get_tree().paused = false
	_pause_active = false
	if _active_pause_menu != null:
		_active_pause_menu.call("close")
	_active_pause_menu = null
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	await SceneTransition.fade_out()
	_exit_labyrinth_mode()
	if labyrinth_area != null and is_instance_valid(labyrinth_area):
		player.global_transform = labyrinth_area.get_return_transform(player)
		_ignored_labyrinth_entry_area = weakref(labyrinth_area)
	await get_tree().process_frame
	await SceneTransition.fade_in()
	_interaction_locked = false
	_sync_input_context()


func _return_to_main_menu() -> void:
	if _pause_transition_locked:
		return

	_pause_transition_locked = true
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	if _active_pause_menu != null:
		_active_pause_menu.call("close")
	elif pause_menu != null:
		pause_menu.call("close")
	get_tree().paused = false
	_pause_active = false
	_active_pause_menu = null
	_focus_before_pause = null
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	await SceneTransition.change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _quit_from_pause() -> void:
	if _pause_transition_locked:
		return

	_pause_transition_locked = true
	if camera_rig != null and camera_rig.has_method("reset_pause_focus_immediately"):
		camera_rig.call("reset_pause_focus_immediately")
	get_tree().paused = false
	_pause_active = false
	if _active_pause_menu != null:
		_active_pause_menu.call("close")
	elif pause_menu != null:
		pause_menu.call("close")
	_active_pause_menu = null
	_focus_before_pause = null
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	get_tree().quit.call_deferred()


func _start_dialogue_balloon(dialogue_resource: DialogueResource, start_title: String) -> void:
	if dialogue_manager == null:
		push_warning("DialogueManager singleton is not available.")
		return

	_active_dialogue_resource = dialogue_resource
	var dialogue_game_states: Array = [player, _dialogue_target_actor, self]
	if player != null and player.has_method("get_dialogue_speaker_name"):
		var player_dialogue_name := String(player.call("get_dialogue_speaker_name"))
		dialogue_game_states.append({
			"player_name": player_dialogue_name,
			"reply_name": player_dialogue_name,
			"echo_name": player_dialogue_name
		})
	if _dialogue_target != null and _dialogue_target.has_method("get_dialogue_game_states"):
		dialogue_game_states.append_array(_dialogue_target.call("get_dialogue_game_states"))
	_active_dialogue_balloon = dialogue_manager.show_dialogue_balloon_scene(
		DIALOGUE_BALLOON_SCENE,
		dialogue_resource,
		start_title,
		dialogue_game_states
	)

	if _active_dialogue_balloon != null and _active_dialogue_balloon.has_signal("speaker_changed"):
		_active_dialogue_balloon.connect("speaker_changed", Callable(self, "_on_balloon_speaker_changed"))
	if _active_dialogue_balloon != null and _active_dialogue_balloon.has_signal("response_selection_state_changed"):
		_active_dialogue_balloon.connect(
			"response_selection_state_changed",
			Callable(self, "_on_balloon_response_selection_state_changed")
		)
	if _active_dialogue_balloon != null and _active_dialogue_balloon.has_signal("pause_requested"):
		_active_dialogue_balloon.connect("pause_requested", Callable(self, "_on_balloon_pause_requested"))
	_set_active_dialogue_input_enabled(_input_context != InputContext.TRANSITION)


func _set_dialogue_speaker(speaker: Node3D) -> void:
	if speaker == null:
		return

	_current_dialogue_speaker = speaker
	_apply_dialogue_animation_roles(speaker)
	player.set_character_visible(speaker == player)
	if is_instance_valid(_dialogue_target_actor) and _dialogue_target_actor.has_method("set_character_visible"):
		var should_show_target_actor := speaker == _dialogue_target_actor
		if (
			not should_show_target_actor
			and _dialogue_target_actor.has_method("contains_dialogue_speaker")
		):
			should_show_target_actor = bool(
				_dialogue_target_actor.call("contains_dialogue_speaker", speaker)
			)
		_dialogue_target_actor.call("set_character_visible", should_show_target_actor)

	var scene_camera := _get_dialogue_scene_camera(speaker)
	if scene_camera != null:
		_set_dialogue_pivots_active(false)
		scene_camera.current = true
		return

	_sync_dialogue_pivots()
	_activate_speaker_camera(speaker)


func _set_dialogue_pivots_active(value: bool) -> void:
	dialogue_pivot_right.visible = value
	dialogue_pivot_left.visible = value
	dialogue_pivot_right.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	dialogue_pivot_left.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED


func _sync_dialogue_pivots() -> void:
	_set_dialogue_pivots_active(true)

	var player_mount: Node3D = player.get_dialogue_camera_mount()
	var target_mount: Node3D
	if is_instance_valid(_dialogue_target_actor) and _dialogue_target_actor.has_method("get_dialogue_camera_mount"):
		target_mount = _dialogue_target_actor.call("get_dialogue_camera_mount") as Node3D

	var npc_uses_right_pivot := _should_actor_use_right_pivot(_dialogue_target_actor)
	var right_mount := target_mount if npc_uses_right_pivot else player_mount
	var left_mount := player_mount if npc_uses_right_pivot else target_mount

	_right_pivot_actor = _dialogue_target_actor if npc_uses_right_pivot else player

	if right_mount != null:
		dialogue_pivot_right.global_transform = _get_dialogue_pivot_transform(right_mount)

	if left_mount != null:
		dialogue_pivot_left.global_transform = _get_dialogue_pivot_transform(left_mount)


func _activate_speaker_camera(speaker: Node3D) -> void:
	if speaker == _right_pivot_actor:
		dialogue_camera_right.current = true
		return

	dialogue_camera_left.current = true


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if not _dialogue_active:
		return

	if _active_dialogue_resource != null and resource != _active_dialogue_resource:
		return

	var finished_dialogue_actor := _dialogue_target_actor
	if is_instance_valid(finished_dialogue_actor) and finished_dialogue_actor.has_method("consume_pending_race_start"):
		if bool(finished_dialogue_actor.call("consume_pending_race_start")):
			_resolve_pending_lap_race_outcome(finished_dialogue_actor)
			await _transition_from_dialogue_to_race(finished_dialogue_actor)
			return

	var should_chain_reward_demonstration := _has_pending_lap_reward_for_actor(finished_dialogue_actor)
	await _exit_dialogue_mode(should_chain_reward_demonstration)

	if is_instance_valid(finished_dialogue_actor) and finished_dialogue_actor.has_method("handle_dialogue_finished"):
		finished_dialogue_actor.call("handle_dialogue_finished", resource)
	if is_instance_valid(finished_dialogue_actor):
		_resolve_pending_lap_race_outcome(finished_dialogue_actor)
	var reward_granted := false
	if is_instance_valid(finished_dialogue_actor):
		reward_granted = _try_grant_pending_lap_reward(finished_dialogue_actor)
	if should_chain_reward_demonstration:
		_try_start_reward_demonstration(true)
		if not _reward_demonstration_start_pending and not _demonstration_active and not _has_queued_reward_demonstration():
			if not reward_granted:
				push_warning("Lap reward flow did not start after dialogue; restoring fade-in.")
			await SceneTransition.fade_in()


func _on_balloon_speaker_changed(character_name: String, _dialogue_line: DialogueLine) -> void:
	var speaker := _resolve_speaker_for_character_name(character_name)
	if speaker != null:
		_set_dialogue_speaker(speaker)


func _on_balloon_response_selection_state_changed(is_active: bool) -> void:
	_dialogue_response_selection_active = is_active
	_sync_input_context()


func _on_balloon_pause_requested() -> void:
	_open_pause_menu()


func _connect_pause_menu_signals(menu: Node) -> void:
	if menu == null:
		return

	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	if menu.has_signal("resume_requested"):
		menu.connect("resume_requested", Callable(self, "_resume_from_pause"))
	if menu.has_signal("main_menu_requested"):
		menu.connect("main_menu_requested", Callable(self, "_return_to_main_menu"))
	if menu.has_signal("quit_requested"):
		menu.connect("quit_requested", Callable(self, "_quit_from_pause"))
	if menu.has_signal("exit_dialogue_requested"):
		menu.connect("exit_dialogue_requested", Callable(self, "_exit_dialogue_from_pause"))
	if menu.has_signal("exit_cutscene_requested"):
		menu.connect("exit_cutscene_requested", Callable(self, "_exit_cutscene_from_pause"))
	if menu.has_signal("exit_labyrinth_requested"):
		menu.connect("exit_labyrinth_requested", Callable(self, "_exit_labyrinth_from_pause"))


func _get_pause_menu_for_current_context() -> Node:
	if _dialogue_active and _dialogue_pause_menu != null:
		return _dialogue_pause_menu
	if _cutscene_active and _cutscene_pause_menu != null:
		return _cutscene_pause_menu
	if _labyrinth_active and _labyrinth_pause_menu != null:
		return _labyrinth_pause_menu

	return pause_menu


func _resolve_speaker_for_character_name(character_name: String) -> Node3D:
	var normalized_name := character_name.strip_edges().to_lower()
	if normalized_name.is_empty():
		return _current_dialogue_speaker

	if _matches_dialogue_speaker_name(player, normalized_name):
		return player

	if (
		is_instance_valid(_dialogue_target_actor)
		and _dialogue_target_actor.has_method("resolve_dialogue_speaker")
	):
		var resolved_speaker := _dialogue_target_actor.call("resolve_dialogue_speaker", character_name) as Node3D
		if resolved_speaker != null:
			return resolved_speaker

	if _matches_dialogue_speaker_name(_dialogue_target_actor, normalized_name):
		return _dialogue_target_actor

	return _current_dialogue_speaker


func _matches_dialogue_speaker_name(actor: Node3D, normalized_name: String) -> bool:
	if actor == null:
		return false

	if actor.has_method("get_dialogue_speaker_name"):
		var actor_name := String(actor.call("get_dialogue_speaker_name")).strip_edges().to_lower()
		if actor_name == normalized_name:
			return true

	return actor.name.strip_edges().to_lower() == normalized_name


func _get_dialogue_scene_camera(actor: Node3D) -> Camera3D:
	if actor == null:
		return null

	if (
		is_instance_valid(_dialogue_target_actor)
		and _dialogue_target_actor.has_method("get_dialogue_scene_camera_for_actor")
	):
		var mapped_camera := _dialogue_target_actor.call("get_dialogue_scene_camera_for_actor", actor) as Camera3D
		if mapped_camera != null:
			return mapped_camera

	if not actor.has_method("get_dialogue_scene_camera"):
		return null

	return actor.call("get_dialogue_scene_camera") as Camera3D


func _get_dialogue_pivot_transform(mount: Node3D) -> Transform3D:
	var pivot_transform := mount.global_transform
	pivot_transform.basis = pivot_transform.basis * Basis.from_euler(Vector3(0.0, DIALOGUE_PIVOT_YAW_OFFSET, 0.0))
	return pivot_transform


func _should_actor_use_right_pivot(actor: Node3D) -> bool:
	if actor == null or actor == player:
		return false

	var actor_forward := _get_planar_forward(actor)
	var camera_right := _get_planar_camera_right()
	if actor_forward.is_zero_approx() or camera_right.is_zero_approx():
		return false

	return actor_forward.dot(camera_right) > 0.0


func _get_planar_forward(actor: Node3D) -> Vector3:
	var forward := -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.000001:
		return Vector3.ZERO

	return forward.normalized()


func _get_planar_camera_right() -> Vector3:
	if game_camera == null:
		return Vector3.ZERO

	var camera_right := game_camera.global_transform.basis.x
	camera_right.y = 0.0
	if camera_right.length_squared() <= 0.000001:
		return Vector3.ZERO

	return camera_right.normalized()


func _refresh_cursor_mode() -> void:
	var desired_mode := CURSOR_MODE_INGAME
	if (
		_input_context == InputContext.PAUSE
		or _input_context == InputContext.DIALOGUE_RESPONSE_SELECTION
		or _input_context == InputContext.INVENTORY
	):
		desired_mode = CURSOR_MODE_UI

	if Input.mouse_mode != desired_mode:
		Input.mouse_mode = desired_mode


func _sync_input_context() -> void:
	if _interaction_locked:
		_set_input_context(InputContext.TRANSITION)
		return

	if _found_item_popup_open:
		_set_input_context(InputContext.INVENTORY)
		return

	if _inventory_open:
		_set_input_context(InputContext.INVENTORY)
		return

	if _pause_active:
		_set_input_context(InputContext.PAUSE)
		return

	if _dialogue_active:
		if _dialogue_response_selection_active:
			_set_input_context(InputContext.DIALOGUE_RESPONSE_SELECTION)
		else:
			_set_input_context(InputContext.DIALOGUE)
		return

	if _demonstration_active:
		_set_input_context(InputContext.DEMONSTRATION)
		return

	if _cutscene_active:
		_set_input_context(InputContext.CUTSCENE)
		return

	if _labyrinth_active:
		_set_input_context(InputContext.LABYRINTH)
		return

	_set_input_context(InputContext.GAMEPLAY)


func _set_input_context(value: int) -> void:
	if _input_context == value:
		return

	_input_context = value
	if _input_context == InputContext.TRANSITION:
		if _pause_active:
			get_tree().paused = false
			_pause_active = false
			if _active_pause_menu != null:
				_active_pause_menu.call("close")
			_active_pause_menu = null
		if player != null:
			player.set_controls_enabled(false)
		if interaction_source != null:
			interaction_source.set_interaction_enabled(false)
	_set_active_dialogue_input_enabled(value != InputContext.TRANSITION)
	_refresh_cursor_mode()
	_refresh_gameplay_world_ui_visibility()
	_sync_follower_gameplay_state()


func _is_scene_transition_active() -> bool:
	return SceneTransition != null and SceneTransition.has_method("is_transitioning") and bool(SceneTransition.call("is_transitioning"))


func _refresh_gameplay_world_ui_visibility() -> void:
	_set_gameplay_world_ui_visible(
		_input_context == InputContext.GAMEPLAY or _input_context == InputContext.LABYRINTH
	)


func _set_gameplay_world_ui_visible(is_visible: bool) -> void:
	if gameplay_ui_layer != null:
		gameplay_ui_layer.set_world_ui_visible(is_visible)


func _set_active_dialogue_input_enabled(enabled: bool) -> void:
	if not is_instance_valid(_active_dialogue_balloon):
		return

	if _active_dialogue_balloon.has_method("set_input_enabled"):
		_active_dialogue_balloon.call("set_input_enabled", enabled)


func _capture_focus_before_pause() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_instance_valid(focus_owner):
		_focus_before_pause = null
		return

	_focus_before_pause = weakref(focus_owner)


func _restore_focus_after_pause() -> void:
	var focus_owner: Control = null
	if _focus_before_pause != null:
		focus_owner = _focus_before_pause.get_ref() as Control

	_focus_before_pause = null
	if focus_owner != null and is_instance_valid(focus_owner) and focus_owner.visible and focus_owner.focus_mode != Control.FOCUS_NONE:
		focus_owner.grab_focus()
		return

	if is_instance_valid(_active_dialogue_balloon) and _active_dialogue_balloon.has_method("restore_interaction_focus"):
		_active_dialogue_balloon.call("restore_interaction_focus")


func _tween_inventory_time_scale(target: float) -> void:
	_kill_inventory_time_scale_tween()
	_inventory_time_scale_tween = create_tween()
	_inventory_time_scale_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_inventory_time_scale_tween.set_ignore_time_scale(true)
	_inventory_time_scale_tween.set_trans(Tween.TRANS_CUBIC)
	_inventory_time_scale_tween.set_ease(Tween.EASE_OUT)
	_inventory_time_scale_tween.tween_method(
		Callable(self, "_set_inventory_time_scale"),
		Engine.time_scale,
		target,
		INVENTORY_TIME_SCALE_DURATION
	)
	_inventory_time_scale_tween.finished.connect(_on_inventory_time_scale_tween_finished)


func _on_inventory_time_scale_tween_finished() -> void:
	_inventory_time_scale_tween = null


func _kill_inventory_time_scale_tween() -> void:
	if _inventory_time_scale_tween != null and _inventory_time_scale_tween.is_valid():
		_inventory_time_scale_tween.kill()
	_inventory_time_scale_tween = null


func _set_inventory_time_scale(value: float) -> void:
	Engine.time_scale = clampf(value, INVENTORY_TIME_SCALE_OPEN, INVENTORY_TIME_SCALE_CLOSED)


func _apply_dialogue_animation_roles(speaker: Node3D) -> void:
	_set_dialogue_animation_mode(player, speaker == player)
	_set_dialogue_animation_mode(_dialogue_target_actor, speaker == _dialogue_target_actor)


func _set_dialogue_animation_mode(actor: Node3D, is_talking: bool) -> void:
	if actor == null or not actor.has_method("enter_dialogue_animation_mode"):
		return

	actor.call("enter_dialogue_animation_mode", is_talking)


func _restore_dialogue_animation_mode(actor: Node3D) -> void:
	if actor == null or not actor.has_method("exit_dialogue_animation_mode"):
		return

	actor.call("exit_dialogue_animation_mode")


func _hide_follower_actors_for_dialogue() -> void:
	_hidden_follower_actors.clear()
	var tree := get_tree()
	if tree == null:
		return

	for actor in tree.get_nodes_in_group(&"friendly_followers"):
		var follower := actor as Node3D
		if follower == null or follower == _dialogue_target_actor:
			continue
		if not follower.has_method("pause_as_follower_during_dialogue"):
			continue

		follower.call("pause_as_follower_during_dialogue")
		_hidden_follower_actors.append(follower)


func _restore_follower_actors_after_dialogue() -> void:
	for actor in _hidden_follower_actors:
		if actor == null:
			continue
		if actor.has_method("resume_as_follower_after_dialogue"):
			actor.call("resume_as_follower_after_dialogue")

	_hidden_follower_actors.clear()


func _on_reward_spawned(_source_id: StringName, marker: RewardMarker, _pickup: PickupItem) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	if marker.get_tree() != get_tree():
		return

	var demonstration_camera := _find_reward_demonstration_camera(marker.marker_id)
	if demonstration_camera == null:
		_resume_pending_lap_race_return_if_ready()
		return

	_queued_reward_demonstration_cameras.append(weakref(demonstration_camera))
	_try_start_reward_demonstration()


func _try_start_reward_demonstration(start_from_faded_state: bool = false) -> void:
	if _reward_demonstration_start_pending or _demonstration_active or _interaction_locked:
		return
	if _dialogue_active or _cutscene_active or _pause_active or _inventory_open or _found_item_popup_open:
		return

	var demonstration_camera := _consume_next_reward_demonstration_camera()
	if demonstration_camera == null:
		_resume_pending_lap_race_return_if_ready()
		return

	_reward_demonstration_start_pending = true
	call_deferred(
		"_start_reward_demonstration",
		demonstration_camera,
		start_from_faded_state or _is_scene_transition_active()
	)


func _consume_next_reward_demonstration_camera() -> RewardDemonstrationCamera:
	while not _queued_reward_demonstration_cameras.is_empty():
		var demonstration_camera := _queued_reward_demonstration_cameras[0].get_ref() as RewardDemonstrationCamera
		_queued_reward_demonstration_cameras.remove_at(0)
		if demonstration_camera != null and is_instance_valid(demonstration_camera):
			return demonstration_camera

	return null


func _start_reward_demonstration(
	demonstration_camera: RewardDemonstrationCamera,
	start_from_faded_state: bool = false
) -> void:
	_reward_demonstration_start_pending = false
	if demonstration_camera == null or not is_instance_valid(demonstration_camera):
		_resume_pending_lap_race_return_if_ready()
		_try_start_reward_demonstration()
		return

	_demonstration_active = true
	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	if not start_from_faded_state:
		await SceneTransition.fade_out()
	_set_dialogue_pivots_active(false)
	if gameplay_ui_layer != null:
		gameplay_ui_layer.set_cinematic_bars_visible(true)
	demonstration_camera.current = true
	await get_tree().process_frame
	_interaction_locked = false
	_set_input_context(InputContext.DEMONSTRATION)
	await SceneTransition.fade_in()

	var duration := demonstration_camera.get_demonstration_duration()
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout

	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	await SceneTransition.fade_out()
	if gameplay_ui_layer != null:
		gameplay_ui_layer.set_cinematic_bars_visible(false)
	camera_rig.activate_game_camera()
	_demonstration_active = false
	player.set_controls_enabled(true)
	interaction_source.set_interaction_enabled(true)
	await get_tree().process_frame
	_interaction_locked = false
	_sync_input_context()
	await SceneTransition.fade_in()
	_resume_pending_lap_race_return_if_ready()
	_try_start_reward_demonstration()


func _sync_follower_gameplay_state() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var follow_enabled := _input_context == InputContext.GAMEPLAY
	for actor in tree.get_nodes_in_group(&"friendly_followers"):
		if actor == null:
			continue

		var friend_follow_state := actor.get_node_or_null(^"FriendFollowState")
		if friend_follow_state != null and friend_follow_state.has_method("set_gameplay_follow_enabled"):
			friend_follow_state.call("set_gameplay_follow_enabled", follow_enabled)


func _try_handle_non_dialogue_interaction(target: InteractionTarget) -> bool:
	if _interaction_locked or _dialogue_active or _cutscene_active or _labyrinth_active or _found_item_popup_open or target == null or not target.is_interaction_available():
		return false

	var interaction_owner := target.get_parent()
	if interaction_owner == null or not interaction_owner.has_method("handle_interaction"):
		return false

	return bool(interaction_owner.call("handle_interaction", player, _inventory_data))


func _connect_labyrinth_area_signals() -> void:
	for area_node in get_tree().get_nodes_in_group(&"labyrinth_areas"):
		var area := area_node as LabyrinthArea
		if area == null:
			continue

		if not area.labyrinth_enter_requested.is_connected(Callable(self, "_on_labyrinth_enter_requested")):
			area.labyrinth_enter_requested.connect(Callable(self, "_on_labyrinth_enter_requested"))
		if not area.labyrinth_exit_requested.is_connected(Callable(self, "_on_labyrinth_exit_requested")):
			area.labyrinth_exit_requested.connect(Callable(self, "_on_labyrinth_exit_requested"))


func _on_labyrinth_enter_requested(area: LabyrinthArea) -> void:
	if _should_ignore_labyrinth_entry(area):
		_ignored_labyrinth_entry_area = null
		return

	if _labyrinth_active:
		_exit_labyrinth_mode()
		return

	_enter_labyrinth_mode(area)


func _on_labyrinth_exit_requested(_area: LabyrinthArea) -> void:
	if _labyrinth_active:
		_exit_labyrinth_mode()
		_grant_labyrinth_exit_reward()
		return

	_enter_labyrinth_mode(_area)


func _enter_labyrinth_mode(area: LabyrinthArea) -> void:
	if _labyrinth_active or _dialogue_active or _cutscene_active or _interaction_locked:
		return

	_labyrinth_active = true
	_active_labyrinth_area = area
	if camera_rig != null and camera_rig.has_method("enter_labyrinth_view"):
		camera_rig.call("enter_labyrinth_view")
	if player != null and player.has_method("enter_labyrinth_state") and camera_rig != null and camera_rig.has_method("get_labyrinth_yaw"):
		player.call("enter_labyrinth_state", float(camera_rig.call("get_labyrinth_yaw")))
	_sync_input_context()


func _exit_labyrinth_mode() -> void:
	if not _labyrinth_active:
		return

	_labyrinth_active = false
	_active_labyrinth_area = null
	if camera_rig != null and camera_rig.has_method("exit_labyrinth_view"):
		camera_rig.call("exit_labyrinth_view")
	if player != null and player.has_method("exit_labyrinth_state"):
		player.call("exit_labyrinth_state")
	_sync_input_context()


func _on_labyrinth_view_yaw_changed(yaw: float) -> void:
	if not _labyrinth_active:
		return
	if player != null and player.has_method("set_labyrinth_view_yaw"):
		player.call("set_labyrinth_view_yaw", yaw)


func _should_ignore_labyrinth_entry(area: LabyrinthArea) -> bool:
	if _ignored_labyrinth_entry_area == null:
		return false

	var ignored_area := _ignored_labyrinth_entry_area.get_ref() as LabyrinthArea
	if ignored_area == null:
		_ignored_labyrinth_entry_area = null
		return false

	return ignored_area == area


func _grant_labyrinth_exit_reward() -> void:
	if RewardService == null:
		return

	RewardService.call(
		"grant_reward",
		LABYRINTH_REWARD_SOURCE_ID,
		LABYRINTH_REWARD_MARKER_ID,
		BRASS_KEY_ITEM,
		1,
		DEFAULT_GAME_SCENE_PATH
	)


func _capture_pending_lap_race_return() -> void:
	if LapRaceFlow == null:
		return

	var current_scene := get_tree().current_scene
	var current_scene_path := String(current_scene.scene_file_path) if current_scene != null else ""
	if not LapRaceFlow.has_pending_return(current_scene_path):
		return

	_pending_lap_return_context = LapRaceFlow.consume_return_context(current_scene_path)


func _resume_pending_lap_race_return_if_ready() -> void:
	if _pending_lap_return_context.is_empty():
		return
	if _demonstration_active or _reward_demonstration_start_pending:
		return
	if _has_queued_reward_demonstration():
		return

	var context := _pending_lap_return_context
	_pending_lap_return_context = {}
	var player_transform: Transform3D = context.get("player_transform", Transform3D.IDENTITY)
	player.global_transform = player_transform
	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)

	var npc_path: NodePath = context.get("npc_path", NodePath())
	var npc := get_node_or_null(npc_path)
	if npc == null or not npc.has_method("prepare_post_race_dialogue"):
		_release_locked_return_transition()
		return

	var result: StringName = context.get("result", &"lose")
	_pending_race_resolution_context = {
		"npc_path": npc_path,
		"result": result,
		"should_grant_reward": false,
	}
	_pending_reward_grant_context = {}
	if npc.has_method("should_grant_reward_for_result") and bool(npc.call("should_grant_reward_for_result", result)):
		_pending_race_resolution_context["should_grant_reward"] = true
		_pending_reward_grant_context = {
			"npc_path": npc_path,
			"target_scene_path": String(context.get("scene_path", DEFAULT_GAME_SCENE_PATH)),
			"reward_source_id": _get_lap_reward_source_id_for_race(StringName(context.get("race_id", &""))),
		}
	var interaction_target := npc.call("prepare_post_race_dialogue", result) as InteractionTarget
	if interaction_target == null:
		_release_locked_return_transition()
		return

	_start_dialogue_with_target_while_faded(interaction_target, true)


func _has_queued_reward_demonstration() -> bool:
	for camera_ref in _queued_reward_demonstration_cameras:
		var demonstration_camera := camera_ref.get_ref() as RewardDemonstrationCamera
		if demonstration_camera != null and is_instance_valid(demonstration_camera):
			return true

	return false


func _find_reward_demonstration_camera(marker_id: StringName) -> RewardDemonstrationCamera:
	if marker_id.is_empty():
		return null

	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene == null:
		return null

	for camera_node in tree.get_nodes_in_group(&"reward_demonstration_cameras"):
		var demonstration_camera := camera_node as RewardDemonstrationCamera
		if demonstration_camera == null or demonstration_camera.get_tree() != tree:
			continue
		if not current_scene.is_ancestor_of(demonstration_camera) and current_scene != demonstration_camera:
			continue
		if demonstration_camera.matches_marker(marker_id):
			return demonstration_camera

	return null


func _start_dialogue_with_target_from_transition(
	target: InteractionTarget,
	ignore_interaction_availability: bool = false
) -> void:
	if _dialogue_active or _cutscene_active or _labyrinth_active or target == null:
		_release_locked_return_transition()
		return
	if not ignore_interaction_availability and not target.is_interaction_available():
		_release_locked_return_transition()
		return

	var dialogue_resource := target.get_dialogue_resource()
	var player_dialogue_anchor: Node3D = target.get_player_dialogue_anchor()
	var restore_player_transform := true
	var preserve_player_height := false
	if target.has_method("should_return_player_to_origin_after_dialogue"):
		restore_player_transform = bool(target.call("should_return_player_to_origin_after_dialogue"))
	if target.has_method("should_preserve_player_height_during_dialogue"):
		preserve_player_height = bool(target.call("should_preserve_player_height_during_dialogue"))

	_saved_player_transform = player.global_transform
	_restore_player_transform_after_sequence = restore_player_transform
	await SceneTransition.fade_out()
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_hide_follower_actors_for_dialogue()
	_move_player_to_anchor(player_dialogue_anchor, preserve_player_height)
	_dialogue_target_actor = target.get_parent() as Node3D
	var player_focus_position := target.global_position
	if _dialogue_target_actor != null and _dialogue_target_actor.has_method("get_dialogue_focus_position"):
		player_focus_position = _dialogue_target_actor.call("get_dialogue_focus_position")
	player.face_towards_position(player_focus_position)
	if _dialogue_target_actor != null and _dialogue_target_actor.has_method("face_towards_position"):
		_dialogue_target_actor.call("face_towards_position", player.global_position)
	_dialogue_target = target
	_dialogue_active = true
	_dialogue_response_selection_active = false
	AudioService.apply_mix_preset(AUDIO_PRESET_DIALOGUE, AUDIO_PRESET_FADE_DURATION)
	_set_dialogue_speaker(_dialogue_target_actor)
	_sync_input_context()
	_start_dialogue_balloon(dialogue_resource, target.get_dialogue_start_title())
	await get_tree().process_frame
	await SceneTransition.fade_in()
	_interaction_locked = false
	_sync_input_context()


func _start_dialogue_with_target_while_faded(
	target: InteractionTarget,
	ignore_interaction_availability: bool = false
) -> void:
	if _dialogue_active or _cutscene_active or _labyrinth_active or target == null:
		_release_locked_return_transition()
		return
	if not ignore_interaction_availability and not target.is_interaction_available():
		_release_locked_return_transition()
		return

	var dialogue_resource := target.get_dialogue_resource()
	var player_dialogue_anchor: Node3D = target.get_player_dialogue_anchor()
	var restore_player_transform := true
	var preserve_player_height := false
	if target.has_method("should_return_player_to_origin_after_dialogue"):
		restore_player_transform = bool(target.call("should_return_player_to_origin_after_dialogue"))
	if target.has_method("should_preserve_player_height_during_dialogue"):
		preserve_player_height = bool(target.call("should_preserve_player_height_during_dialogue"))

	_saved_player_transform = player.global_transform
	_restore_player_transform_after_sequence = restore_player_transform
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_hide_follower_actors_for_dialogue()
	_move_player_to_anchor(player_dialogue_anchor, preserve_player_height)
	_dialogue_target_actor = target.get_parent() as Node3D
	var player_focus_position := target.global_position
	if _dialogue_target_actor != null and _dialogue_target_actor.has_method("get_dialogue_focus_position"):
		player_focus_position = _dialogue_target_actor.call("get_dialogue_focus_position")
	player.face_towards_position(player_focus_position)
	if _dialogue_target_actor != null and _dialogue_target_actor.has_method("face_towards_position"):
		_dialogue_target_actor.call("face_towards_position", player.global_position)
	_dialogue_target = target
	_dialogue_active = true
	_dialogue_response_selection_active = false
	AudioService.apply_mix_preset(AUDIO_PRESET_DIALOGUE, AUDIO_PRESET_FADE_DURATION)
	_set_dialogue_speaker(_dialogue_target_actor)
	_sync_input_context()
	_start_dialogue_balloon(dialogue_resource, target.get_dialogue_start_title())
	_interaction_locked = false
	_sync_input_context()


func _transition_from_dialogue_to_race(actor: Node3D) -> void:
	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	_set_active_dialogue_input_enabled(false)
	await SceneTransition.fade_out()
	if is_instance_valid(_active_dialogue_balloon):
		if _active_dialogue_balloon.has_method("close_balloon"):
			_active_dialogue_balloon.call("close_balloon")
		else:
			_active_dialogue_balloon.queue_free()
	_active_dialogue_balloon = null
	_active_dialogue_resource = null
	_restore_dialogue_animation_mode(player)
	_restore_dialogue_animation_mode(_dialogue_target_actor)
	_restore_follower_actors_after_dialogue()
	player.global_transform = _saved_player_transform
	player.set_character_visible(true)
	if is_instance_valid(_dialogue_target_actor) and _dialogue_target_actor.has_method("set_character_visible"):
		_dialogue_target_actor.call("set_character_visible", true)
	_set_dialogue_pivots_active(false)
	camera_rig.activate_game_camera()
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_dialogue_active = false
	_dialogue_response_selection_active = false
	_dialogue_target = null
	_dialogue_target_actor = null
	_current_dialogue_speaker = null
	_right_pivot_actor = null
	_restore_player_transform_after_sequence = true
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	await get_tree().process_frame
	if is_instance_valid(actor) and actor.has_method("start_race_transition"):
		await actor.call("start_race_transition")


func _release_locked_return_transition() -> void:
	_pending_race_resolution_context = {}
	_pending_reward_grant_context = {}
	_interaction_locked = false
	player.set_controls_enabled(true)
	interaction_source.set_interaction_enabled(true)
	_sync_input_context()


func _resolve_pending_lap_race_outcome(actor: Node3D) -> void:
	if actor == null or _pending_race_resolution_context.is_empty():
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if String(current_scene.get_path_to(actor)) != String(_pending_race_resolution_context.get("npc_path", NodePath())):
		return

	var result: StringName = _pending_race_resolution_context.get("result", &"lose")
	var should_grant_reward := bool(_pending_race_resolution_context.get("should_grant_reward", false))
	_pending_race_resolution_context = {}
	if result == &"win" and not should_grant_reward and actor.has_method("mark_current_race_completed"):
		actor.call("mark_current_race_completed")


func _has_pending_lap_reward_for_actor(actor: Node3D) -> bool:
	if actor == null or _pending_reward_grant_context.is_empty():
		return false

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false

	return String(current_scene.get_path_to(actor)) == String(_pending_reward_grant_context.get("npc_path", NodePath()))


func _try_grant_pending_lap_reward(actor: Node3D) -> bool:
	if _pending_reward_grant_context.is_empty():
		return false

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	if String(current_scene.get_path_to(actor)) != String(_pending_reward_grant_context.get("npc_path", NodePath())):
		return false

	var reward_context := _pending_reward_grant_context
	_pending_reward_grant_context = {}
	if RewardService == null:
		return false

	var granted := bool(RewardService.call(
		"grant_reward",
		reward_context.get("reward_source_id", LAP_REWARD_SOURCE_ID),
		LAP_REWARD_MARKER_ID,
		BRASS_KEY_ITEM,
		1,
		String(reward_context.get("target_scene_path", DEFAULT_GAME_SCENE_PATH))
	))
	if granted and actor.has_method("mark_current_race_reward_completed"):
		actor.call("mark_current_race_reward_completed")
	return granted


func _get_lap_reward_source_id_for_race(race_id: StringName) -> StringName:
	if race_id.is_empty():
		return LAP_REWARD_SOURCE_ID

	return StringName("%s_%s" % [String(LAP_REWARD_SOURCE_ID), String(race_id)])


func _restore_inventory_from_session_state() -> void:
	if GameSessionState == null:
		return

	var inventory_state := GameSessionState.get_inventory_state()
	if inventory_state.is_empty():
		return

	_inventory_data.restore_state(inventory_state)


func _save_inventory_to_session_state() -> void:
	if GameSessionState == null:
		return

	GameSessionState.save_inventory_state(_inventory_data.serialize_state())


func _on_inventory_item_added(item: InventoryItemData, quantity: int) -> void:
	if item == null or _found_item_popup == null:
		return
	if _pause_active or _dialogue_active or _cutscene_active:
		return

	_found_item_popup_open = true
	_tween_inventory_time_scale(INVENTORY_TIME_SCALE_OPEN)
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_sync_input_context()
	_found_item_popup.open_for_item(item, quantity)


func _close_found_item_popup() -> void:
	if not _found_item_popup_open:
		return

	_found_item_popup_open = false
	if _found_item_popup != null:
		_found_item_popup.close()
	_tween_inventory_time_scale(INVENTORY_TIME_SCALE_CLOSED)
	player.set_controls_enabled(true)
	interaction_source.set_interaction_enabled(true)
	_sync_input_context()
