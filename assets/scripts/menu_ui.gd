extends Control

const CINEMA_SCENE_PATH := "res://assets/scenes/cinema.tscn"

@onready var new_game_button: Button = $SafeMargin/Sidebar/ButtonStack/NewGameButton
@onready var options_button: Button = $SafeMargin/Sidebar/ButtonStack/OptionsButton
@onready var exit_button: Button = $SafeMargin/Sidebar/ButtonStack/ExitButton
@onready var sidebar: VBoxContainer = $SafeMargin/Sidebar
@onready var options_screen: VBoxContainer = $SafeMargin/OptionsScreen
@onready var back_button: Button = $SafeMargin/OptionsScreen/BackButton
@onready var exit_overlay: Control = $ExitOverlay
@onready var exit_backdrop: ColorRect = $ExitOverlay/Backdrop
@onready var menu_buttons: Array[Button] = [
	$SafeMargin/Sidebar/ButtonStack/ContinueButton,
	$SafeMargin/Sidebar/ButtonStack/NewGameButton,
	$SafeMargin/Sidebar/ButtonStack/OptionsButton,
	$SafeMargin/Sidebar/ButtonStack/ExitButton,
]
@onready var options_buttons: Array[Button] = [
	$SafeMargin/OptionsScreen/BackButton,
	$SafeMargin/OptionsScreen/OptionsFooter/ResetDefaultsButton,
	$SafeMargin/OptionsScreen/OptionsFooter/CreditsButton,
	$SafeMargin/OptionsScreen/OptionsFooter/ApplyButton,
]
@onready var cancel_exit_button: Button = $ExitOverlay/DialogCenter/DialogPanel/DialogContent/DialogButtons/CancelExitButton
@onready var confirm_exit_button: Button = $ExitOverlay/DialogCenter/DialogPanel/DialogContent/DialogButtons/ConfirmExitButton
@onready var volume_sliders: Array[HSlider] = [
	$SafeMargin/OptionsScreen/OptionsBody/AudioPanel/AudioContent/MasterVolumeRow/MasterVolumeSlider,
	$SafeMargin/OptionsScreen/OptionsBody/AudioPanel/AudioContent/MusicVolumeRow/MusicVolumeSlider,
	$SafeMargin/OptionsScreen/OptionsBody/AudioPanel/AudioContent/SfxVolumeRow/SfxVolumeSlider,
]
@onready var volume_value_labels: Array[Label] = [
	$SafeMargin/OptionsScreen/OptionsBody/AudioPanel/AudioContent/MasterVolumeRow/MasterVolumeValue,
	$SafeMargin/OptionsScreen/OptionsBody/AudioPanel/AudioContent/MusicVolumeRow/MusicVolumeValue,
	$SafeMargin/OptionsScreen/OptionsBody/AudioPanel/AudioContent/SfxVolumeRow/SfxVolumeValue,
]


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_show_options_screen)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_hide_options_screen)
	cancel_exit_button.pressed.connect(_hide_exit_overlay)
	confirm_exit_button.pressed.connect(_confirm_exit)
	cancel_exit_button.mouse_entered.connect(_sync_hover_focus.bind(cancel_exit_button))
	confirm_exit_button.mouse_entered.connect(_sync_hover_focus.bind(confirm_exit_button))

	for index in volume_sliders.size():
		volume_sliders[index].value_changed.connect(_update_volume_label.bind(volume_value_labels[index]))


func _unhandled_input(event: InputEvent) -> void:
	if not exit_overlay.visible:
		if options_screen.visible and event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_hide_options_screen()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_exit_overlay()


func _on_new_game_pressed() -> void:
	await SceneTransition.change_scene_to_file(CINEMA_SCENE_PATH)


func _on_exit_pressed() -> void:
	_set_button_focus_enabled(menu_buttons, false)
	_set_button_focus_enabled(options_buttons, false)
	exit_overlay.visible = true
	confirm_exit_button.grab_focus()


func _hide_exit_overlay() -> void:
	exit_overlay.visible = false
	if options_screen.visible:
		_set_button_focus_enabled(options_buttons, true)
		back_button.grab_focus()
		return

	_set_button_focus_enabled(menu_buttons, true)
	exit_button.grab_focus()


func _confirm_exit() -> void:
	exit_backdrop.visible = false
	exit_overlay.visible = false
	get_tree().quit.call_deferred()


func _show_options_screen() -> void:
	sidebar.visible = false
	options_screen.visible = true
	_set_button_focus_enabled(menu_buttons, false)
	_set_button_focus_enabled(options_buttons, true)
	back_button.grab_focus()


func _hide_options_screen() -> void:
	options_screen.visible = false
	sidebar.visible = true
	_set_button_focus_enabled(options_buttons, false)
	_set_button_focus_enabled(menu_buttons, true)
	options_button.grab_focus()


func _set_button_focus_enabled(buttons: Array[Button], enabled: bool) -> void:
	for button in buttons:
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
			continue

		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _sync_hover_focus(button: Button) -> void:
	if exit_overlay.visible:
		button.grab_focus()


func _update_volume_label(value: float, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(value))
