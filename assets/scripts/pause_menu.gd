extends CanvasLayer

signal resume_requested
signal main_menu_requested
signal quit_requested
signal exit_dialogue_requested

const ACTION_MAIN_MENU := &"main_menu"
const ACTION_QUIT := &"quit"
const GEAR_ICON := preload("res://assets/art/sprites/gear-icon.png")
const EXIT_ICON := preload("res://assets/art/sprites/exit-icon.png")
const HOME_ICON := preload("res://assets/art/sprites/home.png")

@export var allow_exit_dialogue := false

@onready var menu_root: Control = $MenuRoot
@onready var content_root: Control = (
	$MenuRoot.get_node("SafeMargin/Content")
	if $MenuRoot.has_node("SafeMargin/Content")
	else $MenuRoot.get_node("SafeMargin/VerticalCenter/Content")
)
@onready var button_stack: VBoxContainer = content_root.get_node("Layout/MenuColumn/ButtonStack")
@onready var layout: HBoxContainer = content_root.get_node("Layout")
@onready var menu_column: VBoxContainer = content_root.get_node("Layout/MenuColumn")
@onready var resume_button: Button = content_root.get_node("Layout/MenuColumn/ButtonStack/ResumeButton")
@onready var context_button: Button = content_root.get_node("Layout/MenuColumn/ButtonStack/ContextButton")
@onready var main_menu_button: Button = content_root.get_node("Layout/MenuColumn/ButtonStack/MainMenuButton")
@onready var exit_button: Button = content_root.get_node("Layout/MenuColumn/ButtonStack/ExitButton")
@onready var options_panel: Control = content_root.get_node("OptionsPanel")
@onready var confirm_dialog = $MenuRoot/ConfirmDialog

@onready var menu_buttons: Array[Button] = [
	resume_button,
	context_button,
	main_menu_button,
	exit_button,
]

var _pending_action: StringName = &""
var _mirrored_exit_icon: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_root.visible = false
	_mirrored_exit_icon = _make_mirrored_texture(EXIT_ICON)
	main_menu_button.icon = HOME_ICON
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	context_button.pressed.connect(_on_context_button_pressed)
	main_menu_button.pressed.connect(_prompt_main_menu)
	exit_button.pressed.connect(_prompt_quit)
	confirm_dialog.confirmed.connect(_on_confirmed)
	confirm_dialog.canceled.connect(_on_confirm_canceled)
	options_panel.visible = false
	options_panel.call("set_focus_enabled", false)
	confirm_dialog.call("hide_dialog")


func _unhandled_input(event: InputEvent) -> void:
	if not menu_root.visible:
		return

	if bool(confirm_dialog.call("is_open")):
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_confirm_canceled()
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
	menu_root.visible = true
	_pending_action = &""
	confirm_dialog.call("hide_dialog")
	_configure_context_button()
	_show_main_buttons()


func close() -> void:
	menu_root.visible = false
	_pending_action = &""
	confirm_dialog.call("hide_dialog")
	options_panel.visible = false
	layout.visible = true
	options_panel.call("set_focus_enabled", false)
	_set_button_focus_enabled(menu_buttons, false)


func _show_options() -> void:
	layout.visible = false
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


func _on_context_button_pressed() -> void:
	if allow_exit_dialogue:
		exit_dialogue_requested.emit()
		return

	_show_options()


func _on_confirm_canceled() -> void:
	confirm_dialog.call("hide_dialog")
	_show_main_buttons()


func _show_main_buttons() -> void:
	layout.visible = true
	options_panel.visible = false
	_set_button_focus_enabled(menu_buttons, true)
	options_panel.call("set_focus_enabled", false)
	resume_button.grab_focus()


func _set_button_focus_enabled(buttons: Array[Button], enabled: bool) -> void:
	for button in buttons:
		if not is_instance_valid(button):
			continue
		if not button.visible:
			button.focus_mode = Control.FOCUS_NONE
			continue
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _configure_context_button() -> void:
	context_button.visible = true
	if allow_exit_dialogue:
		context_button.icon = _mirrored_exit_icon
		context_button.text = "EXIT DIALOGUE"
	else:
		context_button.icon = GEAR_ICON
		context_button.text = "OPTIONS"


func _make_mirrored_texture(source: Texture2D) -> ImageTexture:
	var image := source.get_image()
	image.flip_x()
	return ImageTexture.create_from_image(image)
