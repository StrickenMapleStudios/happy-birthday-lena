extends Node3D

@onready var camera_rig := $CameraRig
@onready var dialogue_pivot_right := $DialoguePivotRight
@onready var dialogue_pivot_left := $DialoguePivotLeft
@onready var dialogue_camera_right: Camera3D = $DialoguePivotRight/DialogueCameraRight
@onready var dialogue_camera_left: Camera3D = $DialoguePivotLeft/DialogueCameraLeft
@onready var player := $character
@onready var npc := $npc
@onready var interaction_source: InteractionSource = $character/InteractionSource

const ACTION_DIALOGUE_SWITCH_SPEAKER := "dialogue_switch_speaker"
const DIALOGUE_PIVOT_YAW_OFFSET := PI

var _interaction_locked := false
var _dialogue_active := false
var _dialogue_target: InteractionTarget
var _dialogue_target_actor: Node3D
var _current_dialogue_speaker: Node3D
var _saved_player_transform := Transform3D.IDENTITY


func _ready() -> void:
	_ensure_input_map()
	_set_dialogue_pivots_active(false)
	if interaction_source != null:
		interaction_source.interaction_requested.connect(_on_interaction_requested)


func _unhandled_input(event: InputEvent) -> void:
	if not _dialogue_active:
		return

	if event.is_action_pressed(ACTION_DIALOGUE_SWITCH_SPEAKER):
		get_viewport().set_input_as_handled()
		_switch_dialogue_speaker()
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	get_viewport().set_input_as_handled()
	await _exit_dialogue_mode()


func _on_interaction_requested(target: InteractionTarget) -> void:
	if _interaction_locked or _dialogue_active or target == null or not target.is_interaction_available():
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
	_saved_player_transform = player.global_transform
	await SceneTransition.fade_out()
	player.set_controls_enabled(false)
	interaction_source.set_interaction_enabled(false)
	player.global_transform = player_dialogue_anchor.global_transform
	player.face_towards_position(target.global_position)
	_dialogue_target_actor = target.get_parent() as Node3D
	if _dialogue_target_actor != null and _dialogue_target_actor.has_method("face_towards_position"):
		_dialogue_target_actor.call("face_towards_position", player.global_position)
	_dialogue_target = target
	_dialogue_active = true
	_set_dialogue_speaker(_dialogue_target_actor)
	await get_tree().process_frame
	await SceneTransition.fade_in()
	_interaction_locked = false


func _exit_dialogue_mode() -> void:
	if _interaction_locked or not _dialogue_active:
		return

	_interaction_locked = true
	await SceneTransition.fade_out()
	player.global_transform = _saved_player_transform
	player.set_character_visible(true)
	if is_instance_valid(npc):
		npc.set_character_visible(true)
	_set_dialogue_pivots_active(false)
	camera_rig.activate_game_camera()
	player.set_controls_enabled(true)
	interaction_source.set_interaction_enabled(true)
	_dialogue_active = false
	_dialogue_target = null
	_dialogue_target_actor = null
	_current_dialogue_speaker = null
	await get_tree().process_frame
	await SceneTransition.fade_in()
	_interaction_locked = false


func _switch_dialogue_speaker() -> void:
	if not _dialogue_active or _dialogue_target_actor == null:
		return

	var next_speaker: Node3D = player
	if _current_dialogue_speaker == player:
		next_speaker = _dialogue_target_actor

	_set_dialogue_speaker(next_speaker)


func _set_dialogue_speaker(speaker: Node3D) -> void:
	if speaker == null:
		return

	_current_dialogue_speaker = speaker
	player.set_character_visible(speaker == player)
	if is_instance_valid(_dialogue_target_actor) and _dialogue_target_actor.has_method("set_character_visible"):
		_dialogue_target_actor.call("set_character_visible", speaker == _dialogue_target_actor)

	_sync_dialogue_pivots()
	_activate_speaker_camera(speaker)


func _ensure_input_map() -> void:
	if not InputMap.has_action(ACTION_DIALOGUE_SWITCH_SPEAKER):
		InputMap.add_action(ACTION_DIALOGUE_SWITCH_SPEAKER)

	if not InputMap.action_get_events(ACTION_DIALOGUE_SWITCH_SPEAKER).is_empty():
		return

	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	InputMap.action_add_event(ACTION_DIALOGUE_SWITCH_SPEAKER, event)


func _set_dialogue_pivots_active(value: bool) -> void:
	dialogue_pivot_right.visible = value
	dialogue_pivot_left.visible = value
	dialogue_pivot_right.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	dialogue_pivot_left.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED


func _sync_dialogue_pivots() -> void:
	_set_dialogue_pivots_active(true)

	var player_mount: Node3D = player.get_dialogue_camera_mount()
	if player_mount != null:
		dialogue_pivot_right.global_transform = _get_dialogue_pivot_transform(player_mount)

	if is_instance_valid(_dialogue_target_actor) and _dialogue_target_actor.has_method("get_dialogue_camera_mount"):
		var target_mount: Node3D = _dialogue_target_actor.call("get_dialogue_camera_mount") as Node3D
		if target_mount != null:
			dialogue_pivot_left.global_transform = _get_dialogue_pivot_transform(target_mount)


func _activate_speaker_camera(speaker: Node3D) -> void:
	if speaker == player:
		dialogue_camera_right.current = true
		return

	dialogue_camera_left.current = true


func _get_dialogue_pivot_transform(mount: Node3D) -> Transform3D:
	var pivot_transform := mount.global_transform
	pivot_transform.basis = pivot_transform.basis * Basis.from_euler(Vector3(0.0, DIALOGUE_PIVOT_YAW_OFFSET, 0.0))
	return pivot_transform
