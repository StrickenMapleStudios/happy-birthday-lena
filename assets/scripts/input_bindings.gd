extends Node

const ACTION_KEY_BINDINGS := {
	&"ui_accept": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E],
	&"ui_cancel": [KEY_ESCAPE],
	&"ui_up": [KEY_UP, KEY_W],
	&"ui_down": [KEY_DOWN, KEY_S],
	&"ui_left": [KEY_LEFT, KEY_A],
	&"ui_right": [KEY_RIGHT, KEY_D],
	&"dialogue_advance": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E],
	&"dialogue_select": [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
}


func _enter_tree() -> void:
	_ensure_action_bindings()


func _ensure_action_bindings() -> void:
	for action_name in ACTION_KEY_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		for keycode in ACTION_KEY_BINDINGS[action_name]:
			if _action_has_keycode(action_name, keycode):
				continue
			InputMap.action_add_event(action_name, _build_key_event(keycode))


func _action_has_keycode(action_name: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return true

	return false


func _build_key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event
