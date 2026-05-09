extends Area3D

class_name InteractionSource

signal interaction_requested(target: InteractionTarget)
signal interaction_target_changed(target: InteractionTarget)

const ACTION_INTERACT := "interact"

@export_range(-1.0, 1.0, 0.01) var facing_dot_threshold := 0.55

var _current_target: InteractionTarget
var _targets_in_range: Array[InteractionTarget] = []
var _interaction_enabled := true


func _ready() -> void:
	_ensure_input_map()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	if not _interaction_enabled:
		return

	if _targets_in_range.is_empty():
		if _current_target != null:
			_current_target = null
			interaction_target_changed.emit(null)
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


func _on_area_entered(area: Area3D) -> void:
	var target := area as InteractionTarget
	if target == null:
		return

	if _targets_in_range.has(target):
		return

	_targets_in_range.append(target)
	_refresh_current_target()


func _on_area_exited(area: Area3D) -> void:
	var target := area as InteractionTarget
	if target == null:
		return

	_targets_in_range.erase(target)
	_refresh_current_target()


func _refresh_current_target() -> void:
	var valid_targets: Array[InteractionTarget] = []
	for target in _targets_in_range:
		if not is_instance_valid(target):
			continue
		if not target.is_interaction_available():
			continue
		if not _is_target_in_front(target):
			continue
		valid_targets.append(target)

	_targets_in_range = _targets_in_range.filter(func(target: InteractionTarget): return is_instance_valid(target))

	var next_target: InteractionTarget
	var best_distance_squared := INF
	for target in valid_targets:
		var distance_squared := global_position.distance_squared_to(target.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			next_target = target

	if _current_target == next_target:
		return

	_current_target = next_target
	interaction_target_changed.emit(_current_target)


func _is_target_in_front(target: InteractionTarget) -> bool:
	if target == null:
		return false

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.is_zero_approx():
		return true

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.is_zero_approx():
		return true

	var alignment := forward.dot(to_target.normalized())
	return alignment >= facing_dot_threshold


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	if value:
		_refresh_current_target()
		return

	_current_target = null
	interaction_target_changed.emit(null)


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
