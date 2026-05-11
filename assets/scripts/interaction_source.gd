extends Node3D

class_name InteractionSource

signal interaction_requested(target: InteractionTarget)
signal interaction_target_changed(target: InteractionTarget)

const ACTION_INTERACT := "interact"

@export_flags_3d_physics var interaction_collision_mask: int = 4
@export_range(0.1, 50.0, 0.1) var max_interaction_distance := 5.5
@export_range(0.1, 500.0, 0.1) var ray_length := 100.0
@export_range(-1.0, 1.0, 0.01) var facing_dot_threshold := 0.4

var _current_target: InteractionTarget
var _interaction_enabled := true


func _ready() -> void:
	_ensure_input_map()


func _physics_process(_delta: float) -> void:
	if not _interaction_enabled:
		if _current_target != null:
			_set_current_target(null)
		return

	_refresh_current_target()


func _input(event: InputEvent) -> void:
	if not _interaction_enabled:
		return

	if not event.is_action_pressed(ACTION_INTERACT):
		return

	if _current_target == null or not is_instance_valid(_current_target):
		return

	interaction_requested.emit(_current_target)
	get_viewport().set_input_as_handled()


func _refresh_current_target() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_set_current_target(null)
		return
	_set_current_target(_find_best_target(camera))


func _extract_interaction_target(collider: Variant) -> InteractionTarget:
	var node := collider as Node
	while node != null:
		var target := node as InteractionTarget
		if target != null:
			return target
		node = node.get_parent()

	return null


func _find_best_target(camera: Camera3D) -> InteractionTarget:
	var candidates := get_tree().get_nodes_in_group(&"interaction_targets")
	if candidates.is_empty():
		return null

	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var best_target: InteractionTarget
	var best_score := INF

	for candidate_variant in candidates:
		var target := candidate_variant as InteractionTarget
		if not _is_target_valid(target):
			continue

		var prompt_position := target.get_interaction_prompt_position()
		if camera.is_position_behind(prompt_position):
			continue

		var screen_position := camera.unproject_position(prompt_position)
		var screen_distance := screen_position.distance_to(viewport_center)
		var world_distance := global_position.distance_to(target.global_position)
		var score := screen_distance + (world_distance * 20.0)
		if score >= best_score:
			continue

		best_score = score
		best_target = target

	return best_target


func _is_target_valid(target: InteractionTarget) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.is_interaction_available():
		return false

	if global_position.distance_to(target.global_position) > max_interaction_distance:
		return false

	return _is_target_in_front(target)


func _is_target_in_front(target: InteractionTarget) -> bool:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.is_zero_approx():
		return true

	var forward := global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.is_zero_approx():
		return true

	return forward.dot(to_target.normalized()) >= facing_dot_threshold


func _set_current_target(target: InteractionTarget) -> void:
	if _current_target == target:
		return

	_current_target = target
	interaction_target_changed.emit(_current_target)


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	if value:
		_refresh_current_target()
		return

	_set_current_target(null)


func _ensure_input_map() -> void:
	if not InputMap.has_action(ACTION_INTERACT):
		InputMap.add_action(ACTION_INTERACT)

	if not InputMap.action_get_events(ACTION_INTERACT).is_empty():
		return

	_add_key_event(KEY_E)
	_add_key_event(KEY_ENTER)
	_add_joypad_button_event(JOY_BUTTON_A)


func _add_key_event(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(ACTION_INTERACT, event)


func _add_joypad_button_event(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(ACTION_INTERACT, event)
