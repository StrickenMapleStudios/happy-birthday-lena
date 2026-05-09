extends Node3D

@onready var camera_rig := $CameraRig
@onready var dialogue_pivot_right := $DialoguePivotRight
@onready var dialogue_pivot_left := $DialoguePivotLeft
@onready var dialogue_camera_right: Camera3D = $DialoguePivotRight/DialogueCameraRight
@onready var dialogue_camera_left: Camera3D = $DialoguePivotLeft/DialogueCameraLeft
@onready var player := $character
@onready var npc := $npc
@onready var interaction_source: InteractionSource = $character/InteractionSource
@onready var dialogue_manager: Node = Engine.get_singleton("DialogueManager")

const DIALOGUE_BALLOON_SCENE := preload("res://assets/scenes/ui/dialogue_balloon.tscn")
const DIALOGUE_PIVOT_YAW_OFFSET := PI

var _interaction_locked := false
var _dialogue_active := false
var _dialogue_target: InteractionTarget
var _dialogue_target_actor: Node3D
var _current_dialogue_speaker: Node3D
var _active_dialogue_balloon: Node
var _active_dialogue_resource: DialogueResource
var _saved_player_transform := Transform3D.IDENTITY


func _ready() -> void:
	_set_dialogue_pivots_active(false)
	if interaction_source != null:
		interaction_source.interaction_requested.connect(_on_interaction_requested)
	if dialogue_manager != null and not dialogue_manager.is_connected("dialogue_ended", Callable(self, "_on_dialogue_ended")):
		dialogue_manager.connect("dialogue_ended", Callable(self, "_on_dialogue_ended"))


func _unhandled_input(event: InputEvent) -> void:
	if not _dialogue_active:
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	get_viewport().set_input_as_handled()
	await _cancel_active_dialogue()


func _on_interaction_requested(target: InteractionTarget) -> void:
	if _interaction_locked or _dialogue_active or target == null or not target.is_interaction_available():
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
	_start_dialogue_balloon(dialogue_resource, target.get_dialogue_start_title())
	await get_tree().process_frame
	await SceneTransition.fade_in()
	_interaction_locked = false


func _exit_dialogue_mode() -> void:
	if _interaction_locked or not _dialogue_active:
		return

	_interaction_locked = true
	await SceneTransition.fade_out()
	if is_instance_valid(_active_dialogue_balloon):
		_active_dialogue_balloon.queue_free()
	_active_dialogue_balloon = null
	_active_dialogue_resource = null
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


func _cancel_active_dialogue() -> void:
	if _interaction_locked or not _dialogue_active:
		return

	if is_instance_valid(_active_dialogue_balloon):
		_active_dialogue_balloon.queue_free()
	_active_dialogue_balloon = null
	_active_dialogue_resource = null
	await _exit_dialogue_mode()


func _start_dialogue_balloon(dialogue_resource: DialogueResource, start_title: String) -> void:
	if dialogue_manager == null:
		push_warning("DialogueManager singleton is not available.")
		return

	_active_dialogue_resource = dialogue_resource
	_active_dialogue_balloon = dialogue_manager.show_dialogue_balloon_scene(
		DIALOGUE_BALLOON_SCENE,
		dialogue_resource,
		start_title,
		[player, _dialogue_target_actor, self]
	)

	if _active_dialogue_balloon != null and _active_dialogue_balloon.has_signal("speaker_changed"):
		_active_dialogue_balloon.connect("speaker_changed", Callable(self, "_on_balloon_speaker_changed"))


func _set_dialogue_speaker(speaker: Node3D) -> void:
	if speaker == null:
		return

	_current_dialogue_speaker = speaker
	player.set_character_visible(true)
	if is_instance_valid(_dialogue_target_actor) and _dialogue_target_actor.has_method("set_character_visible"):
		_dialogue_target_actor.call("set_character_visible", true)

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


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if not _dialogue_active:
		return

	if _active_dialogue_resource != null and resource != _active_dialogue_resource:
		return

	_active_dialogue_balloon = null
	_active_dialogue_resource = null
	await _exit_dialogue_mode()


func _on_balloon_speaker_changed(character_name: String, _dialogue_line: DialogueLine) -> void:
	var speaker := _resolve_speaker_for_character_name(character_name)
	if speaker != null:
		_set_dialogue_speaker(speaker)


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
