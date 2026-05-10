extends RefCounted

class_name UINavigation


static func handle_linear_navigation_input(event: InputEvent, controls: Array[Button]) -> bool:
	var active_controls := _get_active_controls(controls)
	if active_controls.is_empty():
		return false

	var current_index := _get_focused_index(active_controls)
	if current_index < 0:
		current_index = 0

	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left"):
		active_controls[maxi(current_index - 1, 0)].grab_focus()
		return true

	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right"):
		active_controls[mini(current_index + 1, active_controls.size() - 1)].grab_focus()
		return true

	return false


static func _get_active_controls(controls: Array[Button]) -> Array[Button]:
	var active_controls: Array[Button] = []
	for control in controls:
		if control == null or not is_instance_valid(control):
			continue
		if not control.visible:
			continue
		if control.focus_mode == Control.FOCUS_NONE:
			continue
		active_controls.append(control)

	return active_controls


static func _get_focused_index(controls: Array[Button]) -> int:
	var viewport := controls[0].get_viewport()
	var focus_owner := viewport.gui_get_focus_owner()
	for index in controls.size():
		if controls[index] == focus_owner:
			return index

	return -1
