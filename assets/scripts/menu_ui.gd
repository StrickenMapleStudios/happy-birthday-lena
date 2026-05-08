extends Control

const CINEMA_SCENE_PATH := "res://assets/scenes/cinema.tscn"
const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const LANGUAGE_OPTIONS: Array[String] = ["ENGLISH", "RUSSIAN"]
const DEFAULT_MASTER_VOLUME := 100.0
const DEFAULT_MUSIC_VOLUME := 80.0
const DEFAULT_SFX_VOLUME := 90.0

@onready var new_game_button: Button = $SafeMargin/Sidebar/ButtonStack/NewGameButton
@onready var options_button: Button = $SafeMargin/Sidebar/ButtonStack/OptionsButton
@onready var exit_button: Button = $SafeMargin/Sidebar/ButtonStack/ExitButton
@onready var sidebar: VBoxContainer = $SafeMargin/Sidebar
@onready var options_screen: VBoxContainer = $SafeMargin/OptionsScreen
@onready var back_button: Button = $SafeMargin/OptionsScreen/BackButton
@onready var resolution_left_button: Button = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionLeftButton
@onready var resolution_right_button: Button = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionRightButton
@onready var resolution_value_label: Label = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionValueLabel
@onready var fullscreen_left_button: Button = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenLeftButton
@onready var fullscreen_right_button: Button = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenRightButton
@onready var fullscreen_value_label: Label = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenValueLabel
@onready var vsync_left_button: Button = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncLeftButton
@onready var vsync_right_button: Button = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncRightButton
@onready var vsync_value_label: Label = $SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncValueLabel
@onready var language_left_button: Button = $SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageLeftButton
@onready var language_right_button: Button = $SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageRightButton
@onready var language_value_label: Label = $SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageValueLabel
@onready var hints_left_button: Button = $SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsLeftButton
@onready var hints_right_button: Button = $SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsRightButton
@onready var hints_value_label: Label = $SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsValueLabel
@onready var reset_defaults_button: Button = $SafeMargin/OptionsScreen/OptionsFooter/ResetDefaultsButton
@onready var credits_button: Button = $SafeMargin/OptionsScreen/OptionsFooter/CreditsButton
@onready var apply_button: Button = $SafeMargin/OptionsScreen/OptionsFooter/ApplyButton
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
	$SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionLeftButton,
	$SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionRightButton,
	$SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenLeftButton,
	$SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenRightButton,
	$SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncLeftButton,
	$SafeMargin/OptionsScreen/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncRightButton,
	$SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageLeftButton,
	$SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageRightButton,
	$SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsLeftButton,
	$SafeMargin/OptionsScreen/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsRightButton,
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

var selected_resolution_index := 0
var pending_fullscreen := false
var pending_vsync := true
var selected_language_index := 0
var pending_tutorial_hints := true


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_show_options_screen)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_hide_options_screen)
	resolution_left_button.pressed.connect(_cycle_resolution.bind(-1))
	resolution_right_button.pressed.connect(_cycle_resolution.bind(1))
	fullscreen_left_button.pressed.connect(_toggle_fullscreen)
	fullscreen_right_button.pressed.connect(_toggle_fullscreen)
	vsync_left_button.pressed.connect(_toggle_vsync)
	vsync_right_button.pressed.connect(_toggle_vsync)
	language_left_button.pressed.connect(_cycle_language.bind(-1))
	language_right_button.pressed.connect(_cycle_language.bind(1))
	hints_left_button.pressed.connect(_toggle_hints)
	hints_right_button.pressed.connect(_toggle_hints)
	reset_defaults_button.pressed.connect(_reset_options_to_defaults)
	credits_button.pressed.connect(_show_credits)
	apply_button.pressed.connect(_apply_options)
	cancel_exit_button.pressed.connect(_hide_exit_overlay)
	confirm_exit_button.pressed.connect(_confirm_exit)
	cancel_exit_button.mouse_entered.connect(_sync_hover_focus.bind(cancel_exit_button))
	confirm_exit_button.mouse_entered.connect(_sync_hover_focus.bind(confirm_exit_button))

	for index in volume_sliders.size():
		volume_sliders[index].value_changed.connect(_update_volume_label.bind(volume_value_labels[index]))

	_load_current_options()
	_refresh_option_button_texts()


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


func _load_current_options() -> void:
	selected_resolution_index = _find_resolution_index(get_window().size)
	pending_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	pending_vsync = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	selected_language_index = 0
	pending_tutorial_hints = true


func _refresh_option_button_texts() -> void:
	var resolution := RESOLUTION_OPTIONS[selected_resolution_index]
	resolution_value_label.text = "%d x %d" % [resolution.x, resolution.y]
	fullscreen_value_label.text = _on_off_text(pending_fullscreen)
	vsync_value_label.text = _on_off_text(pending_vsync)
	language_value_label.text = LANGUAGE_OPTIONS[selected_language_index]
	hints_value_label.text = _on_off_text(pending_tutorial_hints)
	resolution_left_button.disabled = selected_resolution_index == 0
	resolution_right_button.disabled = selected_resolution_index == RESOLUTION_OPTIONS.size() - 1


func _cycle_resolution(direction: int) -> void:
	selected_resolution_index = posmod(selected_resolution_index + direction, RESOLUTION_OPTIONS.size())
	_refresh_option_button_texts()


func _toggle_fullscreen() -> void:
	pending_fullscreen = not pending_fullscreen
	_refresh_option_button_texts()


func _toggle_vsync() -> void:
	pending_vsync = not pending_vsync
	_refresh_option_button_texts()


func _cycle_language(direction: int) -> void:
	selected_language_index = posmod(selected_language_index + direction, LANGUAGE_OPTIONS.size())
	_refresh_option_button_texts()


func _toggle_hints() -> void:
	pending_tutorial_hints = not pending_tutorial_hints
	_refresh_option_button_texts()


func _reset_options_to_defaults() -> void:
	volume_sliders[0].value = DEFAULT_MASTER_VOLUME
	volume_sliders[1].value = DEFAULT_MUSIC_VOLUME
	volume_sliders[2].value = DEFAULT_SFX_VOLUME
	selected_resolution_index = _find_resolution_index(Vector2i(1920, 1080))
	pending_fullscreen = true
	pending_vsync = true
	selected_language_index = 0
	pending_tutorial_hints = true
	_refresh_option_button_texts()


func _apply_options() -> void:
	var window := get_window()
	var resolution := RESOLUTION_OPTIONS[selected_resolution_index]

	if pending_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		window.size = resolution

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if pending_vsync else DisplayServer.VSYNC_DISABLED
	)

	if pending_fullscreen:
		window.size = resolution


func _show_credits() -> void:
	credits_button.text = "LENA / OPENAI"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(credits_button):
		credits_button.text = "CREDITS"


func _find_resolution_index(target: Vector2i) -> int:
	for index in RESOLUTION_OPTIONS.size():
		if RESOLUTION_OPTIONS[index] == target:
			return index

	return 2


func _on_off_text(value: bool) -> String:
	return "ON" if value else "OFF"
