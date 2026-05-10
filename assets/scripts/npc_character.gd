extends Node3D

const ANIMATION_IDLE := "Idle"
const CHARACTER_IDENTITY_PATH := ^"CharacterIdentity"

@export var visual_root_path: NodePath = ^"Rig"
@export var player_dialogue_anchor_path: NodePath = ^"PlayerDialogueAnchor"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dialogue_animation_tree: AnimationTree = $AnimationPlayer/DialogueAnimationTree

var _dialogue_animation_mode_active := false
var _saved_animation_tree: AnimationTree


func _ready() -> void:
	if dialogue_animation_tree != null:
		dialogue_animation_tree.active = false


func set_character_visible(value: bool) -> void:
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if visual_root != null:
		visual_root.visible = value


func enter_dialogue_animation_mode(_is_talking: bool) -> void:
	if dialogue_animation_tree == null:
		return

	if not _dialogue_animation_mode_active:
		_saved_animation_tree = _get_active_animation_tree(dialogue_animation_tree)
		if _saved_animation_tree != null:
			_saved_animation_tree.active = false
		_dialogue_animation_mode_active = true

	dialogue_animation_tree.active = true


func exit_dialogue_animation_mode() -> void:
	if dialogue_animation_tree == null or not _dialogue_animation_mode_active:
		return

	dialogue_animation_tree.active = false

	if _saved_animation_tree != null:
		_saved_animation_tree.active = true
	elif animation_player != null and animation_player.has_animation(ANIMATION_IDLE):
		animation_player.play(ANIMATION_IDLE)

	_saved_animation_tree = null
	_dialogue_animation_mode_active = false


func face_towards_position(target_position: Vector3) -> void:
	var offset := target_position - global_position
	offset.y = 0.0
	if offset.is_zero_approx():
		return

	var target_rotation := atan2(offset.x, offset.z)
	var current_transform := global_transform
	current_transform.basis = Basis.from_euler(Vector3(0.0, target_rotation, 0.0))
	global_transform = current_transform


func get_player_dialogue_anchor() -> Node3D:
	return get_node_or_null(player_dialogue_anchor_path) as Node3D


func get_dialogue_camera_mount() -> Node3D:
	return $DialogueSpeakerPivot


func get_dialogue_speaker_name() -> String:
	var character_identity := get_node_or_null(CHARACTER_IDENTITY_PATH)
	if character_identity != null and character_identity.has_method("get_dialogue_speaker_name"):
		var dialogue_name := String(character_identity.call("get_dialogue_speaker_name")).strip_edges()
		if not dialogue_name.is_empty():
			return dialogue_name

	return name


func _get_active_animation_tree(excluded_tree: AnimationTree) -> AnimationTree:
	for child in animation_player.get_children():
		var tree := child as AnimationTree
		if tree == null or tree == excluded_tree:
			continue
		if tree.active:
			return tree

	return null
