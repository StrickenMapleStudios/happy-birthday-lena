extends Control

const NEW_GAME_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"

@onready var menu_character: Node = get_parent().get_node_or_null("menuEnvironment/character")
@onready var sidebar: VBoxContainer = $SafeMargin/Sidebar
@onready var new_game_button: Button = $SafeMargin/Sidebar/ButtonStack/NewGameButton
@onready var options_button: Button = $SafeMargin/Sidebar/ButtonStack/OptionsButton
@onready var exit_button: Button = $SafeMargin/Sidebar/ButtonStack/ExitButton
@onready var back_button: Button = $BackButton
@onready var options_screen: VBoxContainer = $SafeMargin/OptionsPanel
@onready var save_slot_screen: VBoxContainer = $SafeMargin/SaveSlotScreen
@onready var save_slot_buttons: Array[Button] = [
	$SafeMargin/SaveSlotScreen/SlotList/SaveSlotButton01,
	$SafeMargin/SaveSlotScreen/SlotList/SaveSlotButton02,
	$SafeMargin/SaveSlotScreen/SlotList/SaveSlotButton03,
]
@onready var confirm_dialog = $ConfirmDialog

@onready var menu_buttons: Array[Button] = [
	$SafeMargin/Sidebar/ButtonStack/NewGameButton,
	$SafeMargin/Sidebar/ButtonStack/OptionsButton,
	$SafeMargin/Sidebar/ButtonStack/ExitButton,
]
@onready var save_slot_screen_buttons: Array[Button] = [
	$BackButton,
	$SafeMargin/SaveSlotScreen/SlotList/SaveSlotButton01,
	$SafeMargin/SaveSlotScreen/SlotList/SaveSlotButton02,
	$SafeMargin/SaveSlotScreen/SlotList/SaveSlotButton03,
]

var _exit_in_progress := false
var _slot_selection_locked := false
var _ui_transition_locked := false


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_show_options_screen)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_on_back_pressed)

	for index in save_slot_buttons.size():
		save_slot_buttons[index].pressed.connect(_on_save_slot_pressed.bind(index))
		save_slot_buttons[index].mouse_entered.connect(_sync_hover_focus.bind(save_slot_buttons[index]))

	confirm_dialog.confirmed.connect(_confirm_exit)
	confirm_dialog.canceled.connect(_hide_confirm_dialog)

	options_screen.call("set_focus_enabled", false)
	confirm_dialog.call("hide_dialog")


func _unhandled_input(event: InputEvent) -> void:
	if _ui_transition_locked:
		get_viewport().set_input_as_handled()
		return

	if bool(confirm_dialog.call("is_open")):
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_hide_confirm_dialog()
		return

	if save_slot_screen.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_save_slot_screen()
		return

	if options_screen.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_options_screen()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_exit_pressed()


func _on_new_game_pressed() -> void:
	_show_save_slot_screen()


func _on_save_slot_pressed(_slot_index: int) -> void:
	if _slot_selection_locked:
		return

	_slot_selection_locked = true
	_begin_ui_transition_lock()
	if menu_character != null and menu_character.has_method("stand_up_and_wait"):
		await menu_character.call("stand_up_and_wait")
	else:
		_set_character_standing(true)
	await SceneTransition.change_scene_to_file(NEW_GAME_SCENE_PATH)


func _on_exit_pressed() -> void:
	confirm_dialog.call(
		"show_dialog",
		"Exit Game?",
		"Do you want to close the game now?",
		"EXIT GAME",
		"CANCEL"
	)
	_set_button_focus_enabled(menu_buttons, false)
	_set_button_focus_enabled(save_slot_screen_buttons, false)
	options_screen.call("set_focus_enabled", false)


func _hide_confirm_dialog() -> void:
	confirm_dialog.call("hide_dialog")
	if save_slot_screen.visible:
		_set_button_focus_enabled(save_slot_screen_buttons, true)
		save_slot_buttons[0].grab_focus()
		return

	if options_screen.visible:
		options_screen.call("set_focus_enabled", true)
		options_screen.call("grab_default_focus")
		return

	_set_button_focus_enabled(menu_buttons, true)
	exit_button.grab_focus()


