extends Control

const PLAY_SCENE_PATH := "res://assets/scenes/game/test_movement.tscn"
const CREDITS_SCENE_PATH := "res://assets/scenes/game/credits_scene.tscn"
const SCENE_FADE_OUT_DURATION := 0.75
const SCENE_FADE_IN_DURATION := 0.75
const EXIT_FADE_OUT_DURATION := 0.5
const UINavigation = preload("res://assets/scripts/ui_navigation.gd")
const UiScale := preload("res://assets/scripts/ui_scale.gd")
const MENU_REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const MENU_CONTENT_UNSCALED_SIZE := Vector2(900.0, 888.0)
const MENU_CONTENT_MIN_SCALE := 0.68

@onready var menu_character: Node = get_parent().get_node_or_null("menuEnvironment/character")
@onready var menu_content_scale: Control = $SafeMargin/Layout/MenuContentScale
@onready var sidebar: VBoxContainer = $SafeMargin/Layout/MenuContentScale/Sidebar
@onready var play_button: Button = $SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/PlayButton
@onready var credits_button: Button = $SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/CreditsButton
@onready var options_button: Button = $SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/OptionsButton
@onready var exit_button: Button = $SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/ExitButton
@onready var options_screen: Control = $SafeMargin/Layout/MenuContentScale/OptionsPanel
@onready var confirm_dialog = $ConfirmDialog

@onready var menu_buttons: Array[Button] = [
	$SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/PlayButton,
	$SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/OptionsButton,
	$SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/CreditsButton,
	$SafeMargin/Layout/MenuContentScale/Sidebar/ButtonStack/ExitButton,
]

var _exit_in_progress := false
var _play_in_progress := false
var _credits_in_progress := false
var _ui_transition_locked := false


func _ready() -> void:
	get_viewport().size_changed.connect(_update_menu_content_scale)
	_update_menu_content_scale()
	play_button.pressed.connect(_on_play_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	options_button.pressed.connect(_show_options_screen)
	exit_button.pressed.connect(_on_exit_pressed)
	UINavigation.bind_hover_focus_controls(menu_buttons)

	confirm_dialog.confirmed.connect(_confirm_exit)
	confirm_dialog.canceled.connect(_hide_confirm_dialog)

	options_screen.call("set_focus_enabled", false)
	confirm_dialog.call("hide_dialog")
	_set_button_focus_enabled(menu_buttons, true)
	call_deferred("_focus_first_main_menu_button")


func _unhandled_input(event: InputEvent) -> void:
	if _ui_transition_locked:
		get_viewport().set_input_as_handled()
		return

	if bool(confirm_dialog.call("is_open")):
		if confirm_dialog.call("handle_navigation_input", event):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_hide_confirm_dialog()
		return

	if options_screen.visible and options_screen.call("handle_navigation_input", event):
		get_viewport().set_input_as_handled()
		return

	if options_screen.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_options_screen()
		return

	if UINavigation.handle_linear_navigation_input(event, menu_buttons):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_exit_pressed()


func _on_play_pressed() -> void:
	if _play_in_progress:
		return

	_play_in_progress = true
	if GameSessionState != null:
		GameSessionState.reset_session()
	if LapRaceFlow != null and LapRaceFlow.has_method("reset_state"):
		LapRaceFlow.call("reset_state")
	if RewardService != null and RewardService.has_method("reset_state"):
		RewardService.call("reset_state")
	_begin_ui_transition_lock()
	SceneTransition.preload_scene(PLAY_SCENE_PATH)
	if menu_character != null and menu_character.has_method("stand_up_and_wait"):
		await menu_character.call("stand_up_and_wait")
	else:
		_set_character_standing(true)
	await SceneTransition.fade_out(SCENE_FADE_OUT_DURATION)
	await SceneTransition.change_scene_to_file_from_faded_state(PLAY_SCENE_PATH, SCENE_FADE_IN_DURATION)


func _on_credits_pressed() -> void:
	if _credits_in_progress:
		return

	_credits_in_progress = true
	_begin_ui_transition_lock()
	SceneTransition.preload_scene(CREDITS_SCENE_PATH)
	await SceneTransition.fade_out(SCENE_FADE_OUT_DURATION)
	await SceneTransition.change_scene_to_file_from_faded_state(CREDITS_SCENE_PATH, SCENE_FADE_IN_DURATION)


func _on_exit_pressed() -> void:
	confirm_dialog.call(
		"show_dialog",
		"Exit Game?",
		"Do you want to close the game now?",
		"EXIT GAME",
		"CANCEL"
	)
	_set_button_focus_enabled(menu_buttons, false)
	options_screen.call("set_focus_enabled", false)


func _hide_confirm_dialog() -> void:
	confirm_dialog.call("hide_dialog")

	if options_screen.visible:
		options_screen.call("set_focus_enabled", true)
		options_screen.call("grab_default_focus")
		return

	_set_button_focus_enabled(menu_buttons, true)
	_focus_first_main_menu_button()


func _confirm_exit() -> void:
	if _exit_in_progress:
		return

	_exit_in_progress = true
	_begin_ui_transition_lock()
	confirm_dialog.call("hide_dialog")

	if menu_character != null and menu_character.has_method("play_goodbye"):
		await menu_character.call("play_goodbye")

	await SceneTransition.fade_out(EXIT_FADE_OUT_DURATION)
	get_tree().quit.call_deferred()


func _show_options_screen() -> void:
	sidebar.visible = false
	options_screen.visible = true
	options_screen.call("refresh_from_settings")
	_set_character_standing(false)
	_set_button_focus_enabled(menu_buttons, false)
	options_screen.call("set_focus_enabled", true)
	options_screen.call("grab_default_focus")


func _hide_options_screen() -> void:
	options_screen.visible = false
	sidebar.visible = true
	_set_character_standing(false)
	options_screen.call("set_focus_enabled", false)
	_set_button_focus_enabled(menu_buttons, true)
	_focus_first_main_menu_button()


func _set_button_focus_enabled(buttons: Array[Button], enabled: bool) -> void:
	for button in buttons:
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
			continue

		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _focus_first_main_menu_button() -> void:
	var first_button := UINavigation.get_first_focusable_control(menu_buttons) as Button
	if first_button != null:
		first_button.grab_focus()


func _set_character_standing(active: bool) -> void:
	if menu_character != null and menu_character.has_method("set_standing"):
		menu_character.call("set_standing", active)


func _begin_ui_transition_lock() -> void:
	_ui_transition_locked = true
	_set_button_focus_enabled(menu_buttons, false)
	options_screen.call("set_focus_enabled", false)
	_set_button_mouse_filter(menu_buttons, Control.MOUSE_FILTER_IGNORE)
	get_viewport().gui_release_focus()


func _set_button_mouse_filter(buttons: Array, filter: Control.MouseFilter) -> void:
	for button in buttons:
		if button is Control:
			(button as Control).mouse_filter = filter


func _update_menu_content_scale() -> void:
	if menu_content_scale == null:
		return

	var scale_factor := _compute_menu_content_scale()
	menu_content_scale.scale = Vector2(scale_factor, scale_factor)
	menu_content_scale.pivot_offset = Vector2.ZERO
	menu_content_scale.size = MENU_CONTENT_UNSCALED_SIZE


func _compute_menu_content_scale() -> float:
	var viewport_size := get_viewport_rect().size
	return UiScale.compute_reference_scale(
		viewport_size,
		MENU_REFERENCE_SIZE,
		1.0,
		MENU_CONTENT_MIN_SCALE
	)
