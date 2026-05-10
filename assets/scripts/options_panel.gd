extends Control

signal settings_applied(settings: Dictionary)

@onready var resolution_left_button: Button = $Content/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionLeftButton
@onready var resolution_right_button: Button = $Content/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionRightButton
@onready var resolution_value_label: Label = $Content/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionValueLabel
@onready var fullscreen_left_button: Button = $Content/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenLeftButton
@onready var fullscreen_right_button: Button = $Content/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenRightButton
@onready var fullscreen_value_label: Label = $Content/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenValueLabel
@onready var vsync_left_button: Button = $Content/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncLeftButton
@onready var vsync_right_button: Button = $Content/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncRightButton
@onready var vsync_value_label: Label = $Content/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncValueLabel
@onready var language_left_button: Button = $Content/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageLeftButton
@onready var language_right_button: Button = $Content/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageRightButton
@onready var language_value_label: Label = $Content/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageValueLabel
@onready var hints_left_button: Button = $Content/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsLeftButton
@onready var hints_right_button: Button = $Content/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsRightButton
@onready var hints_value_label: Label = $Content/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsValueLabel
@onready var reset_defaults_button: Button = $Content/OptionsFooter/ResetDefaultsButton
@onready var apply_button: Button = $Content/OptionsFooter/ApplyButton

@onready var volume_sliders: Array[HSlider] = [
	$Content/OptionsBody/AudioPanel/AudioContent/MasterVolumeRow/MasterVolumeSlider,
	$Content/OptionsBody/AudioPanel/AudioContent/MusicVolumeRow/MusicVolumeSlider,
	$Content/OptionsBody/AudioPanel/AudioContent/SfxVolumeRow/SfxVolumeSlider,
]
@onready var volume_value_labels: Array[Label] = [
	$Content/OptionsBody/AudioPanel/AudioContent/MasterVolumeRow/MasterVolumeValue,
	$Content/OptionsBody/AudioPanel/AudioContent/MusicVolumeRow/MusicVolumeValue,
	$Content/OptionsBody/AudioPanel/AudioContent/SfxVolumeRow/SfxVolumeValue,
]
@onready var focusable_buttons: Array[Button] = [
	$Content/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionLeftButton,
	$Content/OptionsBody/DisplayPanel/DisplayContent/ResolutionRow/ResolutionPicker/ResolutionRightButton,
	$Content/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenLeftButton,
	$Content/OptionsBody/DisplayPanel/DisplayContent/FullscreenRow/FullscreenPicker/FullscreenRightButton,
	$Content/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncLeftButton,
	$Content/OptionsBody/DisplayPanel/DisplayContent/VsyncRow/VsyncPicker/VsyncRightButton,
	$Content/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageLeftButton,
	$Content/OptionsBody/GameplayPanel/GameplayContent/LanguageRow/LanguagePicker/LanguageRightButton,
	$Content/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsLeftButton,
	$Content/OptionsBody/GameplayPanel/GameplayContent/HintsRow/HintsPicker/HintsRightButton,
	$Content/OptionsFooter/ResetDefaultsButton,
	$Content/OptionsFooter/ApplyButton,
]

var _pending_settings: Dictionary = {}
var _navigation_rows: Array = []


func _ready() -> void:
	_apply_slider_theme()
	_navigation_rows = [
		[resolution_left_button, resolution_right_button],
		[fullscreen_left_button, fullscreen_right_button],
		[vsync_left_button, vsync_right_button],
		[language_left_button, language_right_button],
		[hints_left_button, hints_right_button],
		[reset_defaults_button, apply_button],
	]

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


func handle_navigation_input(event: InputEvent) -> bool:
	if not visible:
		return false

	var focus_position := _get_focus_position()
	if focus_position.x < 0:
		grab_default_focus()
		return true

	if event.is_action_pressed(&"ui_up"):
		return _move_focus_vertical(focus_position, -1)

	if event.is_action_pressed(&"ui_down"):
		return _move_focus_vertical(focus_position, 1)

	if event.is_action_pressed(&"ui_left"):
		return _move_focus_horizontal(focus_position, -1)

	if event.is_action_pressed(&"ui_right"):
		return _move_focus_horizontal(focus_position, 1)

	return false


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


func _apply_slider_theme() -> void:
	var grabber: Texture2D = _make_slider_grabber(Color(1, 1, 1, 1))
	var grabber_disabled: Texture2D = _make_slider_grabber(Color(0.72, 0.72, 0.72, 1))

	for slider in volume_sliders:
		slider.add_theme_icon_override("grabber", grabber)
		slider.add_theme_icon_override("grabber_highlight", grabber)
		slider.add_theme_icon_override("grabber_disabled", grabber_disabled)


func _make_slider_grabber(color: Color) -> ImageTexture:
	var size: int = 20
	var radius: float = 7.0
	var center: Vector2 = Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)

	image.fill(Color(0, 0, 0, 0))

	for y in range(size):
		for x in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


func _get_focus_position() -> Vector2i:
	var focus_owner := get_viewport().gui_get_focus_owner()
	for row_index in _navigation_rows.size():
		var row: Array = _navigation_rows[row_index]
		for column_index in row.size():
			if row[column_index] == focus_owner:
				return Vector2i(row_index, column_index)

	return Vector2i(-1, -1)


func _move_focus_vertical(focus_position: Vector2i, direction: int) -> bool:
	var row_index := focus_position.x + direction
	while row_index >= 0 and row_index < _navigation_rows.size():
		var row: Array = _navigation_rows[row_index]
		var target_column := mini(focus_position.y, row.size() - 1)
		var target := row[target_column] as Control
		if _can_focus_control(target):
			target.grab_focus()
			return true
		row_index += direction

	return false


func _move_focus_horizontal(focus_position: Vector2i, direction: int) -> bool:
	var row: Array = _navigation_rows[focus_position.x]
	var column_index := focus_position.y + direction
	while column_index >= 0 and column_index < row.size():
		var target := row[column_index] as Control
		if _can_focus_control(target):
			target.grab_focus()
			return true
		column_index += direction

	return false


func _can_focus_control(control: Control) -> bool:
	return control != null and is_instance_valid(control) and control.visible and control.focus_mode != Control.FOCUS_NONE
