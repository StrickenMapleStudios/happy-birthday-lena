extends Node3D

const MAIN_MENU_SCENE_PATH := "res://assets/scenes/menu/menu_main.tscn"
const DIALOGUE_PAUSE_MENU_SCENE := preload("res://assets/scenes/ui/dialogue_pause_menu.tscn")

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

const CURSOR_MODE_INGAME := Input.MOUSE_MODE_CAPTURED
const CURSOR_MODE_UI := Input.MOUSE_MODE_VISIBLE

enum InputContext {
	GAMEPLAY,
	DIALOGUE,
	DIALOGUE_RESPONSE_SELECTION,
	INVENTORY,
	PAUSE,
	TRANSITION,
}

var _interaction_locked := false
var _dialogue_active := false
var _dialogue_response_selection_active := false
var _dialogue_target: InteractionTarget
var _dialogue_target_actor: Node3D
var _current_dialogue_speaker: Node3D
var _right_pivot_actor: Node3D
var _active_dialogue_balloon: Node
var _active_dialogue_resource: DialogueResource
var _saved_player_transform := Transform3D.IDENTITY
var _pause_active := false
var _pause_transition_locked := false
var _dialogue_pause_menu: Node
var _active_pause_menu: Node
var _inventory_open := false
var _input_context := InputContext.GAMEPLAY
var _focus_before_pause: WeakRef
var _inventory_data: InventoryData = InventoryData.new()
var _hidden_follower_actors: Array[Node3D] = []
var _inventory_time_scale_tween: Tween


func _ready() -> void:
	_set_inventory_time_scale(INVENTORY_TIME_SCALE_CLOSED)
	_set_dialogue_pivots_active(false)
	_refresh_gameplay_world_ui_visibility()
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY)
	add_child(_inventory_data)
	if interaction_source != null:
		interaction_source.interaction_requested.connect(_on_interaction_requested)
		interaction_source.interaction_target_changed.connect(_on_interaction_target_changed)
	if dialogue_manager != null and not dialogue_manager.is_connected("dialogue_ended", Callable(self, "_on_dialogue_ended")):
		dialogue_manager.connect("dialogue_ended", Callable(self, "_on_dialogue_ended"))
	if pause_menu != null:
		_connect_pause_menu_signals(pause_menu)
	_dialogue_pause_menu = DIALOGUE_PAUSE_MENU_SCENE.instantiate()
	add_child(_dialogue_pause_menu)
	_connect_pause_menu_signals(_dialogue_pause_menu)
	if inventory_ui != null:
		inventory_ui.set_inventory(_inventory_data)
		inventory_ui.close_requested.connect(_close_inventory)
	_refresh_cursor_mode()


func _exit_tree() -> void:
	_kill_inventory_time_scale_tween()
	_set_inventory_time_scale(INVENTORY_TIME_SCALE_CLOSED)


func _unhandled_input(event: InputEvent) -> void:
	if _inventory_open:
		return

	if _pause_active or _pause_transition_locked:
		return

	if not _dialogue_active:
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
	if _interaction_locked or _dialogue_active or target == null or not target.is_interaction_available():
		return

	var interaction_owner := target.get_parent()
	if interaction_owner != null and interaction_owner.has_method("handle_interaction"):
		var was_handled := bool(interaction_owner.call("handle_interaction", player, _inventory_data))
		if was_handled:
			return

	if dialogue_manager == null:
		push_warning("DialogueManager singleton is not available.")
		return

	var dialogue_resource := target.get_dialogue_resource()
	if dialogue_resource == null:
		push_warning("Interaction target '%s' is missing a dialogue resource." % target.name)
		return

	var dialogue_camera_mount: Node3D = target.get_dialogue_camera_mount()
	if dialogue_camera_mount == null:
		push_warning("Interaction target '%s' is missing a dialogue camera mount." % target.name)
		return

	var player_dialogue_anchor: Node3D = target.get_player_dialogue_anchor()
	if player_dialogue_anchor == null:
		push_warning("Interaction target '%s' is missing a player dialogue anchor." % target.name)
		return

	_interaction_locked = true
	_set_input_context(InputContext.TRANSITION)
	_saved_player_transform = player.global_transform
	await SceneTransition.fade_out()
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	_hide_follower_actors_for_dialogue()
	player.global_transform = player_dialogue_anchor.global_transform
	player.face_towards_position(target.global_position)
	_dialogue_target_actor = target.get_parent() as Node3D
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


func _on_interaction_target_changed(target: InteractionTarget) -> void:
	if interaction_prompt_controller != null:
		interaction_prompt_controller.set_target(target)


func _exit_dialogue_mode() -> void:
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
	AudioService.apply_mix_preset(AUDIO_PRESET_GAMEPLAY, AUDIO_PRESET_FADE_DURATION)
	_sync_input_context()
	await get_tree().process_frame
	await SceneTransition.fade_in()
	_interaction_locked = false
	_sync_input_context()


func _cancel_active_dialogue() -> void:
	if _interaction_locked or not _dialogue_active:
		return

	await _exit_dialogue_mode()


func _open_pause_menu() -> void:
	if _pause_active or _interaction_locked or _inventory_open or pause_menu == null:
		return

	_pause_active = true
	_capture_focus_before_pause()
	_active_pause_menu = _get_pause_menu_for_current_context()
	if not _dialogue_active and camera_rig != null and camera_rig.has_method("begin_pause_focus"):
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
	if not _dialogue_active and camera_rig != null and camera_rig.has_method("end_pause_focus"):
		camera_rig.call("end_pause_focus")
	AudioService.apply_mix_preset(
		AUDIO_PRESET_DIALOGUE if _dialogue_active else AUDIO_PRESET_GAMEPLAY,
		AUDIO_PRESET_FADE_DURATION
	)
	_sync_input_context()
	call_deferred("_restore_focus_after_pause")


func _open_inventory() -> void:
	if _inventory_open or _interaction_locked or _pause_active or _dialogue_active or inventory_ui == null:
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
		_dialogue_target_actor.call("set_character_visible", speaker == _dialogue_target_actor)

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

	await _exit_dialogue_mode()


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


func _get_pause_menu_for_current_context() -> Node:
	if _dialogue_active and _dialogue_pause_menu != null:
		return _dialogue_pause_menu

	return pause_menu


func _resolve_speaker_for_character_name(character_name: String) -> Node3D:
	var normalized_name := character_name.strip_edges().to_lower()
	if normalized_name.is_empty():
		return _current_dialogue_speaker

	if _matches_dialogue_speaker_name(player, normalized_name):
		return player

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

	_set_input_context(InputContext.GAMEPLAY)


func _set_input_context(value: int) -> void:
	if _input_context == value:
		return

	_input_context = value
	_set_active_dialogue_input_enabled(value != InputContext.TRANSITION)
	_refresh_cursor_mode()
	_refresh_gameplay_world_ui_visibility()


func _refresh_gameplay_world_ui_visibility() -> void:
	_set_gameplay_world_ui_visible(_input_context == InputContext.GAMEPLAY)


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
