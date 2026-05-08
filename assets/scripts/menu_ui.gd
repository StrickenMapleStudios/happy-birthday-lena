extends Control

const CINEMA_SCENE_PATH := "res://assets/scenes/cinema.tscn"

@onready var new_game_button: Button = $SafeMargin/Sidebar/ButtonStack/NewGameButton
@onready var exit_button: Button = $SafeMargin/Sidebar/ButtonStack/ExitButton
@onready var exit_overlay: Control = $ExitOverlay
@onready var exit_backdrop: ColorRect = $ExitOverlay/Backdrop
@onready var menu_buttons: Array[Button] = [
	$SafeMargin/Sidebar/ButtonStack/ContinueButton,
	$SafeMargin/Sidebar/ButtonStack/NewGameButton,
	$SafeMargin/Sidebar/ButtonStack/OptionsButton,
	$SafeMargin/Sidebar/ButtonStack/ExitButton,
]
@onready var cancel_exit_button: Button = $ExitOverlay/DialogCenter/DialogPanel/DialogContent/DialogButtons/CancelExitButton
@onready var confirm_exit_button: Button = $ExitOverlay/DialogCenter/DialogPanel/DialogContent/DialogButtons/ConfirmExitButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	cancel_exit_button.pressed.connect(_hide_exit_overlay)
	confirm_exit_button.pressed.connect(_confirm_exit)
	cancel_exit_button.mouse_entered.connect(_sync_hover_focus.bind(cancel_exit_button))
	confirm_exit_button.mouse_entered.connect(_sync_hover_focus.bind(confirm_exit_button))


func _unhandled_input(event: InputEvent) -> void:
	if not exit_overlay.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_exit_overlay()


func _on_new_game_pressed() -> void:
	await SceneTransition.change_scene_to_file(CINEMA_SCENE_PATH)


func _on_exit_pressed() -> void:
	_set_menu_focus_enabled(false)
	exit_overlay.visible = true
	confirm_exit_button.grab_focus()


func _hide_exit_overlay() -> void:
	exit_overlay.visible = false
	_set_menu_focus_enabled(true)
	exit_button.grab_focus()


func _confirm_exit() -> void:
	exit_backdrop.visible = false
	exit_overlay.visible = false
	get_tree().quit.call_deferred()


func _set_menu_focus_enabled(enabled: bool) -> void:
	for button in menu_buttons:
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
			continue

		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _sync_hover_focus(button: Button) -> void:
	if exit_overlay.visible:
		button.grab_focus()