func _confirm_exit() -> void:
	if _exit_in_progress:
		return

	_exit_in_progress = true
	_begin_ui_transition_lock()
	confirm_dialog.call("hide_dialog")

	if menu_character != null and menu_character.has_method("play_goodbye"):
		await menu_character.call("play_goodbye")

	get_tree().quit.call_deferred()


func _show_options_screen() -> void:
	sidebar.visible = false
	save_slot_screen.visible = false
	back_button.visible = true
	options_screen.visible = true
	options_screen.call("refresh_from_settings")
	_set_character_standing(false)
	_set_button_focus_enabled(menu_buttons, false)
	_set_button_focus_enabled(save_slot_screen_buttons, false)
	options_screen.call("set_focus_enabled", true)
	options_screen.call("grab_default_focus")


func _hide_options_screen() -> void:
	back_button.visible = false
	options_screen.visible = false
	sidebar.visible = true
	_set_character_standing(false)
	options_screen.call("set_focus_enabled", false)
	_set_button_focus_enabled(menu_buttons, true)
	options_button.grab_focus()


func _show_save_slot_screen() -> void:
	_slot_selection_locked = false
	_ui_transition_locked = false
	sidebar.visible = false
	options_screen.visible = false
	back_button.visible = true
	save_slot_screen.visible = true
	_set_character_standing(false)
	_restore_menu_interactivity()
	options_screen.call("set_focus_enabled", false)
	_set_button_focus_enabled(menu_buttons, false)
	_set_button_focus_enabled(save_slot_screen_buttons, true)
	save_slot_buttons[0].grab_focus()


func _hide_save_slot_screen() -> void:
	_slot_selection_locked = false
	_ui_transition_locked = false
	back_button.visible = false
	save_slot_screen.visible = false
	sidebar.visible = true
	_set_character_standing(false)
	_restore_menu_interactivity()
	_set_button_focus_enabled(save_slot_screen_buttons, false)
	_set_button_focus_enabled(menu_buttons, true)
	new_game_button.grab_focus()


func _on_back_pressed() -> void:
	if save_slot_screen.visible:
		_hide_save_slot_screen()
		return

	_hide_options_screen()


func _set_button_focus_enabled(buttons: Array[Button], enabled: bool) -> void:
	for button in buttons:
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
			continue

		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _sync_hover_focus(button: Button) -> void:
	if _slot_selection_locked or bool(confirm_dialog.call("is_open")):
		return

	if save_slot_screen.visible:
		button.grab_focus()


func _set_character_standing(active: bool) -> void:
	if menu_character != null and menu_character.has_method("set_standing"):
		menu_character.call("set_standing", active)


func _lock_save_slot_selection() -> void:
	_set_button_focus_enabled(save_slot_screen_buttons, false)
	for button in save_slot_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_release_focus()


func _begin_ui_transition_lock() -> void:
	_ui_transition_locked = true
	_lock_save_slot_selection()
	_set_button_focus_enabled(menu_buttons, false)
	options_screen.call("set_focus_enabled", false)
	_set_button_focus_enabled(save_slot_screen_buttons, false)
	_set_button_mouse_filter(menu_buttons, Control.MOUSE_FILTER_IGNORE)
	_set_button_mouse_filter(save_slot_buttons, Control.MOUSE_FILTER_IGNORE)
	back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_release_focus()


func _restore_menu_interactivity() -> void:
	_set_button_mouse_filter(menu_buttons, Control.MOUSE_FILTER_STOP)
	_set_button_mouse_filter(save_slot_buttons, Control.MOUSE_FILTER_STOP)
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _set_button_mouse_filter(buttons: Array, filter: Control.MouseFilter) -> void:
	for button in buttons:
		if button is Control:
			(button as Control).mouse_filter = filter
