extends VBoxContainer

signal settings_applied(settings: Dictionary)

@onready var resolution_left_button: Button = $OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionLeftButton
@onready var resolution_right_button: Button = $OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionRightButton
@onready var resolution_value_label: Label = $OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionValueLabel
@onready var fullscreen_left_button: Button = $OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenLeftButton
@onready var fullscreen_right_button: Button = $OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenRightButton
@onready var fullscreen_value_label: Label = $OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenValueLabel
@onready var vsync_left_button: Button = $OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncLeftButton
@onready var vsync_right_button: Button = $OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncRightButton
@onready var vsync_value_label: Label = $OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncValueLabel
@onready var language_left_button: Button = $OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageLeftButton
@onready var language_right_button: Button = $OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageRightButton
@onready var language_value_label: Label = $OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageValueLabel
@onready var hints_left_button: Button = $OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsLeftButton
@onready var hints_right_button: Button = $OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsRightButton
@onready var hints_value_label: Label = $OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsValueLabel
@onready var reset_defaults_button: Button = $OptionsFooter/ResetDefaultsButton
@onready var apply_button: Button = $OptionsFooter/ApplyButton

@onready var volume_sliders: Array[HSlider] = [
	$OptionsBody/AudioPanel/AudioContent/MasterVolumeRow/MasterVolumeSlider,
	$OptionsBody/AudioPanel/AudioContent/MusicVolumeRow/MusicVolumeSlider,
	$OptionsBody/AudioPanel/AudioContent/SfxVolumeRow/SfxVolumeSlider,
]
@onready var volume_value_labels: Array[Label] = [
	$OptionsBody/AudioPanel/AudioContent/MasterVolumeRow/MasterVolumeValue,
	$OptionsBody/AudioPanel/AudioContent/MusicVolumeRow/MusicVolumeValue,
	$OptionsBody/AudioPanel/AudioContent/SfxVolumeRow/SfxVolumeValue,
]
@onready var focusable_buttons: Array[Button] = [
	$OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionLeftButton,
	$OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionRightButton,
	$OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenLeftButton,
	$OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenRightButton,
	$OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncLeftButton,
	$OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncRightButton,
	$OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageLeftButton,
	$OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageRightButton,
	$OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsLeftButton,
	$OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsRightButton,
	$OptionsFooter/ResetDefaultsButton,
	$OptionsFooter/ApplyButton,
]

var _pending_settings: Dictionary = {}


func _ready() -> void:
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

	for index in volume_sliders.size():
		volume_sliders[index].value_changed.connect(_on_volume_slider_changed.bind(index))

	GameSettings.settings_applied.connect(_on_settings_applied)
	refresh_from_settings()


func refresh_from_settings() -> void:
	_sync_pending_settings_from_source(GameSettings.get_settings())


func set_focus_enabled(enabled: bool) -> void:
	for button in focusable_buttons:
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
			continue
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func grab_default_focus() -> void:
	if resolution_left_button.disabled:
		resolution_right_button.grab_focus()
		return
	resolution_left_button.grab_focus()


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
	settings_applied.emit(_pending_settings.duplicate(true))


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
