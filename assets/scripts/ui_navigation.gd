extends RefCounted

class_name UINavigation


static func bind_hover_focus_controls(controls: Array) -> void:
	for control_variant in controls:
		var control := control_variant as Control
		bind_hover_focus_control(control)


static func bind_hover_focus_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return

	var on_hover_callable := Callable(UINavigation, "_grab_hover_focus").bind(control)
	if control.mouse_entered.is_connected(on_hover_callable):
		return

	control.mouse_entered.connect(on_hover_callable)


static func get_first_focusable_control(controls: Array) -> Control:
	var active_controls := _get_active_controls(controls)
	if active_controls.is_empty():
		return null
	return active_controls[0]


static func handle_linear_navigation_input(event: InputEvent, controls: Array) -> bool:
	var active_controls := _get_active_controls(controls)
	if active_controls.is_empty():
		return false

	var current_index := _get_focused_index(active_controls)
	if current_index < 0:
		current_index = 0

	if is_previous_input(event):
		active_controls[posmod(current_index - 1, active_controls.size())].grab_focus()
		return true

	if is_next_input(event):
		active_controls[posmod(current_index + 1, active_controls.size())].grab_focus()
		return true

	return false


static func handle_grid_navigation_input(event: InputEvent, rows: Array) -> bool:
	var active_rows := _get_active_rows(rows)
	if active_rows.is_empty():
		return false

	var focus_position := _get_grid_focus_position(active_rows)
	if focus_position.x < 0:
		var first_control: Control = active_rows[0][0]
		first_control.grab_focus()
		return true

	if is_up_input(event):
		return _move_grid_vertical(active_rows, focus_position, -1)
	if is_down_input(event):
		return _move_grid_vertical(active_rows, focus_position, 1)
	if is_left_input(event):
		return _move_grid_horizontal(active_rows, focus_position, -1)
	if is_right_input(event):
		return _move_grid_horizontal(active_rows, focus_position, 1)

	return false


static func handle_digit_focus_input(event: InputEvent, controls: Array) -> bool:
	var active_controls := _get_active_controls(controls)
	if active_controls.is_empty():
		return false

	var digit_index := get_pressed_digit_index(event)
	if digit_index < 0 or digit_index >= active_controls.size():
		return false

	active_controls[digit_index].grab_focus()
	return true


static func is_previous_input(event: InputEvent) -> bool:
	return is_up_input(event) or is_left_input(event)


static func is_next_input(event: InputEvent) -> bool:
	return is_down_input(event) or is_right_input(event)


static func is_up_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_up"):
		return true
	return _is_key_pressed(event, [KEY_W])


static func is_down_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_down"):
		return true
	return _is_key_pressed(event, [KEY_S])


static func is_left_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_left"):
		return true
	return _is_key_pressed(event, [KEY_A])


static func is_right_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_right"):
		return true
	return _is_key_pressed(event, [KEY_D])


static func get_pressed_digit_index(event: InputEvent) -> int:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return -1

	match event.keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
		KEY_6, KEY_KP_6:
			return 5
		KEY_7, KEY_KP_7:
			return 6
		KEY_8, KEY_KP_8:
			return 7
		KEY_9, KEY_KP_9:
			return 8

	return -1


static func _is_key_pressed(event: InputEvent, keycodes: Array[Key]) -> bool:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return false

	return keycodes.has(event.keycode)


static func _grab_hover_focus(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if not control.visible:
		return
	if control.focus_mode == Control.FOCUS_NONE:
		return
	if control is BaseButton and (control as BaseButton).disabled:
		return

	var viewport := control.get_viewport()
	if viewport == null:
		return

	var focus_owner := viewport.gui_get_focus_owner()
	if focus_owner == control:
		return

	if focus_owner != null:
		viewport.gui_release_focus()
	control.grab_focus()


static func _get_active_controls(controls: Array) -> Array[Control]:
	var active_controls: Array[Control] = []
	for control_variant in controls:
		var control := control_variant as Control
		if control == null or not is_instance_valid(control):
			continue
		if not control.visible:
			continue
		if control.focus_mode == Control.FOCUS_NONE:
			continue
		active_controls.append(control)

	return active_controls


static func _get_focused_index(controls: Array[Control]) -> int:
	var viewport := controls[0].get_viewport()
	var focus_owner := viewport.gui_get_focus_owner()
	for index in controls.size():
		if controls[index] == focus_owner:
			return index

	return -1


static func _get_active_rows(rows: Array) -> Array:
	var active_rows: Array = []
	for row_variant in rows:
		var row_controls := _get_active_controls(row_variant as Array)
		if not row_controls.is_empty():
			active_rows.append(row_controls)

	return active_rows


static func _get_grid_focus_position(rows: Array) -> Vector2i:
	var focus_owner := (rows[0][0] as Control).get_viewport().gui_get_focus_owner()
	for row_index in rows.size():
		var row: Array[Control] = rows[row_index]
		for column_index in row.size():
			if row[column_index] == focus_owner:
				return Vector2i(row_index, column_index)

	return Vector2i(-1, -1)


static func _move_grid_vertical(rows: Array, focus_position: Vector2i, direction: int) -> bool:
	var row_index := focus_position.x
	for _attempt in rows.size():
		row_index = posmod(row_index + direction, rows.size())
		var row: Array[Control] = rows[row_index]
		var target_column := mini(focus_position.y, row.size() - 1)
		var target: Control = row[target_column]
		if target != null:
			target.grab_focus()
			return true

	return false


static func _move_grid_horizontal(rows: Array, focus_position: Vector2i, direction: int) -> bool:
	var row: Array[Control] = rows[focus_position.x]
	var column_index := focus_position.y
	for _attempt in row.size():
		column_index = posmod(column_index + direction, row.size())
		var target: Control = row[column_index]
		if target != null:
			target.grab_focus()
			return true

	return false
