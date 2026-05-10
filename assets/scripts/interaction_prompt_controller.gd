extends Node3D

class_name InteractionPromptController

const PROMPT_SCENE := preload("res://assets/scenes/common/interaction_prompt_3d.tscn")

@export var gameplay_ui_layer_path: NodePath = ^"../GameplayUI"
@export_range(0.1, 10.0, 0.1) var near_distance := 3.0
@export_range(0.1, 50.0, 0.1) var far_distance := 14.0
@export_range(0.1, 4.0, 0.01) var max_prompt_scale := 1.0
@export_range(0.1, 4.0, 0.01) var min_prompt_scale := 0.65

var _current_target: InteractionTarget
var _prompt: InteractionPrompt3D
var _gameplay_ui_layer: GameplayUiLayer


func _ready() -> void:
	_gameplay_ui_layer = get_node_or_null(gameplay_ui_layer_path) as GameplayUiLayer
	_prompt = PROMPT_SCENE.instantiate() as InteractionPrompt3D
	if _gameplay_ui_layer != null:
		_gameplay_ui_layer.add_world_ui(_prompt)
	else:
		add_child(_prompt)
	_prompt.hide_prompt()


func _process(_delta: float) -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		if _prompt != null:
			_prompt.hide_prompt()
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_prompt.hide_prompt()
		return

	var anchor := _current_target.get_interaction_prompt_anchor()
	if anchor == null:
		anchor = _current_target

	var anchor_position := anchor.global_position
	if camera.is_position_behind(anchor_position):
		_prompt.hide_prompt()
		return

	_prompt.set_visual_scale(_get_prompt_scale(camera.global_position.distance_to(anchor_position)))
	_prompt.set_screen_position(camera.unproject_position(anchor_position))
	_prompt.show_prompt()


func set_target(target: InteractionTarget) -> void:
	_current_target = target
	if _prompt == null:
		return

	if _current_target == null or not is_instance_valid(_current_target):
		_prompt.hide_prompt()
		return

	_prompt.key_text = _current_target.get_interaction_key_text()
	var anchor := _current_target.get_interaction_prompt_anchor()
	if anchor == null:
		anchor = _current_target
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(anchor.global_position):
		_prompt.hide_prompt()
		return
	_prompt.set_visual_scale(_get_prompt_scale(camera.global_position.distance_to(anchor.global_position)))
	_prompt.set_screen_position(camera.unproject_position(anchor.global_position))
	_prompt.show_prompt()


func _get_prompt_scale(distance_to_camera: float) -> float:
	if far_distance <= near_distance:
		return max_prompt_scale

	var weight := clampf(inverse_lerp(near_distance, far_distance, distance_to_camera), 0.0, 1.0)
	return lerpf(max_prompt_scale, min_prompt_scale, weight)
