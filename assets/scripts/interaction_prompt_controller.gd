extends Node3D

class_name InteractionPromptController

const PROMPT_SCENE := preload("res://assets/scenes/common/interaction_prompt_3d.tscn")

@export var gameplay_ui_layer_path: NodePath = ^"../GameplayUI"
@export_range(0.1, 10.0, 0.1) var near_distance := 3.0
@export_range(0.1, 50.0, 0.1) var far_distance := 14.0
@export_range(0.1, 4.0, 0.01) var max_prompt_scale := 1.0
@export_range(0.1, 4.0, 0.01) var min_prompt_scale := 0.65
@export_range(0.0, 200.0, 1.0) var screen_side_offset := 52.0
@export_range(-200.0, 200.0, 1.0) var screen_vertical_offset := -8.0

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

	var prompt_position := _get_prompt_world_position()
	if camera.is_position_behind(prompt_position):
		_prompt.hide_prompt()
		return

	_prompt.set_visual_scale(_get_prompt_scale(camera.global_position.distance_to(prompt_position)))
	_prompt.set_screen_position(_get_prompt_screen_position(camera, prompt_position))
	_prompt.show_prompt()


func set_target(target: InteractionTarget) -> void:
	_current_target = target
	if _prompt == null:
		return

	if _current_target == null or not is_instance_valid(_current_target):
		_prompt.hide_prompt()
		return

	_prompt.key_text = _current_target.get_interaction_key_text()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_prompt.hide_prompt()
		return
	var prompt_position := _get_prompt_world_position()
	if camera.is_position_behind(prompt_position):
		_prompt.hide_prompt()
		return
	_prompt.set_visual_scale(_get_prompt_scale(camera.global_position.distance_to(prompt_position)))
	_prompt.set_screen_position(_get_prompt_screen_position(camera, prompt_position))
	_prompt.show_prompt()


func _get_prompt_scale(distance_to_camera: float) -> float:
	if far_distance <= near_distance:
		return max_prompt_scale

	var weight := clampf(inverse_lerp(near_distance, far_distance, distance_to_camera), 0.0, 1.0)
	return lerpf(max_prompt_scale, min_prompt_scale, weight)


func _get_prompt_world_position() -> Vector3:
	if _current_target == null:
		return Vector3.ZERO

	return _current_target.get_interaction_prompt_position()


func _get_prompt_screen_position(camera: Camera3D, prompt_position: Vector3) -> Vector2:
	var world_screen_position := camera.unproject_position(prompt_position)
	if _current_target == null:
		return world_screen_position

	var target_origin := _current_target.global_position
	var to_camera := camera.global_position - target_origin
	to_camera.y = 0.0

	var camera_right := camera.global_transform.basis.x
	camera_right.y = 0.0
	if camera_right.is_zero_approx():
		camera_right = Vector3.RIGHT
	else:
		camera_right = camera_right.normalized()

	var side_amount := 0.0
	if not to_camera.is_zero_approx():
		side_amount = to_camera.normalized().dot(camera_right)

	return world_screen_position + Vector2(side_amount * screen_side_offset, screen_vertical_offset)
