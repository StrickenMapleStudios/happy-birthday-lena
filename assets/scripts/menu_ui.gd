extends Control

const CINEMA_SCENE_PATH := "res://assets/scenes/cinema.tscn"

@onready var new_game_button: Button = $SafeMargin/Sidebar/ButtonStack/NewGameButton
@onready var options_button: Button = $SafeMargin/Sidebar/ButtonStack/OptionsButton
@onready var exit_button: Button = $SafeMargin/Sidebar/ButtonStack/ExitButton
@onready var back_button: Button = $BackButton
@onready var sidebar: VBoxContainer = $SafeMargin/Sidebar
@onready var options_screen: VBoxContainer = $SafeMargin/OptionsScreen

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
@onready var apply_button: Button = $SafeMargin/OptionsScreen/OptionsFooter/ApplyButton

@onready var exit_overlay: Control = $ExitOverlay
@onready var exit_backdrop: ColorRect = $ExitOverlay/Backdrop
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

@onready var menu_buttons: Array[Button] = [
	$SafeMargin/Sidebar/ButtonStack/ContinueButton,
	$SafeMargin/Sidebar/ButtonStack/NewGameButton,
	$SafeMargin/Sidebar/ButtonStack/OptionsButton,
	$SafeMargin/Sidebar/ButtonStack/ExitButton,
]
@onready var options_buttons: Array[Button] = [
	$BackButton,
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
	$SafeMargin/OptionsScreen/OptionsFooter/ApplyButton,
]

var _pending_settings: Dictionary = {}


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
	apply_button.pressed.connect(_apply_options)

	cancel_exit_button.pressed.connect(_hide_exit_overlay)
	confirm_exit_button.pressed.connect(_confirm_exit)
	cancel_exit_button.mouse_entered.connect(_sync_hover_focus.bind(cancel_exit_button))
	confirm_exit_button.mouse_entered.connect(_sync_hover_focus.bind(confirm_exit_button))

	for index in volume_sliders.size():
		volume_sliders[index].value_changed.connect(_on_volume_slider_changed.bind(index))

	GameSettings.settings_applied.connect(_on_settings_applied)
	_sync_pending_settings_from_source(GameSettings.get_settings())


func _unhandled_input(event: InputEvent) -> void:
	if not exit_overlay.visible:
		if options_screen.visible and event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_hide_options_screen()
		elif event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_show_exit_overlay()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_exit_overlay()


func _on_new_game_pressed() -> void:
	await SceneTransition.change_scene_to_file(CINEMA_SCENE_PATH)


func _on_exit_pressed() -> void:
	_show_exit_overlay()


func _show_exit_overlay() -> void:
	_set_button_focus_enabled(menu_buttons, false)
	_set_button_focus_enabled(options_buttons, false)
	exit_backdrop.visible = true
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
	_sync_pending_settings_from_source(GameSettings.get_settings())
	sidebar.visible = false
	back_button.visible = true
	options_screen.visible = true
	_set_button_focus_enabled(menu_buttons, false)
	_set_button_focus_enabled(options_buttons, true)
	back_button.grab_focus()


func _hide_options_screen() -> void:
	back_button.visible = false
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


func _on_volume_slider_changed(value: float, index: int) -> void:
	volume_value_labels[index].text = "%d%%" % int(round(value))

	match index:
		0:
			_pending_settings["audio"]["master_volume"] = value
		1:
			_pending_settings["audio"]["music_volume"] = value
		2:
			_pending_settings["audio"]["sfx_volume"] = value


func _cycle_resolution(direction: int) -> void:
	var current_index: int = int(_pending_settings["display"]["resolution_index"])
	_pending_settings["display"]["resolution_index"] = clampi(
		current_index + direction,
		0,
		GameSettings.RESOLUTION_OPTIONS.size() - 1
	)
	_refresh_option_views()


func _toggle_fullscreen() -> void:
	_pending_settings["display"]["fullscreen"] = not bool(_pending_settings["display"]["fullscreen"])
	_refresh_option_views()


func _toggle_vsync() -> void:
	_pending_settings["display"]["vsync"] = not bool(_pending_settings["display"]["vsync"])
	_refresh_option_views()


func _cycle_language(direction: int) -> void:
	var current_language: String = str(_pending_settings["gameplay"]["language"])
	var current_index: int = max(GameSettings.LANGUAGE_OPTIONS.find(current_language), 0)
	var next_index: int = posmod(current_index + direction, GameSettings.LANGUAGE_OPTIONS.size())
	_pending_settings["gameplay"]["language"] = GameSettings.LANGUAGE_OPTIONS[next_index]
	_refresh_option_views()


func _toggle_hints() -> void:
	_pending_settings["gameplay"]["tutorial_hints"] = not bool(_pending_settings["gameplay"]["tutorial_hints"])
	_refresh_option_views()


func _reset_options_to_defaults() -> void:
	_sync_pending_settings_from_source({
		"audio": {
			"master_volume": 100.0,
			"music_volume": 80.0,
			"sfx_volume": 90.0,
		},
		"display": {
			"resolution_index": 2,
			"fullscreen": true,
			"vsync": true,
		},
		"gameplay": {
			"language": "ENGLISH",
			"tutorial_hints": true,
		},
	})


func _apply_options() -> void:
	GameSettings.apply_settings(_pending_settings)


func _on_settings_applied(settings: Dictionary) -> void:
	_sync_pending_settings_from_source(settings)


func _sync_pending_settings_from_source(source_settings: Dictionary) -> void:
	_pending_settings = source_settings.duplicate(true) as Dictionary

	volume_sliders[0].value = float(_pending_settings["audio"]["master_volume"])
	volume_sliders[1].value = float(_pending_settings["audio"]["music_volume"])
	volume_sliders[2].value = float(_pending_settings["audio"]["sfx_volume"])
	_refresh_option_views()


func _refresh_option_views() -> void:
	var resolution_index: int = int(_pending_settings["display"]["resolution_index"])
	var resolution: Vector2i = GameSettings.RESOLUTION_OPTIONS[resolution_index]

	resolution_value_label.text = "%d x %d" % [resolution.x, resolution.y]
	fullscreen_value_label.text = _on_off_text(bool(_pending_settings["display"]["fullscreen"]))
	vsync_value_label.text = _on_off_text(bool(_pending_settings["display"]["vsync"]))
	language_value_label.text = str(_pending_settings["gameplay"]["language"])
	hints_value_label.text = _on_off_text(bool(_pending_settings["gameplay"]["tutorial_hints"]))

	resolution_left_button.disabled = resolution_index == 0
	resolution_right_button.disabled = resolution_index == GameSettings.RESOLUTION_OPTIONS.size() - 1


func _on_off_text(value: bool) -> String:
	return "ON" if value else "OFF"
