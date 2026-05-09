extends Area3D

class_name InteractionSource

signal interaction_requested(target: InteractionTarget)
signal interaction_target_changed(target: InteractionTarget)

const ACTION_INTERACT := "interact"

var _current_target: InteractionTarget
var _targets: Array[InteractionTarget] = []
var _interaction_enabled := true


func _ready() -> void:
	_ensure_input_map()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


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

	if _targets.has(target):
		return

	_targets.append(target)
	_refresh_current_target()


func _on_area_exited(area: Area3D) -> void:
	var target := area as InteractionTarget
	if target == null:
		return

	_targets.erase(target)
	_refresh_current_target()


func _refresh_current_target() -> void:
	var valid_targets: Array[InteractionTarget] = []
	for target in _targets:
		if not is_instance_valid(target):
			continue
		if not target.is_interaction_available():
			continue
		valid_targets.append(target)

	_targets = valid_targets

	var next_target: InteractionTarget
	var best_distance_squared := INF
	for target in _targets:
		var distance_squared := global_position.distance_squared_to(target.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			next_target = target

	if _current_target == next_target:
		return

	_current_target = next_target
	interaction_target_changed.emit(_current_target)


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
