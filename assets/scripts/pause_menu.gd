extends CanvasLayer

signal resume_requested
signal main_menu_requested
signal quit_requested

const ACTION_MAIN_MENU := &"main_menu"
const ACTION_QUIT := &"quit"
const GEAR_ICON := preload("res://assets/art/sprites/gear-icon.png")
const HOME_ICON := preload("res://assets/art/sprites/home.png")
const UINavigation = preload("res://assets/scripts/ui_navigation.gd")
const UiScale := preload("res://assets/scripts/ui_scale.gd")
const REFERENCE_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)
const CONTENT_MIN_SCALE := 0.72
const VERTICAL_OFFSET_FROM_CENTER := 56.0

@onready var menu_root: Control = $MenuRoot
@onready var vertical_center: Control = $MenuRoot.get_node("SafeMargin/VerticalCenter")
@onready var content_root: Control = $MenuRoot.get_node("SafeMargin/VerticalCenter/Content")
@onready var button_stack: VBoxContainer = content_root.get_node("MenuColumn/ButtonStack")
@onready var menu_column: VBoxContainer = content_root.get_node("MenuColumn")
@onready var resume_button: Button = content_root.get_node("MenuColumn/ButtonStack/ResumeButton")
@onready var options_button: Button = content_root.get_node("MenuColumn/ButtonStack/ContextButton")
@onready var main_menu_button: Button = content_root.get_node("MenuColumn/ButtonStack/MainMenuButton")
@onready var exit_button: Button = content_root.get_node("MenuColumn/ButtonStack/ExitButton")
@onready var options_panel: Control = $MenuRoot.get_node("SafeMargin/VerticalCenter/OptionsPanel")
@onready var confirm_dialog = $MenuRoot/ConfirmDialog

@onready var menu_buttons: Array[Button] = [
	resume_button,
	options_button,
	main_menu_button,
	exit_button,
]

var _pending_action: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_update_vertical_layout)
	menu_root.visible = false
	main_menu_button.icon = HOME_ICON
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	options_button.pressed.connect(_show_options)
	main_menu_button.pressed.connect(_prompt_main_menu)
	exit_button.pressed.connect(_prompt_quit)
	confirm_dialog.confirmed.connect(_on_confirmed)
	confirm_dialog.canceled.connect(_on_confirm_canceled)
	UINavigation.bind_hover_focus_controls(menu_buttons)
	options_panel.visible = false
	options_panel.call("set_focus_enabled", false)
	confirm_dialog.call("hide_dialog")


func _unhandled_input(event: InputEvent) -> void:
	if not menu_root.visible:
		return

	if bool(confirm_dialog.call("is_open")):
		if confirm_dialog.call("handle_navigation_input", event):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_confirm_canceled()
		return

	if options_panel.visible and options_panel.call("handle_navigation_input", event):
		get_viewport().set_input_as_handled()
		return

	if options_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_hide_options()
		return

	if UINavigation.handle_linear_navigation_input(event, menu_buttons):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func open() -> void:
	menu_root.visible = true
	_pending_action = &""
	confirm_dialog.call("hide_dialog")
	_show_main_buttons()
	call_deferred("_update_vertical_layout")


func close() -> void:
	menu_root.visible = false
	_pending_action = &""
	confirm_dialog.call("hide_dialog")
	options_panel.visible = false
	content_root.visible = true
	options_panel.call("set_focus_enabled", false)
	_set_button_focus_enabled(menu_buttons, false)


func _show_options() -> void:
	content_root.visible = false
	options_panel.visible = true
	options_panel.call("refresh_from_settings")
	_set_button_focus_enabled(menu_buttons, false)
	options_panel.call("set_focus_enabled", true)
	options_panel.call("grab_default_focus")
	call_deferred("_update_vertical_layout")


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


func _on_confirmed() -> void:
	confirm_dialog.call("hide_dialog")
	match _pending_action:
		ACTION_MAIN_MENU:
			main_menu_requested.emit()
		ACTION_QUIT:
			quit_requested.emit()


func _on_confirm_canceled() -> void:
	confirm_dialog.call("hide_dialog")
	_show_main_buttons()


func _show_main_buttons() -> void:
	content_root.visible = true
	options_panel.visible = false
	_set_button_focus_enabled(menu_buttons, true)
	options_panel.call("set_focus_enabled", false)
	resume_button.grab_focus()
	call_deferred("_update_vertical_layout")


func _set_button_focus_enabled(buttons: Array[Button], enabled: bool) -> void:
	for button in buttons:
		if not is_instance_valid(button):
			continue
		if not button.visible:
			button.focus_mode = Control.FOCUS_NONE
			continue
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _update_vertical_layout() -> void:
	_center_panel_vertically(content_root)
	_center_panel_vertically(options_panel)


func _center_panel_vertically(panel: Control) -> void:
	if panel == null:
		return

	if panel == content_root:
		_update_panel_scale(panel)

	var target_size := _get_panel_base_size(panel)
	var scaled_size := _get_panel_scaled_size(panel, target_size)
	panel.size = target_size
	panel.position = Vector2(
		0.0,
		maxf(((vertical_center.size.y - scaled_size.y) * 0.5) - VERTICAL_OFFSET_FROM_CENTER, 0.0)
	)


func _update_panel_scale(panel: Control) -> void:
	var scale_factor := UiScale.compute_reference_scale(
		get_viewport_rect().size,
		REFERENCE_VIEWPORT_SIZE,
		1.0,
		CONTENT_MIN_SCALE
	)
	panel.scale = Vector2(scale_factor, scale_factor)


func _get_panel_base_size(panel: Control) -> Vector2:
	if panel == options_panel and panel.has_method("get_scaled_size"):
		return panel.size
	return panel.get_combined_minimum_size()


func _get_panel_scaled_size(panel: Control, base_size: Vector2) -> Vector2:
	if panel == options_panel and panel.has_method("get_scaled_size"):
		return panel.call("get_scaled_size")
	return UiScale.get_control_scaled_size(panel, base_size)
