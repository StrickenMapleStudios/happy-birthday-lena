extends Control

signal resume_requested
signal main_menu_requested
signal quit_requested

const ACTION_MAIN_MENU := &"main_menu"
const ACTION_QUIT := &"quit"

@onready var button_stack: VBoxContainer = $SafeMargin/Layout/MenuColumn/ButtonStack
@onready var layout: HBoxContainer = $SafeMargin/Layout
@onready var menu_column: VBoxContainer = $SafeMargin/Layout/MenuColumn
@onready var resume_button: Button = $SafeMargin/Layout/MenuColumn/ButtonStack/ResumeButton
@onready var options_button: Button = $SafeMargin/Layout/MenuColumn/ButtonStack/OptionsButton
@onready var main_menu_button: Button = $SafeMargin/Layout/MenuColumn/ButtonStack/MainMenuButton
@onready var exit_button: Button = $SafeMargin/Layout/MenuColumn/ButtonStack/ExitButton
@onready var back_button: Button = $BackButton
@onready var options_panel: Control = $SafeMargin/OptionsPanel
@onready var confirm_dialog = $ConfirmDialog

@onready var menu_buttons: Array[Button] = [
	$SafeMargin/Layout/MenuColumn/ButtonStack/ResumeButton,
	$SafeMargin/Layout/MenuColumn/ButtonStack/OptionsButton,
	$SafeMargin/Layout/MenuColumn/ButtonStack/MainMenuButton,
	$SafeMargin/Layout/MenuColumn/ButtonStack/ExitButton,
]

var _pending_action: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	options_button.pressed.connect(_show_options)
	main_menu_button.pressed.connect(_prompt_main_menu)
	exit_button.pressed.connect(_prompt_quit)
	back_button.pressed.connect(_hide_options)
	confirm_dialog.confirmed.connect(_on_confirmed)
	confirm_dialog.canceled.connect(_hide_confirm_dialog)
	options_panel.call("set_focus_enabled", false)
	confirm_dialog.call("hide_dialog")
	back_button.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if bool(confirm_dialog.call("is_open")):
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_hide_confirm_dialog()
		return

	if options_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_hide_options()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func open() -> void:
	visible = true
	_pending_action = &""
	confirm_dialog.call("hide_dialog")
	_show_main_buttons()


func close() -> void:
	visible = false
	_pending_action = &""
	confirm_dialog.call("hide_dialog")
	options_panel.visible = false
	layout.visible = true
	back_button.visible = false
	options_panel.call("set_focus_enabled", false)
	_set_button_focus_enabled(menu_buttons, false)


func _show_options() -> void:
	layout.visible = false
	back_button.visible = true
	options_panel.visible = true
	options_panel.call("refresh_from_settings")
	_set_button_focus_enabled(menu_buttons, false)
	options_panel.call("set_focus_enabled", true)
	options_panel.call("grab_default_focus")


func _hide_options() -> void:
	options_panel.visible = false
	_show_main_buttons()


func _prompt_main_menu() -> void:
	_pending_action = ACTION_MAIN_MENU
	confirm_dialog.call(
		"show_dialog",
		"Return To Main Menu?",
		"Your current gameplay session will be interrupted.",
		"MAIN MENU",
		"CANCEL"
	)
	_set_button_focus_enabled(menu_buttons, false)
	options_panel.call("set_focus_enabled", false)


func _prompt_quit() -> void:
	_pending_action = ACTION_QUIT
	confirm_dialog.call(
		"show_dialog",
		"Exit Game?",
		"Do you want to close the game now?",
		"EXIT GAME",
		"CANCEL"
	)
	_set_button_focus_enabled(menu_buttons, false)
	options_panel.call("set_focus_enabled", false)


func _hide_confirm_dialog() -> void:
	confirm_dialog.call("hide_dialog")
	if options_panel.visible:
		options_panel.call("set_focus_enabled", true)
		options_panel.call("grab_default_focus")
		return
	_show_main_buttons()


func _on_confirmed() -> void:
	confirm_dialog.call("hide_dialog")
	match _pending_action:
		ACTION_MAIN_MENU:
			main_menu_requested.emit()
		ACTION_QUIT:
			quit_requested.emit()


func _show_main_buttons() -> void:
	layout.visible = true
	back_button.visible = false
	options_panel.visible = false
	_set_button_focus_enabled(menu_buttons, true)
	options_panel.call("set_focus_enabled", false)
	resume_button.grab_focus()


func _set_button_focus_enabled(buttons: Array[Button], enabled: bool) -> void:
	for button in buttons:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
