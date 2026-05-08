extends Control

const CINEMA_SCENE_PATH := "res://assets/scenes/cinema.tscn"

@onready var new_game_button: Button = $SafeMargin/Sidebar/ButtonStack/NewGameButton
@onready var exit_button: Button = $SafeMargin/Sidebar/ButtonStack/ExitButton
@onready var exit_overlay: Control = $ExitOverlay
@onready var cancel_exit_button: Button = $ExitOverlay/DialogCenter/DialogPanel/DialogContent/DialogButtons/CancelExitButton
@onready var confirm_exit_button: Button = $ExitOverlay/DialogCenter/DialogPanel/DialogContent/DialogButtons/ConfirmExitButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	cancel_exit_button.pressed.connect(_hide_exit_overlay)
	confirm_exit_button.pressed.connect(_confirm_exit)


func _unhandled_input(event: InputEvent) -> void:
	if not exit_overlay.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_exit_overlay()


func _on_new_game_pressed() -> void:
	await SceneTransition.change_scene_to_file(CINEMA_SCENE_PATH)


func _on_exit_pressed() -> void:
	exit_overlay.visible = true
	cancel_exit_button.grab_focus()


func _hide_exit_overlay() -> void:
	exit_overlay.visible = false
	exit_button.grab_focus()


func _confirm_exit() -> void:
	get_tree().quit()
